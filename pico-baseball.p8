pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- pico baseball
-- by @nucleartide

#include utils.p8

-- assert(false, 'review game design outline in notion')
-- assert(false, 'start updating the ball-strike count.')

local left_wall = vec3_normalize2(vec3(1, 0, -1))
local right_wall = vec3_normalize2(vec3(-1, 0, -1))

ball_hit_z_range = 2 -- hit if ball is within 2.5 units on the z axis.
ball_hit_y_range = 3 -- hit if ball is within 3 units on the y axis.
ball_catch_radius = 2 -- catch if ball is within 2.5 units.
-- note that ball_hit_z_range and ball_catch_radius should add to 5.
debug = true
rel_to_home_plate_x = 7
half_diagonal = 50 -- in world units.
game2real = 64/50 -- baseball field dimensions are scaled down from reality to keep gameplay tight together.
real2game = 50/64

ball_is_foul = 'foul'
ball_is_home_run = 'home run'
ball_is_in_field = 'in field'

function in_game_bounds(v)
    -- z values.
    -- local behind_field_corner = (-113 * real2game) - half_diagonal
    local home_plate = -half_diagonal
    local in_front_field_corner = 389
    -- local in_front_field_corner = 100

    local home_run_line = -abs(x) + in_front_field_corner
    local foul_line = v.x + home_plate

    local is_foul = v.z < foul_line
    if is_foul then
        return ball_is_foul
    end

    local is_home_run = v.z >= home_run_line
    if is_home_run then
        return ball_is_home_run
    end

    return ball_is_in_field
end

--[[

]]

-->8
-- static objects.

function draw_base(v, r, c)
    local sx, sy = world2screen(v)
    circfill(sx, sy, r or 4, c or 7)
end

function draw_box(box, flip, omit_top)
    local sx1, sy1 = world2screen(box[1], nil, flip)
    local sx2, sy2 = world2screen(box[2], nil, flip)
    local sx3, sy3 = world2screen(box[3], nil, flip)
    local sx4, sy4 = world2screen(box[4], nil, flip)
    if (not omit_top) line(sx1, sy1, sx2, sy2, 7)
    line(sx2, sy2, sx3, sy3, 7)
    line(sx3, sy3, sx4, sy4, 7)
    line(sx4, sy4, sx1, sy1, 7)
end

-->8
-- player.

function player(pos, player_num)
    return {
        pos = pos,
        h = 10,
        side = 2, -- half a side.
        player_num = player_num, -- note that this can be nil.
    }
end

function move_player(p)
    local player_num = p.player_num
    if player_num~=nil then
        if btn(0, player_num) then
            p.pos.x -= 1
        end
        if btn(1, player_num) then
            p.pos.x += 1
        end
        if btn(2, player_num) then
            p.pos.z += 1
        end
        if btn(3, player_num) then
            p.pos.z -= 1
        end
    end
end

function draw_player(p, force_pos, c)
	local sx, sy = world2screen(force_pos or p.pos)
    rectfill(sx-p.side, sy-p.h+1, sx+p.side, sy, c or 8)
	return sx, sy
end

-->8
-- fielder.

function fielder(pos, player_num, _ball, _is_catcher)
    fielder_fielding = 0
    fielder_selecting_action = 1
    pitcher_selecting_pitch = 2
    pitcher_selecting_endpoint = 3

    return assign(player(pos, player_num), {
        -- ...
    })
end

function get_fielder_midpoint(f)
    return vec3(f.pos.x, f.h*.5, f.pos.z)
end

function update_fielder_fielding(f)
    -- if z is pressed,
    -- player_num is not nil (so it's a human player),
    -- and player has the ball,
    if (
        f.player_num ~= nil and
        btn(4, f.player_num) and
        f.ball ~= nil
    ) then
        -- transition state.
        f.state = fielder_selecting_action
    end

    -- otherwise allow movement.
    move_player(f)
end

function update_fielder_when_selecting_action(f)

    if (f.player_num==nil) return

    --
    -- handle arrow keys first.
    --

    -- clamp to ensure selected action index is a valid index.
    local actions = get_actions_for_fielder(f)
    f.selected_action_index = mid(1, f.selected_action_index, #actions)

    -- given input, update selected action index.
    if btnp(0, f.player_num) then f.selected_action_index -= 1 end
    if btnp(1, f.player_num) then f.selected_action_index += 1 end

    -- mod to wraparound index.
    f.selected_action_index -= 1
    f.selected_action_index %= #actions
    f.selected_action_index += 1

    --
    -- handle action buttons.
    --

    -- if releasing button, then go back to fielding state.
    if btnr(4, f.player_num) then
        f.state = fielder_fielding
        f.selected_action_index = -1
        return
    end

    -- if pressing x, then perform action.
    if btnp(5, f.player_num) then
        local action = actions[f.selected_action_index]
        action.on_action(f, action)
        return
    end
end

function update_pitcher_selecting_pitch(f, pitch_actions)
    assert(pitch_actions~=nil)

    -- todo: be able to update select using left and right arrow buttons.

    -- clamp to ensure selected action index is a valid index.
    local actions = pitch_actions
    f.selected_action_index = mid(1, f.selected_action_index, #actions)

    -- given input, update selected action index.
    if btnp(0, f.player_num) then f.selected_action_index -= 1 end
    if btnp(1, f.player_num) then f.selected_action_index += 1 end

    -- mod to wraparound index.
    f.selected_action_index -= 1
    f.selected_action_index %= #actions
    f.selected_action_index += 1

    if btnp(5, f.player_num) then
        f.state = pitcher_selecting_endpoint
    end
end

function update_pitcher_selecting_endpoint(f, on_throw)
    if btn(0) then
        f.reticle.x -= 1
    end
    if btn(1) then
        f.reticle.x += 1
    end
    if btn(2) then
        f.reticle.y += 1
    end
    if btn(3) then
        f.reticle.y -= 1
    end

    if btnp(5, f.player_num) then
        -- throw the ball, taking the reticle's position as the destination
        -- position.
        local dest_pos = worldspace(f.dest.pos, f.reticle)

        -- throw the ball.
        throw_ball(f.ball, f.pos, dest_pos, f.dest)

        -- unset ownership of the ball.
        f.ball = nil

        f.state = fielder_fielding
    end
end

function update_fielder(f)
    if f.player_num==nil then
        return
    end

    if btnp(4, f.player_num) and ball1.is_owned_by==f then
        throw_ball(ball1, f.pitches[1])
        ball1.is_owned_by = nil
    end
end

function get_actions_for_fielder(f)
    if f.state == pitcher_selecting_pitch then
        return pitch_actions
    else
        return throw_actions
    end
end

-->8
-- batter.

batter_batting = 0
batter_charging = 1
batter_swinging = 2
batter_running_unsafe = 3
batter_running_safe = 4
batter_swinging_ball_was_hit = 5

-- goal for today: get this bat drawn and animated.
function batter(x, z, player_num, handedness)
    -- determine the rel_to_home_plate_pos.
    handedness = handedness or 'right'
    local relx = handedness=='right' and -rel_to_home_plate_x or rel_to_home_plate_x
    local player_obj = player(vec3(x, 0, z), player_num)

    return assign(player_obj, {
        -- state of player.
        state = batter_batting,

        -- 'left' | 'right'
        -- determines the batter box side.
        handedness = handedness,

        -- relative to home_plate_pos.
        -- this is where the batter stands at home plate.
        rel_to_home_plate_pos = vec3(relx, 0, 0),
        init_relx = relx,

        -- data representation of a held bat.
        -- pivot --- bat_knob ===== bat_end
        pivot = vec3(3.5, player_obj.h*.5, 0),
        pivot_to_bat_knob_len = .5,
        bat_knob_to_bat_end_len = 5,
        bat_z_angle = -.125, -- apply this rotation first.
        bat_aim_angle = 0, -- use this to determine swing axis.
        bat_swing_angle = 0, -- angle around swing axis.
        -- get_swing_axis
        reticle_z_angle = .25,
        -- rotated_knob = nil
        -- rotated_bat_end = nil

        -- bat animation fields.
        t = 0,
        charging_anim_len = 10, -- cycle every 10 frames.
        swing_anim_len = .25*60, -- half a second.

        -- relative to get_batter_half_body_worldspace.
        -- bat_aim_vec = vec3(bat_aim_x, 0, 0),

        --
        -- run fields.
        --

        -- 4 or 5, indicating whether z or x was last pressed while running.
        -- last_button_pressed = nil,

        -- current base that the batter is on. [1,4].
        -- current_base = 1,
    })
end

function get_batter_worldspace(b, home_plate_pos)
    assert(home_plate_pos~=nil)
    return worldspace(home_plate_pos, b.rel_to_home_plate_pos)
end

--[[
function get_batter_half_body_worldspace(b)
    local pos = get_batter_worldspace(b)
    pos.y = b.h/2
    return pos
end

function get_batter_aim_pos(b)
    return worldspace(
        get_batter_half_body_worldspace(b),
        b.bat_aim_vec
    )
end
]]

function update_batter(b)
    if b.player_num==nil then
        return
    end

    -- hold x to charge.
    if b.state==batter_batting and btnp(4, b.player_num) then
        b.state = batter_charging
        return
    end

    -- if player is charging,
    if b.state==batter_charging and btn(4, b.player_num) then
        -- move the reticle up and down.
        if btn(2, b.player_num) then
            b.reticle_z_angle -= 0.01
        elseif btn(3, b.player_num) then
            b.reticle_z_angle += 0.01
        end
        b.reticle_z_angle = clamp(b.reticle_z_angle, .125, .375)

        -- move the batter left and right.
        if btn(0, b.player_num) then
            b.rel_to_home_plate_pos.x -= 0.1
        end
        if btn(1, b.player_num) then
            b.rel_to_home_plate_pos.x += 0.1
        end
        b.rel_to_home_plate_pos.x = clamp(b.rel_to_home_plate_pos.x, b.init_relx - 2.5, b.init_relx + 2.5)

        -- cycle the animation timer.
        b.t = (b.t + 1)%b.charging_anim_len
    end

    -- release x to swing.
    if b.state==batter_charging and btnr(4, b.player_num) then
        b.state = batter_swinging
        b.t = 0
        return
    end

    -- if player is swinging,
    if b.state==batter_swinging or b.state==batter_swinging_ball_was_hit then
        -- update the swing timer.
        b.t += 1

        -- check whether the bat is in "hit" range.
        local t = b.t / b.swing_anim_len
        local in_range, xt = in_swing_range(b.rotated_knob, b.rotated_bat_end, ball1, b, t)

        if in_range and ball1.state == ball_throwing then
            handle_ball_hit(b.rotated_knob, b.rotated_bat_end, ball1, b, t)
        elseif b.t >= b.swing_anim_len then
            -- if ball was not hit, increment strikes.
            if b.state==batter_swinging then
                log('strike!')
                num_strikes += 1
            end

            -- swing is done, reset the bat's swinging state.
            b.t = 0
            b.state = batter_batting
        end
    end

    -- compute the bat knob and bat end locatinos.
    compute_bat_knob_and_end_points(b)
end

function in_swing_range(bat_knob, bat_end, ball, batter, swing_t)
    assert(ball~=nil)
    assert(batter~=nil)
    assert(swing_t~=nil)

    bat_knob, bat_end = get_batter_bat_worldspace(batter)

    -- find the t value of the ball in the x-axis.
    local ball_pos = ball.pos
    local a = batter.handedness=='right' and bat_knob or bat_end
    local b = batter.handedness=='right' and bat_end  or bat_knob
    local xt = inverse_lerp(ball_pos.x, a.x, b.x)

    -- is in swing timing.
    local in_swing_timing = .3<swing_t and swing_t<.7

    -- is in x range.
    local is_in_x_range = 0<=xt and xt<=1

    -- determine the y position of the bat.
    local is_in_y_range
    do
        local m = (b.y-a.y) / (b.x-a.x)
        local x = ball_pos.x - a.x
        local b = a.y
        local y = m*x + b

        -- is in y range.
        is_in_y_range = abs(y - ball_pos.y) < ball_hit_y_range -- sign should be useful for lift of the ball.
    end

    local is_in_z_range
    do
        local m = (b.z-a.z) / (b.x-a.x)
        local x = ball_pos.z - a.z
        local b = a.z
        local z = m*x + b
        is_in_z_range = abs(z - ball_pos.z) < ball_hit_z_range
    end

    return in_swing_timing and is_in_x_range and is_in_y_range and is_in_z_range, xt
end

function handle_ball_hit(bat_knob, bat_end, ball, batter, xt)
    log('ball was hit')
    assert(ball~=nil)
    assert(batter~=nil)
    batter.state = batter_swinging_ball_was_hit

    local ball_pos = ball.pos

        -- set state of ball.
        ball.state = ball_idle_physical_obj

        -- determine the pivot in world space.
        local world_pos = get_batter_worldspace(batter, bases[1])
        local pivot_pos = worldspace(world_pos, batter.pivot)

        -- determine the ball vector relative to pivot.
        local ball_in_pivot_space = vec3_sub(ball_pos, pivot_pos)

        -- determine the bat vector relative to pivot.
        local rotated_knob = batter.rotated_knob
        local rotated_bat_end = batter.rotated_bat_end

        -- determine the bat vector normalized relative to pivot. this is the bat direction.
        local bat_direction = vec3_normalize2(rotated_bat_end)

        -- compute the dot product of both ball and bat vectors. this gives the magnitude of projection.
        local magnitude_of_projection = vec3_dot(ball_in_pivot_space, bat_direction)

        -- multiply the magnitude and bat direction to get the projection vector.
        local projection_vector = vec3_mul(bat_direction, magnitude_of_projection)
        vec3_print(ball_in_pivot_space, true)
        vec3_print(projection_vector, true)

        -- compute the projection-to-ball vector, and normalize.
        local direction_vector = vec3_sub(ball_in_pivot_space, projection_vector)
        vec3_print(direction_vector, true)
        direction_vector = vec3_normalize2(direction_vector)
        vec3_print(direction_vector, true)

        -- set the ball's velocity to some arbitrary velocity for now. and test!
        ball.vel.x = direction_vector.x * xt * 200
        ball.vel.y = direction_vector.y * xt * 200
        ball.vel.z = abs(direction_vector.z) * xt * 200
end

function compute_bat_knob_and_end_points(b)
    -- compute the knob point.
    local knob = vec3()
    knob.y += b.pivot_to_bat_knob_len

    -- compute the end point.
    local bat_end = vec3_set(vec3(), knob)
    bat_end.y += b.bat_knob_to_bat_end_len

    -- rotate depending on batter state.
    if b.state==batter_swinging then
        -- determine the swing axis.
        local swing_axis = rotate_angle_axis(vec3(0,1,0), b.reticle_z_angle + .25, vec3(0,0,1))

        -- determine the swing angle.
        local swing_angle = 1 - b.t / b.swing_anim_len

        -- rotate the bat to the correct starting z angle.
        local bat_starting_angle = b.reticle_z_angle + .5
        local rotated_knob = rotate_angle_axis(knob, bat_starting_angle, vec3(0,0,1))
        local rotated_bat_end = rotate_angle_axis(bat_end, bat_starting_angle, vec3(0,0,1))

        -- then, rotate the bat around the swing axis based on the current t.
        b.rotated_knob = rotate_angle_axis(rotated_knob, swing_angle, swing_axis)
        b.rotated_bat_end = rotate_angle_axis(rotated_bat_end, swing_angle, swing_axis)
    else
        -- elseif b.state==batter_batting or b.state==batter_charging then
        -- determine points for bat_knob and bat_end.
        local angle = b.bat_z_angle
        b.rotated_knob = rotate_angle_axis(knob, angle, vec3(0, 0, 1))
        b.rotated_bat_end = rotate_angle_axis(bat_end, angle, vec3(0, 0, 1))
    end
end

function get_batter_bat_worldspace(b)
    local world_pos = get_batter_worldspace(b, bases[1])
    local pivot_pos = worldspace(world_pos, b.pivot)
    local knob_pos = worldspace(pivot_pos, b.rotated_knob)
    local bat_end_pos = worldspace(pivot_pos, b.rotated_bat_end)
    return knob_pos, bat_end_pos
end

function draw_batter(b)
    -- precondition.
    assert(bases[1].x~=nil)

    -- draw the player body.
    draw_player(b, get_batter_worldspace(b, bases[1]))

    -- determine the pivot around which the bat swings.
    local knob_pos, bat_end_pos = get_batter_bat_worldspace(b)

    -- draw the player's bat.
    local sx1, sy1 = world2screen(knob_pos)
    local sx2, sy2 = world2screen(bat_end_pos)
    for i=1,2 do
        line(sx1, sy1+i, sx2, sy2+i, 9)
    end

    -- draw the reticle.
    if b.state == batter_charging then
        -- compute.
        local angle = b.reticle_z_angle
        local bat_end = vec3(0, b.pivot_to_bat_knob_len + b.bat_knob_to_bat_end_len, 0)
        local rotated_reticle = rotate_angle_axis(bat_end, angle, vec3(0, 0, 1))
        local world_pos = get_batter_worldspace(b, bases[1])
        local pivot_pos = worldspace(world_pos, b.pivot)

        -- draw.

        if debug then
            local downward = vec3_set(vec3(), rotated_reticle)
            downward.y -= ball_hit_y_range
            local sx, sy = world2screen(worldspace(pivot_pos, downward))
            circ(sx, sy, 1, 11)
        end

        if debug then
            local forward = vec3_set(vec3(), rotated_reticle)
            forward.z += ball_hit_z_range
            local sx, sy = world2screen(worldspace(pivot_pos, forward))
            circ(sx, sy, 1, 10)
        end

        local sx, sy = world2screen(worldspace(pivot_pos, rotated_reticle))
        circ(sx, sy+2, 2, 9)

        if debug then
            local upward = vec3_set(vec3(), rotated_reticle)
            upward.y += ball_hit_y_range
            local sx, sy = world2screen(worldspace(pivot_pos, upward))
            circ(sx, sy, 1, 11)
        end

        if debug then
            local backward = vec3_set(vec3(), rotated_reticle)
            backward.z -= ball_hit_z_range
            local sx, sy = world2screen(worldspace(pivot_pos, backward))
            circ(sx, sy, 1, 10)
        end
    end
end

-->8
-- fielder action.

-- x,y,z: local space position.
-- ch: if applicable, the character that should be displayed for this action.
-- parent_pos: the parent position that this action is displayed relative to.
-- on_action: callback that will be executed should this action be selected. accepts a fielder.
function fielder_action(x,y,z,ch,parent_pos,on_action)
    assert(parent_pos~=nil)
    assert(on_action~=nil)

    return {
        parent_pos = parent_pos, -- the parent vec3 that this action should be drawn relative to.
        pos = vec3(x,y,z), -- local space vec3.

        -- display characteristics.
        -- currently just used for prototyping.
        ch = ch,
        c = 8,

        -- class identifier.
        fielder_action = true,

        -- the behavior that will execute upon action selection.
        on_action = on_action,
    }
end

-- draw the action as a ui element in world space.
function fielder_action_draw(p,player1)
    assert(player1~=nil)
    local new_pos = vec3_set(vec3(), player1.pos)
    vec3_add_to(new_pos, p.pos)
    local sx, sy = world2screen(new_pos)
    sx -= 3
    sy -= 3
    print(p.ch, sx, sy, p.c)
end

-- draw a selection circle around the action.
function fielder_action_draw_select(pa)
    assert(pa.pos~=nil)

    -- if there is a parent_pos, then create a custom pos
    local worldspace
    if pa.parent_pos~=nil then
        worldspace = vec3_set(vec3(), pa.parent_pos)
        vec3_add_to(worldspace, pa.pos)
    else
        worldspace = pa.pos
    end

    local sx, sy = world2screen(worldspace)
    circ(sx, sy, 4, 9)
end

-->8
-- pitcher.

-- x,z: position
-- v1,v2,v3,v4: pitch trajectory for a test pitch
-- player_num: input controller index
-- ball: the ball, if pitcher is holding
-- actions: list of actions that can be performed by pitcher
function pitcher(pos, v1, v2, v3, v4, player_num)
    return assign(fielder(pos, player_num), {
        -- the pitcher's arsenal of pitches.
        -- just one test pitch for now.
        pitches = {
            cubic_bezier(v1, v2, v3, v4),
        },
    })
end

function update_pitcher(p)
    update_fielder(p)
end

function pitcher_draw(p)
    local sx, sy = draw_player(p)

    --[[ -- may need this.
    if p.state==pitcher_selecting_endpoint then
        -- draw strike box.
        do
            local sx, sy = world2screen(p.dest.pos)
            local height = 10
            local half_width = 4
            local y_offset = 1
            rect(sx-half_width, sy-height+1+y_offset, sx+half_width, sy+y_offset, 6)
        end

        -- draw the reticle for the fielder being thrown to.
        local sx, sy = world2screen(worldspace(p.dest.pos, p.reticle))
        circ(sx, sy, 2, c)
    end
    ]]
end

-->8
-- ball.

ball_holding = 0
ball_throwing = 1
ball_idle_physical_obj = 2

function ball(pos, initial_state, is_owned_by)
    assert(is_owned_by~=nil)
    return {
        -- physical properties.
        pos = vec3_set(vec3(), pos),
        vel = vec3(),
        acc = vec3_mul(vec3(0, gravity, 0), 1/60),

        -- the fielder that is holding the ball.
        -- will be used soon.
        is_owned_by = is_owned_by,

        -- throw animation.
        t = 0, -- timer field used for animation.
        throw_duration = -1, -- this is dynamically set elsewhere.

        -- state of the ball.
        state = initial_state,

        -- populated when thrown. of type cubic_bezier.
        trajectory = nil,

        -- whether a first bounce has been seen.
        -- reset upon returning the ball to the pitcher.
        has_bounced = false,
    }
end

function simulate_as_rigidbody(b, fielders)
    -- declare some state.
    local spare1, spare2 = vec3(), vec3()

    -- update velocity.
    vec3_add_to(b.vel, b.acc)
    if (b.vel.y<gravity) b.vel.y=gravity -- clamp velocity to bound.

    -- update position.
    vec3_set(spare1, b.vel)
    vec3_mul(spare1, 1/60)
    vec3_add_to(b.pos, spare1)

    -- handle bounces.
    if (b.pos.y<0) then
        log('ball has bounced: ' .. flr(b.pos.x) .. ',' .. flr(b.pos.y) .. ',' .. flr(b.pos.z))

        -- constrain.
        b.pos.y=0

        -- add bounce velocity in the reverse direction.
        b.vel.y *= -0.5

        -- attenuate the x and z velocities.
        b.vel.x *= 0.8
        b.vel.z *= 0.8

        evaluate_bounce(b)
    end
end

home_run_y_threshold = 5

-- todo: how do i reset the ball?
function evaluate_bounce(ball)
    local result = in_game_bounds(ball.pos)
    if not ball.has_bounced then
        if result == ball_is_foul then
            if num_strikes < 2 then
                log('strike!') assert(false)
                num_strikes += 1
            end
        elseif result == ball_is_home_run then
            log('home run!') assert(false)
            num_runs += 1
        end
    else
        if result == ball_is_home_run then
            if ball.pos.y > home_run_y_threshold then
                log('ground rule double') assert(false)
            else
                ball.vel.x = 0
                ball.vel.y = 0
                ball.vel.z = 0
            end
        end
    end
end

function reset_ball_state(ball1)
    log('resetting ball state.')
    ball1.has_bounced = false
end

function check_for_foul_ball(ball1)
    -- get the ball's z.
    z = ball1.pos.z

    -- check if the computed z is less than the
    -- equation of the foul line.
    -- z = m * x + b
    local m = 1
    local x = ball1.pos.x
    local b = -half_diagonal
    z_line = m * x + b
    return z < z_line -- foul lines are still fair
end

function throw_ball(b, trajectory)
    -- set trajectory.
    b.trajectory = trajectory

    -- set animation.
    b.t = 0
    b.throw_duration = (distance2(trajectory[1], trajectory[4]) / 200) * 60

    -- set state.
    b.state = ball_throwing
end

function return_ball_to_pitcher(b, fielder, pitcher)
    local start = get_fielder_midpoint(fielder)
    local _end = get_fielder_midpoint(pitcher)

    -- reset ball state.
    reset_ball_state(b)

    -- set trajectory.
    b.trajectory = cubic_bezier(
        start,
        vec3_lerp_into(start, _end, vec3(), .33),
        vec3_lerp_into(start, _end, vec3(), .67),
        _end
    )

    -- set animation.
    b.t = 0
    b.throw_duration = (distance2(start, _end) / 50) * 60

    -- set state.
    b.state = ball_throwing
end

function pick_up_ball_if_nearby(b, fielders)
    assert(#fielders>0)
    for f in all(fielders) do
        local d = distance2(get_fielder_midpoint(f), b.pos, nil, nil, nil)
        if d<ball_catch_radius then
            b.state = ball_holding
            b.is_owned_by = f

            if f==catcher1 then
                log('ball was caught')

                -- x should be -2.5 to 2.5 for strike.
                -- y should be 2.5 to 7.5 for strike.
                local half_strike_zone = 2.5
                local xl, xr = -half_strike_zone, half_strike_zone
                local yb, yt = 5 - half_strike_zone, 5 + half_strike_zone
                local x = b.pos.x
                local y = b.pos.y
                if xl<=x and x<=xr and yb<=y and y<=yt then
                    log('strrrrrike!')
                    num_strikes += 1
                else
                    log('ball!')
                    num_balls += 1
                end

                -- after 1s, catcher throws the ball back.
                delay(function()
                    log('ball is returned')
                    b.is_owned_by = nil
                    return_ball_to_pitcher(b, f, pitcher1)
                end, 60)
            end
        end
    end
end

function animate_thrown_ball(b)
    -- update the ball's position.
    local t = b.t / b.throw_duration
    cubic_bezier_fixed_sample(100, b.trajectory, t, b.pos)

    -- if the ball has been thrown, then
    if t>.2 then
        -- check whether any fielders are around to catch.
        -- can filter out by is_owned_by
        assert(fielders~=nil)
        pick_up_ball_if_nearby(b, fielders)
    end

    -- increment timer for next frame.
    b.t += 1
end

-- set the position of the ball if the ball is held.
function hold_ball(b, fielders)
    assert(fielders~=nil)
    for f in all(fielders) do
        if f.ball==b then
            local raised = vec3_set(vec3(), f.pos)
            raised.y = 5
            vec3_set(b.pos, raised)
        end
    end
end

function draw_ball(p, draw_shadow)
    local sx, sy = world2screen(p.pos)
    if draw_shadow then
        local shadow_x, shadow_y = world2screen(p.pos, true)
        circfill(shadow_x, shadow_y, 2, 5)
    end
    circfill(sx, sy, 2, 7)
end

-->8
-- reticle.

function reticle(x, y, z)
    return vec3(x, y, z)
end

function reticle_update(r, player_num)
    assert(player_num~=nil)
    if btn(0, player_num) then
        r.x -= 1
    end
    if btn(1, player_num) then
        r.x += 1
    end
    if btn(2, player_num) then
        r.y += 1
    end
    if btn(3, player_num) then
        r.y -= 1
    end
    if r.y<0 then r.y=0 end
end

-->8
-- umpire.

function umpire(x, z)
    return {
        pos = vec3(x, 0, z),
        t = 0,
        sign_display_len = 2*60,
        display_text = 'safe', -- 'safe' | 'out'
        h = 8,
        side = 2,
    }
end

function draw_umpire(u)
    draw_player(u, nil, 1)
end

-->8
-- game state.

function init_game()
    bases = {
        vec3(0, 0, -half_diagonal), -- home
        vec3(half_diagonal, 0, 0), -- 1st
        vec3(0, 0, half_diagonal), -- 2nd
        vec3(-half_diagonal, 0, 0), -- 3rd
    }

    pitchers_mound = vec3()

    -- should be flipped for lefty's batter box.
    batters_box = {
        vec3(-10, 0, -half_diagonal+5),
        vec3(-4, 0, -half_diagonal+5),
        vec3(-4, 0, -half_diagonal-2.5),
        vec3(-10, 0, -half_diagonal-2.5),
    }

    catchers_box = {
        vec3(-7, 0, -half_diagonal-2.5),
        vec3(7, 0, -half_diagonal-2.5),
        vec3(7, 0, -half_diagonal-10),
        vec3(-7, 0, -half_diagonal-10),
    }

    raised_pitcher_mound = vec3_set(vec3(), pitchers_mound)
    raised_pitcher_mound.y += 5

    raised_home_plate = vec3_set(vec3(), bases[1])
    raised_home_plate.y += 5

    pitcher1 = pitcher(
        vec3(),
        raised_pitcher_mound,
        vec3_lerp_into(raised_pitcher_mound, raised_home_plate, vec3(), .33),
        vec3_lerp_into(raised_pitcher_mound, raised_home_plate, vec3(), .67),
        raised_home_plate,
        0
    )

    do
        local catcher_pos = vec3_set(vec3(), bases[1])
        catcher_pos.z -= 8
        catcher1 = fielder(catcher_pos, nil)
    end

    gravity = -50

    ball1 = ball(raised_pitcher_mound, ball_holding, pitcher1)

    fielders = {catcher1, pitcher1}

    batter1 = batter(-10, bases[1].z, 1, 'right')

    num_strikes = 0
    num_balls = 0
    num_runs = 0
end

function update_game()

    --
    -- bookkeeping.
    --

    btnr_update()

    --
    -- update entities.
    --

    update_fielder(pitcher1)
    update_batter(batter1)

    --
    -- update the ball.
    --

    if ball1.state == ball_throwing then
        animate_thrown_ball(ball1)
    elseif ball1.state == ball_idle_physical_obj then
        simulate_as_rigidbody(ball1)
    end

    --
    -- bookkeeping.
    --

    count_down_timers()
end

log_y = 10
log_messages = {}

function log(msg)
    add(log_messages, msg)
    if #log_messages>5 then deli(log_messages, 1) end
end

function log_v(v)
    log(flr(v.x) .. ',' .. flr(v.y) .. ',' .. flr(v.z))
end

function draw_log()
    local init = log_y
    for i,msg in ipairs(log_messages) do
        print(msg, 0, init)
        init += 10
    end
end

fixed_y = 10

function fixed(msg)
    -- print(msg, 0, fixed_y)
    fixed_y += 10
end

function fixed_reset()
    fixed_y = 10
end

function draw_game()
    cls(3)

    fixed(ball1.pos.x)
    fixed(ball1.pos.y)
    fixed(ball1.pos.z)
    fixed(in_game_bounds(ball1.pos))
    fixed('strikes:' .. num_strikes)
    fixed('balls:' .. num_balls)
    fixed('runs:' .. num_runs)
    fixed_reset()

    draw_log()

    -- draw sand around home plate.
    do
        local sx, sy = world2screen(bases[1])
        local half_w = 8*3.5
        local half_h = 4*3.5
        sy += 4
        ovalfill(sx-half_w, sy-half_h, sx+half_w, sy+half_h, 15)
    end

    -- draw bases.
    for b in all(bases) do
        draw_base(b)
    end

    -- draw base lines.
    for i=1,#bases do
        local sx1, sy1 = world2screen(bases[i])
        local sx2, sy2 = world2screen(bases[luamod(i+1, 4)])
        line(sx1, sy1, sx2, sy2, 7)
    end

    -- draw pitcher's mound.
    do
        local sx, sy = world2screen(pitchers_mound)
        local half_w = 8
        local half_h = 4
        ovalfill(sx-half_w, sy-half_h, sx+half_w, sy+half_h, 15)
    end

    -- draw batter's boxes.
    draw_box(batters_box)
    draw_box(batters_box, true)

    -- draw catcher's box.
    draw_box(catchers_box, nil, true)

    -- compute ball shadow position.
    local shadow_pos = vec3_set(vec3(), ball1.pos)
    shadow_pos.y = -1

    -- sort entities by position.
    local sorted = isort({
        -- {obj, draw_fn},
        {pitcher1.pos, pitcher1, pitcher_draw},
        {ball1.pos, ball1, draw_ball},
        {shadow_pos, nil, function() draw_ball(ball1, true) end},
        {catcher1.pos, catcher1, draw_player},
        {batter1.pos, batter1, draw_batter},
    })

    -- draw sorted entities.
    for t in all(sorted) do
        local entity_data = t[2]
        local draw_fn = t[3]
        draw_fn(entity_data)
    end

    -- draw the ui.
--[[
    print('dad 0', 0, 0)
    print('jes 2', 0, 6)
    print('⬇️4', 117, 0)
    circfill(119, 8, 2, 1)
    circfill(125, 8, 2, 1)
    local x_offset = 0
    local y_offset = 3
    rectfill(88, 108+y_offset, 117, 116+y_offset, 0)
    print('strike!', 90, 110+y_offset, 7)
]]
    -- print('2-2', 64-ceil(3*4*.5)+1, 0, 7)
    -- num_strikes = 0
    -- num_balls = 0
    cprint(num_balls .. '-' .. num_strikes, 1, 7)
    print(num_runs, 1, 1, 7)
end

function cprint(msg, y, c)
    local half_width = #msg * 2 -- 4 pixels per character, but halved.
    local x = 64 - half_width
    print(msg, x, y, c)
end

-->8
-- game loop.

_init = init_game
_update60 = update_game
_draw = draw_game

__gfx__
01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01111f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666611000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06611161100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06611110110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
066611111fff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0666661111f400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0066660011ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00016660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00066666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00066666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00066611100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00066111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00111000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

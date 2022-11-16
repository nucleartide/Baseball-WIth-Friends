pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- pico baseball
-- by @nucleartide

#include utils.p8

-->8
-- base.

function draw_base(v, r, c)
    local sx, sy = world2screen(v)
    circfill(sx, sy, r or 4, c or 7)
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
    --[[
	spr(0,
		sx,
		sy, 1.5, 3, false, false)
    ]]
	return sx, sy
end

-->8
-- fielder.

function fielder(pos, player_num, ball, is_catcher)
    assert(actions==nil, 'this should be nil to avoid cyclic dependencies')
    assert(is_catcher~=nil)

    fielder_fielding = 0
    fielder_selecting_action = 1
    pitcher_selecting_pitch = 2
    pitcher_selecting_endpoint = 3

    return assign(player(pos, player_num), {
        -- reference to ball, if fielder is holding one.
        -- todo: it may be useful to move tthis to an "Owned_by" field
        -- on the ball, so that we don't need to update the state of multiple fielders.
        -- not too important though.
        ball = ball,

        -- currently selected action.
        selected_action_index = -1,

        -- check whether this object is a fielder.
        fielder = true,

        -- the fielder's current state.
        state = fielder_fielding,

        -- whether this fielder is a catcher, in which case in the pitching phase:
        -- 1. this catcher can't move, and
        -- 2. when a pitcher throws to this catcher, the pitching_action ui is shown.
        catcher = is_catcher,
    })
end

-- todo: clean up.
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

-- todo: clean up.
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

function update_fielder(f, _unused, on_select_teammate, on_throw)
    if f.state == fielder_fielding then
        update_fielder_fielding(f)
    elseif f.state == fielder_selecting_action then
        update_fielder_when_selecting_action(f)
    elseif f.state == pitcher_selecting_pitch then
        update_pitcher_selecting_pitch(f, pitch_actions)
    elseif f.state == pitcher_selecting_endpoint then
        update_pitcher_selecting_endpoint(f, on_throw)
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

-- batter states.
batter_batting = 0
batter_charging = 1
batter_swinging = 2
batter_running_unsafe = 3
batter_running_safe = 4
-- no running as of now.

-- batter can bat and run.
function batter(x, z, player_num, handedness, home_plate_pos, bases)
    assert(home_plate_pos~=nil)
    assert(bases~=nil)

    -- [x] player's position.
    -- [x] handedness.
    -- [x] home plate position.
    -- [x] rel_to_home_plate_pos.
    -- [x] get_batter_worldspace()
    -- [x] get_batter_half_body_worldspace()
    -- [ ] bat aim vector (relative to get_batter_half_body_worldspace)

    handedness = handedness or 'right'
    local rel_to_home_plate_x = handedness=='right' and -5 or 5
    local bat_aim_x = handedness=='right' and 5 or -5

    return assign(player(vec3(x,0,z), player_num), {
        -- state of player.
        -- state = batter_batting,
        state = batter_running_unsafe,

        -- animation timer.
        -- in the case of running, this ranges from [0,1]
        t = 0,

        -- animation lengths (in frames).
        charging_anim_len = 10,
        swing_anim_len = .5*60,

        -- 'left' | 'right'
        handedness = handedness or 'right',

        -- relative to get_batter_Half_body_worldspace.
        bat_aim_vec = vec3(bat_aim_x, 0, 0),

        -- home plate pos reference.
        home_plate_pos = home_plate_pos,

        -- relative to home_plate_pos.
        rel_to_home_plate_pos = vec3(rel_to_home_plate_x, 0, 0),

        -- 4 or 5, indicating whether z or x was last pressed while running.
        last_button_pressed = nil,

        -- reference to set of bases.
        bases = bases,

        -- current base that the batter is on. [1,4].
        current_base = 1,
    })
end

function get_batter_worldspace(b)
    if b.state==batter_running_unsafe or b.state==batter_running_safe then
        return b.pos
    else
        return worldspace(
            b.home_plate_pos,
            b.rel_to_home_plate_pos
        )
    end
end

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

function update_batter(b, ball1)
    if b.player_num==nil then
        return
    end

    -- hold x to charge
    if b.state==batter_batting and btnp(4, b.player_num) then
        b.state = batter_charging
        return
    end

    -- if player is charging,
    if b.state==batter_charging and btn(4, b.player_num) then
        -- cycle the animation timer.
        b.t = (b.t + 1)%b.charging_anim_len
    end

    -- release x to swing.
    if b.state==batter_batting and btnr(4, b.player_num) then
        b.state = batter_swinging
        b.t = 0
        swing(b, ball1)
        return
    end

    -- if player is swinging,
    if b.state==batter_swinging then
        b.t += 1
        if (b.t == b.swing_anim_len) then
            b.t = 0
            b.state = batter_batting
        end
    end

    -- if player is batting,
    if b.state==batter_batting then
        if btn(0, b.player_num) then
            b.rel_to_home_plate_pos.x -= .1
        end
        if btn(1, b.player_num) then
            b.rel_to_home_plate_pos.x += .1
        end
        if btn(2, b.player_num) then
            b.bat_aim_vec.y+=.5
        end
        if btn(3, b.player_num) then
            b.bat_aim_vec.y-=.5
        end
    end

    if b.state==batter_running_unsafe then
    --assert(false, 'continue on running update behavior')
        if b.last_button_pressed~=4 and btnp(4, b.player_num) then
            b.t += .01
            b.last_button_pressed = 4
        elseif b.last_button_pressed~=5 and btnp(5, b.player_num) then
            b.t += .01
            b.last_button_pressed = 5
        end
    end
end

function swing(batter, ball1)
    local batter_pos = batter.pos
    assert(batter_pos~=nil)

    if ball1~=nil then
        -- equation of line of bat. - y = mx + b
        -- (x,y) would be the hit point of the bat.
        local b = batter.pos.y + 5 -- y intercept
        local m = -.33
        local x = batter.pos.x + 5 -- [0, b.pos.x + 5]
        local y = m*x + b

        -- compute x difference...
        local x_diff = ball1.pos.x - x

        -- compute y difference between bat and ball.
            -- plot the x of the ball to get the y of the bat at that point.
            -- then subtract.
        local y_of_bat = m * ball1.pos.x + b
        local y_of_ball = ball1.pos.y
        local y_diff = y_of_ball - y_of_bat

        -- compute the z difference too.
        local z_diff = ball1.pos.z - batter.pos.z

        -- throw with difference results.
        -- if abs(x difference) is <= 10, then it's within range of bat.
        -- if abs(y difference) is <= 10, then it's within range of bat.
        -- if abs(z difference) is <= 10, then it's within range of bat.
        if x_diff<=10 and y_diff<=10 and z_diff<=10 then
            -- assert(false, x_diff .. ',' .. y_diff .. ',' .. z_diff)

            -- set the velocity of the ball
            -- ball1.vel.x = 0
            -- todo: this needs tweaking, but is good enough for now.
            ball1.vel.x = x_diff
            ball1.vel.y = 30 * y_diff/10
            ball1.vel.z = 30 - 50 * z_diff/10
            ball1.state = ball_idle_physical_obj
        end
    end
end

function __batter_update(b, on_hit)
    assert(on_hit~=nil)

    if b.state==0 and btn(4, 1) then
        b.state=1
    end

    if b.state==1 and btnr(4, 1) then
        -- todo: flesh this out.
        b.state=2
        b.batted_state_timer = b.batted_state_t_interval
    end

    if b.state==2 then
        batter_check_for_hit(b, batter_reticle, bases[1], ball1.pos, ball1.vel, on_hit)
        b.batted_state_timer -= 1
        if (b.batted_state_timer<0) then
            b.batted_state_timer=0
            b.state=1
        end
    end
end

function __batter_check_for_hit(b, batter_reticle, home_plate_vec, ball_pos, ball_vel, on_hit)
    -- take reticle position and distance to home plate.
    assert(batter_reticle.x~=nil)
    assert(home_plate_vec.x~=nil)
    assert(ball_pos.x~=nil)

    -- ball is close enough if...
    -- - distance to home plate is less than .5 (can tweak later)
    -- - distance to batter reticle is less than .5 (can tweak later)
    local dist_to_home_plate = distance2(home_plate_vec, ball_pos, true, true, nil)
    local dist_from_reticle = distance2(batter_reticle, ball_pos, nil, nil, true)
    local is_close_enough = dist_to_home_plate <= 5 and dist_from_reticle <= 5

    if is_close_enough then
        -- then update the velocity on the ball when hit
        on_hit(0, 20, 30)
    end
end

function draw_batter(b)
    -- determine world pos.
    local world_pos = get_batter_worldspace(b)

    -- draw player body.
    draw_player(b, world_pos)

    -- determine batter screen space.
    local bx, by = world2screen(world_pos)

    --
    -- draw batter in running state.
    --

    if b.state==batter_running_unsafe or b.state==batter_running_safe then
        -- determine points to draw z and x.
        local zpos = bx - 5 - 5
        local xpos = bx + 5
        local y = by - 3

        -- draw z.
        print('❎', xpos, y, b.last_button_pressed==5 and 6 or 7)
        print('🅾️', zpos, y, b.last_button_pressed==4 and 6 or 7)

        return
    end

    --
    -- draw batter in batting state.
    --

    -- draw bat.
    if b.state==batter_batting or b.state==batter_charging then
        -- determine whether to flip.
        local scale = 1
        if b.handedness == 'left' then scale *= -1 end

        -- determine points of bat.
        local high_point_x, high_point_y = bx - b.side*2*scale, by - b.h
        local low_point_x, low_point_y = bx + b.side*2*scale, by - b.h*.5

        -- actually draw bat.
        for i=0,1 do
            local c = 9
            if b.t>(b.charging_anim_len*.5) then c = 8 end
            line(high_point_x, high_point_y-i, low_point_x, low_point_y-i, c)
        end
    elseif b.state==batter_swinging then
        -- determine points of bat.
        local high_point_x, high_point_y = bx, by - b.h*.5

        -- actually draw bat.
        local ax, ay = world2screen(get_batter_aim_pos(b))
        for i=0,1 do line(high_point_x, high_point_y-i, ax, ay-i, 9) end
    end

    -- draw baseball bat preview.
    local ax, ay = world2screen(get_batter_aim_pos(b))
    circ(ax, ay, 2, 6)
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
function pitcher(pos, v1, v2, v3, v4, player_num, ball)
    assert(ball==nil, 'fielder should not have ball field')
    return assign(fielder(pos, player_num, ball, false), {
        -- the pitcher's arsenal of pitches.
        -- just one test pitch for now.
        pitches = {
            cubic_bezier(v1, v2, v3, v4),
        },

        -- identifier to distinguish this pitcher.
        pitcher = true,

        -- pitch endpoint relative to destination player.
        pitch_endpoint = vec3(),

        -- reticle relative to pitcher's position.
        reticle = vec3(),

        -- destination fielder, if throwing to a fielder.
        dest = nil,
    })
end

function update_pitcher(p, fielders, something, on_throw)
    update_fielder(p, fielders, nil, on_throw)
end

function pitcher_draw(p, pitch_actions)
    -- assert(pitch_actions~=nil)

    local sx, sy = draw_player(p)

    --[[
    if p.state==pitcher_selecting_pitch then
        for action in all(pitch_actions) do
            fielder_action_draw(action, p)
        end
    end

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

function ball(pos, initial_state)
    assert(pos~=nil)
    assert(gravity~=nil)
    assert(initial_state~=nil)

    return {
        -- physical properties.
        pos = vec3_set(vec3(), pos),
        vel = vec3(),
        acc = vec3_mul(vec3(0, gravity, 0), 1/60), -- force of gravity

        -- when thrown.
        trajectory = nil, -- of type cubic_bezier.

        -- throw animation.
        t = 0, -- timer field used for animation.
        throw_duration = 2*60, -- this is dynamically set elsewhere.

        -- if a catcher doesn't catch the ball at the end,
        -- sample from the bezier curve past t=1.

        -- state of the ball.
        state = initial_state,
    }
end

function simulate_as_rigidbody(b, fielders)
    assert(fielders~=nil)
    local spare1, spare2 = vec3(), vec3()

    -- update vel.
    vec3_add_to(b.vel, b.acc)
    if (b.vel.y<gravity) b.vel.y=gravity -- clamp velocity to bound.

    -- update pos.
    vec3_set(spare1, b.vel)
    vec3_mul(spare1, 1/60)
    vec3_add_to(b.pos, spare1)

    -- constrain pos.
    if (b.pos.y<0) b.pos.y=0
    -- if (b.pos.y<=0) vec3_zero(b.vel)

    pick_up_ball_if_nearby(b, fielders)
end

-- throw ball by updating the state of passed-in ball b.
--
-- b: ball table.
-- starting_vec: the starting point of the throw.
-- ending_vec: the ending point of the throw.
-- dest_player: the player that is being thrown to.
function throw_ball(b, starting_vec, ending_vec, dest_player)
    assert(b~=nil)
    assert(dest_player.pos~=nil)

    -- create 4 points.
    local start = vec3_set(vec3(), starting_vec)
    local endpoint = vec3_set(vec3(), ending_vec)
    local middle1 = vec3_lerp_into(start, endpoint, vec3(), .33)
    local middle2 = vec3_lerp_into(start, endpoint, vec3(), .67)

    -- tweak 4 points so ball follows an arc.
    start.y += 5
    middle1.y += 15
    middle2.y += 15
    endpoint.y += 5

    --
    -- set fields on the ball object.
    --

    -- set trajectory on ball.
    b.trajectory = cubic_bezier(start, middle1, middle2, endpoint)

    -- reset animation fields.
    b.t = 0
    local d = distance2(start, endpoint)
    -- b.throw_duration = d / 200 * 60
    b.throw_duration = 3 * 60

    -- set the ball's state, we'll need it to know whether we are animating.
    b.state = ball_throwing

    -- set the destination player.
    b.dest_player = dest_player
end

function pick_up_ball_if_nearby(b, fielders)
    for f in all(fielders) do
        local d = distance2(f.pos, b.pos, nil, nil, nil)
        if d<2 then
            f.ball = b
            b.state = ball_holding
        end
    end
end

function animate_thrown_ball(b, fielders)
    assert(fielders~=nil)

    -- update the ball's position.
    local t = b.t / b.throw_duration
    -- local t = b.t / 200 -- testing.
    cubic_bezier_fixed_sample(100, b.trajectory, t, b.pos)

    if b.pos.y<=0 then
        b.state = ball_idle_physical_obj

        --   x and z are determined by trajectory[1] and trajectory[4]
        vec3_set(b.vel, b.trajectory[4])
        vec3_sub_from(b.vel, b.trajectory[1])
        local old_d = vec3_normalize(b.vel)
        vec3_mul(b.vel, old_d * .1)

        -- initially:
        -- set velocity
        b.vel.y = 5
    end

    -- if the ball has been thrown, then check whether any fielders are around to catch.
    if t>.2 then
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
-- skeleton character.

function character()
    return {
        pos = vec3(),
    }
end

function move_character(char)
    if btn(0) then
        char.pos.x -= 1
    end
    if btn(1) then
        char.pos.x += 1
    end
    if btn(2) then
        char.pos.z += 1
    end
    if btn(3) then
        char.pos.z -= 1
    end
end

function draw_character(char)
    local sx, sy = world2screen(char.pos)
    for i=0,2 do
        circfill(sx, sy-i, 3, 7)
    end

    -- draw feet
    local left_leg_x, left_leg_y = sx-2, sy+4
    local right_leg_x, right_leg_y = sx+2, sy+4

    -- draw legs.
    for i=0,4 do
        circfill(left_leg_x, left_leg_y+i, 1, 8)
    end
    for i=0,4 do
        circfill(right_leg_x, right_leg_y+i, 1, 9)
    end

    local left_arm_x, left_arm_y = sx-4, sy-2
    for i=0,4 do
        circfill(left_arm_x, left_arm_y+i, 1, 6)
    end

    local right_arm_x, right_arm_y = sx+4, sy-2
    for i=0,4 do
        circfill(right_arm_x, right_arm_y+i, 1, 6)
    end

    circfill(left_arm_x, left_arm_y+4, 1, 9)
    circfill(right_arm_x, right_arm_y+4, 1, 9)


    -- draw feet
    rectfill(left_leg_x, left_leg_y+5, left_leg_x+1, left_leg_y+6, 10)
    rectfill(right_leg_x, right_leg_y+5, right_leg_x+1, right_leg_y+6, 10)

    -- draw head.
    circfill(sx, sy-8, 4, 2)
    circfill(sx, sy-7, 3, 12)
end

-->8
-- game state.

game_batting = 0
game_ball_in_play = 1

function init_game()
    half_diagonal = 50 -- in world units.

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

    x,z=0,0

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
        0,
        nil
    )

    gravity = -20
    ball1 = ball(raised_pitcher_mound, ball_holding)

    --[[
    --
    -- config.
    --

    offset = 5 -- used for visually offsetting pitch actions from pitcher.

    --
    -- game state.
    --

    game_state = game_batting

    --
    -- game objects.
    --


    -- reference points.
    raised_pitcher_mound = vec3_raise(pitchers_mound, 5)
    raised_home_plate = vec3_raise(bases[1], 5)

    balls = {
    }

    -- fielder positions.
    fpos = {
        vec3(half_diagonal, 0, 0),
        vec3(0, 0, half_diagonal),
        vec3(-half_diagonal, 0, 0),
        vec3(0, 0, -half_diagonal - 5),
        vec3(),
    }

    fielders={
        fielder(fpos[1], nil, nil, false),
        fielder(fpos[2], nil, nil, false),
        fielder(fpos[3], nil, nil, false),
        -- fielder(fpos[4], nil, nil, true),
        pitcher(
            fpos[5],
            raised_pitcher_mound,
            vec3_lerp_into(raised_pitcher_mound, raised_home_plate, vec3(), .33),
            vec3_lerp_into(raised_pitcher_mound, raised_home_plate, vec3(), .67),
            raised_home_plate,
            0,
            balls[1]
        ),
    }

    -- set of actions that can be performed by a fielder.
    throw_actions={}
    for f in all(fielders) do
        local fa = fielder_action(
            0,0,0,
            '',
            f.pos,
            function(throwing_fielder, action)
                local src = throwing_fielder
                local dest = f

                assert(src~=nil)
                assert(action~=nil)

                if src.pitcher and dest.catcher then
                    -- then change into pitching state.
                    src.state = pitcher_selecting_pitch 
                    src.dest = dest
                else
                    -- throw the ball.
                    throw_ball(throwing_fielder.ball, throwing_fielder.pos, worldspace(action.parent_pos, action.pos), f)

                    -- fielder no longer owns ball.
                    src.ball = nil
                end
            end
        )
        add(throw_actions, fa)
    end

    -- set of actions that can be performed by the pitcher.
    local ppos = fpos[5]
    pitch_actions = {
        fielder_action(0,offset,offset,'⬆️',ppos,function(throwing_fielder, action, dest_fielder)
            assert(false, 'get rid of this')
            assert(throwing_fielder~=nil)
            assert(action~=nil)
            assert(dest_fielder~=nil)

            local src = throwing_fielder
            local dest = dest_fielder

            -- then transition states.
            -- src.state = 
        end),
        fielder_action(0,offset,-offset,'⬇️',ppos,function() assert(false) end),
        fielder_action(-offset,offset,0,'⬅️',ppos,function() assert(false) end),
        fielder_action(offset,offset,0,'➡️',ppos,function() assert(false) end),
    }

    batters = {
        batter(bases[1].x, bases[1].z, 1, 'left', bases[1], bases)
    }

    umpires = {
        umpire(bases[2].x + 7, bases[2].z),
    }
    ]]
end

function update_game()
    if btn(0) then
        x -= 1
    end
    if btn(1) then
        x += 1
    end
    if btn(2) then
        z += 1
    end
    if btn(3) then
        z -= 1
    end

    --[[
    btnr_update()

    local active_ball
    for b in all(balls) do
        if b.state==ball_throwing then
            active_ball = b
            animate_thrown_ball(b, fielders)
        elseif b.state==ball_holding then
            hold_ball(b, fielders)
        elseif b.state==ball_idle_physical_obj then
            simulate_as_rigidbody(b, fielders)
        else
            assert(false)
        end
    end

    for f in all(fielders) do
        if f.pitcher then
            update_pitcher(f, throw_actions, nil, on_throw)
        else
            update_fielder(f, throw_actions, nil, on_throw)
        end
    end

    for b in all(batters) do
        update_batter(b, active_ball)
    end
    ]]
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

function comparator(v1, v2)
    if v1[1].z==v2[1].z then
        return v1[1].y < v2[1].y
    else
        return v1[1].z > v2[1].z
    end
end

function isort(t) --insertion sort, ascending y
    for n=2,#t do
        local i=n
        while i>1 and comparator(t[i], t[i-1]) do
            t[i],t[i-1]=t[i-1],t[i]
            i-=1
        end
    end
end

function draw_game()
    cls(3)

    -- draw sand around home plate.
    do
        local sx, sy = world2screen(bases[1])
        local half_w = 8*3.5
        local half_h = 4*3.5
        sy += 4
        ovalfill(sx-half_w, sy-half_h, sx+half_w, sy+half_h, 15)
    end

    for b in all(bases) do
        draw_base(b)
    end

    -- assert(false, 'continue recreating the core batting loop')

    -- draw base lines
    for i=1,#bases do
        local sx1, sy1 = world2screen(bases[i])
        local sx2, sy2 = world2screen(bases[luamod(i+1, 4)])
        line(sx1, sy1, sx2, sy2, 7)
    end

    -- draw pitcher's mound
    do
        local sx, sy = world2screen(pitchers_mound)
        local half_w = 8
        local half_h = 4
        ovalfill(sx-half_w, sy-half_h, sx+half_w, sy+half_h, 15)
    end

    -- draw batter's box.
    draw_box(batters_box)
    draw_box(batters_box, true)

    -- draw catcher's box.
    draw_box(catchers_box, nil, true)

    -- draw test entity.
    do
        local sx, sy = world2screen(vec3(x, 0, z))
        -- circfill(sx, sy, 3, 8)
    end

    -- sort these by position.
    local shadow_pos = vec3_set(vec3(), ball1.pos)
    shadow_pos.y = -1
    local sorted = {
        -- {obj, draw_fn},
        {pitcher1.pos, pitcher1, pitcher_draw},
        {ball1.pos, ball1, draw_ball},
        {shadow_pos, nil, function() draw_ball(ball1, true) end},
    }
    isort(sorted)
    for t in all(sorted) do
        local entity_data = t[2]
        local draw_fn = t[3]
        draw_fn(entity_data)
    end

    -- todo:
    -- sort the ball, pitcher, and ball shadow.

    --[[
    -- draw fielders.
    for f in all(fielders) do
        if f.pitcher then
            pitcher_draw(f, pitch_actions)
        else
            draw_player(f)
        end

        -- draw selection circle around pitcher action.
        if f.state==fielder_selecting_action or f.state==pitcher_selecting_pitch then
            local actions = get_actions_for_fielder(f)
            for i=1,#actions do
                local a = actions[i]
                local selected = i==f.selected_action_index
                if selected then
                    fielder_action_draw_select(a)
                end
            end
        end
    end

    -- draw batters.
    for b in all(batters) do
        draw_batter(b)
    end

    for u in all(umpires) do
        draw_umpire(u)
    end

    for b in all(balls) do
        draw_ball(b)
    end
    ]]
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

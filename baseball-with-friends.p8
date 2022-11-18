pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- pico baseball
-- by @nucleartide

#include utils.p8

--[[

todo:

- vec functions should just create new vectors

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

    if btnp(4, f.player_num) then
        throw_ball(ball1, f.pitches[1])
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

function ball(pos, initial_state)
    return {
        -- physical properties.
        pos = vec3_set(vec3(), pos),
        vel = vec3(),
        acc = vec3_mul(vec3(0, gravity, 0), 1/60),

        -- the fielder that is holding the ball.
        -- will be used soon.
        is_owned_by = nil,

        -- throw animation.
        t = 0, -- timer field used for animation.
        throw_duration = -1, -- this is dynamically set elsewhere.

        -- state of the ball.
        state = initial_state,

        -- populated when thrown. of type cubic_bezier.
        trajectory = nil,
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
        if d<5 then
            b.state = ball_holding

            if f~=pitcher1 then
                -- after 1s, catcher throws the ball back.
                delay(function()
                    return_ball_to_pitcher(b, f, pitcher1)
                end, 60)
            end
        end
    end
end

function animate_thrown_ball(b)
    -- handle dropped balls.
    --[[
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
    ]]

    -- update the ball's position.
    local t = b.t / b.throw_duration
    cubic_bezier_fixed_sample(100, b.trajectory, t, b.pos)

    vec3_print(b.pos, true)

    -- if the ball has been thrown, then
    if t>.2 then
        -- check whether any fielders are around to catch.
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
        catcher_pos.z -= 5
        catcher1 = fielder(catcher_pos, nil)
    end

    gravity = -20

    ball1 = ball(raised_pitcher_mound, ball_holding)

    fielders = {catcher1, pitcher1}
end

function update_game()
    -- assert(false, 'todo: revisit the logic here.')

    update_fielder(pitcher1)

    if ball1.state == ball_throwing then
        animate_thrown_ball(ball1)
    end

    -- bookkeeping.
    count_down_timers()
end

function draw_game()
    cls(3)

    print(ball1.state)
    print(stat(1))

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
    })

    -- draw sorted entities.
    for t in all(sorted) do
        local entity_data = t[2]
        local draw_fn = t[3]
        draw_fn(entity_data)
    end
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

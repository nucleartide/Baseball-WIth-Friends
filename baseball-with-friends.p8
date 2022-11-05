pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- baseball with friends
-- by @nucleartide

#include utils.p8

assert(false, 'focus on getting a working swing')

--[[

## current user story

[x] init
[x] draw
    [x] draw the batter
[ ] update
    [x] hold x to charge
    [x] release x to swing
    [ ] implement swing function
        [ ] set the velocity of the ball
    [ ] nuances to swing
        [ ] up arrow to aim up
        [ ] left/right arrows to position in batter box
        [ ] down arrow to aim down

]]

-->8
-- static objects.

-- bases are vectors.
function base_draw(v)
    local sx, sy = world2screen(v)
    circfill(sx, sy, 4, 7)
end

-->8
-- dynamic objects.

--
-- player base class.
--

function player(pos, player_num)
    return {
        pos = pos,
        h = 10,
        side = 2, -- half a side.
        player_num = player_num, -- note that this can be nil.
    }
end

function player_move(p)
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

function player_draw(p)
    local sx, sy = world2screen(p.pos)
    rectfill(sx-p.side, sy-p.h+1, sx+p.side, sy, 8)
    return sx, sy
end

--
-- fielder class.
--

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
    player_move(f)
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

-- batter states.
batter_batting = 0
batter_charging = 1
batter_swinging = 2
-- no running as of now.

-- batter can bat and run.
function batter(x, z, player_num)
    return assign(player(vec3(x,0,z), player_num), {
        state = batter_batting,
        -- animation timer.
        t = 0,
        charging_anim_len = 10,
        swing_anim_len = .5*60,
    })
end

function update_batter(b, ball1)
    -- hold x to charge
    if btnp(4, b.player_num) then
        b.state = batter_charging
        return
    end

    -- if player is charging,
    if btn(4, b.player_num) then
        -- cycle the animation timer.
        b.t = (b.t + 1)%b.charging_anim_len
    end

    -- release x to swing.
    if btnr(4, b.player_num) then
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
        assert(false, x_diff .. ',' .. y_diff .. ',' .. z_diff)

        -- if x difference is negative, then it's within range of bat.
        -- if x difference is positive, then it's a miss.
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
    player_draw(b)

    --
    -- draw baseball stick
    --

    local bx, by = world2screen(b.pos)
    if b.state==batter_batting or b.state==batter_charging then
        local high_point_x, high_point_y = bx - b.side*2, by - b.h
        local low_point_x, low_point_y = bx + b.side*2, by - b.h*.5
        for i=0,1 do
            local c = 9
            if b.t>(b.charging_anim_len*.5) then c = 8 end
            line(high_point_x, high_point_y-i, low_point_x, low_point_y-i, c)
        end
    elseif b.state==batter_swinging then
        local high_point_x, high_point_y = bx, by - b.h*.5
        local low_point_x, low_point_y = bx + b.side*4, by
        for i=0,1 do
            line(high_point_x, high_point_y-i, low_point_x, low_point_y-i, 9)
        end
    end
end

--
-- fielder action class.
--

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

--
-- pitcher class.
--

-- x,z: position
-- v1,v2,v3,v4: pitch trajectory for a test pitch
-- player_num: input controller index
-- ball: the ball, if pitcher is holding
-- actions: list of actions that can be performed by pitcher
function pitcher(pos, v1, v2, v3, v4, player_num, ball)
    assert(ball.pos~=nil)

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
    assert(pitch_actions~=nil)

    local sx, sy = player_draw(p)

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
end

--
-- ball class.
--

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
        throw_duration = .5*60, -- 1 second for now.

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
    b.throw_duration = d / 200 * 60

    -- set the ball's state, we'll need it to know whether we are animating.
    b.state = ball_throwing

    -- set the destination player.
    b.dest_player = dest_player
end

function pick_up_ball_if_nearby(b, fielders)
    for f in all(fielders) do
        local d = distance2(f.pos, b.pos, nil, true, nil)
        if d<5 then
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

function draw_ball(p)
    local sx, sy = world2screen(p.pos)
    local shadow_x, shadow_y = world2screen(p.pos, true)
    circfill(shadow_x, shadow_y, 2, 5)
    circfill(sx, sy, 2, 7)
end

--
-- reticle class. this should be absorbed into individual player sub-classes.
--

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

function get_actions_for_fielder(f)
    if f.state == pitcher_selecting_pitch then
        return pitch_actions
    else
        return throw_actions
    end
end

-->8
-- game loop.

function init_game()

    --
    -- config.
    --

    half_diagonal = 50 -- in world units.
    gravity = -20
    offset = 5 -- used for visually offsetting pitch actions from pitcher.

    --
    -- game objects.
    --

    bases = {
        vec3(0, 0, -half_diagonal), -- home
        vec3(half_diagonal, 0, 0), -- 1st
        vec3(0, 0, half_diagonal), -- 2nd
        vec3(-half_diagonal, 0, 0), -- 3rd
    }

    pitchers_mound = vec3()

    -- reference points.
    raised_pitcher_mound = vec3_raise(pitchers_mound, 5)
    raised_home_plate = vec3_raise(bases[1], 5)

    balls = {
        ball(raised_pitcher_mound, ball_holding),
    }

    -- fielder positions.
    fpos = {
        vec3(half_diagonal, 0, 0),
        vec3(0, 0, half_diagonal),
        vec3(-half_diagonal, 0, 0),
        vec3(0, 0, -half_diagonal),
        vec3(),
    }

    fielders={
        fielder(fpos[1], nil, nil, false),
        fielder(fpos[2], nil, nil, false),
        fielder(fpos[3], nil, nil, false),
        fielder(fpos[4], nil, nil, true),
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
        batter(bases[1].x - 5, bases[1].z, 1)
    }
end

function update_game()
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
end

function draw_game()
    cls(3)

    print('has ball:' .. tostr(fielders[5].ball~=nil))

    -- draw base lines
    for i=1,#bases do
        local sx1, sy1 = world2screen(bases[i])
        local sx2, sy2 = world2screen(bases[luamod(i+1, 4)])
        line(sx1, sy1, sx2, sy2, 7)
    end

    -- draw bases
    for b in all(bases) do
        base_draw(b)
    end

    -- draw pitcher's mound
    base_draw(pitchers_mound)

    -- draw fielders.
    for f in all(fielders) do
        if f.pitcher then
            pitcher_draw(f, pitch_actions)
        else
            player_draw(f)
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

    for b in all(balls) do
        draw_ball(b)
    end
end

_init = init_game
_update60 = update_game
_draw = draw_game

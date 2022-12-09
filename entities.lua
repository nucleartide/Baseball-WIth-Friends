
-->8
-- environment.

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

function fielder(pos, player_num)
    return assign(player(pos, player_num), {
        -- ...
    })
end

function get_fielder_midpoint(f)
    return vec3(f.pos.x, f.h*.5, f.pos.z)
end

function update_fielder_and_ball(f, ball1)
    if f.player_num~=nil and btnp(4, f.player_num) and ball1.is_owned_by==f then
        -- grab reference.
        local trajectory = f.pitches[1]

        -- set trajectory.
        ball1.trajectory = trajectory

        -- set animation.
        ball1.t = 0
        ball1.throw_duration = (distance2(trajectory[1], trajectory[4]) / 200) * 60

        -- set state.
        ball1.state = ball_throwing
        ball1.is_owned_by = nil
    end
end

-->8
-- batter.

-- goal for today: get this bat drawn and animated.
function batter(x, z, player_num, handedness)
    handedness = handedness or 'right'

    local player_obj = player(vec3(x, 0, z), player_num)
    local relx = handedness=='right' and -rel_to_home_plate_x or rel_to_home_plate_x

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
    })
end

function get_batter_worldspace(b, home_plate_pos)
    assert(home_plate_pos~=nil)
    return worldspace(home_plate_pos, b.rel_to_home_plate_pos)
end

function update_batter_and_ball(b, ball1, bases)
    if b.player_num==nil then
        return
    end

    -- hold x to charge.
    if b.state==batter_batting and btnp(4, b.player_num) and not b.did_swing then
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
        b.did_swing = true -- check to ensure batter doesn't swing again.
        return
    end

    -- if player is swinging,
    if b.state==batter_swinging or b.state==batter_swinging_ball_was_hit then
        -- update the swing timer.
        b.t += 1

        -- check whether the bat is in "hit" range.
        local t = b.t / b.swing_anim_len
        local in_range, xt = is_hit(b.rotated_knob, b.rotated_bat_end, ball1, b, t, bases)

        if in_range and ball1.state == ball_throwing then
            b.state = batter_swinging_ball_was_hit
            hit_ball(b.rotated_knob, b.rotated_bat_end, ball1, b, t, bases)
        elseif b.t >= b.swing_anim_len then
            -- if ball was not hit,
            -- and the ball was thrown,
            -- increment strikes.
            assert(false, 'refactor to pass in a score object')
            if b.state==batter_swinging and ball1.state == ball_throwing then
                log('strike!')
                -- num_strikes += 1
            end

            if ball1.state != ball_throwing then
                b.did_swing = false
            end

            -- swing is done, reset the bat's swinging state.
            b.t = 0
            b.state = batter_batting
        end
    end

    -- compute the bat knob and bat end locatinos.
    compute_batter_bat_endpoints(b)
end

function is_hit(bat_knob, bat_end, ball, batter, swing_t, bases)
    assert(ball~=nil)
    assert(batter~=nil)
    assert(swing_t~=nil)

    bat_knob, bat_end = get_batter_bat_worldspace(batter, bases)

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

function hit_ball(bat_knob, bat_end, ball, batter, xt, bases)
    log('ball was hit')
    assert(ball~=nil)
    assert(batter~=nil)

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

function compute_batter_bat_endpoints(b)
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

function get_batter_bat_worldspace(b, bases)
    local world_pos = get_batter_worldspace(b, bases[1])
    local pivot_pos = worldspace(world_pos, b.pivot)
    local knob_pos = worldspace(pivot_pos, b.rotated_knob)
    local bat_end_pos = worldspace(pivot_pos, b.rotated_bat_end)
    return knob_pos, bat_end_pos
end

function draw_batter(b, bases)
    -- precondition.
    assert(bases[1].x~=nil)

    -- draw the player body.
    draw_player(b, get_batter_worldspace(b, bases[1]))

    -- determine the pivot around which the bat swings.
    local knob_pos, bat_end_pos = get_batter_bat_worldspace(b, bases)

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

function pitcher_draw(p)
    local sx, sy = draw_player(p)
end

-->8
-- ball.

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

        -- state of the ball.
        state = initial_state,

        -- throw animation.
        t = 0, -- timer field used for animation.
        throw_duration = -1, -- this is dynamically set elsewhere.

        -- populated when thrown. of type cubic_bezier.
        trajectory = nil,

        -- whether a first bounce has been seen.
        -- reset upon returning the ball to the pitcher.
        has_bounced = false,
    }
end

function simulate_ball_physics_async(b, fielders, catcher1, pitcher1, active_batter, num_strikes)
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

        assert(false, 'todo: pass in a score object to update instead of returning results')
        return evaluate_ball_bounced_async(b, catcher1, pitcher1, active_batter, num_strikes)
    end
    return result_nothing
end

function evaluate_ball_bounced_async(ball, catcher1, pitcher1, active_batter, num_strikes)
    assert(active_batter!=nil)
    assert(false, 'todo: pass in a scoring object.')
    local result = is_fair(ball.pos)
    if not ball.has_bounced then
        if result == ball_is_foul then
            local return_code = result_nothing
            if num_strikes < 2 then
                log('strike!')
                return_code = result_strike
            end
            return_ball_to_catcher_async(ball, catcher1, pitcher1)
            return return_code
        elseif result == ball_is_home_run then
            local return_code = result_nothing
            log('home run!')
            return_ball_to_catcher_async(ball, catcher1, pitcher1)
            return_code = result_run
            return return_code
        end
        ball.has_bounced = true
    else
        if result == ball_is_home_run then
            if ball.pos.y > home_run_y_threshold then
                local return_code = result_nothing
                log('ground rule double') assert(false)
                return_ball_to_catcher_async(ball, catcher1, pitcher1)
                return return_code
            else
                -- hit the endfield walls. zero out velocity.
                ball.vel.x = 0
                ball.vel.y = 0
                ball.vel.z = 0

                -- return ball after 1s.
                delay(function()
                    return_ball_to_catcher_async(ball, catcher1, pitcher1)
                end, 60)
            end
        elseif ball.state != ball_returning then
            local len = length(ball.vel)
            if len < 1 then
                -- update the ball state.
                ball.state = ball_returning

                -- the ball has settled. return the ball to the catcher.
                delay(function()
                    return_ball_to_catcher_async(ball, catcher1, pitcher1)
                end, 60)
            end
        end
    end
    return result_nothing
end

function is_foul(ball1)
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

function return_ball_to_pitcher(b, fielder, pitcher)
    assert(fielder != nil)
    assert(pitcher != nil)
    log('ball is returned')

    -- reset ball state.
    b.has_bounced = false
    b.is_owned_by = nil

    -- set trajectory.
    local start = get_fielder_midpoint(fielder)
    local _end = get_fielder_midpoint(pitcher)
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

function is_strike(b)
    -- x should be -2.5 to 2.5 for strike.
    -- y should be 2.5 to 7.5 for strike.
    local half_strike_zone = 2.5
    local xl, xr = -half_strike_zone, half_strike_zone
    local yb, yt = 5 - half_strike_zone, 5 + half_strike_zone
    local x = b.pos.x
    local y = b.pos.y
    if xl<=x and x<=xr and yb<=y and y<=yt then
        log('strrrrrike!')
        return true
    else
        log('ball!')
        return false
    end
end

function pickup_ball_async(b, fielders, catcher1, pitcher1, active_batter)
    assert(#fielders>0)

    local result = nil
    for f in all(fielders) do
        local d = distance2(get_fielder_midpoint(f), b.pos, nil, nil, nil)
        if d<ball_catch_radius then
            b.state = ball_holding
            b.is_owned_by = f

            if f==catcher1 then
                log('ball was caught')

                if active_batter.state != batter_swinging_ball_was_hit then
                    result = is_strike(b)
                end

                -- after 1s, catcher throws the ball back.
                delay(function()
                    return_ball_to_pitcher(b, f, pitcher1)
                end, 60)

                return result
            end
        end
    end
    return result
end

function return_ball_to_catcher_async(ball, catcher1, pitcher1)
    ball.state = ball_holding
    ball.is_owned_by = catcher1

    delay(function()
        return_ball_to_pitcher(ball, catcher1, pitcher1)
    end, 60)
end

function animate_ball_throw_async(b, fielders, catcher1, pitcher1, active_batter)
    -- update the ball's position.
    local t = b.t / b.throw_duration
    cubic_bezier_fixed_sample(100, b.trajectory, t, b.pos)

    -- if the ball has been thrown, then
    if t>.2 then
        -- check whether any fielders are around to catch.
        -- can filter out by is_owned_by
        assert(fielders~=nil)
        pickup_ball_async(b, fielders, catcher1, pitcher1, active_batter)
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

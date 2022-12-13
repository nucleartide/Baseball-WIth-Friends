
do -- Start game state scope.

local bases -- 15 tokens to get rid of global state. i'll take it.
    , pitchers_mound
    , batters_box
    , catchers_box
    , raised_pitcher_mound
    , raised_home_plate
    , pitcher1
    , catcher1
    , ball1
    , fielders
    , batter1
    , score
    , active_batter

function init_game()
    bases = {
        vec3(0, 0, -half_diagonal), -- home
        vec3(half_diagonal, 0, 0), -- 1st
        vec3(0, 0, half_diagonal), -- 2nd
        vec3(-half_diagonal, 0, 0), -- 3rd
    }

    pitchers_mound = vec3()

    -- flip the x axis for lefty's batter box.
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

    ball1 = ball(raised_pitcher_mound, ball_holding, pitcher1)

    fielders = {catcher1, pitcher1}

    batter1 = batter(-10, bases[1].z, 1, 'right')

    score = {
        num_strikes = 0,
        num_balls = 0,
        num_runs = 0,
    }

    active_batter = batter1
end

function update_game()
    local function on_strike_score()
        log('strike')
        score.num_strikes += 1
    end

    local function on_return_ball()
        return_ball_to_pitcher(ball1, catcher1, pitcher1, active_batter)
    end

    update_fielder(pitcher1, is_owner(ball1, pitcher1), function()
        throw_ball(ball1, pitcher1.pitches[1])
    end)

    update_batter(batter1, ball1, bases, catcher1, function(swing_t)
        hit_ball(ball1, batter1, swing_t, bases)
    end)

    if ball1.state == ball_throwing then
        update_ball_throwing(ball1, fielders, function(fielder1)
            catch_ball(ball1, fielder1, active_batter, catcher1, on_strike_score, on_return_ball)
        end)
    elseif ball1.state == ball_idle_physical_obj then
        simulate_ball_physics(ball1, fielders, catcher1, pitcher1, active_batter, score, on_return_ball)
    elseif ball1.state == ball_holding then
        -- no-op.
    elseif ball1.state == ball_returning then
        -- no-op.
    else
        assert(false, 'unhandled case')
    end
end

function draw_game()
    cls(3)

    fixed(ball1.pos.x)
    fixed(ball1.pos.y)
    fixed(ball1.pos.z)
    fixed(is_fair(ball1.pos))
    fixed('strikes:' .. score.num_strikes)
    fixed('balls:' .. score.num_balls)
    fixed('runs:' .. score.num_runs)
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
        {batter1.pos, batter1, function() draw_batter(batter1, bases) end},
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
    cprint(score.num_balls .. '-' .. score.num_strikes, 1, 7)
    print(score.num_runs, 1, 1, 7)
end

end -- End game state scope.

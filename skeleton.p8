pico-8 cartridge // http://www.pico-8.com
version 38
__lua__

#include utils.p8

-->8
-- game loop.

function skeleton(
    hip_y,
    leg_len,
    torso_len,
    arm_len,
    neck_len
)
    return {
        pos = vec3(),
        left_foot = vec3(),
        right_foot = vec3(),
        hip = vec3(),
        chest = vec3(),
        left_arm = vec3(),
        right_arm = vec3(),
        head = vec3(),

        hip_y = hip_y,
        leg_len = leg_len,
        torso_len = torso_len,
        arm_len = arm_len,
        neck_len = neck_len,
    }
end

function compute_skeleton(s)
    -- compute hip.
    vec3_set(s.hip, s.pos)
    s.hip.y += s.hip_y

    -- compute chest.
    vec3_set(s.chest, s.hip)
    s.chest.y += s.torso_len

    -- compute head.
    vec3_set(s.head, s.chest)
    s.head.y += s.neck_len

    -- compute left foot.
    -- ...

    -- compute right foot.
    -- ...

    -- compute left arm.
    -- ...

    -- compute right arm.
    -- ...
end

function draw_joint(v, r)
    local sx, sy = world2screen(v)
    circfill(sx, sy, r or 1, 7)
end

function draw_line(v1, v2)
    local sx1, sy1 = world2screen(v1)
    local sx2, sy2 = world2screen(v2)
    line(sx1, sy1, sx2, sy2, 8)
end

function draw_skeleton(s)
    draw_line(s.hip, s.chest)
    draw_joint(s.hip)
    draw_joint(s.chest)
    draw_joint(s.head, 2)
end

-->8
-- game loop.

function _init()
    skeleton1 = skeleton(
        -- hip_y = 4,
        4,
        -- leg_len = 0,
        0,
        -- torso_len = 0,
        6,
        -- arm_len = 0,
        0,
        -- neck_len = 0
        2
    )
end

function _update60()
    compute_skeleton(skeleton1)
end

function _draw()
    cls()
    print('testing skeleton')
    draw_skeleton(skeleton1)
end

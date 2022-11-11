pico-8 cartridge // http://www.pico-8.com
version 38
__lua__

#include utils.p8

-- todo: how do you move legs?

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

        -- animation timer.
        t = 0,
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
    vec3_set(s.left_foot, s.hip)
    s.left_foot.x -= 2
    s.left_foot.y -= 5
    s.left_foot.z += 3 * sin(s.t)

    -- compute right foot.
    vec3_set(s.right_foot, s.hip)
    s.right_foot.x += 2
    s.right_foot.y -= 5
    s.right_foot.z += 3 * -sin(s.t)

    -- compute left arm.
    vec3_set(s.left_arm, s.chest)
    s.left_arm.x -= 4

    -- compute right arm.
    vec3_set(s.right_arm, s.chest)
    s.right_arm.x += 4
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
    draw_limb(s.hip, s.left_foot, s.leg_len, vec3(-1, 0, -1))
    draw_limb(s.hip, s.right_foot, s.leg_len, vec3(1, 0, -1))
    draw_limb(s.chest, s.left_arm, s.arm_len, skeleton_bend_backward)
    draw_limb(s.chest, s.right_arm, s.arm_len, skeleton_bend_backward)
    draw_joint(s.hip)
    draw_joint(s.chest)
    draw_joint(s.head, 2)
end

-- bend_dir should be the direction that the char is facing.
skeleton_bend_backward = vec3(0, 0, 1)
skeleton_bend_forward = vec3(0, 0, -1)
function draw_limb(v1, v2, desired_len, bend_dir)
    -- default value.
    bend_dir = bend_dir or skeleton_bend_backward

    -- how long is the requested line?
    local d = distance2(v1, v2)

    if d>desired_len then
        -- then distance is greater than requested length.
        -- normalize the difference vector to the requested length.
        local v = vec3_set(vec3(), v2)
        vec3_sub_from(v, v1)
        vec3_normalize(v)
        vec3_mul(v, desired_len)
        vec3_add_to(v, v1)

        -- draw limb.
        draw_line(v1, v)
    else
        -- get the center of v1 + v2.
        local v = vec3_set(vec3(), v1)
        vec3_add_to(v, v2)
        vec3_mul(v, .5)

        -- compute the amount to push joint outward.
        local bend_factor = abs(desired_len - d) * .71
        local b = vec3_set(vec3(), bend_dir)
        vec3_mul(b, bend_factor)

        -- add to center.
        vec3_add_to(v, b)

        -- draw limb in 2 parts.
        draw_line(v1, v)
        draw_line(v, v2)
    end
end

-->8
-- game loop.

function _init()
    skeleton1 = skeleton(
        -- hip_y = 4,
        4,
        -- leg_len = 0,
        6,
        -- torso_len = 0,
        3,
        -- arm_len = 0,
        6,
        -- neck_len = 0
        2
    )
end

function move_skeleton(s)
    if btn(0) then
        s.pos.x -= 1
    end
    if btn(1) then
        s.pos.x += 1
    end
    if btn(2) then
        s.pos.z += 1
    end
    if btn(3) then
        s.pos.z -= 1
    end
    s.t += .01
end

function _update60()
    move_skeleton(skeleton1)
    compute_skeleton(skeleton1)
end

function _draw()
    cls(3)
    print('testing skeleton')
    vec3_print(skeleton1.pos)
    draw_skeleton(skeleton1)
end

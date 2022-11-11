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
    vec3_set(s.left_foot, s.hip)
    s.left_foot.x -= 2
    s.left_foot.y -= 9

    -- compute right foot.
    vec3_set(s.right_foot, s.hip)
    s.right_foot.x += 2
    s.right_foot.y -= 9

    -- compute left arm.
    vec3_set(s.left_arm, s.chest)
    s.left_arm.x -= 10

    -- compute right arm.
    vec3_set(s.right_arm, s.chest)
    s.right_arm.x += 10
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
    draw_limb(s.hip, s.left_foot, s.leg_len)
    draw_limb(s.hip, s.right_foot, s.leg_len)
    draw_limb(s.chest, s.left_arm, s.arm_len)
    draw_limb(s.chest, s.right_arm, s.arm_len)
    draw_joint(s.hip)
    draw_joint(s.chest)
    draw_joint(s.head, 2)
end

function draw_limb(v1, v2, desired_len)
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
        -- ...
    end
end

--[[
-- get the length of the vector from p1 to p2.
--
-- if present, alt_c is used for the 2nd line segment for
-- lines that are split into 2 segments.
function draw_limb(v1, v2, c, water_c, desired_len, bend_dir, alt_c)
	-- if the dist is greater than the requested length,
	if dist>desired_len then
		-- then the requested line is too long. clamp its length + draw.
		local v2_clamped = v2:dupe()
			:sub(v1)
			:normalize()
			:mul(desired_len)
			:add(v1)
		if alt_c then
			local between = v1:dupe():add(v2_clamped):mul(.5)
			draw_line_in_water2(v1, between, c, water_c, 'limb1')
			draw_line_in_water2(v2_clamped, between, alt_c, alt_c, 'limb1')
		else
			draw_line_in_water2(v1, v2_clamped, c, water_c, 'limb1')
		end

	-- otherwise,
	else
		-- the requested line is too short. introduce a knee or elbow:

		-- get the center of v1 + v2.
		local joint = v1:dupe():add(v2):mul(.5)

		-- push the joint outward.
		local bend_factor = (desired_len-dist)/1.4
		joint:add(
			bend_dir:dupe():mul(bend_factor)
		)

		-- draw 2 separate lines.
		draw_line_in_water2(v1, joint, c, water_c, 'limb2')
		draw_line_in_water2(v2, joint, alt_c or c, alt_c or water_c, 'limb2')
	end
end
]]

-->8
-- game loop.

function _init()
    skeleton1 = skeleton(
        -- hip_y = 4,
        4,
        -- leg_len = 0,
        8,
        -- torso_len = 0,
        4,
        -- arm_len = 0,
        5,
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
end

function _update60()
    compute_skeleton(skeleton1)
    move_skeleton(skeleton1)
end

function _draw()
    cls(3)
    print('testing skeleton')
    vec3_print(skeleton1.pos)
    draw_skeleton(skeleton1)
end

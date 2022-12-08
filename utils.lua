
--
-- ## vec3 operations.
--

function vec3(x, y, z)
	return {
		x = x or 0,
		y = y or 0,
		z = z or 0,
	}
end

function vec3_lerp_into(v1, v2, v3, t)
	v3.x = lerp(v1.x, v2.x, t)
	v3.y = lerp(v1.y, v2.y, t)
	v3.z = lerp(v1.z, v2.z, t)
	return v3
end

function vec3_to_screen(v)
	return v.x+64,v.y+64
end

function vec3_from_screen(sx, sy, v)
	v.x = sx - 64
	v.y = sy - 64
	v.z = 0
end

-- check whether vector v1 is in circle defined by v2 and r.
-- note that the z components of v1 and v2 are unused.
function vec3_in_circle(v1, v2, r)
	local d = distance(v1, v2)
	return d <= r
end

function vec3_print(v, to_console)
	local func = to_console and printh or print
	func(v.x .. ',' .. v.y .. ',' .. v.z)
end

function vec3_set(v1, v2)
	v1.x = v2.x
	v1.y = v2.y
	v1.z = v2.z
	return v1
end

function vec3_flip(v)
	return vec3(v.x*-1, v.y, v.z)
end

function vec3_add_to(v1, v2)
	v1.x += v2.x
	v1.y += v2.y
	v1.z += v2.z
	return v1
end

function vec3_sub_from(v1, v2)
	v1.x -= v2.x
	v1.y -= v2.y
	v1.z -= v2.z
	return v1
end

function vec3_sub(v1, v2)
	local new_v = vec3_set(vec3(), v1)
	new_v.x -= v2.x
	new_v.y -= v2.y
	new_v.z -= v2.z
	return new_v
end

function vec3_mul(v1, c)
	v1.x *= c
	v1.y *= c
	v1.z *= c
	return v1
end

function vec3_mul2(v1, c)
	local v2 = vec3_set(vec3(), v1)
	v2.x *= c
	v2.y *= c
	v2.z *= c
	return v2
end

function vec3_zero(v)
	v.x = 0
	v.y = 0
	v.z = 0
end

function vec3_raise(v, height)
	local new = vec3_set(vec3(), v)
	new.y += height
	return new
end

-- return distance in case you want to do something with it
function vec3_normalize(v)
	local d =distance2(vec3(), v)
	v.x /= d
	v.y /= d
	v.z /= d
	return d
end

function vec3_normalize2(v)
	local d =distance2(vec3(), v)
	local v2 = vec3_set(vec3(),v)
	v2.x /= d
	v2.y /= d
	v2.z /= d
	return v2
end

-- amount that is in common between two vectors.
function vec3_dot(v1, v2)
	return v1.x*v2.x + v1.y*v2.y + v1.z*v2.z
end

--function crossProduct(v1, v2)
--return [v1[1]*v2[2] - v1[2]*v2[1], v1[2]*v2[0] - v1[0]*v2[2], v1[0]*v2[1] - v1[1]*v2[0]]

function matrix_multiply(m, v)
	return vec3(
		vec3_dot(m[1], v),
		vec3_dot(m[2], v),
		vec3_dot(m[3], v)
	)
end

function rotate_angle_axis(v, angle, axis)
	local ca = cos(angle)
	local sa = sin(angle)
	local t = 1 - ca
	-- print(ca)
	-- print(sa)
	-- print(t)
	local x = axis.x
	local y = axis.y
	local z = axis.z

	-- copied from rosetta code javascript implementation.
	-- recopy if something seems off, since i have no idea how this works lol.
	local rotation_matrix = {
        vec3(ca + x*x*t, x*y*t - z*sa, x*z*t + y*sa),
        vec3(x*y*t + z*sa, ca + y*y*t, y*z*t - x*sa),
        vec3(z*x*t - y*sa, z*y*t + x*sa, ca + z*z*t),
	}

	-- vec3_print(rotation_matrix[1])
	-- vec3_print(rotation_matrix[2])
	-- vec3_print(rotation_matrix[3])
	return matrix_multiply(rotation_matrix, v)
end

do
	cls()
	local v1 = vec3(1, 0, 0)
	local axis = vec3(0, 1, 0)
	local angle = .75 -- goes counterclockwise if you face down from the top of the axis
	local result = rotate_angle_axis(v1, angle, axis)
	vec3_print(v1)
	vec3_print(result)
	-- assert(false, result)
end

--
-- ## general math utilities.
--

function lerp(a, b, t)
	return (1-t)*a + t*b
end

function distance(v1, v2)
	local dx = abs(v2.x - v1.x)
	local dy = abs(v2.y - v1.y)
	return sqrt(dx*dx + dy*dy)
end

-- a revised distance function more amenable to large numbers.
function distance2(a, b, ignore_x, ignore_y, ignore_z)
  -- scale inputs down by 6 bits
  local dx=(a.x-b.x)/64
  local dy=(a.y-b.y)/64
  local dz=(a.z-b.z)/64
  if (ignore_x) dx=0
  if (ignore_y) dy=0
  if (ignore_z) dz=0

  -- get distance squared
  local dsq=dx*dx+dy*dy+dz*dz

  -- in case of overflow/wrap
  if(dsq<0) then return 32767.99999 end

  -- scale output back up by 6 bits
  return sqrt(dsq)*64
end

function length(v)
	return distance2(v, vec3())
end

-- modulo operator that works with lua indices, which start at 1.
function luamod(i, mod)
    return (i-1)%mod+1
end

--
-- ## general drawing utilities.
--

circle_r = 4

function draw_line(p1, p2)
	local sx1,sy1 = vec3_to_screen(p1)
	local sx2,sy2 = vec3_to_screen(p2)
	line(sx1, sy1, sx2, sy2, 7)
end

function draw_circle(p1, highlight)
	local sx,sy = vec3_to_screen(p1)
	circ(sx, sy, circle_r, highlight and 8 or 7)
end

--
-- ## cubic bezier operations.
--

function cubic_bezier(v1, v2, v3, v4)
	return {v1, v2, v3, v4}
end

do
	local p5, p6, p7, p8, p9 = vec3(), vec3(), vec3(), vec3(), vec3() -- 3 intermediary points, 2 final points

	-- note: use cubic_bezier_fixed_sample instead.
	function cubic_bezier_sample(c, t, final_p)
		local p1 = c[1]
		local p2 = c[2]
		local p3 = c[3]
		local p4 = c[4]

		-- intermediary points
		vec3_lerp_into(p1, p2, p5, t)
		vec3_lerp_into(p2, p3, p6, t)
		vec3_lerp_into(p3, p4, p7, t)

		-- 2nd intermediary points
		vec3_lerp_into(p5, p6, p8, t)
		vec3_lerp_into(p6, p7, p9, t)

		-- final point
		vec3_lerp_into(p8, p9, final_p, t)
	end
end

-- compute n points along a curve defined by cubic_bezier_func,
-- and return the n points in a lua table.
function arclength(n, cubic_bezier_func)
	local total_dist, total_dists, dists_between_points = 0, {}, {}

	for i=0,n-1 do
		-- calculate current and next points.
		local v1, v2 = vec3(), vec3()
		cubic_bezier_sample(cubic_bezier_func, i/n, v1)
		cubic_bezier_sample(cubic_bezier_func, (i+1)/n, v2)

		-- get the distance between the 2 points.
		local d = distance2(v1, v2)

		-- store in dists_between_points,
		-- where index is current total_dist.
		dists_between_points[total_dist] = {v1, v2, d}

		-- store total_dist in total_dists,
		-- where index is 1..n
		add(total_dists, total_dist)

		-- update total_dist.
		total_dist += d
	end

	-- total_dists is indexed by 1..n
	-- dists_between_points is indexed by total_dist, and returns {v1, v2, dist_between_points}
	return total_dist, total_dists, dists_between_points
end

do
local temp_vec = vec3()

-- map t to fixed_t so that you are sampling more evenly.
-- num_points:        number of points to compute
-- t:                 interpolation parameter
-- cubic_bezier_func: cubic bezier funtion
function cubic_bezier_fixed_sample(num_points, cubic_bezier_func, t, result_vec)
	-- gather values from arclength function.
	local total_dist, total_dists, dists_between_points = arclength(num_points, cubic_bezier_func)

	-- get distance along the arclength.
	local normalized_t, nearest_total_dist = t * total_dist, nil

	-- given the distance, compute the nearest point on the arclength.
	for d in all(total_dists) do
		-- find the nearest point that is passed by normalized_t.
		if (normalized_t - d) < 0 then break end
		nearest_total_dist = d
	end

	-- lerp between the nearest point on the arclength and its neighbor to get an approximation.
	local dist_between_points = dists_between_points[nearest_total_dist]
	local v1, v2, d = dist_between_points[1], dist_between_points[2], dist_between_points[3]
	local percent = (normalized_t - nearest_total_dist) / d

	-- v1 + (v2 - v1) * percent
	vec3_set(temp_vec, v2)
	vec3_sub_from(temp_vec, v1)
	vec3_mul(temp_vec, percent)
	vec3_add_to(temp_vec, v1)
	vec3_set(result_vec, temp_vec)
	return result_vec
end
end

-- this is used only for debugging.
-- if you are using a cubic bezier to animate another object, you probably don't need to draw the line out explicitly.
function cubic_bezier_draw(c, highlighted_point)
	local p1 = c[1]
	local p2 = c[2]
	local p3 = c[3]
	local p4 = c[4]
	local p5, p6, p7, p8, p9, p10 = vec3(), vec3(), vec3(), vec3(), vec3(), vec3() -- 3 intermediary points, 2 final points

	local incr=.01
	local sx1,sy1,sx2,sy2
	for t=0,1,incr do
		-- intermediary points
		vec3_lerp_into(p1, p2, p5, t)
		vec3_lerp_into(p2, p3, p6, t)
		vec3_lerp_into(p3, p4, p7, t)

		-- 2nd intermediary points
		vec3_lerp_into(p5, p6, p8, t)
		vec3_lerp_into(p6, p7, p9, t)

		-- final point
		vec3_lerp_into(p8, p9, p10, t)
		sx1,sy1=vec3_to_screen(p10)

		-- intermediary points
		vec3_lerp_into(p1, p2, p5, t+incr)
		vec3_lerp_into(p2, p3, p6, t+incr)
		vec3_lerp_into(p3, p4, p7, t+incr)

		-- 2nd intermediary points
		vec3_lerp_into(p5, p6, p8, t+incr)
		vec3_lerp_into(p6, p7, p9, t+incr)

		-- final point
		vec3_lerp_into(p8, p9, p10, t+incr)
		sx2,sy2=vec3_to_screen(p10)

		line(sx1, sy1, sx2, sy2, 7)
	end

	draw_circle(p1, p1 == highlighted_point)
	draw_circle(p2, p2 == highlighted_point)
	draw_circle(p3, p3 == highlighted_point)
	draw_circle(p4, p4 == highlighted_point)

	draw_line(p1, p2)
	draw_line(p2, p3)
	draw_line(p3, p4)
end

--
-- ## quadratic bezier operations.
--
-- it is preferable to use cubic_bezier, so this is commented out.
--

--[[
function quadratic_bezier(v1, v2, v3)
	return {v1, v2, v3}
end

function quadratic_bezier_draw(q)
	local p1 = q[1]
	local p2 = q[2]
	local p3 = q[3]
	local p4 = vec3()
	local p5 = vec3()
	local p6 = vec3()
	local p7 = vec3()

	local incr=.01
	for t=0,1,incr do
		vec3_lerp_into(p1, p2, p4, t)
		vec3_lerp_into(p2, p3, p5, t)
		vec3_lerp_into(p4, p5, p6, t)

		vec3_lerp_into(p1, p2, p4, t+incr)
		vec3_lerp_into(p2, p3, p5, t+incr)
		vec3_lerp_into(p4, p5, p7, t+incr)

		local sx1,sy1=vec3_to_screen(p6)
		local sx2,sy2=vec3_to_screen(p7)

		line(sx1,sy1,sx2,sy2,7)
	end

	draw_circle(p1)
	draw_circle(p2)
	draw_circle(p3)
	draw_line(p1, p2)
	draw_line(p2, p3)
end
]]

--
-- ## transformation functions.
--

-- no_y is used for shadows.
function old_world2screen(o,no_y)	
	-- world 2 camera
	local x = o.x
	local y = max(o.y, 0) -- cannot be negative.
    local z = o.z
    z += 64 -- since our home plate is at the origin, and we are disallowing negative numbers, offset z so stuff isn't warped.
	z = max(z, 0) -- cannot be negative.

	if no_y then y=0 end
	local pz = 1+z*.01
	local ppz = 1+z*.01
	
	-- camera 2 screen
	-- x smaller as z increases
	-- z smaller as z increases
	-- y smaller as z increases
	-- x larger as y increases
	sx = 64+(x/pz+y*x*.01/pz)*1.75
	sy = 64-(z/pz+y/pz)*1.75+64 -- 1.5 to magnify, 64 to undo the previous offset
	return sx,sy
end

function world2screen(o, no_y, flip_x)	
	-- x.
	local x = o.x
	if (flip_x) x *= -1

	-- y. cannot be negative.
	local y = max(o.y, 0)

	-- y. account for shadows.
	if no_y then y=0 end

	-- z. cannot be negative.
	local z = o.z
	z += 64 -- bump things forward so we can treat a point slightly behind home plate as the origin.
	z = max(z, 0)

	-- perspective factors.
	local pz = 1+z*.01
	
	-- camera 2 screen.
	local sx = 64 + (x/pz + y*x*.01/pz)*1.75 -- the second term means: as y gets larger, x gets larger, however influenced by the sign and magnitude of x.
	local sy = 128 - (z/pz + y/pz)*1.75
	return sx, sy
end

function worldspace(parent_pos, pos)
	local v = vec3_add_to(vec3(), parent_pos)
	vec3_add_to(v, pos)
	return v
end

--
-- ## general input utilities.
--

-- returns true on the frame that btn() transitions from true to false.
-- note: remember to call btnr_update() at the start of your game's update function, otherwise btnr() will not be accurate.
do
    local prev = {false, false, false, false, false, false}
    local prev1 = {false, false, false, false, false, false}
    local curr = {false, false, false, false, false, false}
    local curr1 = {false, false, false, false, false, false}

    function btnr(i, player)
        if player==1 then
            return prev1[i+1] and not curr1[i+1]
        end
        return prev[i+1] and not curr[i+1]
    end

    function btnr_update()
        -- set prev to curr
        for i=1,6 do
            prev[i] = curr[i]
            prev1[i] = curr1[i]
        end

        -- update curr
        for i=0,5 do
            curr[i+1] = btn(i)
            curr1[i+1] = btn(i, 1)
        end
    end

    function btnr_print()
        for i=0,5 do
            print(btnr(i) .. ';' .. btnr(i,1))
        end
    end
end

--
-- ## general object utilities.
--

function assign(obj1, obj2)
	for k,v in pairs(obj2) do
		obj1[k] = v
	end
	return obj1
end

function concat(list1, list2)
	local list3 = {}
	for obj in all(list1) do add(list3, obj) end
	for obj in all(list2) do add(list3, obj) end
	return list3
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
    return t
end

do
	local functions = {}

	function delay(reified_function, t)
		add(functions, {reified_function, t})
	end

	function count_down_timers()
		for f in all(functions) do
			f[2] -= 1
			if f[2]<=0 then
				f[1]()
				del(functions, f)
			end
		end
	end
end

function clamp(n, a, b)
	return max(min(n, b), a)
end

-- given n, and bounds a and b, determine the t value.
function inverse_lerp(n, a, b)
	return (n - a) / (b - a)
end

function cprint(msg, y, c)
    local half_width = #msg * 2 -- 4 pixels per character, but halved.
    local x = 64 - half_width
    print(msg, x, y, c)
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

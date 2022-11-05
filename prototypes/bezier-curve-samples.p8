pico-8 cartridge // http://www.pico-8.com
version 38
__lua__

#include ../utils.p8




local d = distance2(
    vec3(14.8498,0.1486,0),
    vec3(15,0,0)
)
printh(d)

curve = cubic_bezier(
    vec3(0, 0, 0),
    vec3(5, 5, 0),
    vec3(10, 5, 0),
    vec3(15, 0, 0)
    --[[
vec3(0,5,0),
vec3(16.4993,15,0),
vec3(33.4999,15,0),
vec3(50,5,0)
    ]]
)

--[[
]]

printh()
for i=0,1.5,.1 do
    local v1 = vec3()
    cubic_bezier_fixed_sample(10, curve, i, v1)
    printh(i)
    vec3_print(v1, true)
end

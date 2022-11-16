pico-8 cartridge // http://www.pico-8.com
version 38
__lua__

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

function sort(t, a, b)
    local a, b = a or 1, b or #t
    if (a >= b) return
    local m = (a + b) \ 2
    local j, k = a, m + 1
    sort(t, a, m)
    sort(t, k, b)
    local v = { unpack(t) }
    for i = a, b do
        if (k > b or j <= m and v[j] <= v[k]) t[i] = v[j] j += 1 else t[i] = v[k] k += 1
    end
end

function _init()
    test_table = {
        {y = 5, z=0},
        {y = 0, z=0},
        {y = -1, z=0},
    }
    isort(test_table)
end

function _draw()
    cls()
    for i=1,#test_table do
        print(test_table[i].y .. ' ' .. test_table[i].z)
    end
end

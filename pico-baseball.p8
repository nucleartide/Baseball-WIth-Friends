pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- pico baseball
-- by @nucleartide

#include utils.lua
#include constants.lua
#include entities.lua
#include game_state.lua

-- naming conventions:
--
-- draw_<entity> - no mutation
-- <verb>_<entity> - mutates first arg
-- <verb>_<entity>_and_<entity> -- mutates second arg
-- get_<entity>_<description> - no mutation
-- is_<description> -- no mutation
-- <something>_<async> -- indicates that this function contains a delay
-- vec3s functions are generally mutable. but write immutable versions of vec3 functions in the future.

--    - [ ] todo: pass in a scoring object.
--    - [ ] Fix up game so there are reasonably no exceptions; do this by reviewing code for false assertions
-- assert(false, 'you no longer need to ctrl-r, please play the game loop and think where it needs to go')

_init = init_game

function _update60()
    btnr_update()
    update_game()
    count_down_timers()
end

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

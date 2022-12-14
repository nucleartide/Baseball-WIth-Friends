
--
-- constants.
--

left_wall = vec3_normalize2(vec3(1, 0, -1))
right_wall = vec3_normalize2(vec3(-1, 0, -1))
debug = true
rel_to_home_plate_x = 7
half_diagonal = 50 -- in world units.
game2real = 64/50 -- baseball field dimensions are scaled down from reality to keep gameplay tight together.
real2game = 50/64
gravity = -50
home_run_y_threshold = 5

-- note that ball_hit_z_range and ball_catch_radius should add to 5.
ball_hit_z_range = 2 -- hit if ball is within 2.5 units on the z axis.
ball_hit_y_range = 3 -- hit if ball is within 3 units on the y axis.
ball_catch_radius = 2 -- catch if ball is within 2.5 units.

--
-- result states.
--

ball_is_foul = 0
ball_is_home_run = 1
ball_is_in_field = 2

--
-- entity states.
--

ball_holding = 'holding'
ball_throwing = 'throwing'
ball_idle_physical_obj = 'idle'

-- this constant is important for disabling swings while the ball is getting returned.
ball_returning = 'returning' -- the ball has been caught by the catcher, and is awaiting return to the pitcher.

batter_batting = 'batting' -- handles the "no swing" case.
batter_charging = 'charging' -- meaning that z is held down.
batter_swinging = 'swinging' -- meaning that the bat is actively being swung.
batter_swinging_and_hit = 'swinging and hit'
batter_swing_and_hit = 'swing and hit' -- meaning that the bat has been swung, and the ball was hit.
batter_swing_and_miss = 'swing and miss' -- meaning that the bat has been swung, and the ball was missed.
function did_batter_miss(b) return b.state != batter_swinging_and_hit and b.state != batter_swing_and_hit end

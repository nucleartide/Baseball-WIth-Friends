
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

ball_holding = 0
ball_throwing = 1
ball_idle_physical_obj = 2
ball_returning = 3 -- the ball has been caught by the catcher, and is awaiting return to the pitcher.

batter_batting = 0 -- handles the "no swing" case.
batter_charging = 1 -- meaning that z is held down.
batter_swinging = 2 -- meaning that the bat is actively being swung.
batter_swinging_and_hit = 3
batter_swing_and_hit = 4 -- meaning that the bat has been swung, and the ball was hit.
batter_swing_and_miss = 5 -- meaning that the bat has been swung, and the ball was missed.
function did_batter_miss(b) return b.state != batter_swinging_and_hit and b.state != batter_swing_and_hit end


local left_wall = vec3_normalize2(vec3(1, 0, -1))
local right_wall = vec3_normalize2(vec3(-1, 0, -1))

ball_hit_z_range = 2 -- hit if ball is within 2.5 units on the z axis.
ball_hit_y_range = 3 -- hit if ball is within 3 units on the y axis.
ball_catch_radius = 2 -- catch if ball is within 2.5 units.
-- note that ball_hit_z_range and ball_catch_radius should add to 5.
debug = true
rel_to_home_plate_x = 7
half_diagonal = 50 -- in world units.
game2real = 64/50 -- baseball field dimensions are scaled down from reality to keep gameplay tight together.
real2game = 50/64

ball_is_foul = 'foul'
ball_is_home_run = 'home run'
ball_is_in_field = 'in field'

gravity = -50

home_run_y_threshold = 5

ball_holding = 0
ball_throwing = 1
ball_idle_physical_obj = 2
ball_returning = 3 -- the ball has been caught by the catcher, and is awaiting return to the pitcher.

batter_batting = 0
batter_charging = 1
batter_swinging = 2
batter_running_unsafe = 3
batter_running_safe = 4
batter_swinging_ball_was_hit = 5

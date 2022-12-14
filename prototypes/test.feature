Feature: pitching

    as a pitcher,
    i want to pitch the ball,
    so that the batter can swing at the ball.

    @done
    scenario: simple throw
        Given a catcher is available to receive pitches,
        When the pitcher presses z,
        Then the ball is pitched to the catcher.

    @done
    scenario: throw back
        given a catcher has the ball,
        when 1 second has passed,
        then the ball is returned to the game's pitcher.

Feature: batting

    as a batter,
    i want to swing at the ball,
    so that i can move the ball into play and get a chance to score runs.

    @bug @done
    scenario: hit the ball
        given a batter
        when i've hit the ball,
        then the catcher should not catch the ball.

    @bug @done
    scenario: visualizing the batting range
        given a batter
        when i press z
        then i want to see the batting range for debugging

    @done
    scenario: hitting the ball

    @done
    scenario: aiming up and down

    @done
    scenario: releasing the bat

    @done
    scenario: moving left and right
        given a batter
        when i press left or right
        then i inch left or right in the batter's box.

    # just needed to tweak the hit timing
    # hitting ball on inner end of bat is rare
    @bug @still-a-bug @done
    scenario: can't hit ball on inner end of bat

    @bug @done
    scenario: can't control direction of hit that well

    # moved catcher back a little
    @bug @done
    scenario: catcher sometimes still catches ball

    @bug @done
    scenario: pitcher can't rethrow when ball is in motion

    @bug @done
    scenario: can't hit home runs, meat of bat has more power

    @ready-for-dev
    scenario: game scoring

# case: swing and hit (should have action UI)
    # foul ball -> strike up to 2 strikes, otherwise nothing
    # home run -> run
    # line drive (normal hit) -> runners progress
    # timeout is reached (normal hit) -> runners progress
# case: swing and miss -> strike
# case: no swing
    # strike zone -> strike
    # not strike zone -> ball

# update score with strike or ball

# post score update
# 4 balls: walk
# 3 strikes: out
# 3 outs: next inning
    # increment inning
    # switch roles
    # if there are no innings, go to game end condition
# 9 innings: game over

# game end condition
    # side with most runs wins

    @juice
    scenario: camera juice, audience, crowd roaring

    @cleanup
    scenario: ...
        charging the bat

feature: pitching (out of scope)

    @out-of-scope
    scenario: curve ball

feature: batting (not mechanics)

    @juice
    scenario: show some hit particles upon hit

    @art
    scenario: sprites are boxes

    @sound
    scenario: no sound

feature: batting (out of scope)

    @out-of-scope
    Scenario: charging the bat
        Given blah
        When Start to type your When step here
        Then Start to type your Then step here

    @out-of-scope
    scenario: using charged-up energy

    @out-of-scope
    scenario: cancel swing

    @out-of-scope
    scenario: check swing

    @out-of-scope
    scenario: check swing for bunt

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
    @bug @still-a-bug
    scenario: can't hit ball on inner end of bat

    @bug
    scenario: can't control direction of hit that well

    @bug
    scenario: catcher sometimes still catches ball

    @bug
    scenario: pitcher can't rethrow when ball is in motion

    @bug
    scenario: show some hit particles upon hit

    @bug
    scenario: sprites are boxes

    @bug
    scenario: no sound

    @bug
    scenario: can't hit home runs

    @ready-for-dev
    scenario: timeout after ball is hit or caught or neither, then scorekeeping

feature: pitching (out of scope)

    @out-of-scope
    scenario: curve ball

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

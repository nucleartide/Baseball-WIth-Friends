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

    @ready-for-dev
    Scenario: charging the bat
        Given blah
        When Start to type your When step here
        Then Start to type your Then step here

    @ready-for-dev
    scenario: hitting the ball

    @ready-for-dev
    scenario: aiming up and down

    @ready-for-dev
    scenario: moving left and right

    @ready-for-dev
    scenario: scorekeeping

    @ready-for-dev
    scenario: releasing the bat

feature: pitching (out of scope)

    @out-of-scope
    scenario: curve ball

feature: batting (out of scope)

    @out-of-scope
    scenario: using charged-up energy

    @out-of-scope
    scenario: cancel swing

    @out-of-scope
    scenario: check swing

    @out-of-scope
    scenario: check swing for bunt

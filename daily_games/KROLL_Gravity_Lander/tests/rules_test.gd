extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
    _test_velocity_step()
    _test_fuel_never_goes_negative()
    _test_landing_envelope()
    print("KROLL Gravity Lander rules tests passed.")
    quit(0)

func _test_velocity_step() -> void:
    var result := Rules.step_velocity(Vector2.ZERO, -1, true, 1.0, 10.0, 15.0, 5.0)
    assert(result.is_equal_approx(Vector2(-5.0, -5.0)))
    assert(Rules.step_velocity(Vector2(2.0, 3.0), 0, false, 0.0, 10.0, 15.0, 5.0) == Vector2(2.0, 3.0))

func _test_fuel_never_goes_negative() -> void:
    assert(is_equal_approx(Rules.consume_fuel(100.0, 20.0), 80.0))
    assert(is_zero_approx(Rules.consume_fuel(3.0, 99.0)))
    assert(is_equal_approx(Rules.consume_fuel(5.0, -10.0), 5.0))
    assert(is_zero_approx(Rules.consume_fuel(10.0, INF)))

func _test_landing_envelope() -> void:
    assert(Rules.landing_outcome(480.0, 0.0, 70.0, 390.0, 570.0, 65.0, 90.0) == "landed")
    assert(Rules.landing_outcome(390.0, -65.0, 90.0, 390.0, 570.0, 65.0, 90.0) == "landed")
    assert(Rules.landing_outcome(389.9, 0.0, 10.0, 390.0, 570.0, 65.0, 90.0) == "crashed")
    assert(Rules.landing_outcome(480.0, 66.0, 10.0, 390.0, 570.0, 65.0, 90.0) == "crashed")
    assert(Rules.landing_outcome(480.0, 0.0, 91.0, 390.0, 570.0, 65.0, 90.0) == "crashed")

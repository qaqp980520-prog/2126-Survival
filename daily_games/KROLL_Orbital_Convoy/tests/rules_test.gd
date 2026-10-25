extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
    _test_collision_radius()
    _test_cargo_count_caps_at_goal()
    _test_damage_never_goes_negative()
    _test_round_outcomes()
    _test_clamp_to_field()
    print("KROLL Orbital Convoy rules tests passed.")
    quit()

func _test_collision_radius() -> void:
    assert(Rules.within_radius(Vector2.ZERO, Vector2(3.0, 4.0), 5.0))
    assert(not Rules.within_radius(Vector2.ZERO, Vector2(3.0, 4.01), 5.0))
    assert(not Rules.within_radius(Vector2.ZERO, Vector2.ONE, -1.0))

func _test_cargo_count_caps_at_goal() -> void:
    assert(Rules.collect_count(0, 6) == 1)
    assert(Rules.collect_count(5, 6) == 6)
    assert(Rules.collect_count(6, 6) == 6)
    assert(Rules.collect_count(0, 0) == 0)

func _test_damage_never_goes_negative() -> void:
    assert(Rules.apply_damage(3) == 2)
    assert(Rules.apply_damage(1, 5) == 0)
    assert(Rules.apply_damage(2, -1) == 2)

func _test_round_outcomes() -> void:
    assert(Rules.outcome(0, 3, 10.0) == "playing")
    assert(Rules.outcome(6, 0, 0.0) == "won")
    assert(Rules.outcome(2, 0, 10.0) == "lost")
    assert(Rules.outcome(2, 3, 0.0) == "lost")

func _test_clamp_to_field() -> void:
    var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
    assert(Rules.clamp_to_field(Vector2(-20.0, 200.0), bounds, 10.0) == Vector2(10.0, 90.0))

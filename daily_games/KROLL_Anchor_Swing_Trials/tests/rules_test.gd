extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_test_anchor_selection()
	_test_rope_geometry()
	_test_horizontal_motion()
	_test_goal_and_score()
	if failures.is_empty():
		print("KROLL Anchor Swing Trials rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_anchor_selection() -> void:
	var anchors: Array = [Vector2(100.0, 0.0), Vector2(180.0, 0.0), Vector2(20.0, 0.0)]
	_expect(Rules.nearest_anchor(Vector2.ZERO, anchors, 120.0) == 2, "nearest anchor is selected inside range")
	_expect(Rules.nearest_anchor(Vector2.ZERO, anchors, 10.0) == -1, "anchors outside range are rejected")
	_expect(Rules.nearest_anchor(Vector2.ZERO, [Vector2(40.0, 0.0), Vector2(-40.0, 0.0)], 50.0) == 0, "equal-distance tie deterministically selects the first anchor")
	_expect(Rules.nearest_anchor(Vector2.ZERO, ["not-a-vector", Vector2(12.0, 0.0)], 20.0) == 1, "malformed anchor entries are ignored")

func _test_rope_geometry() -> void:
	_expect(is_equal_approx(Rules.calculate_rope_length(10.0), Rules.MIN_ROPE_LENGTH), "rope length respects its minimum")
	_expect(is_equal_approx(Rules.calculate_rope_length(999.0), Rules.MAX_ROPE_LENGTH), "rope length respects its maximum")
	var outward: Dictionary = Rules.constrain_rope(Vector2(120.0, 0.0), Vector2(30.0, 12.0), Vector2.ZERO, 80.0)
	_expect(outward["tension"], "rope reports tension outside its length")
	_expect((outward["position"] as Vector2).is_equal_approx(Vector2(80.0, 0.0)), "rope clamps the player to its maximum radius")
	_expect((outward["velocity"] as Vector2).is_equal_approx(Vector2(0.0, 12.0)), "rope removes outward radial speed but preserves tangential speed")
	var inward: Dictionary = Rules.constrain_rope(Vector2(120.0, 0.0), Vector2(-30.0, 12.0), Vector2.ZERO, 80.0)
	_expect((inward["velocity"] as Vector2).is_equal_approx(Vector2(-30.0, 12.0)), "rope preserves inward radial speed")
	var slack: Dictionary = Rules.constrain_rope(Vector2(40.0, 0.0), Vector2(4.0, 8.0), Vector2.ZERO, 80.0)
	_expect(not bool(slack["tension"]), "rope remains slack inside its length")
	_expect((slack["position"] as Vector2).is_equal_approx(Vector2(40.0, 0.0)), "slack rope does not move the player")
	var zero_offset: Dictionary = Rules.constrain_rope(Vector2.ZERO, Vector2(1.0, 2.0), Vector2.ZERO, 80.0)
	_expect((zero_offset["velocity"] as Vector2).is_equal_approx(Vector2(1.0, 2.0)), "zero-offset rope constraint is safe")

func _test_horizontal_motion() -> void:
	var accelerated: Vector2 = Rules.apply_horizontal(Vector2.ZERO, 1.0, 0.1, false)
	_expect(accelerated.x > 0.0, "right input accelerates the player")
	var capped: Vector2 = Rules.apply_horizontal(Vector2(420.0, 0.0), 1.0, 0.1, false)
	_expect(capped.x <= Rules.MAX_HORIZONTAL_SPEED, "horizontal speed is capped")
	var grounded: Vector2 = Rules.apply_horizontal(Vector2(200.0, 0.0), 0.0, 0.1, true)
	var airborne: Vector2 = Rules.apply_horizontal(Vector2(200.0, 0.0), 0.0, 0.1, false)
	_expect(grounded.x < airborne.x, "ground friction is stronger than air drag")
	_expect(Rules.apply_horizontal(Vector2(12.0, 4.0), 1.0, 0.0, false).is_equal_approx(Vector2(12.0, 4.0)), "zero delta leaves velocity unchanged")

func _test_goal_and_score() -> void:
	var goal := Rect2(Vector2(100.0, 100.0), Vector2(60.0, 60.0))
	_expect(Rules.goal_contains(Vector2(120.0, 120.0), goal), "goal contains a point inside its gate")
	_expect(not Rules.goal_contains(Vector2(200.0, 200.0), goal), "goal rejects a point outside its gate")
	_expect(Rules.calculate_score(90.0, 0) == 1900, "perfect clear receives full time bonus")
	_expect(Rules.calculate_score(90.0, 2) == 1600, "falls apply a deterministic score penalty")
	_expect(Rules.calculate_score(-5.0, 20) == 0, "score never becomes negative")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

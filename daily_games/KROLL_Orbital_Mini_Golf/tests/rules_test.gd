extends SceneTree

const Rules = preload("res://rules.gd")
var _failed: bool = false

func _initialize() -> void:
	_check(Rules.calculate_shot_velocity(Vector2(100.0, 100.0), Vector2(80.0, 100.0)).is_equal_approx(Vector2(100.0, 0.0)), "A 20px pull should produce a 100 speed shot.")
	_check(Rules.calculate_shot_velocity(Vector2(100.0, 100.0), Vector2(100.0, 100.0)) == Vector2.ZERO, "Zero drag must not launch.")
	_check(Rules.calculate_shot_velocity(Vector2(100.0, 100.0), Vector2(97.0, 100.0)) == Vector2.ZERO, "Tiny drag must not launch.")
	var capped: Vector2 = Rules.calculate_shot_velocity(Vector2.ZERO, Vector2(-1000.0, 0.0))
	_check(is_equal_approx(capped.length(), Rules.MAX_SHOT_SPEED), "Shot speed must be capped.")
	var slowed: Vector2 = Rules.apply_friction(Vector2(100.0, 0.0), 0.5)
	_check(slowed.length() < 100.0 and slowed.length() > 0.0, "Friction should reduce speed smoothly.")
	_check(Rules.apply_friction(Vector2(1.0, 0.0), 0.1) == Vector2.ZERO, "Very slow balls should stop cleanly.")
	_check(Rules.can_sink(10.0, 100.0), "A slow ball inside the cup should sink.")
	_check(not Rules.can_sink(10.0, 250.0), "A fast ball should lip past the cup.")
	_check(not Rules.can_sink(30.0, 10.0), "A ball outside the cup should not sink.")
	var reflected: Vector2 = Rules.reflect_velocity(Vector2(100.0, 0.0), Vector2.LEFT, 0.5)
	_check(reflected.is_equal_approx(Vector2(-50.0, 0.0)), "Reflection should reverse the normal component and apply restitution.")
	if _failed:
		print("KROLL Orbital Mini Golf rules tests failed.")
		quit(1)
	else:
		print("KROLL Orbital Mini Golf rules tests passed.")
		quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

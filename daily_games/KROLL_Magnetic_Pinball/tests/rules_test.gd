extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	assert(is_equal_approx(Rules.distance_to_segment(Vector2(5.0, 3.0), Vector2.ZERO, Vector2(10.0, 0.0)), 3.0))
	assert(is_equal_approx(Rules.distance_to_segment(Vector2(5.0, 0.0), Vector2.ZERO, Vector2.ZERO), 5.0))
	var reflected: Vector2 = Rules.reflect_velocity(Vector2(0.0, 10.0), Vector2.UP, 0.8)
	assert(reflected.y < 0.0, "A ball moving into a surface should reflect away")
	assert(is_equal_approx(Rules.reflect_velocity(Vector2(0.0, -10.0), Vector2.UP, 0.8).y, -10.0))
	var active_kick: Vector2 = Rules.flipper_kick(Vector2(0.0, 120.0), 1, true)
	assert(active_kick.x > 0.0 and active_kick.y <= -390.0)
	var right_kick: Vector2 = Rules.flipper_kick(Vector2.ZERO, -1, true)
	assert(right_kick.x < 0.0 and right_kick.y < 0.0)
	assert(Rules.bump_score(100, 100) == 200)
	assert(Rules.bump_score(10, -50) == 10)
	assert(not Rules.is_ball_lost(954.9, 955.0))
	assert(Rules.is_ball_lost(955.1, 955.0))
	print("KROLL Magnetic Pinball rules tests passed.")
	quit(0)

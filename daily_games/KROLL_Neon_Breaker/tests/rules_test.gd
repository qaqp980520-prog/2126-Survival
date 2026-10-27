extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run()
	if failures.is_empty():
		print("KROLL Neon Breaker rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _run() -> void:
	_expect(is_equal_approx(Rules.clamp_paddle_center(2.0, 50.0, 960.0), 50.0), "paddle clamps to left boundary")
	_expect(is_equal_approx(Rules.clamp_paddle_center(1000.0, 50.0, 960.0), 910.0), "paddle clamps to right boundary")
	_expect(is_equal_approx(Rules.clamp_paddle_center(100.0, 50.0, 80.0), 40.0), "paddle centers if field is narrower than paddle")
	var reflected := Rules.reflect_velocity(Vector2(3.0, 4.0), Vector2.UP)
	_expect(reflected.is_equal_approx(Vector2(3.0, -4.0)), "reflection reverses velocity along collision normal")
	_expect(Rules.reflect_velocity(Vector2(3.0, 4.0), Vector2.ZERO).is_equal_approx(Vector2(3.0, 4.0)), "zero normal safely preserves velocity")
	var center_bounce := Rules.paddle_bounce(0.0, 62.0, 400.0)
	_expect(absf(center_bounce.x) < 0.001 and center_bounce.y < 0.0, "center paddle hit returns ball vertically upward")
	var left_bounce := Rules.paddle_bounce(-1.0, 62.0, 400.0)
	var right_bounce := Rules.paddle_bounce(1.0, 62.0, 400.0)
	_expect(left_bounce.x < 0.0 and right_bounce.x > 0.0, "paddle edges steer ball in opposite directions")
	_expect(is_equal_approx(left_bounce.length(), 400.0), "paddle bounce preserves configured speed")
	_expect(not Rules.has_lost_ball(508.0, 500.0, 8.0), "ball exactly at loss boundary is not lost")
	_expect(Rules.has_lost_ball(509.0, 500.0, 8.0), "ball beyond loss boundary is lost")
	_expect(Rules.remaining_lives(3) == 2 and Rules.remaining_lives(0) == 0, "lives decrement without going negative")
	_expect(Rules.time_expired(0.0) and Rules.time_expired(-1.0) and not Rules.time_expired(0.1), "timer expiration boundary")
	_expect(Rules.all_bricks_cleared(0) and Rules.all_bricks_cleared(-1) and not Rules.all_bricks_cleared(1), "victory depends on no remaining bricks")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run_tests()
	if failures.is_empty():
		print("KROLL Magnetic Salvage rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _run_tests() -> void:
	_expect(Rules.clamp_to_arena(Vector2(-10, 700), Vector2(960, 600)) == Vector2(24, 576), "arena clamp respects margins")
	_expect(Rules.can_pulse(1, 0.0, "playing"), "pulse available with charge and no cooldown")
	_expect(not Rules.can_pulse(0, 0.0, "playing"), "pulse rejects empty charge")
	_expect(not Rules.can_pulse(2, 0.1, "playing"), "pulse respects cooldown")
	_expect(not Rules.can_pulse(2, 0.0, "won"), "pulse rejected after round ends")
	var pulled: Vector2 = Rules.pulled_position(Vector2(200, 100), Vector2(100, 100), 150, 40)
	_expect(pulled.is_equal_approx(Vector2(160, 100)), "magnet pulls metal by the configured distance")
	_expect(Rules.pulled_position(Vector2(300, 100), Vector2(100, 100), 150, 40) == Vector2(300, 100), "magnet ignores scrap outside range")
	_expect(Rules.is_collected(Vector2(120, 100), Vector2(100, 100), 22), "scrap within collection radius is collected")
	_expect(not Rules.is_collected(Vector2(130, 100), Vector2(100, 100), 22), "scrap outside collection radius remains loose")
	_expect(Rules.can_extract(6, Vector2(880, 300), Vector2(880, 300), 54, "playing"), "six parts at dock allow extraction")
	_expect(not Rules.can_extract(5, Vector2(880, 300), Vector2(880, 300), 54, "playing"), "extraction requires target part count")
	_expect(not Rules.can_extract(6, Vector2(500, 300), Vector2(880, 300), 54, "playing"), "extraction requires dock proximity")
	_expect(not Rules.can_extract(6, Vector2(880, 300), Vector2(880, 300), 54, "lost"), "extraction rejected after timeout")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

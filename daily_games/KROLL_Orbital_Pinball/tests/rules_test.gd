extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Dictionary = Rules.create_state(0)
	_expect(int(state.get("lives", 0)) == 3 and not bool(state.get("launched", false)), "new table starts with three balls and a ready launcher")
	_expect(Rules.launch(state), "launcher starts a new ball")
	_expect(bool(state.get("launched", false)) and Vector2(state.get("velocity", Vector2.ZERO)).y < 0.0, "launch velocity sends the ball into the table")
	var wall_state: Dictionary = Rules.create_state(0)
	wall_state["launched"] = true
	wall_state["ball"] = Vector2(28.0, 240.0)
	wall_state["velocity"] = Vector2(-120.0, 0.0)
	Rules.step(wall_state, 0.016, false, false)
	_expect(float(wall_state.get("velocity", Vector2.ZERO).x) > 0.0, "left rail collision reflects the ball into the board")
	var bumper_state: Dictionary = Rules.create_state(0)
	bumper_state["launched"] = true
	bumper_state["ball"] = Vector2(110.0, 132.0)
	bumper_state["velocity"] = Vector2(0.0, 600.0)
	Rules.step(bumper_state, 0.02, false, false)
	_expect(int(bumper_state.get("score", 0)) == 100 and int(bumper_state.get("bumper_hits", 0)) == 1, "bumper collision awards exactly one hit")
	_expect(Vector2(bumper_state.get("velocity", Vector2.ZERO)).y < 0.0, "bumper collision redirects the ball upward")
	var flipper_state: Dictionary = Rules.create_state(0)
	flipper_state["launched"] = true
	flipper_state["ball"] = Vector2(120.0, 530.0)
	flipper_state["velocity"] = Vector2.ZERO
	Rules.step(flipper_state, 0.016, true, false)
	_expect(int(flipper_state.get("score", 0)) == 10 and Vector2(flipper_state.get("velocity", Vector2.ZERO)).y < 0.0, "left flipper returns the ball and awards control points")
	var drain_state: Dictionary = Rules.create_state(0)
	drain_state["launched"] = true
	drain_state["ball"] = Vector2(200.0, 609.0)
	drain_state["velocity"] = Vector2(0.0, 100.0)
	Rules.step(drain_state, 0.016, false, false)
	_expect(int(drain_state.get("lives", 0)) == 2 and not bool(drain_state.get("launched", true)), "drain consumes exactly one ball and resets the launcher")
	var reset_state: Dictionary = Rules.reset(bumper_state)
	_expect(int(reset_state.get("score", -1)) == 0 and int(reset_state.get("lives", 0)) == 3, "reset restores score and ball count")
	var next_state: Dictionary = Rules.create_state(1)
	_expect(int(next_state.get("table_index", -1)) == 1 and next_state.get("bumpers") != state.get("bumpers"), "three authored tables have distinct bumper layouts")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("KROLL Orbital Pinball rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

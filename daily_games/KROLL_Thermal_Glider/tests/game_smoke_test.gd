extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = GameScene.instantiate() as Control
	_expect(game != null, "Thermal Glider scene instantiates")
	if game == null:
		_finish(1)
		return
	root.add_child(game)
	await process_frame
	_expect(game.has_method("get_current_state"), "game exposes a read-only flight snapshot")
	_expect(game.has_method("set_control_state") and game.has_method("step_simulation"), "game exposes deterministic input hooks for smoke validation")
	var state: Dictionary = game.call("get_current_state")
	_expect(str(state.get("status", "")) == "flying", "runtime scene starts a flight")
	_expect(game.find_child("FlightControls", true, false) != null, "runtime scene creates the touch control row")
	_expect(game.find_child("StatusLabel", true, false) != null or game.find_children("*", "Label", true, false).size() >= 2, "runtime scene creates flight HUD labels")
	var battery_before: float = float(state.get("battery", 0.0))
	var pitch_before: float = float(state.get("pitch", 0.0))
	game.call("set_control_state", 1, true, false)
	var advanced: Dictionary = game.call("step_simulation", 0.05)
	_expect(float(advanced.get("battery", 100.0)) < battery_before, "runtime boost control drains battery")
	_expect(float(advanced.get("pitch", 0.0)) > pitch_before, "runtime nose-up control changes pitch")
	game.call("set_control_state", 0, false, true)
	var braked: Dictionary = game.call("step_simulation", 0.05)
	_expect(float(braked.get("velocity", Vector2.ZERO).x) < float(advanced.get("velocity", Vector2.ZERO).x), "runtime airbrake changes the flight model")
	game.call("next_course")
	var next_state: Dictionary = game.call("get_current_state")
	_expect(int(next_state.get("course_index", -1)) == 1, "next-course action selects the second route")
	game.call("reset_course")
	var reset_state: Dictionary = game.call("get_current_state")
	_expect(int(reset_state.get("course_index", -1)) == 1 and int(reset_state.get("checkpoint", -1)) == 0, "reset restarts the selected route")

	_finish(0 if failures.is_empty() else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func _finish(exit_code: int) -> void:
	if failures.is_empty() and exit_code == 0:
		print("KROLL Thermal Glider runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

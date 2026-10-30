extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = MainScene.instantiate() as Control
	_expect(game != null, "main scene instantiates as a Control")
	if game == null:
		await _finish()
		return
	root.add_child(game)
	await process_frame
	var state: Dictionary = game.get("state")
	_expect(str(state.get("status", "")) == "active", "scene starts in an active shift")
	_expect(int(state.get("round", -1)) == 0, "scene begins before the first cycle")
	var life_minus: Button = game.find_child("CrewLifeMinus", true, false) as Button
	var power_plus: Button = game.find_child("CrewPowerPlus", true, false) as Button
	var run_button: Button = game.find_child("RunCycleButton", true, false) as Button
	var restart_button: Button = game.find_child("RestartButton", true, false) as Button
	var next_button: Button = game.find_child("NextScenarioButton", true, false) as Button
	_expect(life_minus != null and power_plus != null and run_button != null, "crew and cycle controls exist")
	_expect(restart_button != null and next_button != null, "restart and scenario controls exist")
	if life_minus != null and power_plus != null and run_button != null:
		life_minus.pressed.emit()
		power_plus.pressed.emit()
		state = game.get("state")
		_expect(state["crew"] == [2, 1, 2], "real button signals reassign crew between stations")
		run_button.pressed.emit()
		state = game.get("state")
		_expect(int(state.get("round", -1)) == 1, "run-cycle button advances the actual game state")
	if restart_button != null:
		restart_button.pressed.emit()
		state = game.get("state")
		_expect(int(state.get("round", -1)) == 0, "restart button resets the current scenario")
	if next_button != null:
		next_button.pressed.emit()
		_expect(int(game.get("scenario_index")) == 1, "next-scenario button selects the next authored scenario")
	await _finish(game)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish(game: Node = null) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Station Shift runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

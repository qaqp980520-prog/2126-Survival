extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	_expect(game != null, "Inertial Docking scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	var title_found: bool = false
	for label_value in game.find_children("*", "Label", true, false):
		if str((label_value as Label).text) == "KROLL // INERTIAL DOCKING":
			title_found = true
	_expect(title_found, "game UI identifies the project as Inertial Docking")
	_expect(game.has_method("get_current_state"), "game exposes its flight state")
	_expect(game.has_method("set_control") and game.has_method("step_simulation"), "game exposes deterministic input and simulation hooks")
	_expect(game.get_control_button_count() == 5, "game creates five hold-to-control thruster buttons")
	_expect(str(game.call("get_current_scenario").get("id", "")) == "cargo_bay", "game starts at Cargo Bay")
	var before: Dictionary = game.call("get_current_state")
	_expect(bool(game.call("set_control", "thrust", true)), "public thrust control accepts a valid action")
	_expect(bool(game.call("step_simulation", 0.05)), "game simulation advances one bounded frame")
	var after: Dictionary = game.call("get_current_state")
	_expect((after["velocity"] as Vector2).length() > (before["velocity"] as Vector2).length(), "root scene applies thrust to the craft")
	_expect(bool(game.call("set_control", "thrust", false)), "public thrust control can be released")
	_expect(not bool(game.call("set_control", "warp", true)), "unknown control names are rejected")
	game.call("reset_scenario")
	_expect(float(game.call("get_current_state").get("elapsed", -1.0)) == 0.0, "reset action restores the starting flight state")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Inertial Docking runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

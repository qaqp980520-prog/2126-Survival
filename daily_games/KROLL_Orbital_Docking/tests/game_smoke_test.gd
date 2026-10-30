extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []
var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = MainScene.instantiate() as Node2D
	_expect(game != null, "main scene instantiates")
	if game == null:
		_finish(1)
		return
	root.add_child(game)
	await process_frame
	_expect(game.get("hud") != null and game.get("status_label") != null, "flight HUD is created")
	var buttons: Dictionary = game.get("touch_buttons")
	_expect(buttons.has("left") and buttons.has("right") and buttons.has("thrust") and buttons.has("reverse"), "touch controls expose all four flight inputs")
	var before_fuel: float = float(game.get("state").get("fuel", 0.0))
	(buttons["thrust"] as Button).emit_signal("button_down")
	game.call("_advance_simulation", 0.1)
	(buttons["thrust"] as Button).emit_signal("button_up")
	var after_state: Dictionary = game.get("state")
	_expect(float(after_state.get("fuel", before_fuel)) < before_fuel, "touch thrust consumes fuel")
	_expect((after_state.get("velocity", Vector2.ZERO) as Vector2).length() > 0.0, "touch thrust changes inertial velocity")
	var scenario: Dictionary = game.get("scenario")
	var dock_state: Dictionary = game.get("state").duplicate(true)
	dock_state["position"] = scenario["target_position"] + Vector2(10.0, 0.0)
	dock_state["velocity"] = Vector2.ZERO
	dock_state["angle"] = float(scenario["target_angle"])
	game.set("state", dock_state)
	game.call("_advance_simulation", 0.016)
	_expect(str(game.get("state").get("status", "")) == "docked", "runtime simulation completes a valid docking approach")
	game.call("_restart")
	_expect(str(game.get("state").get("status", "")) == "active", "restart resets the current approach")
	game.call("_next_scenario")
	_expect(int(game.get("scenario_index")) == 1, "next button advances to the next approach")
	_finish(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish(exit_code: int) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("KROLL Orbital Docking runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

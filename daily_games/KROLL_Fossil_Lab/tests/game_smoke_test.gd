extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []
var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = MainScene.instantiate() as Node2D
	_expect(game != null, "Fossil Lab scene instantiates")
	if game == null:
		_finish(1)
		return
	root.add_child(game)
	await process_frame
	var buttons: Dictionary = game.get("buttons")
	_expect(buttons.has("piece_0") and buttons.has("rotate_right") and buttons.has("place") and buttons.has("undo") and buttons.has("next") and buttons.has("reset"), "touch and mouse controls are created")
	buttons["piece_0"].emit_signal("pressed")
	buttons["place"].emit_signal("pressed")
	var state: Dictionary = game.get("state")
	_expect(state["placements"].has(0), "PLACE button commits the selected fragment")
	buttons["undo"].emit_signal("pressed")
	state = game.get("state")
	_expect(not state["placements"].has(0), "UNDO button returns the fragment to the tray")
	buttons["rotate_right"].emit_signal("pressed")
	state = game.get("state")
	_expect(int(state["rotations"][0]) == 1, "ROT+ button rotates the selected fragment")
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_D
	game.call("_unhandled_input", key_event)
	state = game.get("state")
	_expect(state["cursor"] == Vector2i(1, 0), "keyboard D moves the board cursor")
	buttons["next"].emit_signal("pressed")
	_expect(int(game.get("scenario_index")) == 1, "NEXT cycles to the next blueprint")
	buttons["reset"].emit_signal("pressed")
	_expect(int(game.get("scenario_index")) == 1 and (game.get("state") as Dictionary)["placements"].is_empty(), "RESET restarts the current blueprint")
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
		print("KROLL Fossil Lab runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

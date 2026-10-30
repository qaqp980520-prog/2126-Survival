extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = MainScene.instantiate() as Node2D
	root.add_child(game)
	await process_frame

	_expect(game != null and game.has_method("get_debug_state"), "main scene instantiates the playable game")
	var state: Dictionary = game.call("get_debug_state")
	_expect(Vector2i(state.get("player", Vector2i(-1, -1))) == Vector2i(0, 3), "first layout starts at its authored player position")
	_expect(Vector2i(state.get("crate", Vector2i(-1, -1))) == Vector2i(2, 3), "first layout starts with the crate in the corridor")

	var pulse_button: Button = game.get_node_or_null("HUD/ControlPanel/Layout/Pulse") as Button
	var mode_button: Button = game.get_node_or_null("HUD/ControlPanel/Layout/ToggleMode") as Button
	var restart_button: Button = game.get_node_or_null("HUD/ControlPanel/Layout/Restart") as Button
	var next_button: Button = game.get_node_or_null("HUD/ControlPanel/Layout/NextLevel") as Button
	var move_up_button: Button = game.get_node_or_null("HUD/ControlPanel/Layout/MoveUp") as Button
	_expect(pulse_button != null and mode_button != null and restart_button != null and next_button != null and move_up_button != null, "all core touch controls are created with stable names")
	if pulse_button != null:
		pulse_button.emit_signal("pressed")
	state = game.call("get_debug_state")
	_expect(Vector2i(state.get("crate", Vector2i(-1, -1))) == Vector2i(3, 3), "pulse button actually moves the crate")
	if mode_button != null:
		mode_button.emit_signal("pressed")
	state = game.call("get_debug_state")
	_expect(str(state.get("mode", "")) == "pull", "mode button actually switches the magnet mode")
	if restart_button != null:
		restart_button.emit_signal("pressed")
	state = game.call("get_debug_state")
	_expect(str(state.get("mode", "")) == "push" and Vector2i(state.get("crate", Vector2i(-1, -1))) == Vector2i(2, 3), "restart restores the current layout and mode")
	if move_up_button != null:
		move_up_button.emit_signal("pressed")
	state = game.call("get_debug_state")
	_expect(Vector2i(state.get("player", Vector2i(-1, -1))) == Vector2i(0, 2), "movement button changes the player position")
	if next_button != null:
		next_button.emit_signal("pressed")
	state = game.call("get_debug_state")
	_expect(int(state.get("level_index", -1)) == 1, "next button advances to the next layout")
	if restart_button != null:
		restart_button.emit_signal("pressed")
	state = game.call("get_debug_state")
	_expect(Vector2i(state.get("player", Vector2i(-1, -1))) == Vector2i(1, 5), "restart uses the selected layout's authored start")

	var status_label: Label = game.get_node_or_null("HUD/ControlPanel/Layout/StatusLabel") as Label
	_expect(status_label != null and status_label.text.contains("CORNER TRANSFER"), "status panel displays the selected layout")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Magnetic Maze runtime smoke test passed.")
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

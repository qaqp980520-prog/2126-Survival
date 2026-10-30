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
	_expect(int(state.get("level_index", -1)) == 0, "first layout loads on startup")
	var drone_b: Button = game.get_node_or_null("HUD/ControlPanel/Layout/DroneSelection/DroneB") as Button
	var command_right: Button = game.get_node_or_null("HUD/ControlPanel/Layout/CommandPad/CommandRight") as Button
	var step_button: Button = game.get_node_or_null("HUD/ControlPanel/Layout/StepAll") as Button
	var restart_button: Button = game.get_node_or_null("HUD/ControlPanel/Layout/Restart") as Button
	var next_button: Button = game.get_node_or_null("HUD/ControlPanel/Layout/NextLevel") as Button
	_expect(drone_b != null and command_right != null and step_button != null and restart_button != null and next_button != null, "all selection and command controls are created with stable names")
	if drone_b != null:
		drone_b.emit_signal("pressed")
	_expect(int(game.call("get_selected_drone")) == 1, "touch selection switches to drone B")
	if command_right != null:
		command_right.emit_signal("pressed")
	if step_button != null:
		step_button.emit_signal("pressed")
	state = game.call("get_debug_state")
	var drones: Array = state.get("drones", [])
	_expect(Vector2i(drones[1].get("position")) == Vector2i(1, 2), "command button and simultaneous step move the selected drone")
	_expect(Vector2i(drones[0].get("position")) == Vector2i(0, 0), "uncommanded drones hold their positions")
	_expect(int(state.get("ticks", 0)) == 1, "step button advances one simulation tick")
	if restart_button != null:
		restart_button.emit_signal("pressed")
	state = game.call("get_debug_state")
	_expect(int(state.get("ticks", -1)) == 0 and Vector2i(state.get("drones", [])[1].get("position")) == Vector2i(0, 2), "restart restores the authored starting state")
	if next_button != null:
		next_button.emit_signal("pressed")
	state = game.call("get_debug_state")
	_expect(int(state.get("level_index", -1)) == 1, "next button advances to the next layout")
	var status_label: Label = game.get_node_or_null("HUD/ControlPanel/Layout/StatusLabel") as Label
	_expect(status_label != null and status_label.text.contains("CARGO DETOURS"), "status panel displays the selected layout")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Drone Relay runtime smoke test passed.")
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

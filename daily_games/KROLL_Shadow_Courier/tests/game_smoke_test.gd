extends SceneTree

const MainScene = preload("res://main.tscn")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = MainScene.instantiate() as Control
	_expect(game != null, "Shadow Courier main scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	_expect(game.find_child("Button_up", true, false) != null, "touch UI exposes an up control")
	_expect(game.find_child("Button_wait", true, false) != null, "touch UI exposes a wait control")
	_expect(game.find_child("Button_decoy", true, false) != null, "touch UI exposes a decoy control")
	_expect(game.find_child("Button_reset", true, false) != null, "touch UI exposes a reset control")
	_expect(game.find_child("Button_next", true, false) != null, "touch UI exposes a next-mission control")

	var state: Dictionary = game.get("state")
	var before: Vector2i = state.get("player_pos", Vector2i.ZERO)
	(game.find_child("Button_down", true, false) as Button).pressed.emit()
	state = game.get("state")
	_expect(state.get("player_pos") == before + Vector2i.DOWN, "touch direction button moves the player")
	(game.find_child("Button_wait", true, false) as Button).pressed.emit()
	var current_state: Dictionary = game.get("state")
	_expect(int(current_state.get("turn", 0)) >= 2, "touch wait button advances the patrol turn")
	(game.find_child("Button_decoy", true, false) as Button).pressed.emit()
	current_state = game.get("state")
	_expect(int(current_state.get("decoys", 2)) <= 2, "touch decoy button safely invokes the decoy action")
	(game.find_child("Button_reset", true, false) as Button).pressed.emit()
	current_state = game.get("state")
	_expect(int(current_state.get("turn", -1)) == 0, "touch reset button restarts the mission")
	(game.find_child("Button_next", true, false) as Button).pressed.emit()
	current_state = game.get("state")
	_expect(int(current_state.get("level_index", -1)) == 1, "touch next button advances the mission")

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_D
	game.call("_unhandled_input", key_event)
	current_state = game.get("state")
	_expect(current_state.get("player_pos") == Vector2i(1, 7), "keyboard event moves the player one tile")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Shadow Courier runtime smoke test passed.")
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

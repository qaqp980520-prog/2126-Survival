extends SceneTree

const GameScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.get_game_state() == "running")
	assert(game.debug_action(0, "vent"))
	var outputs: Array = game.get("outputs")
	var heats: Array = game.get("heats")
	assert(is_equal_approx(float(outputs[0]), 40.0))
	assert(is_equal_approx(float(heats[0]), 17.0))
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = true
	pointer.position = Vector2(650.0, 420.0)
	game.call("_input", pointer)
	outputs = game.get("outputs")
	heats = game.get("heats")
	assert(is_equal_approx(float(outputs[2]), 58.0))
	assert(is_equal_approx(float(heats[2]), 50.0))
	game.set("outputs", [50.0, 50.0, 50.0])
	game.set("heats", [95.0, 30.0, 30.0])
	assert(game.debug_action(0, "boost"))
	assert(game.get_game_state() == "meltdown")
	game.restart_game()
	game.set("outputs", [50.0, 50.0, 50.0])
	game.set("heats", [30.0, 30.0, 30.0])
	game.set("stable_seconds", 17)
	assert(game.debug_tick([0.0, 0.0, 0.0]))
	assert(game.get_game_state() == "victory")
	game.restart_game()
	game.set("outputs", [100.0, 25.0, 25.0])
	game.set("heats", [98.0, 20.0, 20.0])
	game.set("stable_seconds", 17)
	assert(game.debug_tick([0.0, 0.0, 0.0]))
	assert(game.get_game_state() == "meltdown")
	game.restart_game()
	assert(game.get_game_state() == "running")
	assert(is_equal_approx(float(game.get("time_left")), 60.0))
	game.queue_free()
	await process_frame
	print("KROLL Reactor Balance runtime smoke test passed.")
	quit(0)

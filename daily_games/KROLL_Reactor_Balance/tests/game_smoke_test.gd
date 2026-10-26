extends SceneTree

const GameScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = GameScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	assert(game.get_game_state() == "running")
	assert(game.debug_action(0, "vent"))
	var outputs: Array = game.get("outputs")
	var heats: Array = game.get("heats")
	assert(is_equal_approx(float(outputs[0]), 40.0))
	assert(is_equal_approx(float(heats[0]), 17.0))
	game.set("outputs", [50.0, 50.0, 50.0])
	game.set("heats", [30.0, 30.0, 30.0])
	game.set("stable_seconds", 17)
	assert(game.debug_tick([0.0, 0.0, 0.0]))
	assert(game.get_game_state() == "victory")
	game.restart_game()
	assert(game.get_game_state() == "running")
	assert(is_equal_approx(float(game.get("time_left")), 60.0))
	game.queue_free()
	await process_frame
	print("KROLL Reactor Balance runtime smoke test passed.")
	quit(0)

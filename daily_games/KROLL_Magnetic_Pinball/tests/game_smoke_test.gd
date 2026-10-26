extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	assert(packed != null, "Main scene must load")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.lives == 3)
	assert(game.score == 0)
	assert(not game.ball_in_play)
	var initial_position: Vector2 = game.ball_position
	game.start_ball()
	assert(game.ball_in_play)
	assert(game.ball_velocity.y < 0.0)
	game.step_simulation(0.016)
	assert(game.ball_position != initial_position, "Launched ball should advance")
	game.reset_game()
	assert(game.lives == 3 and game.score == 0 and not game.ball_in_play)
	game.queue_free()
	print("KROLL Magnetic Pinball game smoke test passed.")
	quit(0)

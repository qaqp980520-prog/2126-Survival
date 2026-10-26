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
	game.ball_position = Vector2(230.0, 250.0)
	game.ball_velocity = Vector2(0.0, 100.0)
	game.step_simulation(0.016)
	assert(game.score == 100, "Contact with a bumper should score exactly once")
	game.ball_position = Vector2(400.0, 960.0)
	game.ball_velocity = Vector2.ZERO
	game.ball_in_play = true
	game.step_simulation(0.016)
	assert(game.lives == 2 and not game.ball_in_play, "A drained ball should consume one life")
	game.reset_game()
	assert(game.lives == 3 and game.score == 0 and not game.ball_in_play)
	var launch_touch := InputEventScreenTouch.new()
	launch_touch.index = 0
	launch_touch.position = Vector2(700.0, 700.0)
	launch_touch.pressed = true
	game._input(launch_touch)
	assert(game.ball_in_play, "Touching the shooter lane should launch the ball")
	game.reset_game()
	var flipper_touch := InputEventScreenTouch.new()
	flipper_touch.index = 1
	flipper_touch.position = Vector2(200.0, 900.0)
	flipper_touch.pressed = true
	game._input(flipper_touch)
	game._physics_process(0.016)
	assert(game.left_flipper_active, "Holding the left touch pad should activate the left flipper")
	flipper_touch.pressed = false
	game._input(flipper_touch)
	game._physics_process(0.016)
	assert(not game.left_flipper_active, "Releasing the touch pad should release the flipper")
	var right_touch := InputEventScreenTouch.new()
	right_touch.index = 2
	right_touch.position = Vector2(600.0, 900.0)
	right_touch.pressed = true
	game._input(right_touch)
	game._physics_process(0.016)
	assert(game.right_flipper_active, "Holding the right touch pad should activate the right flipper")
	var second_left_touch := InputEventScreenTouch.new()
	second_left_touch.index = 3
	second_left_touch.position = Vector2(200.0, 900.0)
	second_left_touch.pressed = true
	game._input(second_left_touch)
	game._physics_process(0.016)
	assert(game.left_flipper_active and game.right_flipper_active, "Two fingers should operate both flippers simultaneously")
	right_touch.pressed = false
	game._input(right_touch)
	game._physics_process(0.016)
	assert(game.left_flipper_active and not game.right_flipper_active, "Releasing one finger should preserve the other flipper")
	second_left_touch.pressed = false
	game._input(second_left_touch)
	game._physics_process(0.016)
	assert(not game.left_flipper_active and not game.right_flipper_active)
	game.queue_free()
	await process_frame
	print("KROLL Magnetic Pinball game smoke test passed.")
	quit(0)

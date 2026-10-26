extends SceneTree

const GameScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var game: Control = GameScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	assert(game.state == "showing")
	var known_sequence: Array[int] = [0, 1, 2]
	game.sequence = known_sequence
	game.round_number = 1
	game.lives = 3
	game.score = 0
	game.debug_force_input_phase()
	assert(game.submit_cell(0))
	assert(game.submit_cell(1))
	assert(game.submit_cell(2))
	assert(game.round_number == 2)
	assert(game.state == "showing")
	assert(game.sequence.size() == 4)

	game.sequence = [1, 2, 3]
	game.lives = 1
	game.debug_force_input_phase()
	assert(not game.submit_cell(0), "A wrong tile must be rejected")
	assert(game.state == "failed", "The last failed attempt must end the run")
	game.start_game()
	assert(game.state == "showing")
	assert(game.round_number == 1 and game.lives == 3 and game.score == 0)
	print("KROLL Cipher Recall runtime smoke test passed.")
	game.queue_free()
	await process_frame
	quit(0)

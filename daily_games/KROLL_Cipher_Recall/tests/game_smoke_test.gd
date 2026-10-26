extends SceneTree

const GameScene = preload("res://main.tscn")
var _failed: bool = false
var _finished: bool = false

func _initialize() -> void:
	call_deferred("_run_tests")
	call_deferred("_watchdog")

func _watchdog() -> void:
	await create_timer(20.0).timeout
	if not _finished:
		push_error("KROLL Cipher Recall runtime smoke test timed out.")
		quit(1)

func _run_tests() -> void:
	var game: Variant = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_check(game.state == "showing", "Game should start by showing a sequence")
	var known_sequence: Array[int] = [0, 1, 2]
	game.set("sequence", known_sequence)
	game.set("round_number", 1)
	game.set("lives", 3)
	game.set("score", 0)
	game.debug_force_input_phase()
	_check(bool(game.submit_cell(0)), "First correct tile should be accepted")
	_check(bool(game.submit_cell(1)), "Second correct tile should be accepted")
	_check(bool(game.submit_cell(2)), "Third correct tile should be accepted")
	_check(int(game.round_number) == 2, "Completing a sequence should advance the round")
	_check(str(game.state) == "showing", "Next round should display its sequence")
	_check(game.sequence.size() == 4, "Second round sequence should contain four cells")

	var wrong_sequence: Array[int] = [1, 2, 3]
	game.set("sequence", wrong_sequence)
	game.set("lives", 1)
	game.debug_force_input_phase()
	_check(not bool(game.submit_cell(0)), "A wrong tile must be rejected")
	_check(str(game.state) == "failed", "The last failed attempt must end the run")
	game.start_game()
	_check(str(game.state) == "showing", "Restart should begin a new sequence")
	_check(int(game.round_number) == 1 and int(game.lives) == 3 and int(game.score) == 0, "Restart must reset round, lives and score")
	game.queue_free()
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

func _finish() -> void:
	_finished = true
	if _failed:
		print("KROLL Cipher Recall runtime smoke test failed.")
		quit(1)
	else:
		print("KROLL Cipher Recall runtime smoke test passed.")
		quit(0)

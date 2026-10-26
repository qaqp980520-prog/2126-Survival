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
		push_error("KROLL Cargo Tugs runtime smoke test timed out.")
		quit(1)

func _run_tests() -> void:
	var game: Variant = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_check(int(game.level_index) == 0, "Game should start on shift one.")
	_check(game.crates.size() == 1, "Shift one should have one crate.")
	_check(not bool(game.attempt_move(Vector2i(-1, 0))), "The player must not walk through a wall.")
	_check(bool(game.attempt_move(Vector2i(1, 0))), "The player should push the first crate.")
	_check(game.crates[0] == Vector2i(3, 2), "The crate should move one cell to the right.")
	_check(bool(game.undo_move()), "Undo should restore the last move.")
	_check(game.crates[0] == Vector2i(2, 2), "Undo should restore the crate position.")
	_check(game.player_pos == Vector2i(1, 2), "Undo should restore the player position.")

	_check(bool(game.attempt_move(Vector2i(1, 0))), "First push toward the docking pad should work.")
	_check(bool(game.attempt_move(Vector2i(1, 0))), "Second push toward the docking pad should work.")
	_check(bool(game.attempt_move(Vector2i(1, 0))), "Third push should dock the crate.")
	_check(str(game.state) == "won", "Docking every crate should win the shift.")
	_check(bool(game.load_level(1)) if game.has_method("debug_load_level") else true, "Level transition hook is optional.")
	game.load_level(1)
	_check(game.crates.size() == 2, "Shift two should have two crates.")
	game.load_level(2)
	_check(game.crates.size() == 3, "Shift three should have three crates.")
	game.load_level(0)
	game.queue_free()
	await process_frame
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

func _finish() -> void:
	_finished = true
	if _failed:
		print("KROLL Cargo Tugs runtime smoke test failed.")
		quit(1)
	else:
		print("KROLL Cargo Tugs runtime smoke test passed.")
		quit(0)

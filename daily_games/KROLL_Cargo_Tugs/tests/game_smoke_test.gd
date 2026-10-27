extends SceneTree

const GameScene = preload("res://main.tscn")
var _failed: bool = false
var _finished: bool = false
var _watchdog_timer: Timer

func _initialize() -> void:
	_watchdog_timer = Timer.new()
	_watchdog_timer.one_shot = true
	_watchdog_timer.wait_time = 20.0
	root.add_child(_watchdog_timer)
	_watchdog_timer.timeout.connect(_on_watchdog_timeout)
	call_deferred("_start_watchdog")
	call_deferred("_run_tests")

func _start_watchdog() -> void:
	if not _finished and is_instance_valid(_watchdog_timer) and _watchdog_timer.is_inside_tree():
		_watchdog_timer.start()

func _on_watchdog_timeout() -> void:
	if _finished:
		return
	_finished = true
	push_error("KROLL Cargo Tugs runtime smoke test timed out.")
	if is_instance_valid(_watchdog_timer):
		_watchdog_timer.stop()
		_watchdog_timer.free()
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
	if is_instance_valid(_watchdog_timer):
		_watchdog_timer.stop()
		_watchdog_timer.free()
	if _failed:
		print("KROLL Cargo Tugs runtime smoke test failed.")
		quit(1)
	else:
		print("KROLL Cargo Tugs runtime smoke test passed.")
		quit(0)

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
		push_error("KROLL Vector Rally runtime smoke test timed out.")
		quit(1)

func _run_tests() -> void:
	var game: Variant = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game()
	_check(int(game.lap_count) == 0 and int(game.next_checkpoint) == 1, "Race should start at lap zero with gate 1 next.")
	_check(not bool(game.finished) and not bool(game.time_up), "Race should start active.")
	_check(not bool(game.debug_enter_checkpoint(0)), "Start gate must not be accepted out of order.")
	for gate in [1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0]:
		_check(bool(game.debug_enter_checkpoint(gate)), "Expected checkpoint should be accepted.")
	_check(int(game.lap_count) == 3 and bool(game.finished), "Three laps should finish the race.")
	_check(not bool(game.time_up), "Winning before the time limit must not time out.")
	game.start_game()
	game.debug_set_car_state(Vector2(400.0, 350.0), Vector2(120.0, 0.0), 0.0)
	game.debug_step(0.1, 0.0, false, false)
	_check(bool(game.off_track), "The center island is off track.")
	_check(game.car_velocity.length() < 120.0, "Off-track driving should reduce speed.")
	game.start_game()
	game.debug_set_car_state(Vector2(550.0, 468.0), Vector2(60.0, 0.0), 0.0)
	game.debug_step(0.016, 0.0, false, false)
	_check(int(game.boost_count) == 1, "Crossing an available boost pad above minimum speed should trigger boost.")
	_check(float(game.boost_cooldown) > 0.0, "Boost should start a cooldown.")
	game.start_game()
	game.debug_step(90.1, 0.0, false, false)
	_check(bool(game.time_up) and not bool(game.finished), "The time limit should end an unfinished race.")
	game.start_game()
	_check(float(game.elapsed_seconds) == 0.0 and int(game.boost_count) == 0, "Restart should reset timer and boost stats.")
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
		print("KROLL Vector Rally runtime smoke test failed.")
		quit(1)
	else:
		print("KROLL Vector Rally runtime smoke test passed.")
		quit(0)

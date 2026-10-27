extends SceneTree

const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")

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
	push_error("KROLL Vertical Relay runtime smoke test timed out.")
	if is_instance_valid(_watchdog_timer):
		_watchdog_timer.queue_free()
	quit(1)

func _run_tests() -> void:
	var game: Variant = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_check(game.player != null, "Scene should construct a player.")
	_check(game.camera != null, "Scene should construct a follow camera.")
	_check(game.platforms.size() >= 10, "Level should contain enough climb platforms.")
	_check(game.pickups.size() == Rules.REQUIRED_DATA, "Level should contain all five data pickups.")
	_check(game.hazards.size() == 2, "Level should construct two moving hazards.")
	_check(str(game.state.get("status", "")) == "playing", "Game should start in the playing state.")

	game.state = Rules.fail(game.state, "test")
	var restart := InputEventKey.new()
	restart.keycode = KEY_R
	restart.pressed = true
	game.call("_unhandled_input", restart)
	_check(str(game.state.get("status", "")) == "playing", "R should restart a terminal game.")
	_check(game.player.position.is_equal_approx(Vector2(480.0, 1680.0)), "Restart should restore the player start position.")
	_check(float(game.state.get("remaining_time", 0.0)) == Rules.TIME_LIMIT, "Restart should reset the timer.")
	_check(bool(game.pickups["relay_data_01"].visible), "Restart should restore collected pickup visibility.")

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
		_watchdog_timer.queue_free()
	if _failed:
		print("KROLL Vertical Relay runtime smoke test failed.")
		quit(1)
	else:
		print("KROLL Vertical Relay runtime smoke test passed.")
		quit(0)

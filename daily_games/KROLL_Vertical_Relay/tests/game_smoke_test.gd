extends SceneTree

const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")

var _failed: bool = false
var _finished: bool = false

func _initialize() -> void:
	call_deferred("_run_tests")
	call_deferred("_watchdog")

func _watchdog() -> void:
	await create_timer(20.0).timeout
	if not _finished:
		push_error("KROLL Vertical Relay runtime smoke test timed out.")
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
	if _failed:
		print("KROLL Vertical Relay runtime smoke test failed.")
		quit(1)
	else:
		print("KROLL Vertical Relay runtime smoke test passed.")
		quit(0)

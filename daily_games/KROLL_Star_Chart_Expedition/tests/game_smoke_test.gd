extends SceneTree

const MainScript = preload("res://main.gd")
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var game: Node2D = MainScript.new()
	root.add_child(game)
	await process_frame
	_check(game.state["status"] == "playing", "Game should start in playing state.")
	_check(int(game.state["fuel"]) == 34, "Game should start with 34 fuel.")
	game._unhandled_input(_key_event(KEY_W))
	_check(int(game.state["fuel"]) == 33, "A valid key press should move and spend one fuel.")
	game._reset_game()
	_check(int(game.state["fuel"]) == 34 and game.state["position"] == Vector2i(0, 3), "Restart should restore the launch state.")
	game.queue_free()
	await process_frame
	if _failed:
		print("Star Chart Expedition runtime smoke test failed.")
		quit(1)
	else:
		print("Star Chart Expedition runtime smoke test passed.")
		quit(0)

func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

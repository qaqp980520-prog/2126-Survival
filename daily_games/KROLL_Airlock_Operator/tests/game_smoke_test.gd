extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = GameScene.instantiate()
	_expect(game is Control, "main scene instantiates as Control")
	root.add_child(game)
	await process_frame
	_expect(game.action_buttons.size() == 9, "scene builds all nine action buttons")
	game.action_buttons["open_outer"].emit_signal("pressed")
	game.action_buttons["load_pod"].emit_signal("pressed")
	game.action_buttons["close_outer"].emit_signal("pressed")
	game.action_buttons["pressurize"].emit_signal("pressed")
	game.action_buttons["pressurize"].emit_signal("pressed")
	game.action_buttons["open_inner"].emit_signal("pressed")
	game.action_buttons["unload_pod"].emit_signal("pressed")
	_expect(int(game.state.get("pods_delivered",0)) == 1, "button sequence delivers one cargo pod")
	_expect(int(game.state.get("oxygen",0)) == 50, "UI sequence updates oxygen with cargo transfer")
	game.restart_button.emit_signal("pressed")
	_expect(int(game.state.get("actions",-1)) == 0 and int(game.state.get("pods_exterior",0)) == 3, "restart restores the initial shift")
	var key := InputEventKey.new()
	key.keycode = KEY_Q
	key.pressed = true
	game._unhandled_key_input(key)
	_expect(int(game.state.get("airlock_pressure",-1)) == 50, "keyboard shortcut operates the pressure valve")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Airlock Operator runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)

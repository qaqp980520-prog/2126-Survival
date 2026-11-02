extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // SWARM DISPATCHER", "game displays its title")
	_expect(game.call("get_level_count") == 3, "game provides three missions")
	_expect(game.call("get_drone_button_count") == 3, "game builds three drone selectors")
	_expect(game.call("get_action_button_count") == 5, "game builds four directions and wait")
	_expect(game.call("get_control_button_count") == 6, "game builds six execution controls")
	_expect(bool(game.call("select_drone", 1)), "second drone can be selected")
	_expect(bool(game.call("append_action", "wait")), "selected drone accepts a wait command")
	_expect(bool(game.call("undo_action")), "unexecuted command can be undone")
	_expect(not bool(game.call("undo_action")), "empty route cannot be undone")
	_expect(bool(game.call("append_action", "right")), "selected drone accepts a movement command")
	_expect(bool(game.call("clear_program")), "unexecuted route can be cleared")
	var state: Dictionary = game.call("get_current_state")
	_expect((state["programs"][1] as Array).is_empty(), "clear removes only the selected drone's unexecuted route")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Swarm Dispatcher runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // MESS HALL RUSH", "game exposes its title")
	_expect(game.call("get_shift_count") == 3, "game exposes three shifts")
	_expect(game.call("get_order_button_count") == 4, "game builds four order tickets")
	_expect(game.call("get_action_button_count") == 11, "game builds eleven workstation buttons")
	_expect(game.call("get_control_button_count") == 2, "game builds next-shift and restart controls")
	var state: Dictionary = game.call("get_current_state")
	_expect(str(state.get("status", "")) == "playing", "game starts with an active shift")
	var selected_id: String = str(game.call("get_selected_order_id"))
	var action_result: Dictionary = game.call("perform_action", selected_id, "chop")
	_expect(bool(action_result.get("ok", false)), "runtime accepts a workstation action")
	if bool(action_result.get("ok", false)):
		var updated: Dictionary = game.call("get_current_state")
		var order: Dictionary = updated.get("orders", [])[0]
		_expect(int(order.get("progress", 0)) == 1, "runtime refresh follows the accepted order state")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Mess Hall Rush runtime smoke test passed.")
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

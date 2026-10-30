extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.get("state") is Dictionary, "runner scene creates its state")
	var buttons: Dictionary = game.get("touch_buttons")
	for key in ["left", "right", "jump", "slide", "reset", "next"]:
		_expect(buttons.has(key), "touch/action button exists: " + key)
	var state: Dictionary = game.get("state")
	_expect(int(state.get("lane", -1)) == 1, "scene begins in center lane")
	(buttons["left"] as Button).pressed.emit()
	game.call("_process", 0.1)
	state = game.get("state")
	_expect(int(state.get("lane", -1)) == 0, "actual lane button signal changes the runner lane")
	(buttons["jump"] as Button).pressed.emit()
	game.call("_process", 0.1)
	state = game.get("state")
	_expect(float(state.get("jump_timer", 0.0)) > 0.0, "actual jump button signal activates the jump window")
	(buttons["slide"] as Button).pressed.emit()
	game.call("_process", 0.1)
	state = game.get("state")
	_expect(float(state.get("slide_timer", 0.0)) > 0.0, "actual slide button signal activates the slide window")
	(buttons["reset"] as Button).pressed.emit()
	state = game.get("state")
	_expect(is_equal_approx(float(state.get("distance", -1.0)), 0.0), "reset button restarts the route")
	(buttons["next"] as Button).pressed.emit()
	_expect(int(game.get("scenario_index")) == 1, "next button advances to the next route")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Void Runner runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

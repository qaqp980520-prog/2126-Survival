extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.get("state") is Dictionary, "imager scene creates a playable camera state")
	var buttons: Dictionary = game.get("touch_buttons")
	for key in ["left", "right", "up", "down", "zoom_out", "zoom_in", "capture", "reset", "next"]:
		_expect(buttons.has(key), "touch/action button exists: " + key)
	var initial_center: Vector2 = game.get("state").get("center")
	(buttons["right"] as Button).pressed.emit()
	var moved_center: Vector2 = game.get("state").get("center")
	_expect(moved_center.x > initial_center.x, "right button pans the camera")
	(buttons["zoom_in"] as Button).pressed.emit()
	_expect(int(game.get("state").get("zoom", 0)) == 1, "zoom button narrows the camera frame")
	var state: Dictionary = game.get("state")
	state["center"] = Vector2(320.0, 170.0)
	state["zoom"] = 1
	state["shots_left"] = 3
	state["status"] = "aiming"
	game.call("_refresh_ui")
	(buttons["capture"] as Button).pressed.emit()
	_expect(str(game.get("state").get("status", "")) == "won", "actual shutter button captures a valid target composition")
	_expect(int(game.get("state").get("shots_left", -1)) == 2, "successful capture consumes exactly one film frame")
	(buttons["next"] as Button).pressed.emit()
	_expect(int(game.get("scenario_index")) == 1, "next button advances to the next imaging assignment")
	_expect(str(game.get("state").get("status", "")) == "aiming", "next assignment resets the camera state")
	(buttons["reset"] as Button).pressed.emit()
	_expect(int(game.get("state").get("shots_left", 0)) == 3, "reset restores the three-frame film budget")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Orbital Imager runtime smoke test passed.")
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

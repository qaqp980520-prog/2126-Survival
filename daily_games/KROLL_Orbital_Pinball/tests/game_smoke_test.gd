extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.get("state") is Dictionary, "pinball scene creates a playable table state")
	var buttons: Dictionary = game.get("touch_buttons")
	for key in ["left", "launch", "right", "reset", "next"]:
		_expect(buttons.has(key), "mouse/touch control exists: " + key)
	(buttons["launch"] as Button).pressed.emit()
	_expect(bool(game.get("state").get("launched", false)), "actual launch button starts the ball")
	var previous_ball: Vector2 = game.get("state").get("ball", Vector2.ZERO)
	game.call("_process", 0.016)
	_expect(game.get("state").get("ball", Vector2.ZERO) != previous_ball, "runtime frame advances the ball simulation")
	(buttons["left"] as Button).button_down.emit()
	_expect(bool(game.get("left_flipper_active")), "left flipper button press is wired")
	(buttons["left"] as Button).button_up.emit()
	_expect(not bool(game.get("left_flipper_active")), "left flipper button release is wired")
	(buttons["reset"] as Button).pressed.emit()
	_expect(not bool(game.get("state").get("launched", true)) and int(game.get("state").get("score", -1)) == 0, "actual reset button restores the table")
	(buttons["next"] as Button).pressed.emit()
	_expect(int(game.get("state").get("table_index", -1)) == 1, "actual next-table button changes the bumper layout")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Orbital Pinball runtime smoke test passed.")
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

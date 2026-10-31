extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	var buttons: Dictionary = game.get("touch_buttons")
	for key in ["up", "left", "brake", "right", "down", "tether", "reset", "next"]:
		_expect(buttons.has(key), "touch control exists: " + key)
	var start_position: Vector2 = game.get("state").get("drone_pos", Vector2.ZERO)
	(buttons["up"] as Button).button_down.emit()
	game.call("_process", 0.05)
	(buttons["up"] as Button).button_up.emit()
	_expect(game.get("state").get("drone_pos", Vector2.ZERO) != start_position, "actual thrust button moves the drone")
	var game_state: Dictionary = game.get("state")
	var cargo: Array = game_state.get("cargo", [])
	game_state["drone_pos"] = cargo[0].get("position", Vector2.ZERO) + Vector2(-40.0, 0.0)
	game.set("state", game_state)
	(buttons["tether"] as Button).pressed.emit()
	_expect(int(game.get("state").get("tethered_index", -1)) == 0, "actual tether button attaches the nearest cargo")
	(buttons["reset"] as Button).pressed.emit()
	_expect(int(game.get("state").get("tethered_index", -1)) == -1 and int(game.get("state").get("score", -1)) == 0, "actual reset button restores the mission")
	(buttons["next"] as Button).pressed.emit()
	_expect(int(game.get("state").get("mission_index", -1)) == 1, "actual next button advances the mission")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Tether Recovery runtime smoke test passed.")
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

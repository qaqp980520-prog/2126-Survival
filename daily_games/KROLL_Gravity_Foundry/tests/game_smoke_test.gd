extends SceneTree

const MainScene = preload("res://main.tscn")
const SOLUTIONS: Array = [
	["right", "right", "right", "up", "up", "up", "up", "right", "rotate_left"],
	["right", "right", "right", "rotate_left", "right", "down", "down", "down", "left", "down", "left", "left", "left"],
	["right", "up", "right", "right", "down", "right", "rotate_left", "rotate_left"]
]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := MainScene.instantiate()
	root.add_child(game)
	await process_frame
	var state: Dictionary = game.call("get_current_state")
	_expect(str(state.get("status", "")) == "playing", "scene starts a playable gravity puzzle")
	_expect(game.get("buttons") is Dictionary and game.get("buttons").size() == 8, "scene creates eight keyboard/touch controls")

	var buttons: Dictionary = game.get("buttons")
	var right_button: Button = buttons.get("right") as Button
	_expect(right_button != null, "right movement touch button exists")
	if right_button != null:
		right_button.pressed.emit()
	_expect(game.call("get_current_state").get("player") == Vector2i(2, 5), "touch button emits a real movement action")
	game.call("restart_game")

	for level_index in range(SOLUTIONS.size()):
		if level_index > 0:
			var next_button: Button = buttons.get("next") as Button
			_expect(next_button != null and not next_button.disabled, "next-level button unlocks after winning")
			if next_button != null:
				next_button.pressed.emit()
		for action in SOLUTIONS[level_index]:
			game.call("_act", str(action))
		var solved: Dictionary = game.call("get_current_state")
		_expect(str(solved.get("status", "")) == "won", "live scene completes level %d" % (level_index + 1))
		if level_index < SOLUTIONS.size() - 1:
			_expect(int(solved.get("level_index", -1)) == level_index, "winning state keeps the completed level index")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Gravity Foundry runtime smoke test passed.")
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

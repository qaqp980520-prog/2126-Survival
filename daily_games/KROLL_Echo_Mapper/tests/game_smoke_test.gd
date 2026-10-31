extends SceneTree

const MainScene = preload("res://main.tscn")
const SOLUTIONS: Array = [
	["right", "right", "down", "down", "right", "right", "down", "down", "down", "right", "right", "up", "down", "down"],
	["right", "right", "down", "down", "down", "right", "right", "down", "right", "right", "down", "down"],
	["down", "down", "right", "right", "left", "left", "up", "up", "right", "right", "right", "right", "down", "down", "down", "down", "right", "right", "down", "down"]
]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := MainScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.has_method("get_current_state"), "scene exposes its live sonar mission state")
	_expect(game.get("buttons") is Dictionary and game.get("buttons").size() == 7, "scene creates seven keyboard/touch controls")

	var controls: Dictionary = game.get("buttons")
	var ping_button: Button = controls.get("ping") as Button
	var right_button: Button = controls.get("right") as Button
	var next_button: Button = controls.get("next") as Button
	_expect(ping_button != null and right_button != null and next_button != null, "ping, movement and mission navigation buttons exist")
	if ping_button != null:
		ping_button.pressed.emit()
	_expect(int(game.call("get_current_state").get("sonar_charges", -1)) == 5, "touch ping button emits a real sonar action")
	game.call("restart_game")
	if right_button != null:
		right_button.pressed.emit()
	_expect(game.call("get_current_state").get("player") == Vector2i(2, 1), "touch direction button emits a real movement action")
	game.call("restart_game")

	for level_index in range(SOLUTIONS.size()):
		if level_index > 0 and next_button != null:
			_expect(not next_button.disabled, "next mission unlocks after successful extraction")
			next_button.pressed.emit()
		game.call("_act", "ping")
		for action in SOLUTIONS[level_index]:
			game.call("_act", str(action))
		var solved: Dictionary = game.call("get_current_state")
		_expect(str(solved.get("status", "")) == "won", "live scene completes mission %d" % (level_index + 1))
		_expect(solved.get("player") == solved.get("exit"), "live scene reaches extraction in mission %d" % (level_index + 1))

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Echo Mapper runtime smoke test passed.")
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

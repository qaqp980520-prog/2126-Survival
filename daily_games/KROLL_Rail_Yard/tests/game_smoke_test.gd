extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = MainScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	_expect(game.get("state") is Dictionary, "scene initializes yard state")
	var buttons: Dictionary = game.get("action_buttons")
	for key in ["direct", "push", "pop", "restart", "next"]:
		_expect(buttons.has(key), "control exists: " + key)
	_expect(buttons["direct"].name == "DirectButton" and buttons["push"].name == "PushButton" and buttons["pop"].name == "PopButton", "shunting buttons have stable names")

	var plans: Array = [
		["push", "direct", "pop", "direct", "direct", "direct"],
		["push", "direct", "direct", "pop", "direct", "direct"],
		["push", "push", "direct", "pop", "direct", "pop", "direct"]
	]
	for layout_index in range(Rules.SEEDS.size()):
		var initial: Dictionary = game.get("state")
		_expect(int(initial.get("seed", -1)) == Rules.SEEDS[layout_index], "scene displays expected seed")
		for action_name in plans[layout_index]:
			buttons[str(action_name)].emit_signal("pressed")
		var state: Dictionary = game.get("state")
		_expect(str(state.get("status", "")) == "won", "scene completes layout %d through real button signals" % Rules.SEEDS[layout_index])
		_expect(state.get("output", []) == Rules.TARGET_ORDER, "scene output is sorted for layout %d" % Rules.SEEDS[layout_index])
		if layout_index < Rules.SEEDS.size() - 1:
			game.call("next_layout")

	game.call("restart_game")
	_expect(str(game.get("state").get("status", "")) == "playing" and int(game.get("state").get("moves", -1)) == 0, "restart resets current layout")
	game.call("next_layout")
	_expect(int(game.get("state").get("seed", -1)) == 2, "next layout advances deterministically")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Rail Yard runtime smoke test passed.")
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

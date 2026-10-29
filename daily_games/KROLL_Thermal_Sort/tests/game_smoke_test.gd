extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := MainScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.get("state") is Dictionary, "scene initializes a shift state")
	_expect(game.get("status_label") is Label and game.get("temperature_label") is Label, "status and temperature labels exist")
	var buttons: Dictionary = game.get("action_buttons")
	_expect(buttons.has("cold") and buttons.has("stable") and buttons.has("hot"), "three routing buttons exist")
	_expect(buttons["cold"].name == "ColdButton" and buttons["stable"].name == "StableButton" and buttons["hot"].name == "HotButton", "routing buttons have stable names")

	for temperature in game.get("state")["temperatures"]:
		game.call("_act", Rules.route(game.get("state"), Rules.expected_bin(int(temperature))))
	_expect(str(game.get("state")["status"]) == "won", "live scene completes a clean twelve-canister shift")

	game.call("restart_game")
	_expect(str(game.get("state")["status"]) == "playing" and int(game.get("state")["index"]) == 0, "restart resets the current seed")
	game.call("next_layout")
	_expect(int(game.get("state")["seed"]) == 202, "next layout advances deterministically")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Thermal Sort runtime smoke test passed.")
		quit(0)
	else:
		for failure_message in failures:
			push_error("FAIL: " + failure_message)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

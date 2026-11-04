extends SceneTree

const GameScript = preload("res://main.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = GameScript.new()
	root.add_child(game)
	await process_frame
	_expect(game.get_node_or_null("SafeMargin/Scroll/MainColumn/FlightGrid/Cell_40") != null, "81-cell flight deck exists")
	_expect(game.get_node_or_null("SafeMargin/Scroll/MainColumn/ThrustControls/ThrustRightButton") != null, "right-thrust touch button exists")
	_expect(game.get_node_or_null("SafeMargin/Scroll/MainColumn/ThrustControls/CoastButton") != null, "coast touch button exists")
	_expect(game.get_node_or_null("SafeMargin/Scroll/MainColumn/FlightControls/UndoButton") != null, "undo touch button exists")
	_expect(str(game.call("get_game_state").get("status", "")) == "active", "game starts with an active rescue mission")

	_click_action(game, "ThrustRightButton")
	_click_action(game, "ThrustRightButton")
	_click_action(game, "CoastButton")
	_click_action(game, "ThrustLeftButton")
	_click_action(game, "ThrustLeftButton")
	_expect(str(game.call("get_game_state").get("status", "")) == "completed", "touch-button flight sequence docks the first mission")
	_expect(int(game.call("get_game_state").get("campaign_score", 0)) == 100, "first mission awards exactly 100 points")

	game.get_node("SafeMargin/Scroll/MainColumn/FlightControls/RestartButton").emit_signal("pressed")
	_click_action(game, "ThrustRightButton")
	_click_action(game, "ThrustRightButton")
	_click_action(game, "CoastButton")
	_click_action(game, "ThrustLeftButton")
	_click_action(game, "ThrustLeftButton")
	_expect(int(game.call("get_game_state").get("campaign_score", 0)) == 100, "replaying a cleared mission cannot duplicate its reward")
	game.get_node("SafeMargin/Scroll/MainColumn/FlightControls/NextButton").emit_signal("pressed")
	_expect(int(game.call("get_game_state").get("level_index", -1)) == 1, "next button advances to the second rescue")

	var second_route := ["ThrustUpButton","CoastButton","ThrustRightButton","ThrustRightButton","ThrustDownButton","ThrustLeftButton","ThrustLeftButton"]
	for button_name in second_route:
		_click_action(game, button_name)
	_expect(str(game.call("get_game_state").get("status", "")) == "completed", "second mission completes through touch controls")
	game.get_node("SafeMargin/Scroll/MainColumn/FlightControls/NextButton").emit_signal("pressed")
	var third_route := ["ThrustDownButton","ThrustDownButton","ThrustUpButton","ThrustRightButton","ThrustRightButton","ThrustUpButton","ThrustLeftButton","ThrustLeftButton"]
	for button_name in third_route:
		_click_action(game, button_name)
	_expect(str(game.call("get_game_state").get("status", "")) == "completed", "third mission completes through touch controls")
	game.get_node("SafeMargin/Scroll/MainColumn/FlightControls/NextButton").emit_signal("pressed")
	_expect(str(game.call("get_game_state").get("status", "")) == "campaign_complete", "campaign completion is visible in the game state")
	_expect(int(game.call("get_game_state").get("campaign_score", 0)) == 300, "three missions award at most 300 points")

	game.get_node("SafeMargin/Scroll/MainColumn/FlightControls/CampaignButton").emit_signal("pressed")
	var fresh: Dictionary = game.call("get_game_state")
	_expect(int(fresh.get("campaign_score", -1)) == 0, "new campaign clears the score ledger")
	var keyboard_event := InputEventKey.new()
	keyboard_event.pressed = true
	keyboard_event.keycode = KEY_RIGHT
	game.call("_unhandled_input", keyboard_event)
	_expect(game.get_game_state().get("position") == Vector2i(2, 4), "keyboard arrow applies a thrust command")
	keyboard_event.keycode = KEY_U
	game.call("_unhandled_input", keyboard_event)
	_expect(game.get_game_state().get("position") == Vector2i(1, 4), "keyboard undo restores the previous state")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Drift Rescue runtime smoke test passed.")
		quit(0)
	else:
		push_error("KROLL Drift Rescue runtime smoke failures: " + str(failures))
		quit(1)

func _click_action(game: Control, button_name: String) -> void:
	game.get_node("SafeMargin/Scroll/MainColumn/ThrustControls/" + button_name).emit_signal("pressed")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = GameScene.instantiate() as Control
	_check(game != null, "Orbital Surveyor scene instantiates")
	root.add_child(game)
	await process_frame
	_check(game.find_child("SurveyGrid", true, false) != null, "seven-by-seven survey grid exists")
	_check(game.find_child("MoveUpButton", true, false) != null, "touch movement controls exist")
	_check(game.find_child("ScanButton", true, false) != null, "touch scan control exists")
	_check(game.find_child("NextMissionButton", true, false) != null, "mission navigation control exists")
	_check(game.has_method("perform_action") and game.has_method("get_game_state"), "game exposes deterministic action and state APIs")
	var first: bool = bool(game.call("perform_action", "move_down"))
	_check(first, "runtime accepts a valid rover move")
	var state: Dictionary = game.call("get_game_state")
	_check(int(state["mission_state"]["y"]) == 1, "runtime updates the rover position")
	game.call("restart_campaign")
	state = game.call("get_game_state")
	_check(int(state["mission_state"]["battery"]) == 25 and int(state["score"]) == 0, "restart restores mission battery and campaign score")

	var plans: Array[Array] = [
		["move_down","move_down","move_right","move_right","move_right","scan","move_down","move_down","move_down","move_right","scan","move_left","move_left","move_up","scan","move_left","move_left","move_up","move_up","move_up","move_up"],
		["move_right","move_right","move_down","move_down","move_down","move_right","move_right","move_up","scan","move_down","move_right","move_down","move_down","move_left","scan","move_down","move_left","move_left","move_up","move_up","scan","move_up","move_up","move_up","move_left","move_left","move_up"],
		["move_down","move_down","move_right","move_right","move_right","scan","move_left","move_down","move_down","move_down","move_right","scan","move_left","move_left","move_up","scan","move_left","move_up","move_up","move_up","move_up"]
	]
	for mission_index in range(3):
		for action in plans[mission_index]:
			_check(bool(game.call("perform_action", str(action))), "runtime accepts mission %d action %s" % [mission_index + 1, str(action)])
		if mission_index < 2:
			_check(bool(game.call("perform_action", "next")), "runtime unlocks next mission")
	state = game.call("get_game_state")
	_check(str(state["status"]) == "won", "runtime completes all three survey missions")
	_check(int(game.call("get_campaign_score")) == 300, "runtime awards the 300-point campaign total")
	_check(int(state["mission_state"]["x"]) == 0 and int(state["mission_state"]["y"]) == 0, "final rover returns to the base")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Orbital Surveyor runtime smoke test passed.")
		quit(0)
	else:
		push_error("KROLL Orbital Surveyor runtime smoke failures: " + str(failures))
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

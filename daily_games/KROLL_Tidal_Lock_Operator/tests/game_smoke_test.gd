extends SceneTree

const GameScript = preload("res://main.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = GameScript.new()
	root.add_child(game)
	await process_frame

	_expect(game.find_child("PumpUpButton", true, false) != null, "pump-up pointer/touch button exists")
	_expect(game.find_child("PumpDownButton", true, false) != null, "pump-down pointer/touch button exists")
	_expect(game.find_child("LowerGateButton", true, false) != null, "lower-gate pointer/touch button exists")
	_expect(game.find_child("MoveShipButton", true, false) != null, "move-ship pointer/touch button exists")
	_expect(game.find_child("UpperGateButton", true, false) != null, "upper-gate pointer/touch button exists")
	_expect(game.find_child("NextButton", true, false) != null, "next-lock navigation button exists")
	_expect(game.find_child("RestartCampaignButton", true, false) != null, "campaign restart button exists")

	var pump_button := game.find_child("PumpUpButton", true, false) as Button
	pump_button.emit_signal("pressed")
	_expect(int(game.get_game_state()["chamber_level"]) == 2, "pointer/touch button invokes the pump action")
	game.restart_current_level()
	_expect(int(game.get_game_state()["chamber_level"]) == 1, "reset restores the authored chamber level")

	var first_solution: Array[String] = ["toggle_lower_gate", "move_ship", "toggle_lower_gate", "pump_up", "pump_up", "toggle_upper_gate", "move_ship"]
	_solve(game, first_solution)
	_expect(game.get_campaign_score() == 100, "first lock awards 100 points")
	_expect(game.get_reward_claimed(0), "first lock reward is marked claimed")
	game.restart_current_level()
	_solve(game, first_solution)
	_expect(game.get_campaign_score() == 100, "replaying first lock cannot duplicate its reward")

	_expect(game.advance_level(), "advance opens the second lock")
	var second_solution: Array[String] = ["pump_up", "pump_up", "toggle_lower_gate", "move_ship", "toggle_lower_gate", "pump_down", "pump_down", "pump_down", "toggle_upper_gate", "move_ship"]
	_solve(game, second_solution)
	_expect(game.get_campaign_score() == 200, "second lock raises campaign score to 200")

	_expect(game.advance_level(), "advance opens the third lock")
	var third_solution: Array[String] = ["pump_down", "pump_down", "pump_down", "toggle_lower_gate", "move_ship", "toggle_lower_gate", "pump_up", "pump_up", "pump_up", "pump_up", "pump_up", "toggle_upper_gate", "move_ship"]
	_solve(game, third_solution)
	_expect(game.get_campaign_score() == 300, "third lock reaches the 300-point campaign cap")
	_expect(game.is_campaign_complete(), "third lock completes the campaign")
	_expect(not game.advance_level(), "campaign cannot advance beyond the final lock")

	game.restart_current_level()
	_solve(game, third_solution)
	_expect(game.get_campaign_score() == 300, "replaying final lock cannot duplicate its reward")
	game.restart_campaign()
	_expect(game.get_campaign_score() == 0, "campaign restart resets the score")
	_expect(game.get_level_index() == 0, "campaign restart returns to the first lock")
	_expect(not game.get_reward_claimed(0), "campaign restart resets one-time reward claims")

	root.remove_child(game)
	game.free()
	if failures.is_empty():
		print("KROLL Tidal Lock Operator runtime smoke test passed.")
		quit(0)
	else:
		push_error("Tidal Lock runtime smoke failures: " + str(failures))
		quit(1)

func _solve(game: Variant, actions: Array[String]) -> void:
	for action in actions:
		_expect(game.perform_game_action(action), "game accepts authored action " + action)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

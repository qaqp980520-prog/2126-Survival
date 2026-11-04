extends SceneTree

const GameScript = preload("res://main.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = GameScript.new()
	root.add_child(game)
	await process_frame
	_expect(game.get_node_or_null("SafeMargin/Scroll/MainColumn/RecipeButtons/circuit_board") != null, "circuit recipe button exists")
	_expect(game.get_node_or_null("SafeMargin/Scroll/MainColumn/RecipeButtons/sensor_array") != null, "sensor recipe button exists")
	_expect(game.get_node_or_null("SafeMargin/Scroll/MainColumn/CampaignControls/NextButton") != null, "next-order touch button exists")
	_expect(game.get_node_or_null("SafeMargin/Scroll/MainColumn/CampaignControls/RestartLevelButton") != null, "restart-order touch button exists")
	_expect(game.get_node_or_null("SafeMargin/Scroll/MainColumn/CampaignControls/RestartCampaignButton") != null, "new-campaign touch button exists")
	_expect(str(game.call("get_state_snapshot").get("status", "")) == "active", "scene starts with an active work order")

	_click_recipe(game, "circuit_board")
	_click_recipe(game, "glass_lens")
	_click_recipe(game, "sensor_array")
	_expect(str(game.call("get_state_snapshot").get("status", "")) == "completed", "button-driven recipe chain completes the first order")
	_expect(int(game.call("get_state_snapshot").get("campaign_score", 0)) == 100, "first order awards exactly 100 points")
	game.call("restart_level")
	_click_recipe(game, "circuit_board")
	_click_recipe(game, "glass_lens")
	_click_recipe(game, "sensor_array")
	_expect(int(game.call("get_state_snapshot").get("campaign_score", 0)) == 100, "replaying an order cannot duplicate its reward")
	game.get_node("SafeMargin/Scroll/MainColumn/CampaignControls/NextButton").emit_signal("pressed")
	_expect(int(game.call("get_state_snapshot").get("level_index", -1)) == 1, "next-order button advances to the second contract")

	_click_recipe(game, "alloy_plate")
	_click_recipe(game, "circuit_board")
	_click_recipe(game, "power_cell")
	_expect(str(game.call("get_state_snapshot").get("status", "")) == "completed", "second work order completes through the UI")
	game.get_node("SafeMargin/Scroll/MainColumn/CampaignControls/NextButton").emit_signal("pressed")
	_expect(int(game.call("get_state_snapshot").get("level_index", -1)) == 2, "third contract loads")
	_click_recipe(game, "alloy_plate")
	_click_recipe(game, "circuit_board")
	_click_recipe(game, "circuit_board")
	_click_recipe(game, "coolant_pump")
	_expect(str(game.call("get_state_snapshot").get("status", "")) == "completed", "third work order completes through the UI")
	game.get_node("SafeMargin/Scroll/MainColumn/CampaignControls/NextButton").emit_signal("pressed")
	var final_state: Dictionary = game.call("get_state_snapshot")
	_expect(str(final_state.get("status", "")) == "campaign_complete", "campaign completion is explicit")
	_expect(int(final_state.get("campaign_score", 0)) == 300, "three orders award at most 300 points")

	game.get_node("SafeMargin/Scroll/MainColumn/CampaignControls/RestartCampaignButton").emit_signal("pressed")
	_expect(int(game.call("get_state_snapshot").get("campaign_score", -1)) == 0, "new-campaign button resets the reward ledger")
	var keyboard_event := InputEventKey.new()
	keyboard_event.pressed = true
	keyboard_event.keycode = KEY_2
	game.call("_unhandled_input", keyboard_event)
	_expect(int(game.call("get_state_snapshot").get("inventory", {}).get("circuit_board", 0)) == 1, "keyboard shortcut 2 runs the circuit recipe")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Orbital Foundry runtime smoke test passed.")
		quit(0)
	else:
		push_error("KROLL Orbital Foundry runtime smoke failures: " + str(failures))
		quit(1)

func _click_recipe(game: Control, recipe_id: String) -> void:
	var button: Button = game.get_node("SafeMargin/Scroll/MainColumn/RecipeButtons/" + recipe_id)
	button.emit_signal("pressed")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

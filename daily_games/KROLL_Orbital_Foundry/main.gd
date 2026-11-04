extends Control

const Rules = preload("res://rules.gd")
const RECIPE_KEYS := ["alloy_plate","circuit_board","glass_lens","power_cell","sensor_array","coolant_pump"]

var _state: Dictionary = {}
var _message: String = "Read the work order, then chain the correct recipes before the reactor runs out of power."
var _recipe_buttons: Dictionary = {}
var _mission_label: Label
var _inventory_label: Label
var _goal_label: Label
var _stats_label: Label
var _message_label: Label
var _score_label: Label

func _ready() -> void:
	_build_ui()
	_state = Rules.new_state()
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			craft_recipe("alloy_plate")
		KEY_2:
			craft_recipe("circuit_board")
		KEY_3:
			craft_recipe("glass_lens")
		KEY_4:
			craft_recipe("power_cell")
		KEY_5:
			craft_recipe("sensor_array")
		KEY_6:
			craft_recipe("coolant_pump")
		KEY_N:
			next_level()
		KEY_R:
			restart_level()
		KEY_C:
			restart_campaign()

func craft_recipe(recipe_id: String) -> bool:
	var result: Dictionary = Rules.apply_recipe(_state, recipe_id)
	_state = result.get("state", _state)
	_message = _message_for_result(result)
	_update_ui()
	return bool(result.get("accepted", false))

func next_level() -> bool:
	var result: Dictionary = Rules.advance(_state)
	_state = result.get("state", _state)
	_message = _message_for_result(result)
	_update_ui()
	return bool(result.get("accepted", false))

func restart_level() -> void:
	_state = Rules.restart_level(_state)
	_message = "Current work order reset. Campaign credits are preserved."
	_update_ui()

func restart_campaign() -> void:
	_state = Rules.restart_campaign()
	_message = "New shift started. All campaign rewards have been reset."
	_update_ui()

func get_state_snapshot() -> Dictionary:
	return _state.duplicate(true)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.018, 0.032, 0.058)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "SafeMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.name = "MainColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)

	var title := _make_label("GameTitle", 30, Color(0.48, 0.86, 1.0))
	title.text = "KROLL  /  ORBITAL FOUNDRY"
	column.add_child(title)
	var subtitle := _make_label("Subtitle", 15, Color(0.66, 0.77, 0.87))
	subtitle.text = "MANUFACTURING CONTROL  •  GODOT 4.3 PROTOTYPE"
	column.add_child(subtitle)

	_mission_label = _make_label("MissionStatus", 21, Color(1.0, 0.82, 0.48))
	column.add_child(_mission_label)
	_goal_label = _make_label("WorkOrder", 18, Color(0.77, 0.92, 1.0))
	column.add_child(_goal_label)
	_inventory_label = _make_label("StockLedger", 16, Color(0.71, 0.9, 0.81))
	_inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_inventory_label)
	_stats_label = _make_label("FoundryMetrics", 16, Color(0.84, 0.88, 0.96))
	column.add_child(_stats_label)

	var recipe_title := _make_label("RecipeTitle", 18, Color(0.48, 0.86, 1.0))
	recipe_title.text = "RECIPE TERMINAL  /  SELECT A PRODUCTION CYCLE"
	column.add_child(recipe_title)
	var recipe_grid := GridContainer.new()
	recipe_grid.name = "RecipeButtons"
	recipe_grid.columns = 2
	recipe_grid.add_theme_constant_override("h_separation", 8)
	recipe_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(recipe_grid)

	for recipe_id in RECIPE_KEYS:
		var recipe: Dictionary = Rules.recipe_info(recipe_id)
		var button := Button.new()
		button.name = recipe_id
		button.text = "%s  [%d E]" % [str(recipe.get("label", recipe_id)), int(recipe.get("energy", 0))]
		button.custom_minimum_size = Vector2(250, 58)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 17)
		button.tooltip_text = _recipe_tooltip(recipe)
		button.pressed.connect(craft_recipe.bind(recipe_id))
		recipe_grid.add_child(button)
		_recipe_buttons[recipe_id] = button

	_message_label = _make_label("FoundryMessage", 16, Color(1.0, 0.86, 0.58))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message_label)

	var controls := HBoxContainer.new()
	controls.name = "CampaignControls"
	controls.add_theme_constant_override("separation", 8)
	column.add_child(controls)
	_add_control_button(controls, "NextButton", "NEXT ORDER  [N]", Callable(self, "next_level"))
	_add_control_button(controls, "RestartLevelButton", "RESTART ORDER  [R]", Callable(self, "restart_level"))
	_add_control_button(controls, "RestartCampaignButton", "NEW CAMPAIGN  [C]", Callable(self, "restart_campaign"))

	_score_label = _make_label("CampaignScore", 20, Color(0.48, 0.95, 0.75))
	column.add_child(_score_label)
	var help := _make_label("ControlsHelp", 13, Color(0.57, 0.68, 0.78))
	help.text = "KEYS  1–6: recipes   N: next order   R: restart order   C: restart campaign   •   Buttons also support mouse and touch."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)

func _make_label(label_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _add_control_button(parent: Node, button_name: String, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = caption
	button.custom_minimum_size = Vector2(180, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)

func _recipe_tooltip(recipe: Dictionary) -> String:
	var parts := PackedStringArray()
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id in inputs.keys():
		parts.append("%s × %d" % [str(item_id), int(inputs[item_id])])
	return "Consumes: " + ", ".join(parts)

func _message_for_result(result: Dictionary) -> String:
	var reason: String = str(result.get("reason", ""))
	if not bool(result.get("accepted", false)):
		match reason:
			"missing_materials":
				return "INSUFFICIENT STOCK. The rejected recipe did not consume energy or materials."
			"insufficient_energy":
				return "POWER RESERVE TOO LOW. Choose a cheaper production cycle."
			"action_limit":
				return "SHIFT LIMIT REACHED. Restart this work order to try another sequence."
			"contract_incomplete":
				return "The work order is not complete yet."
			"inactive":
				return "This shift is no longer active."
			_:
				return "Recipe rejected: " + reason
	match reason:
		"crafted":
			return "Production complete. Check the remaining stock and energy before the next cycle."
		"contract_complete":
			return "WORK ORDER COMPLETE. One campaign reward has been recorded."
		"next_contract":
			return "Next work order loaded. New stock, new production chain."
		"campaign_complete":
			return "FOUNDRY CAMPAIGN CERTIFIED. All three contracts are complete."
		_:
			return "Foundry state updated."

func _update_ui() -> void:
	if _state.is_empty():
		return
	var level_index: int = int(_state.get("level_index", 0))
	var level: Dictionary = Rules.level_at(level_index)
	var inventory: Dictionary = _state.get("inventory", {})
	var stock_parts := PackedStringArray()
	var keys: Array = inventory.keys()
	keys.sort()
	for item_id in keys:
		var amount: int = int(inventory[item_id])
		if amount > 0:
			stock_parts.append("%s %d" % [str(item_id).to_upper(), amount])
	if stock_parts.is_empty():
		stock_parts.append("EMPTY")
	var goal: Dictionary = level.get("goal", {})
	var goal_parts := PackedStringArray()
	for item_id in goal.keys():
		goal_parts.append("%s × %d" % [str(item_id).to_upper(), int(goal[item_id])])
	var status: String = str(_state.get("status", "active"))
	var status_text: String = status.to_upper().replace("_", " ")
	_mission_label.text = "WORK ORDER %d / %d   •   %s" % [level_index + 1, Rules.level_count(), str(level.get("name", "UNKNOWN"))]
	_goal_label.text = "REQUIRED OUTPUT: " + ", ".join(goal_parts)
	_inventory_label.text = "STOCK LEDGER: " + "     ".join(stock_parts)
	_stats_label.text = "ENERGY %d / %d     ACTIONS %d / %d     STATUS %s" % [
		int(_state.get("energy", 0)),
		int(_state.get("starting_energy", 0)),
		int(_state.get("actions", 0)),
		int(_state.get("action_limit", 0)),
		status_text
	]
	_message_label.text = _message
	_score_label.text = "CAMPAIGN SCORE  %d / 300" % int(_state.get("campaign_score", 0))
	for recipe_id in _recipe_buttons.keys():
		var button: Button = _recipe_buttons[recipe_id]
		button.disabled = status != "active"
		var recipe: Dictionary = Rules.recipe_info(str(recipe_id))
		button.text = "%s  [%d E]" % [str(recipe.get("label", recipe_id)), int(recipe.get("energy", 0))]
	$SafeMargin/Scroll/MainColumn/CampaignControls/NextButton.disabled = status != "completed"
	$SafeMargin/Scroll/MainColumn/CampaignControls/RestartLevelButton.disabled = status == "campaign_complete"
	$SafeMargin/Scroll/MainColumn/CampaignControls/RestartCampaignButton.disabled = false

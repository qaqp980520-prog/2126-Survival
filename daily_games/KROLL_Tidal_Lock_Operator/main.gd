extends Control

const Rules = preload("res://rules.gd")

var _level_index: int = 0
var _state: Dictionary = {}
var _score: int = 0
var _rewards_claimed: Array[bool] = [false, false, false]

var _title_label: Label
var _brief_label: Label
var _lower_label: Label
var _chamber_label: Label
var _upper_label: Label
var _action_label: Label
var _score_label: Label
var _status_label: Label
var _message_label: Label
var _next_button: Button

func _ready() -> void:
	_build_ui()
	_start_level(0)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_UP:
			perform_game_action("pump_up")
		KEY_DOWN:
			perform_game_action("pump_down")
		KEY_L:
			perform_game_action("toggle_lower_gate")
		KEY_U:
			perform_game_action("toggle_upper_gate")
		KEY_ENTER:
			perform_game_action("move_ship")
		KEY_R:
			restart_current_level()
		KEY_N:
			advance_level()
		KEY_C:
			restart_campaign()

func perform_game_action(action: String) -> bool:
	if _state.is_empty():
		return false
	var result: Dictionary = Rules.perform_action(_state, action)
	_state = result.get("state", _state)
	if bool(result.get("accepted", false)) and str(_state.get("status", "")) == "won":
		if not _rewards_claimed[_level_index]:
			_score += Rules.reward_for_clear(_state)
			_rewards_claimed[_level_index] = true
	_update_ui()
	return bool(result.get("accepted", false))

func advance_level() -> bool:
	if str(_state.get("status", "")) != "won" or _level_index >= Rules.level_count() - 1:
		return false
	_start_level(_level_index + 1)
	return true

func restart_current_level() -> void:
	_start_level(_level_index)

func restart_campaign() -> void:
	_score = 0
	_rewards_claimed = [false, false, false]
	_start_level(0)

func get_game_state() -> Dictionary:
	return _state.duplicate(true)

func get_campaign_score() -> int:
	return _score

func get_level_index() -> int:
	return _level_index

func get_reward_claimed(index: int) -> bool:
	return index >= 0 and index < _rewards_claimed.size() and _rewards_claimed[index]

func is_campaign_complete() -> bool:
	return _level_index == Rules.level_count() - 1 and str(_state.get("status", "")) == "won"

func _start_level(index: int) -> void:
	_level_index = clampi(index, 0, Rules.level_count() - 1)
	_state = Rules.new_state(_level_index)
	_update_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.055, 0.085)
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

	var column := VBoxContainer.new()
	column.name = "MainColumn"
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_title_label = Label.new()
	_title_label.name = "GameTitle"
	_title_label.text = "KROLL  /  TIDAL LOCK OPERATOR"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	column.add_child(_title_label)

	_status_label = Label.new()
	_status_label.name = "CampaignStatus"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	column.add_child(_status_label)

	_brief_label = Label.new()
	_brief_label.name = "LevelBrief"
	_brief_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9))
	column.add_child(_brief_label)

	var basin_row := HBoxContainer.new()
	basin_row.name = "BasinDiagram"
	basin_row.add_theme_constant_override("separation", 12)
	basin_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(basin_row)

	_lower_label = _create_basin_panel(basin_row, "LowerBasinPanel", "LOWER BASIN")
	_chamber_label = _create_basin_panel(basin_row, "LockChamberPanel", "LOCK CHAMBER")
	_upper_label = _create_basin_panel(basin_row, "UpperBasinPanel", "UPPER BASIN")

	_action_label = Label.new()
	_action_label.name = "ActionCounter"
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", 18)
	_action_label.add_theme_color_override("font_color", Color(0.95, 0.83, 0.52))
	column.add_child(_action_label)

	_score_label = Label.new()
	_score_label.name = "CampaignScore"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 18)
	_score_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.72))
	column.add_child(_score_label)

	var pump_row := HBoxContainer.new()
	pump_row.name = "PumpControls"
	pump_row.add_theme_constant_override("separation", 10)
	column.add_child(pump_row)
	_create_action_button(pump_row, "PumpUpButton", "PUMP UP  ↑", "pump_up")
	_create_action_button(pump_row, "PumpDownButton", "PUMP DOWN  ↓", "pump_down")

	var gate_row := HBoxContainer.new()
	gate_row.name = "GateControls"
	gate_row.add_theme_constant_override("separation", 10)
	column.add_child(gate_row)
	_create_action_button(gate_row, "LowerGateButton", "LOWER GATE  [L]", "toggle_lower_gate")
	_create_action_button(gate_row, "MoveShipButton", "MOVE SHIP  [ENTER]", "move_ship")
	_create_action_button(gate_row, "UpperGateButton", "UPPER GATE  [U]", "toggle_upper_gate")

	var navigation_row := HBoxContainer.new()
	navigation_row.name = "NavigationControls"
	navigation_row.add_theme_constant_override("separation", 10)
	column.add_child(navigation_row)

	var reset_button := Button.new()
	reset_button.name = "ResetButton"
	reset_button.text = "RESET LOCK  [R]"
	reset_button.custom_minimum_size = Vector2(150, 46)
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.pressed.connect(restart_current_level)
	navigation_row.add_child(reset_button)

	_next_button = Button.new()
	_next_button.name = "NextButton"
	_next_button.text = "NEXT LOCK  [N]"
	_next_button.custom_minimum_size = Vector2(150, 46)
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.pressed.connect(advance_level)
	navigation_row.add_child(_next_button)

	var campaign_button := Button.new()
	campaign_button.name = "RestartCampaignButton"
	campaign_button.text = "RESTART CAMPAIGN  [C]"
	campaign_button.custom_minimum_size = Vector2(190, 46)
	campaign_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_button.pressed.connect(restart_campaign)
	navigation_row.add_child(campaign_button)

	_message_label = Label.new()
	_message_label.name = "OperationFeedback"
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 16)
	_message_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	column.add_child(_message_label)

	var hint := Label.new()
	hint.name = "ControlHints"
	hint.text = "UP/DOWN: PUMP    L/U: GATES    ENTER: MOVE    R: RESET    N: NEXT    C: CAMPAIGN"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.62, 0.72))
	column.add_child(hint)

func _create_basin_panel(parent: HBoxContainer, node_name: String, heading: String) -> Label:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.13, 0.18)
	style.border_color = Color(0.18, 0.38, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var label := Label.new()
	label.name = node_name + "Readout"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.82, 0.93, 1.0))
	panel.add_child(label)
	return label

func _create_action_button(parent: HBoxContainer, node_name: String, caption: String, action: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.custom_minimum_size = Vector2(150, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_on_action_button_pressed.bind(action))
	parent.add_child(button)
	return button

func _on_action_button_pressed(action: String) -> void:
	perform_game_action(action)

func _update_ui() -> void:
	if _state.is_empty() or not is_instance_valid(_status_label):
		return
	var level: Dictionary = Rules.get_level(_level_index)
	var lower_level: int = int(level["lower_level"])
	var upper_level: int = int(level["upper_level"])
	var chamber_level: int = int(_state["chamber_level"])
	var ship_position: String = str(_state["ship_position"])
	var lower_gate: String = "OPEN" if bool(_state["lower_gate_open"]) else "CLOSED"
	var upper_gate: String = "OPEN" if bool(_state["upper_gate_open"]) else "CLOSED"
	var ship_lower: String = "SHIP HERE" if ship_position == "lower" else ""
	var ship_chamber: String = "SHIP HERE" if ship_position == "chamber" else ""
	var ship_upper: String = "SHIP HERE" if ship_position == "upper" else ""

	_title_label.text = "KROLL  /  TIDAL LOCK OPERATOR"
	_brief_label.text = "LOCK %d / %d  —  %s\n%s" % [_level_index + 1, Rules.level_count(), str(level["name"]), str(level["brief"])]
	_lower_label.text = "LOWER BASIN\nWATER LEVEL  %d\nGATE  %s\n%s" % [lower_level, lower_gate, ship_lower]
	_chamber_label.text = "LOCK CHAMBER\nWATER LEVEL  %d\nLOWER GATE  %s\nUPPER GATE  %s\n%s" % [chamber_level, lower_gate, upper_gate, ship_chamber]
	_upper_label.text = "UPPER BASIN\nWATER LEVEL  %d\nGATE  %s\n%s" % [upper_level, upper_gate, ship_upper]
	_action_label.text = "ACTIONS  %d / %d     |     PAR  %d" % [int(_state["actions"]), int(level["max_actions"]), int(level["par_actions"])]
	_score_label.text = "CAMPAIGN SCORE  %d / 300" % _score
	_message_label.text = str(_state.get("message", ""))

	var status: String = str(_state.get("status", "playing"))
	if status == "won" and _level_index == Rules.level_count() - 1:
		_status_label.text = "CAMPAIGN COMPLETE"
	elif status == "won":
		_status_label.text = "LOCK CLEARED — ADVANCE TO THE NEXT LOCK"
	elif status == "failed":
		_status_label.text = "LOCK FAILED — RESET TO TRY AGAIN"
	else:
		_status_label.text = "VESSEL POSITION: " + ship_position.to_upper()
	_next_button.disabled = status != "won" or _level_index >= Rules.level_count() - 1

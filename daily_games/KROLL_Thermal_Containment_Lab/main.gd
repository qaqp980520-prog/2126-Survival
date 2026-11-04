extends Control

const Rules = preload("res://rules.gd")

var _state: Dictionary = {}
var _message: String = "Select a row to vent, then advance one thermal cycle. Contain every cell between 19°C and 29°C after four cycles."
var _grid_panels: Array[PanelContainer] = []
var _grid_labels: Array[Label] = []
var _row_buttons: Array[Button] = []
var _mission_label: Label
var _stats_label: Label
var _message_label: Label
var _score_label: Label
var _advance_button: Button
var _undo_button: Button
var _next_button: Button

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
			select_row(0)
		KEY_2:
			select_row(1)
		KEY_3:
			select_row(2)
		KEY_4:
			select_row(3)
		KEY_SPACE:
			advance_cycle()
		KEY_U:
			undo_cycle()
		KEY_R:
			restart_level()
		KEY_N:
			next_level()
		KEY_C:
			restart_campaign()

func select_row(row: int) -> bool:
	if row < 0 or row >= Rules.BOARD_SIZE:
		return false
	_state = _state.duplicate(true)
	_state["selected_row"] = row
	_message = "Vent row %d selected. Press VENT / ADVANCE to run the next cycle." % (row + 1)
	_update_ui()
	return true

func advance_cycle() -> bool:
	var result: Dictionary = Rules.advance_cycle(_state, int(_state.get("selected_row", 0)))
	_state = result.get("state", _state)
	_message = _message_for_result(str(result.get("reason", "")), bool(result.get("accepted", false)))
	_update_ui()
	return bool(result.get("accepted", false))

func undo_cycle() -> bool:
	var result: Dictionary = Rules.undo_cycle(_state)
	_state = result.get("state", _state)
	_message = _message_for_result(str(result.get("reason", "")), bool(result.get("accepted", false)))
	_update_ui()
	return bool(result.get("accepted", false))

func restart_level() -> void:
	_state = Rules.restart_level(_state)
	_message = "Chamber reset. Previously certified chambers keep their campaign points."
	_update_ui()

func next_level() -> bool:
	var result: Dictionary = Rules.advance(_state)
	_state = result.get("state", _state)
	_message = _message_for_result(str(result.get("reason", "")), bool(result.get("accepted", false)))
	_update_ui()
	return bool(result.get("accepted", false))

func restart_campaign() -> void:
	_state = Rules.restart_campaign()
	_message = "New thermal containment campaign initialized."
	_update_ui()

func get_game_state() -> Dictionary:
	return _state.duplicate(true)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.012, 0.026, 0.052)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "SafeMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
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

	var title := _make_label("GameTitle", 23, Color(0.48, 0.88, 1.0))
	title.text = "KROLL  /  THERMAL CONTAINMENT"
	column.add_child(title)
	var subtitle := _make_label("Subtitle", 11, Color(0.64, 0.77, 0.9))
	subtitle.text = "HEAT DIFFUSION  •  ROW VENTING  •  FOUR-CYCLE STABILIZATION"
	column.add_child(subtitle)

	_mission_label = _make_label("MissionStatus", 16, Color(1.0, 0.82, 0.48))
	column.add_child(_mission_label)
	_stats_label = _make_label("ThermalMetrics", 12, Color(0.72, 0.9, 0.85))
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_stats_label)

	var grid := GridContainer.new()
	grid.name = "ThermalGrid"
	grid.columns = Rules.BOARD_SIZE
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(grid)

	for index in range(Rules.BOARD_SIZE * Rules.BOARD_SIZE):
		var panel := PanelContainer.new()
		panel.name = "Cell_%02d" % index
		panel.custom_minimum_size = Vector2(58, 58)
		var label := _make_label("Temperature", 17, Color(0.9, 0.96, 1.0))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(label)
		grid.add_child(panel)
		_grid_panels.append(panel)
		_grid_labels.append(label)

	var row_caption := _make_label("VentCaption", 13, Color(0.64, 0.82, 0.96))
	row_caption.text = "SELECT VENT ROW  [1–4]"
	column.add_child(row_caption)
	var row_controls := HBoxContainer.new()
	row_controls.name = "VentRowControls"
	row_controls.add_theme_constant_override("separation", 6)
	column.add_child(row_controls)
	for row in range(Rules.BOARD_SIZE):
		var button := Button.new()
		button.name = "VentRow%d" % (row + 1)
		button.text = "ROW %d" % (row + 1)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(76, 42)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select_row.bind(row))
		row_controls.add_child(button)
		_row_buttons.append(button)

	var actions := GridContainer.new()
	actions.name = "ThermalActions"
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	column.add_child(actions)
	_advance_button = _add_button(actions, "AdvanceButton", "VENT / ADVANCE  [SPACE]", Callable(self, "advance_cycle"))
	_undo_button = _add_button(actions, "UndoButton", "UNDO  [U]", Callable(self, "undo_cycle"))
	_next_button = _add_button(actions, "NextButton", "NEXT CHAMBER  [N]", Callable(self, "next_level"))
	_add_button(actions, "RestartButton", "RESTART  [R]", Callable(self, "restart_level"))
	_add_button(actions, "CampaignButton", "NEW CAMPAIGN  [C]", Callable(self, "restart_campaign"))

	_message_label = _make_label("ThermalMessage", 13, Color(1.0, 0.86, 0.58))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message_label)
	_score_label = _make_label("CampaignScore", 16, Color(0.48, 0.95, 0.75))
	column.add_child(_score_label)

	var help := _make_label("ControlsHelp", 11, Color(0.58, 0.69, 0.8))
	help.text = "Each cycle: vent one complete row by 4°C, add heat at reactor sources, then diffuse heat toward neighboring cells. Stabilize every cell between 19°C and 29°C after four cycles."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)

func _make_label(label_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _add_button(parent: Node, button_name: String, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = caption
	button.custom_minimum_size = Vector2(150, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _message_for_result(reason: String, accepted: bool) -> String:
	if not accepted:
		match reason:
			"invalid_row":
				return "Invalid vent row."
			"nothing_to_undo":
				return "No thermal cycle is available to undo."
			"not_contained":
				return "Contain this chamber before advancing."
			"campaign_complete":
				return "CAMPAIGN COMPLETE. All three thermal chambers are stable."
			_:
				return "Command rejected: " + reason
	match reason:
		"contained":
			return "THERMAL CONTAINMENT CONFIRMED. All 16 cells are within the safe band."
		"thermal_limit_exceeded":
			return "CONTAINMENT FAILED. One or more cells remain outside the safe band. Undo or restart."
		"undone":
			return "Previous vent cycle restored."
		"next_chamber":
			return "Next thermal chamber loaded."
		_:
			return "Thermal cycle advanced. Check the temperature field."

func _update_ui() -> void:
	if _state.is_empty():
		return
	var level_index: int = int(_state.get("level_index", 0))
	var mission: Dictionary = Rules.mission_at(level_index)
	_mission_label.text = "CHAMBER %d / %d  —  %s" % [level_index + 1, Rules.LEVELS.size(), str(mission.get("name", ""))]
	_stats_label.text = "CYCLE %d / %d     VENT ROW %d     SAFE BAND %d–%d°C" % [
		int(_state.get("cycles", 0)), Rules.CYCLE_LIMIT,
		int(_state.get("selected_row", 0)) + 1, Rules.TARGET_MIN, Rules.TARGET_MAX
	]
	_score_label.text = "CAMPAIGN SCORE  %d / 300" % int(_state.get("campaign_score", 0))
	_message_label.text = _message
	var grid: Array = _state.get("grid", [])
	for row in range(Rules.BOARD_SIZE):
		for column in range(Rules.BOARD_SIZE):
			var index: int = row * Rules.BOARD_SIZE + column
			var temperature: int = int(grid[row][column])
			_grid_labels[index].text = "%d°C" % temperature
			var cell_color := Color(0.12, 0.28, 0.42)
			if temperature < Rules.TARGET_MIN:
				cell_color = Color(0.12, 0.2, 0.46)
			elif temperature > Rules.TARGET_MAX:
				cell_color = Color(0.52, 0.19, 0.13)
			else:
				cell_color = Color(0.1, 0.34, 0.28)
			var style := StyleBoxFlat.new()
			style.bg_color = cell_color
			style.corner_radius_top_left = 5
			style.corner_radius_top_right = 5
			style.corner_radius_bottom_left = 5
			style.corner_radius_bottom_right = 5
			_grid_panels[index].add_theme_stylebox_override("panel", style)
	for row in range(_row_buttons.size()):
		_row_buttons[row].button_pressed = row == int(_state.get("selected_row", 0))
		_row_buttons[row].disabled = bool(_state.get("completed", false)) or bool(_state.get("failed", false))
	_advance_button.disabled = bool(_state.get("completed", false)) or bool(_state.get("failed", false))
	_undo_button.disabled = (_state.get("history", []) as Array).is_empty() or bool(_state.get("completed", false))
	_next_button.disabled = not bool(_state.get("completed", false)) or level_index >= Rules.LEVELS.size() - 1

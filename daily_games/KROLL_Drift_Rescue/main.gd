extends Control

const Rules = preload("res://rules.gd")

var _state: Dictionary = {}
var _message: String = "Use counter-thrust to brake. Dock only when your position and velocity both match the target."
var _cell_panels: Array[PanelContainer] = []
var _cell_labels: Array[Label] = []
var _mission_label: Label
var _stats_label: Label
var _message_label: Label
var _score_label: Label
var _buttons: Dictionary = {}

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
		KEY_W, KEY_UP:
			perform_action("thrust_up")
		KEY_S, KEY_DOWN:
			perform_action("thrust_down")
		KEY_A, KEY_LEFT:
			perform_action("thrust_left")
		KEY_D, KEY_RIGHT:
			perform_action("thrust_right")
		KEY_SPACE:
			perform_action("coast")
		KEY_U:
			perform_action("undo")
		KEY_R:
			restart_mission()
		KEY_N:
			next_mission()
		KEY_C:
			restart_campaign()

func perform_action(action: String) -> bool:
	var result: Dictionary = Rules.perform_action(_state, action)
	_state = result.get("state", _state)
	_message = _message_for_result(result)
	_update_ui()
	return bool(result.get("accepted", false))

func restart_mission() -> void:
	_state = Rules.restart_level(_state)
	_message = "Mission reset. Previously earned campaign points are preserved."
	_update_ui()

func next_mission() -> bool:
	var result: Dictionary = Rules.advance(_state)
	_state = result.get("state", _state)
	_message = _message_for_result(result)
	_update_ui()
	return bool(result.get("accepted", false))

func restart_campaign() -> void:
	_state = Rules.restart_campaign()
	_message = "New rescue campaign initialized."
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
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.name = "MainColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)

	var title := _make_label("GameTitle", 23, Color(0.48, 0.88, 1.0))
	title.text = "KROLL  /  DRIFT RESCUE"
	column.add_child(title)
	var subtitle := _make_label("Subtitle", 11, Color(0.64, 0.77, 0.9))
	subtitle.text = "ORBITAL RECOVERY  •  MOMENTUM / BRAKING / DOCKING"
	column.add_child(subtitle)

	_mission_label = _make_label("MissionStatus", 16, Color(1.0, 0.82, 0.48))
	column.add_child(_mission_label)
	_stats_label = _make_label("FlightMetrics", 12, Color(0.72, 0.9, 0.85))
	column.add_child(_stats_label)

	var grid := GridContainer.new()
	grid.name = "FlightGrid"
	grid.columns = Rules.BOARD_SIZE
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(grid)

	for index in range(Rules.BOARD_SIZE * Rules.BOARD_SIZE):
		var panel := PanelContainer.new()
		panel.name = "Cell_%02d" % index
		panel.custom_minimum_size = Vector2(34, 34)
		var label := _make_label("CellLabel", 18, Color(0.8, 0.9, 1.0))
		panel.add_child(label)
		grid.add_child(panel)
		_cell_panels.append(panel)
		_cell_labels.append(label)

	var thrust_controls := GridContainer.new()
	thrust_controls.name = "ThrustControls"
	thrust_controls.columns = 3
	thrust_controls.add_theme_constant_override("h_separation", 6)
	thrust_controls.add_theme_constant_override("v_separation", 6)
	column.add_child(thrust_controls)
	_add_action_button(thrust_controls, "ThrustUpButton", "UP  [W]", "thrust_up")
	_add_action_button(thrust_controls, "ThrustLeftButton", "LEFT  [A]", "thrust_left")
	_add_action_button(thrust_controls, "ThrustDownButton", "DOWN  [S]", "thrust_down")
	_add_action_button(thrust_controls, "ThrustRightButton", "RIGHT  [D]", "thrust_right")
	_add_action_button(thrust_controls, "CoastButton", "COAST  [SPACE]", "coast")

	_message_label = _make_label("FlightMessage", 13, Color(1.0, 0.86, 0.58))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message_label)

	var flight_controls := GridContainer.new()
	flight_controls.name = "FlightControls"
	flight_controls.columns = 2
	flight_controls.add_theme_constant_override("h_separation", 6)
	flight_controls.add_theme_constant_override("v_separation", 6)
	column.add_child(flight_controls)
	_add_control_button(flight_controls, "UndoButton", "UNDO  [U]", Callable(self, "perform_action").bind("undo"))
	_add_control_button(flight_controls, "RestartButton", "RESTART  [R]", Callable(self, "restart_mission"))
	_add_control_button(flight_controls, "NextButton", "NEXT  [N]", Callable(self, "next_mission"))
	_add_control_button(flight_controls, "CampaignButton", "NEW CAMPAIGN  [C]", Callable(self, "restart_campaign"))

	_score_label = _make_label("CampaignScore", 16, Color(0.48, 0.95, 0.75))
	column.add_child(_score_label)
	var help := _make_label("ControlsHelp", 11, Color(0.58, 0.69, 0.8))
	help.text = "THRUST changes velocity; COAST preserves it. Counter-thrust to stop exactly on the green target. Each thrust costs one fuel."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)

func _make_label(label_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _add_action_button(parent: Node, button_name: String, caption: String, action: String) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = caption
	button.custom_minimum_size = Vector2(90, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(perform_action.bind(action))
	parent.add_child(button)
	_buttons[button_name] = button

func _add_control_button(parent: Node, button_name: String, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = caption
	button.custom_minimum_size = Vector2(140, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(action)
	parent.add_child(button)
	_buttons[button_name] = button

func _message_for_result(result: Dictionary) -> String:
	var reason: String = str(result.get("reason", ""))
	if not bool(result.get("accepted", false)):
		match reason:
			"fuel_empty":
				return "FUEL EMPTY. Coast or undo; directional thrust is unavailable."
			"nothing_to_undo":
				return "No previous flight step is available to undo."
			"not_docked":
				return "DOCKING REQUIRED. Reach the target and brake to zero velocity before advancing."
			"inactive":
				return "Mission is no longer active. Restart or advance when available."
			_:
				return "Command rejected: " + reason
	match reason:
		"docked":
			return "DOCKING CONFIRMED. The craft is stationary inside the recovery frame."
		"collision":
			return "HULL IMPACT. The swept flight path crossed debris. Undo or restart the mission."
		"out_of_bounds":
			return "FLIGHT DECK LOST. The craft crossed the navigation boundary."
		"turn_limit":
			return "RESCUE WINDOW EXPIRED. Restart and use fewer flight actions."
		"undone":
			return "Previous flight step restored."
		"next_mission":
			return "Next recovery sector loaded."
		"campaign_complete":
			return "CAMPAIGN COMPLETE. All three recovery operations are certified."
		_:
			return "Flight state updated."

func _update_ui() -> void:
	if _state.is_empty():
		return
	var level_index: int = int(_state.get("level_index", 0))
	var mission: Dictionary = Rules.mission_at(level_index)
	var position: Vector2i = _state.get("position", mission["start"])
	var velocity: Vector2i = _state.get("velocity", Vector2i.ZERO)
	var status: String = str(_state.get("status", "active"))
	_mission_label.text = "MISSION %d / %d  •  %s" % [level_index + 1, Rules.level_count(), str(mission.get("name", "UNKNOWN"))]
	_stats_label.text = "POSITION (%d,%d)   VELOCITY (%d,%d)   FUEL %d/%d   TURNS %d/%d   STATUS %s" % [
		position.x, position.y, velocity.x, velocity.y,
		int(_state.get("fuel", 0)), int(_state.get("starting_fuel", 0)),
		int(_state.get("turns", 0)), int(_state.get("max_turns", 0)),
		status.to_upper().replace("_", " ")
	]
	_message_label.text = _message
	_score_label.text = "CAMPAIGN SCORE  %d / 300" % int(_state.get("campaign_score", 0))

	var obstacles: Array = mission.get("obstacles", [])
	var goal: Vector2i = mission["goal"]
	for index in range(_cell_labels.size()):
		var cell := Vector2i(index % Rules.BOARD_SIZE, floori(float(index) / float(Rules.BOARD_SIZE)))
		var label: Label = _cell_labels[index]
		var panel: PanelContainer = _cell_panels[index]
		var text_value := "·"
		var background := Color(0.035, 0.075, 0.12)
		var foreground := Color(0.54, 0.7, 0.82)
		if obstacles.has(cell):
			text_value = "X"
			background = Color(0.22, 0.12, 0.16)
			foreground = Color(1.0, 0.48, 0.42)
		if cell == goal:
			text_value = "G"
			background = Color(0.08, 0.24, 0.2)
			foreground = Color(0.48, 1.0, 0.72)
		if cell == position:
			text_value = "D/G" if cell == goal else "D"
			background = Color(0.12, 0.25, 0.38)
			foreground = Color(0.58, 0.9, 1.0)
		label.text = text_value
		label.add_theme_color_override("font_color", foreground)
		var style := StyleBoxFlat.new()
		style.bg_color = background
		style.set_border_width_all(1)
		style.border_color = Color(0.16, 0.28, 0.4)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)

	if _buttons.has("NextButton"):
		(_buttons["NextButton"] as Button).disabled = status != "completed"
	if _buttons.has("UndoButton"):
		(_buttons["UndoButton"] as Button).disabled = _state.get("history", []).is_empty()

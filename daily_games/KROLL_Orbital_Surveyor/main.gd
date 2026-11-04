extends Control

const Rules = preload("res://rules.gd")

var _state: Dictionary = {}
var _message: String = "Survey all three beacons, then return to the base."
var _cell_panels: Array[PanelContainer] = []
var _cell_labels: Array[Label] = []
var _buttons: Dictionary = {}
var _mission_label: Label
var _stats_label: Label
var _message_label: Label
var _result_label: Label

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
			perform_action("move_up")
		KEY_S, KEY_DOWN:
			perform_action("move_down")
		KEY_A, KEY_LEFT:
			perform_action("move_left")
		KEY_D, KEY_RIGHT:
			perform_action("move_right")
		KEY_SPACE:
			perform_action("scan")
		KEY_N:
			perform_action("next")
		KEY_R:
			restart_campaign()

func perform_action(action: String) -> bool:
	var result: Dictionary = Rules.perform_action(_state, action)
	_state = result.get("state", _state)
	_message = _message_for_result(result)
	_update_ui()
	return bool(result.get("accepted", false))

func restart_campaign() -> void:
	_state = Rules.new_state()
	_message = "Fresh survey launched. All battery reserves restored."
	_update_ui()

func get_game_state() -> Dictionary:
	return _state.duplicate(true)

func get_campaign_score() -> int:
	return maxi(0, int(_state.get("score", 0)))

func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.018, 0.035, 0.065)
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

	var title := Label.new()
	title.name = "GameTitle"
	title.text = "KROLL  /  ORBITAL SURVEYOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.52, 0.88, 1.0))
	column.add_child(title)

	_mission_label = _make_label("MissionStatus", 20, Color(0.96, 0.82, 0.48))
	column.add_child(_mission_label)
	_stats_label = _make_label("SurveyStats", 17, Color(0.76, 0.88, 0.96))
	column.add_child(_stats_label)

	var grid := GridContainer.new()
	grid.name = "SurveyGrid"
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(grid)

	for index in range(49):
		var panel := PanelContainer.new()
		panel.name = "Cell_%02d" % index
		panel.custom_minimum_size = Vector2(64, 52)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		panel.add_child(label)
		grid.add_child(panel)
		_cell_panels.append(panel)
		_cell_labels.append(label)

	var movement_row := HBoxContainer.new()
	movement_row.name = "MovementControls"
	movement_row.add_theme_constant_override("separation", 8)
	column.add_child(movement_row)
	_add_button(movement_row, "MoveUpButton", "UP  [W]", "move_up")
	_add_button(movement_row, "MoveLeftButton", "LEFT  [A]", "move_left")
	_add_button(movement_row, "MoveDownButton", "DOWN  [S]", "move_down")
	_add_button(movement_row, "MoveRightButton", "RIGHT  [D]", "move_right")
	_add_button(movement_row, "ScanButton", "SCAN  [SPACE]", "scan")

	var footer := HBoxContainer.new()
	footer.name = "CampaignControls"
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	_add_button(footer, "NextMissionButton", "NEXT MISSION  [N]", "next")
	var restart := Button.new()
	restart.name = "RestartButton"
	restart.text = "RESTART CAMPAIGN  [R]"
	restart.custom_minimum_size = Vector2(210, 48)
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.pressed.connect(restart_campaign)
	footer.add_child(restart)

	_message_label = _make_label("SurveyMessage", 16, Color(0.88, 0.93, 0.98))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message_label)
	_result_label = _make_label("CampaignResult", 19, Color(0.48, 0.95, 0.74))
	column.add_child(_result_label)

	var legend := _make_label("Legend", 14, Color(0.58, 0.7, 0.8))
	legend.text = "R Rover   B Base   A/B/C Beacons   ≈ Rough terrain (2 battery)   ■ Rock"
	column.add_child(legend)

func _make_label(label_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _add_button(parent: Node, button_name: String, caption: String, action: String) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = caption
	button.custom_minimum_size = Vector2(150, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: perform_action(action))
	parent.add_child(button)
	_buttons[action] = button

func _message_for_result(result: Dictionary) -> String:
	var reason: String = str(result.get("reason", ""))
	if not bool(result.get("accepted", false)):
		match reason:
			"outside_map":
				return "Map boundary reached. Choose another direction."
			"blocked":
				return "Rock formation blocks this route."
			"not_on_beacon":
				return "No survey beacon at the rover's current position."
			"already_scanned":
				return "This beacon has already been recorded."
			"mission_not_complete":
				return "Scan A, B and C, then return to base before advancing."
			"campaign_finished":
				return "Campaign finished. Press R to launch again."
			_:
				return "Action rejected: " + reason
	if reason == "battery_depleted":
		return "Battery depleted before the rover returned to base. Mission failed."
	if reason == "beacon_scanned":
		return "Beacon recorded. Continue the survey and return to base."
	if reason == "next_mission":
		return "Next survey sector loaded."
	if reason == "moved":
		return "Rover moved. Watch the remaining battery."
	return "Survey action accepted."

func _update_ui() -> void:
	var mission_index: int = int(_state.get("mission_index", 0))
	var mission: Dictionary = Rules.mission_at(mission_index)
	var mission_state: Dictionary = _state.get("mission_state", {})
	var grid: Array = mission.get("grid", [])
	var scanned: Dictionary = mission_state.get("scanned", {})
	var x: int = int(mission_state.get("x", 0))
	var y: int = int(mission_state.get("y", 0))
	var battery: int = int(mission_state.get("battery", 0))
	var initial_battery: int = int(mission_state.get("initial_battery", 0))
	var scanned_count: int = 0
	for value in scanned.values():
		if bool(value):
			scanned_count += 1

	_mission_label.text = "MISSION %d / %d     %s" % [mission_index + 1, Rules.mission_count(), str(mission.get("name", "Unknown"))]
	_stats_label.text = "BATTERY  %d / %d     BEACONS  %d / 3     ACTIONS  %d     CAMPAIGN  %d / 300" % [
		battery, initial_battery, scanned_count, int(mission_state.get("actions", 0)), int(_state.get("score", 0))
	]

	for row in range(7):
		for col in range(7):
			var index: int = row * 7 + col
			var tile: String = str(grid[row]).substr(col, 1)
			var label_text: String = "·"
			var background_color: Color = Color(0.07, 0.13, 0.19)
			var font_color: Color = Color(0.72, 0.84, 0.92)
			if tile == "#":
				label_text = "■"
				background_color = Color(0.13, 0.17, 0.22)
				font_color = Color(0.48, 0.56, 0.64)
			elif tile == "~":
				label_text = "≈"
				background_color = Color(0.12, 0.2, 0.27)
				font_color = Color(0.45, 0.82, 0.94)
			elif tile == "S":
				label_text = "BASE"
				background_color = Color(0.12, 0.28, 0.22)
				font_color = Color(0.55, 0.96, 0.72)
			elif ["A","B","C"].has(tile):
				if bool(scanned.get(tile, false)):
					label_text = "✓"
					background_color = Color(0.1, 0.25, 0.22)
					font_color = Color(0.55, 0.96, 0.72)
				else:
					label_text = tile
					background_color = Color(0.3, 0.22, 0.1)
					font_color = Color(1.0, 0.83, 0.48)
			if col == x and row == y:
				label_text = "R"
				background_color = Color(0.08, 0.34, 0.48)
				font_color = Color(0.75, 0.95, 1.0)
			_cell_labels[index].text = label_text
			_cell_labels[index].add_theme_color_override("font_color", font_color)
			var style := StyleBoxFlat.new()
			style.bg_color = background_color
			style.set_border_width_all(1)
			style.border_color = Color(0.22, 0.34, 0.43)
			style.set_corner_radius_all(5)
			_cell_panels[index].add_theme_stylebox_override("panel", style)

	var mission_status: String = str(mission_state.get("status", "active"))
	var campaign_status: String = str(_state.get("status", "active"))
	_buttons["next"].disabled = mission_status != "won" or mission_index >= Rules.mission_count() - 1
	var current_tile: String = str(grid[y]).substr(x, 1)
	_buttons["scan"].disabled = mission_status != "active" or not ["A","B","C"].has(current_tile) or bool(scanned.get(current_tile, false)) or campaign_status != "active"
	for action in ["move_up","move_down","move_left","move_right"]:
		_buttons[action].disabled = campaign_status != "active" or mission_status != "active"

	if campaign_status == "won":
		_result_label.text = "SURVEY COMPLETE  /  ALL THREE SECTORS SECURED"
	elif campaign_status == "lost":
		_result_label.text = "MISSION ABORTED  /  PRESS R TO RETRY"
	elif mission_status == "won":
		_result_label.text = "SECTOR COMPLETE  /  +100 CAMPAIGN POINTS"
	else:
		_result_label.text = "OBJECTIVE  /  SCAN A, B AND C, THEN RETURN TO BASE"
	_message_label.text = _message

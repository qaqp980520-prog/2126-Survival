extends Control

const Rules = preload("res://rules.gd")

var _state: Dictionary = {}
var _message: String = "Pack every cargo piece and keep the center of mass inside the support frame."
var _cell_buttons: Array[Button] = []
var _buttons: Dictionary = {}
var _mission_label: Label
var _cargo_label: Label
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
		KEY_Q:
			perform_action("rotate")
		KEY_SPACE:
			perform_action("place")
		KEY_U:
			perform_action("undo")
		KEY_N:
			perform_action("next")
		KEY_R:
			perform_action("restart")

func perform_action(action: String) -> bool:
	var result: Dictionary = Rules.perform_action(_state, action)
	_state = result.get("state", _state)
	_message = _message_for_result(result)
	_update_ui()
	return bool(result.get("accepted", false))

func get_game_state() -> Dictionary:
	return _state.duplicate(true)

func _on_cell_pressed(index: int) -> void:
	if str(_state.get("status", "active")) != "active":
		return
	var next: Dictionary = _state.duplicate(true)
	next["cursor"] = Vector2i(index % Rules.BOARD_SIZE, floori(float(index) / float(Rules.BOARD_SIZE)))
	_state = next
	_message = "Placement cursor moved. Press PLACE when the footprint is clear."
	_update_ui()

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
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	var title := _make_label("GameTitle", 30, Color(0.52, 0.88, 1.0))
	title.text = "KROLL  /  ZERO-G CARGO BAY"
	column.add_child(title)

	_mission_label = _make_label("ManifestStatus", 19, Color(1.0, 0.82, 0.48))
	column.add_child(_mission_label)
	_cargo_label = _make_label("CurrentCargo", 17, Color(0.75, 0.91, 1.0))
	column.add_child(_cargo_label)
	_stats_label = _make_label("CargoMetrics", 16, Color(0.72, 0.88, 0.82))
	column.add_child(_stats_label)

	var grid := GridContainer.new()
	grid.name = "CargoGrid"
	grid.columns = Rules.BOARD_SIZE
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(grid)

	for index in range(Rules.BOARD_SIZE * Rules.BOARD_SIZE):
		var button := Button.new()
		button.name = "Cell_%02d" % index
		button.custom_minimum_size = Vector2(84, 66)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_on_cell_pressed.bind(index))
		grid.add_child(button)
		_cell_buttons.append(button)

	var movement := HBoxContainer.new()
	movement.name = "CursorControls"
	movement.add_theme_constant_override("separation", 6)
	column.add_child(movement)
	_add_button(movement, "MoveUpButton", "UP", "move_up")
	_add_button(movement, "MoveLeftButton", "LEFT", "move_left")
	_add_button(movement, "MoveDownButton", "DOWN", "move_down")
	_add_button(movement, "MoveRightButton", "RIGHT", "move_right")
	_add_button(movement, "RotateButton", "ROTATE  [Q]", "rotate")

	var actions := HBoxContainer.new()
	actions.name = "ActionControls"
	actions.add_theme_constant_override("separation", 6)
	column.add_child(actions)
	_add_button(actions, "PlaceButton", "PLACE  [SPACE]", "place")
	_add_button(actions, "UndoButton", "UNDO  [U]", "undo")
	_add_button(actions, "NextButton", "NEXT MANIFEST  [N]", "next")
	_add_button(actions, "RestartButton", "RESTART  [R]", "restart")

	_message_label = _make_label("CargoMessage", 15, Color(0.88, 0.93, 0.98))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message_label)
	_result_label = _make_label("CampaignResult", 19, Color(0.48, 0.95, 0.74))
	column.add_child(_result_label)

	var legend := _make_label("Legend", 13, Color(0.58, 0.7, 0.8))
	legend.text = "C Crate   B Bar   L Elbow   P Power cell   S Sensor   H Solar panel   Support frame: 1.25–3.75"
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
	button.custom_minimum_size = Vector2(145, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: perform_action(action))
	parent.add_child(button)
	_buttons[action] = button

func _message_for_result(result: Dictionary) -> String:
	var reason: String = str(result.get("reason", ""))
	if not bool(result.get("accepted", false)):
		match reason:
			"invalid_placement":
				return "That footprint is outside the deck or overlaps another cargo piece."
			"undo_required":
				return "The deck is unstable. Undo the last cargo piece and rebalance the load."
			"level_not_stable":
				return "Complete a stable load before advancing to the next manifest."
			"nothing_to_undo":
				return "There is no placed cargo to remove."
			"no_current_cargo":
				return "Every cargo piece in this manifest has already been placed."
			_:
				return "Action rejected: " + reason
	match reason:
		"cargo_placed":
			return "Cargo secured. Continue packing the manifest."
		"unstable":
			return "UNSTABLE LOAD. Undo the last piece and move the center of mass inward."
		"stable":
			return "Load secured. The support frame can carry this manifest."
		"last_cargo_removed":
			return "Last cargo piece removed. Reposition it to rebalance the deck."
		"next_manifest":
			return "Next manifest loaded. New cargo, new balance."
		"campaign_complete":
			return "ALL MANIFESTS SECURED. KROLL cargo bay certified."
		"restarted":
			return "Campaign restarted. The deck is clear."
		_:
			return "Cargo bay state updated."

func _update_ui() -> void:
	var level_index: int = int(_state.get("level_index", 0))
	var level: Dictionary = Rules.level_at(level_index)
	var manifest: Array = level.get("manifest", [])
	var placements: Array = _state.get("placements", [])
	var cursor: Vector2i = _state.get("cursor", Vector2i.ZERO)
	var occupied: Dictionary = Rules.occupied_map(placements)
	var current_shape: String = Rules.current_shape_id(_state)
	var status: String = str(_state.get("status", "active"))
	var center: Vector2 = Rules.calculate_center_of_mass(placements)
	var center_text: String = "--" if placements.is_empty() else "%.2f, %.2f" % [center.x, center.y]

	_mission_label.text = "MANIFEST %d / %d     %s" % [level_index + 1, Rules.level_count(), str(level.get("name", "UNKNOWN"))]
	if current_shape.is_empty():
		_cargo_label.text = "MANIFEST COMPLETE     %d / %d CARGO PIECES" % [placements.size(), manifest.size()]
	else:
		var info: Dictionary = Rules.shape_info(current_shape)
		var cells: Array = info.get("cells", [])
		_cargo_label.text = "NEXT: %s     MASS %d     FOOTPRINT %d CELLS     ROTATION %d°" % [
			str(info.get("label", current_shape)), int(info.get("mass", 0)), cells.size(), int(_state.get("rotation", 0)) * 90
		]
	_stats_label.text = "PLACED %d / %d     TOTAL MASS %d     CENTER OF MASS %s     SCORE %d / 300" % [
		placements.size(), manifest.size(), Rules.total_mass(placements), center_text, int(_state.get("score", 0))
	]

	for index in range(_cell_buttons.size()):
		var position := Vector2i(index % Rules.BOARD_SIZE, floori(float(index) / float(Rules.BOARD_SIZE)))
		var button: Button = _cell_buttons[index]
		var shape_id: String = str(occupied.get(position, ""))
		var label_text: String = "·"
		var background_color: Color = Color(0.07, 0.13, 0.19)
		var font_color: Color = Color(0.72, 0.84, 0.92)
		if not shape_id.is_empty():
			var info: Dictionary = Rules.shape_info(shape_id)
			label_text = str(info.get("symbol", "?"))
			background_color = Color(0.12, 0.27, 0.34)
			font_color = Color(0.76, 0.94, 1.0)
		if position == cursor:
			label_text = "▶ " + label_text
			background_color = Color(0.27, 0.25, 0.12)
			font_color = Color(1.0, 0.88, 0.55)
		button.text = label_text
		button.disabled = status != "active"
		var style := StyleBoxFlat.new()
		style.bg_color = background_color
		style.set_border_width_all(1)
		style.border_color = Color(0.22, 0.34, 0.43)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override("normal", style)

	_buttons["move_up"].disabled = status != "active" or cursor.y <= 0
	_buttons["move_down"].disabled = status != "active" or cursor.y >= Rules.BOARD_SIZE - 1
	_buttons["move_left"].disabled = status != "active" or cursor.x <= 0
	_buttons["move_right"].disabled = status != "active" or cursor.x >= Rules.BOARD_SIZE - 1
	_buttons["rotate"].disabled = status != "active" or current_shape.is_empty()
	_buttons["place"].disabled = status != "active" or current_shape.is_empty()
	_buttons["undo"].disabled = placements.is_empty() or not ["active","unstable"].has(status)
	_buttons["next"].disabled = status != "won"
	_buttons["restart"].disabled = false

	if status == "campaign_won":
		_result_label.text = "CAMPAIGN COMPLETE  /  ALL THREE MANIFESTS SECURED"
	elif status == "won":
		_result_label.text = "LOAD STABLE  /  ADVANCE TO THE NEXT MANIFEST"
	elif status == "unstable":
		_result_label.text = "LOAD UNSTABLE  /  UNDO THE LAST PIECE"
	else:
		_result_label.text = "OBJECTIVE  /  PLACE EVERY PIECE INSIDE THE DECK AND KEEP THE CENTER OF MASS IN THE SUPPORT FRAME"
	_message_label.text = _message

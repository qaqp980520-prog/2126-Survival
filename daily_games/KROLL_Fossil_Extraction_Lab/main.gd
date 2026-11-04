extends Control

const Rules = preload("res://rules.gd")

var _state: Dictionary = {}
var _selected_tool: String = "brush"
var _message: String = "Scan a sediment square, then uncover every fossil fragment without damaging the specimen."
var _grid_buttons: Array[Button] = []
var _tool_buttons: Dictionary = {}
var _mission_label: Label
var _stats_label: Label
var _message_label: Label
var _next_button: Button

func _ready() -> void:
	_state = Rules.new_state()
	_build_ui()
	_refresh()

func get_game_state() -> Dictionary:
	return _state.duplicate(true)

func get_grid_button_count() -> int:
	return _grid_buttons.size()

func select_tool(tool: String) -> bool:
	if not _tool_buttons.has(tool):
		return false
	_selected_tool = tool
	_message = "Selected tool: %s." % tool.capitalize()
	_refresh()
	return true

func apply_tool_at(tool: String, cell: Vector2i) -> bool:
	var result: Dictionary = Rules.apply_tool(_state, tool, cell)
	if not bool(result.get("accepted", false)):
		_message = _message_for_reason(str(result.get("reason", "rejected")))
		_refresh()
		return false
	_state = result["state"]
	if tool == "scan":
		var scan: Dictionary = _state.get("last_scan", {})
		_message = "SCAN: %d fossil fragment(s) in this 3×3 sector." % int(scan.get("fossil_count", 0))
	else:
		_message = _message_for_reason(str(result.get("reason", "")))
	if str(_state.get("status", "")) == "complete":
		_message = "SPECIMEN SECURED. Integrity %d%% — mission score %d." % [int(_state["integrity"]), int(_state["mission_score"])]
	elif str(_state.get("status", "")) == "failed":
		_message = "EXCAVATION FAILED. Restart the site and use gentler tools."
	_refresh()
	return true

func restart_mission() -> void:
	_state = Rules.restart_mission(_state)
	_message = "SITE RESET. Campaign rewards already earned are preserved."
	_refresh()

func next_mission() -> bool:
	var result: Dictionary = Rules.next_mission(_state)
	if not bool(result.get("accepted", false)):
		_message = "Expose every fossil fragment before advancing."
		_refresh()
		return false
	_state = result["state"]
	_message = "CAMPAIGN COMPLETE. All specimens catalogued." if str(_state["status"]) == "campaign_complete" else "NEXT SITE READY. Check the sediment layers."
	_refresh()
	return true

func restart_campaign() -> void:
	_state = Rules.restart_campaign()
	_message = "NEW EXPEDITION STARTED."
	_refresh()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	var title := Label.new()
	title.text = "KROLL // FOSSIL EXTRACTION LAB"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(0.48, 0.86, 0.92))
	column.add_child(title)

	_mission_label = Label.new()
	_mission_label.name = "MissionLabel"
	_mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_mission_label)

	_stats_label = Label.new()
	_stats_label.name = "StatsLabel"
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.88))
	column.add_child(_stats_label)

	var grid_panel := PanelContainer.new()
	grid_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(grid_panel)

	var grid := GridContainer.new()
	grid.name = "ExcavationGrid"
	grid.columns = Rules.GRID_SIZE
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid_panel.add_child(grid)

	for y in range(Rules.GRID_SIZE):
		for x in range(Rules.GRID_SIZE):
			var cell := Vector2i(x, y)
			var button := Button.new()
			button.custom_minimum_size = Vector2(54.0, 44.0)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.pressed.connect(_on_cell_pressed.bind(cell))
			grid.add_child(button)
			_grid_buttons.append(button)

	var tool_row := HBoxContainer.new()
	tool_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_row.add_theme_constant_override("separation", 8)
	column.add_child(tool_row)
	_add_tool_button(tool_row, "brush", "1  BRUSH")
	_add_tool_button(tool_row, "air", "2  AIR SCRIBE")
	_add_tool_button(tool_row, "chisel", "3  MICRO CHISEL")
	_add_tool_button(tool_row, "scan", "4  SCANNER")

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	column.add_child(action_row)
	var restart_button := Button.new()
	restart_button.text = "RESTART SITE  (R)"
	restart_button.pressed.connect(restart_mission)
	action_row.add_child(restart_button)
	_next_button = Button.new()
	_next_button.text = "NEXT SITE  (N)"
	_next_button.pressed.connect(next_mission)
	action_row.add_child(_next_button)
	var campaign_button := Button.new()
	campaign_button.text = "NEW EXPEDITION  (C)"
	campaign_button.pressed.connect(restart_campaign)
	action_row.add_child(campaign_button)

	_message_label = Label.new()
	_message_label.name = "MessageLabel"
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.48))
	column.add_child(_message_label)

func _add_tool_button(parent: HBoxContainer, tool: String, caption: String) -> void:
	var button := Button.new()
	button.text = caption
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(142.0, 44.0)
	button.pressed.connect(select_tool.bind(tool))
	parent.add_child(button)
	_tool_buttons[tool] = button

func _on_cell_pressed(cell: Vector2i) -> void:
	apply_tool_at(_selected_tool, cell)

func _refresh() -> void:
	var mission: Dictionary = Rules.mission_at(int(_state.get("mission_index", 0)))
	_mission_label.text = "SITE %d / %d  —  %s" % [int(_state["mission_index"]) + 1, Rules.mission_count(), str(mission["name"])]
	_stats_label.text = "Actions %d/%d   |   Integrity %d%%   |   Fossils %d/%d   |   Air %d   Chisel %d   Scan %d   |   Campaign %d" % [
		int(_state["actions_left"]),
		Rules.STARTING_ACTIONS,
		int(_state["integrity"]),
		int(_state["exposed_count"]),
		_state["fossil_cells"].size(),
		int(_state["air_charges"]),
		int(_state["chisel_charges"]),
		int(_state["scan_charges"]),
		int(_state["campaign_score"])
	]
	_message_label.text = _message
	for tool in _tool_buttons.keys():
		var tool_button: Button = _tool_buttons[tool]
		tool_button.button_pressed = str(tool) == _selected_tool
		tool_button.disabled = str(_state["status"]) != "active"
	var grid: Array = _state["grid"]
	for index in range(_grid_buttons.size()):
		var cell := Vector2i(index % Rules.GRID_SIZE, int(index / Rules.GRID_SIZE))
		var data: Dictionary = grid[cell.y][cell.x]
		var depth: int = int(data["depth"])
		var exposed: bool = bool(data["exposed"])
		var button: Button = _grid_buttons[index]
		if exposed:
			button.text = "FOSSIL"
			button.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
		elif depth > 0:
			button.text = "SED %d" % depth
			button.add_theme_color_override("font_color", Color(0.78, 0.82, 0.84))
		else:
			button.text = "CLEAR"
			button.add_theme_color_override("font_color", Color(0.45, 0.85, 0.68))
		button.tooltip_text = "Cell %d,%d — sediment depth %d" % [cell.x, cell.y, depth]
		button.disabled = str(_state["status"]) != "active" or (depth <= 0 and _selected_tool != "scan")
	_next_button.disabled = str(_state["status"]) != "complete"

func _message_for_reason(reason: String) -> String:
	match reason:
		"brush_complete":
			return "BRUSH: one sediment layer removed safely."
		"air_complete":
			return "AIR SCRIBE: one layer cleared across a 3×3 sector."
		"chisel_complete":
			return "MICRO CHISEL: two layers removed. Fossil contact reduces specimen integrity."
		"scan_complete":
			return "SCAN COMPLETE."
		"outside_grid":
			return "TARGET OUTSIDE THE EXCAVATION GRID."
		"no_sediment":
			return "NO SEDIMENT REMAINS AT THAT TARGET."
		"no_air_charges":
			return "AIR SCRIBE CHARGE DEPLETED."
		"no_chisel_charges":
			return "MICRO CHISEL CHARGE DEPLETED."
		"no_scan_charges":
			return "SCANNER CHARGE DEPLETED."
		"mission_not_active":
			return "SITE IS NOT ACTIVE. Restart or advance the expedition."
		_:
			return "UNKNOWN TOOL OR ACTION."

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			select_tool("brush")
		KEY_2:
			select_tool("air")
		KEY_3:
			select_tool("chisel")
		KEY_4:
			select_tool("scan")
		KEY_R:
			restart_mission()
		KEY_N:
			next_mission()
		KEY_C:
			restart_campaign()

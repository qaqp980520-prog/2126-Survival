extends Control

const Rules = preload("res://rules.gd")
const COLORS: Dictionary = {
	"ION": Color(0.22, 0.72, 0.91), "FORK": Color(0.96, 0.66, 0.25),
	"HOOK": Color(0.72, 0.56, 0.93), "CORE": Color(0.30, 0.78, 0.56)
}
const MARKS: Dictionary = {"ION":"I","FORK":"F","HOOK":"H","CORE":"C"}
const PREVIEWS: Dictionary = {"ION":"####","FORK":"###/.#.","HOOK":"#./#./##","CORE":"##/##"}

var level_index := 0
var placements: Dictionary = {}
var placement_order: Array[String] = []
var rotations: Dictionary = {"ION":0,"FORK":0,"HOOK":0,"CORE":0}
var selected_piece := "ION"
var anchor_cell := Vector2i.ZERO
var campaign_complete := false
var board_buttons: Array[Button] = []
var piece_buttons: Dictionary = {}
var level_label: Label
var status_label: Label
var selected_label: Label
var undo_button: Button
var next_button: Button
var left_button: Button
var right_button: Button

func _ready() -> void:
	_build_ui()
	_load_level(0)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.018, 0.032, 0.055)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = "KROLL // CARGO MOSAIC"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.42, 0.91, 1.0))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "FREIGHT BAY GEOMETRY · FILL EVERY SIGNALLED CELL"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	column.add_child(subtitle)
	level_label = Label.new()
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 18)
	column.add_child(level_label)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	var board_panel := PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(board_panel)
	var board_margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		board_margin.add_theme_constant_override("margin_" + side, 10)
	board_panel.add_child(board_margin)
	var grid := GridContainer.new()
	grid.columns = Rules.BOARD_WIDTH
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	board_margin.add_child(grid)
	for y in range(Rules.BOARD_HEIGHT):
		for x in range(Rules.BOARD_WIDTH):
			var cell := Vector2i(x, y)
			var button := Button.new()
			button.name = "Cell_%d_%d" % [x, y]
			button.custom_minimum_size = Vector2(55, 55)
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override("font_size", 20)
			button.pressed.connect(_on_cell_pressed.bind(cell))
			grid.add_child(button)
			board_buttons.append(button)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(290, 0)
	side.add_theme_constant_override("separation", 8)
	content.add_child(side)
	var heading := Label.new()
	heading.text = "CARGO MODULES"
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color(0.58, 0.88, 1.0))
	side.add_child(heading)
	for piece_id in Rules.get_piece_ids():
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 42)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_piece.bind(piece_id))
		side.add_child(button)
		piece_buttons[piece_id] = button
	selected_label = Label.new()
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(selected_label)
	left_button = _add_action(side, "ROTATE LEFT  Q", _rotate_left)
	right_button = _add_action(side, "ROTATE RIGHT  E", _rotate_right)
	undo_button = _add_action(side, "UNDO  BACKSPACE", _undo_last)
	_add_action(side, "RESET BAY  R", reset_level)
	next_button = _add_action(side, "NEXT BAY  N", advance_level)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 62)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.48, 0.92, 0.72))
	side.add_child(status_label)
	var guide := Label.new()
	guide.text = "1–4 SELECT · ARROWS MOVE · Q/E ROTATE · ENTER PLACE\nTAP A SIGNALLED CELL TO PLACE; TAP A MODULE TO LIFT IT."
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size", 11)
	guide.add_theme_color_override("font_color", Color(0.62, 0.73, 0.82))
	side.add_child(guide)

func _add_action(parent: VBoxContainer, text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _load_level(index: int) -> void:
	level_index = clampi(index, 0, Rules.get_level_count() - 1)
	placements.clear()
	placement_order.clear()
	rotations = {"ION":0,"FORK":0,"HOOK":0,"CORE":0}
	selected_piece = "ION"
	anchor_cell = Vector2i.ZERO
	campaign_complete = false
	status_label.text = "Place four modules. Every illuminated cell must be covered exactly once."
	_refresh_ui()

func _select_piece(piece_id: String) -> void:
	if campaign_complete or not Rules.get_piece_ids().has(piece_id):
		return
	if placements.has(piece_id):
		placements = Rules.remove_piece(placements, piece_id)
		placement_order.erase(piece_id)
		status_label.text = "%s lifted back to the tray." % Rules.get_piece_name(piece_id)
	selected_piece = piece_id
	_refresh_ui()

func _on_cell_pressed(cell: Vector2i) -> void:
	if campaign_complete:
		return
	var occupant := _piece_at_cell(cell)
	if not occupant.is_empty():
		_select_piece(occupant)
		return
	anchor_cell = cell
	if selected_piece.is_empty():
		status_label.text = "Select a cargo module first."
		_refresh_ui()
	else:
		try_place_piece(selected_piece, cell, int(rotations.get(selected_piece, 0)))

func try_place_piece(piece_id: String, origin: Vector2i, rotation: int) -> bool:
	if campaign_complete or Rules.is_solved(level_index, placements):
		return false
	var result: Dictionary = Rules.place_piece(level_index, placements, piece_id, origin, rotation)
	if not bool(result.get("ok", false)):
		status_label.text = "Placement rejected: %s." % str(result.get("reason", "invalid"))
		_refresh_ui()
		return false
	placements = result["placements"]
	if not placement_order.has(piece_id):
		placement_order.append(piece_id)
	rotations[piece_id] = posmod(rotation, 4)
	selected_piece = _find_next_unplaced()
	if Rules.is_solved(level_index, placements):
		status_label.text = "BAY SEALED · ALL SIGNALLED CELLS COVERED."
	else:
		status_label.text = "%s secured · %d / 4 modules placed." % [Rules.get_piece_name(piece_id), placements.size()]
	_refresh_ui()
	return true

func _piece_at_cell(cell: Vector2i) -> String:
	for piece_id in placements:
		if Rules.get_placement_cells(str(piece_id), placements[piece_id]).has(cell):
			return str(piece_id)
	return ""

func _find_next_unplaced() -> String:
	for piece_id in Rules.get_piece_ids():
		if not placements.has(piece_id):
			return piece_id
	return ""

func _rotate_left() -> void:
	_rotate_selected(-1)

func _rotate_right() -> void:
	_rotate_selected(1)

func _rotate_selected(amount: int) -> void:
	if selected_piece.is_empty() or placements.has(selected_piece) or campaign_complete:
		return
	rotations[selected_piece] = posmod(int(rotations.get(selected_piece, 0)) + amount, 4)
	_refresh_ui()

func _move_anchor(delta: Vector2i) -> void:
	anchor_cell.x = clampi(anchor_cell.x + delta.x, 0, Rules.BOARD_WIDTH - 1)
	anchor_cell.y = clampi(anchor_cell.y + delta.y, 0, Rules.BOARD_HEIGHT - 1)
	_refresh_ui()

func _place_selected() -> void:
	if not selected_piece.is_empty():
		try_place_piece(selected_piece, anchor_cell, int(rotations.get(selected_piece, 0)))

func _undo_last() -> void:
	if placement_order.is_empty() or campaign_complete:
		return
	var piece_id: String = placement_order.pop_back()
	placements = Rules.remove_piece(placements, piece_id)
	selected_piece = piece_id
	status_label.text = "%s returned to the tray." % Rules.get_piece_name(piece_id)
	_refresh_ui()

func reset_level() -> void:
	if not campaign_complete:
		_load_level(level_index)

func advance_level() -> bool:
	if not Rules.is_solved(level_index, placements):
		return false
	if level_index + 1 >= Rules.get_level_count():
		campaign_complete = true
		status_label.text = "CAMPAIGN COMPLETE · ALL THREE BAYS SEALED."
		_refresh_ui()
		return true
	_load_level(level_index + 1)
	return true

func _refresh_ui() -> void:
	if status_label == null:
		return
	var level: Dictionary = Rules.get_level_data(level_index)
	var targets: Array[Vector2i] = level.get("target_cells", [])
	level_label.text = "BAY %02d / %02d · %s" % [level_index + 1, Rules.get_level_count(), level.get("name", "")]
	for index in range(board_buttons.size()):
		var cell := Vector2i(index % Rules.BOARD_WIDTH, index / Rules.BOARD_WIDTH)
		var button: Button = board_buttons[index]
		var occupant := _piece_at_cell(cell)
		if not targets.has(cell):
			button.text = "×"
			button.disabled = true
			_style_button(button, Color(0.035, 0.055, 0.075), Color(0.09, 0.13, 0.17))
		elif not occupant.is_empty():
			button.text = str(MARKS[occupant])
			button.disabled = false
			_style_button(button, COLORS[occupant], Color(0.82, 0.94, 1.0))
		else:
			button.text = "◎" if cell == anchor_cell and not selected_piece.is_empty() else "·"
			button.disabled = false
			_style_button(button, Color(0.10, 0.18, 0.25) if cell == anchor_cell else Color(0.075, 0.12, 0.17), Color(0.24, 0.46, 0.58))
	for piece_id in Rules.get_piece_ids():
		var button: Button = piece_buttons[piece_id]
		var placed: bool = placements.has(piece_id)
		button.text = "%s  %s  %s%s" % [MARKS[piece_id], Rules.get_piece_name(piece_id), PREVIEWS[piece_id], " ✓" if placed else (" ◀" if selected_piece == piece_id else "")]
		button.add_theme_color_override("font_color", Color(0.04, 0.07, 0.09) if placed else Color(0.84, 0.93, 1.0))
		_style_button(button, COLORS[piece_id] if placed else Color(0.08, 0.15, 0.21), COLORS[piece_id])
	selected_label.text = "SELECTED: %s · ROTATION %d° · ANCHOR %d,%d" % [
		"NONE" if selected_piece.is_empty() else Rules.get_piece_name(selected_piece),
		int(rotations.get(selected_piece, 0)) * 90, anchor_cell.x, anchor_cell.y
	]
	undo_button.disabled = placement_order.is_empty() or campaign_complete
	next_button.disabled = not Rules.is_solved(level_index, placements)
	left_button.disabled = selected_piece.is_empty() or campaign_complete or placements.has(selected_piece)
	right_button.disabled = left_button.disabled

func _style_button(button: Button, fill: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _select_piece("ION")
		KEY_2: _select_piece("FORK")
		KEY_3: _select_piece("HOOK")
		KEY_4: _select_piece("CORE")
		KEY_Q: _rotate_left()
		KEY_E: _rotate_right()
		KEY_LEFT: _move_anchor(Vector2i(-1, 0))
		KEY_RIGHT: _move_anchor(Vector2i(1, 0))
		KEY_UP: _move_anchor(Vector2i(0, -1))
		KEY_DOWN: _move_anchor(Vector2i(0, 1))
		KEY_ENTER, KEY_KP_ENTER: _place_selected()
		KEY_BACKSPACE: _undo_last()
		KEY_R: reset_level()
		KEY_N: advance_level()
	get_viewport().set_input_as_handled()

func get_current_state() -> Dictionary:
	var level: Dictionary = Rules.get_level_data(level_index)
	return {"level_index":level_index,"level_id":level.get("id",""),"placed_count":placements.size(),
		"solved":Rules.is_solved(level_index, placements),"campaign_complete":campaign_complete}

func get_title_text() -> String:
	return "KROLL // CARGO MOSAIC"

func get_piece_preview_text(piece_id: String) -> String:
	return str(PREVIEWS.get(piece_id, ""))

func get_board_button_count() -> int:
	return board_buttons.size()

func get_piece_button_count() -> int:
	return piece_buttons.size()

func get_target_cell_count() -> int:
	return Rules.get_level_data(level_index).get("target_cells", []).size()

extends Control

const ROOT_RULES_PATH: String = "res://daily_games/KROLL_Raster_Survey/rules.gd"
const LOCAL_RULES_PATH: String = "res://rules.gd"
const GRID_SIZE: int = 6

var _rules: RefCounted
var _state: Dictionary = {}
var _selected := Vector2i.ZERO
var _row_clue_labels: Array = []
var _column_clue_labels: Array = []
var _cell_buttons: Array = []
var _site_label: Label
var _status_label: Label
var _progress_label: Label
var _selection_label: Label
var _next_button: Button

func _ready() -> void:
	var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else LOCAL_RULES_PATH
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("KROLL Raster Survey could not load its rules module.")
		return
	_rules = rules_script.new() as RefCounted
	_state = _rules.call("make_state", 0)
	_build_ui()
	_refresh_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#07141d")
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = "KROLL // RASTER SURVEY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#72e4f3"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "RECONSTRUCT THE SCAN GRID FROM ROW AND COLUMN CLUES"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("#b5cbd3"))
	column.add_child(subtitle)
	_site_label = Label.new()
	_site_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_site_label.add_theme_font_size_override("font_size", 22)
	_site_label.add_theme_color_override("font_color", Color("#f1d59b"))
	column.add_child(_site_label)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color("#a7e8d2"))
	column.add_child(_status_label)
	var board_row := HBoxContainer.new()
	board_row.alignment = BoxContainer.ALIGNMENT_CENTER
	board_row.add_theme_constant_override("separation", 8)
	board_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(board_row)
	var row_column := VBoxContainer.new()
	row_column.add_theme_constant_override("separation", 4)
	board_row.add_child(row_column)
	var row_header := Label.new()
	row_header.text = "ROW"
	row_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row_header.custom_minimum_size = Vector2(76.0, 34.0)
	row_column.add_child(row_header)
	for _y in range(GRID_SIZE):
		var clue := Label.new()
		clue.custom_minimum_size = Vector2(76.0, 54.0)
		clue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		clue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clue.add_theme_color_override("font_color", Color("#d7e7ed"))
		clue.add_theme_font_size_override("font_size", 17)
		row_column.add_child(clue)
		_row_clue_labels.append(clue)
	var grid_column := VBoxContainer.new()
	grid_column.add_theme_constant_override("separation", 4)
	board_row.add_child(grid_column)
	var top_clues := HBoxContainer.new()
	top_clues.add_theme_constant_override("separation", 4)
	grid_column.add_child(top_clues)
	for _x in range(GRID_SIZE):
		var clue := Label.new()
		clue.custom_minimum_size = Vector2(58.0, 52.0)
		clue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clue.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		clue.add_theme_color_override("font_color", Color("#d7e7ed"))
		clue.add_theme_font_size_override("font_size", 16)
		top_clues.add_child(clue)
		_column_clue_labels.append(clue)
	var cells := GridContainer.new()
	cells.columns = GRID_SIZE
	cells.add_theme_constant_override("h_separation", 4)
	cells.add_theme_constant_override("v_separation", 4)
	grid_column.add_child(cells)
	for y in range(GRID_SIZE):
		var row: Array = []
		for x in range(GRID_SIZE):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(58.0, 54.0)
			cell.focus_mode = Control.FOCUS_NONE
			cell.add_theme_font_size_override("font_size", 24)
			cell.pressed.connect(_on_cell_pressed.bind(x, y))
			cell.gui_input.connect(_on_cell_gui_input.bind(x, y))
			cells.add_child(cell)
			row.append(cell)
		_cell_buttons.append(row)
	var instructions := Label.new()
	instructions.text = "LEFT CLICK / TAP: fill   RIGHT CLICK: mark empty\nKeyboard: arrows select · Space fill · X empty · Backspace clear"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.custom_minimum_size = Vector2(190.0, 0.0)
	instructions.add_theme_color_override("font_color", Color("#8faeb9"))
	board_row.add_child(instructions)
	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_color_override("font_color", Color("#d2e7ed"))
	column.add_child(_progress_label)
	_selection_label = Label.new()
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_label.add_theme_color_override("font_color", Color("#f1d59b"))
	column.add_child(_selection_label)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	column.add_child(controls)
	_add_control_button(controls, "FILL", _fill_selected)
	_add_control_button(controls, "EMPTY", _empty_selected)
	_add_control_button(controls, "CLEAR", _clear_selected)
	_add_control_button(controls, "RESET", _reset_site)
	_next_button = Button.new()
	_next_button.text = "NEXT SITE"
	_next_button.custom_minimum_size = Vector2(140.0, 48.0)
	_next_button.pressed.connect(_advance_site)
	controls.add_child(_next_button)

func _add_control_button(parent: HBoxContainer, label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(104.0, 48.0)
	button.pressed.connect(callback)
	parent.add_child(button)

func _on_cell_pressed(x: int, y: int) -> void:
	_selected = Vector2i(x, y)
	var board: Array = _state.get("board", [])
	var current: int = int(board[y][x])
	apply_mark(x, y, 0 if current == 1 else 1)

func _on_cell_gui_input(event: InputEvent, x: int, y: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_selected = Vector2i(x, y)
			apply_mark(x, y, 2)
			accept_event()

func _fill_selected() -> void:
	apply_mark(_selected.x, _selected.y, 1)

func _empty_selected() -> void:
	apply_mark(_selected.x, _selected.y, 2)

func _clear_selected() -> void:
	apply_mark(_selected.x, _selected.y, 0)

func _reset_site() -> void:
	_state = _rules.call("reset_state", _state)
	_selected = Vector2i.ZERO
	_refresh_ui()

func _advance_site() -> void:
	advance_to_next_puzzle()

func apply_mark(x: int, y: int, mark: int) -> bool:
	if _rules == null:
		return false
	var result: Dictionary = _rules.call("mark_cell", _state, x, y, mark)
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_selected = Vector2i(x, y)
	_refresh_ui()
	return true

func advance_to_next_puzzle() -> bool:
	if _rules == null:
		return false
	var result: Dictionary = _rules.call("advance_state", _state)
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_selected = Vector2i.ZERO
	_refresh_ui()
	return true

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func get_current_puzzle() -> Dictionary:
	return _rules.call("get_puzzle", int(_state.get("puzzle_index", -1))) if _rules != null else {}

func get_cell_button_count() -> int:
	return GRID_SIZE * GRID_SIZE if _cell_buttons.size() == GRID_SIZE else 0

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_LEFT: _selected.x = maxi(0, _selected.x - 1)
		KEY_RIGHT: _selected.x = mini(GRID_SIZE - 1, _selected.x + 1)
		KEY_UP: _selected.y = maxi(0, _selected.y - 1)
		KEY_DOWN: _selected.y = mini(GRID_SIZE - 1, _selected.y + 1)
		KEY_SPACE: _fill_selected()
		KEY_X: _empty_selected()
		KEY_BACKSPACE, KEY_DELETE: _clear_selected()
		KEY_R: _reset_site()
		KEY_N: _advance_site()
	_refresh_ui()

func _format_clues(clues: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for value in clues:
		parts.append(str(value))
	return "\n".join(parts)

func _refresh_ui() -> void:
	if _rules == null or _state.is_empty():
		return
	var puzzle: Dictionary = get_current_puzzle()
	if puzzle.is_empty():
		return
	_site_label.text = "%s  //  %s" % [str(puzzle.get("name", "Survey")), str(puzzle.get("id", "")).to_upper()]
	var rows: Array = _rules.call("get_row_clues", puzzle)
	var columns: Array = _rules.call("get_column_clues", puzzle)
	for y in range(GRID_SIZE):
		_row_clue_labels[y].text = _format_clues(rows[y])
	for x in range(GRID_SIZE):
		_column_clue_labels[x].text = _format_clues(columns[x])
	var board: Array = _state.get("board", [])
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var mark: int = int(board[y][x])
			var button: Button = _cell_buttons[y][x]
			button.text = "■" if mark == 1 else ("×" if mark == 2 else "·")
			button.modulate = Color("#f1d59b") if _selected == Vector2i(x, y) else Color.WHITE
			button.add_theme_color_override("font_color", Color("#07141d") if mark == 1 else (Color("#f1a8a8") if mark == 2 else Color("#9eb9c4")))
			button.add_theme_color_override("font_hover_color", Color("#07141d"))
	var progress: Dictionary = _rules.call("get_progress", _state)
	_progress_label.text = "MARKED %d / %d     MOVES %d" % [int(progress["marked"]), int(progress["total"]), int(progress["moves"])]
	_selection_label.text = "SELECTED: COLUMN %d / ROW %d" % [_selected.x + 1, _selected.y + 1]
	var status: String = str(_state.get("status", "playing"))
	if status == "solved":
		_status_label.text = "SURVEY SOLVED — NEXT SITE UNLOCKED"
	elif status == "campaign_complete":
		_status_label.text = "ALL THREE SURVEY SITES COMPLETE"
	else:
		_status_label.text = str(puzzle.get("brief", "Mark every cell using the scan clues."))
	_next_button.disabled = status != "solved"
	_next_button.text = "CAMPAIGN COMPLETE" if status == "campaign_complete" else "NEXT SITE"

extends Control

const Rules = preload("res://rules.gd")

var game_state: Dictionary = {}
var _cell_buttons: Array[Button] = []
var _row_clue_labels: Array[Label] = []
var _col_clue_labels: Array[Label] = []
var _status_label: Label
var _selected_index: int = 12
var _seed_value: int = 20261028

func _ready() -> void:
	_build_ui()
	_start_game(_seed_value)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.018, 0.032, 0.064)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "KROLL // SIGNAL SLEUTH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	layout.add_child(title)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status_label)

	var clue_header := HBoxContainer.new()
	clue_header.add_theme_constant_override("separation", 4)
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(72, 64)
	clue_header.add_child(corner)
	for col in range(Rules.SIZE):
		var clue_label := Label.new()
		clue_label.custom_minimum_size = Vector2(48, 64)
		clue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clue_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		clue_label.add_theme_color_override("font_color", Color(0.34, 0.86, 1.0))
		_col_clue_labels.append(clue_label)
		clue_header.add_child(clue_label)
	layout.add_child(clue_header)

	for row in range(Rules.SIZE):
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 4)
		var row_clue := Label.new()
		row_clue.custom_minimum_size = Vector2(72, 48)
		row_clue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row_clue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_clue.add_theme_color_override("font_color", Color(0.34, 0.86, 1.0))
		_row_clue_labels.append(row_clue)
		row_box.add_child(row_clue)
		for col in range(Rules.SIZE):
			var index: int = row * Rules.SIZE + col
			var cell := Button.new()
			cell.focus_mode = Control.FOCUS_NONE
			cell.custom_minimum_size = Vector2(48, 48)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.tooltip_text = "Row %d, column %d" % [row + 1, col + 1]
			cell.pressed.connect(_on_cell_pressed.bind(index))
			_cell_buttons.append(cell)
			row_box.add_child(cell)
		layout.add_child(row_box)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	var restart := Button.new()
	restart.focus_mode = Control.FOCUS_NONE
	restart.text = "RESTART (R)"
	restart.pressed.connect(_restart_game)
	controls.add_child(restart)
	var next_grid := Button.new()
	next_grid.focus_mode = Control.FOCUS_NONE
	next_grid.text = "NEXT GRID (N)"
	next_grid.pressed.connect(_next_puzzle)
	controls.add_child(next_grid)
	layout.add_child(controls)

	var help := Label.new()
	help.text = "Click a cell to cycle: unknown → filled → empty mark. Arrows move; Space marks."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(help)

func _start_game(seed_value: int) -> void:
	_seed_value = seed_value
	game_state = Rules.create_game(_seed_value)
	_selected_index = 12
	_refresh_ui()

func _restart_game() -> void:
	_start_game(_seed_value)

func _next_puzzle() -> void:
	_start_game(_seed_value + 1)

func _on_cell_pressed(index: int) -> void:
	if index < 0 or index >= Rules.SIZE * Rules.SIZE:
		return
	if Rules.toggle_cell(game_state, int(index / Rules.SIZE), index % Rules.SIZE):
		_selected_index = index
		_refresh_ui()

func _move_cursor(row_delta: int, col_delta: int) -> void:
	var row: int = int(_selected_index / Rules.SIZE)
	var col: int = _selected_index % Rules.SIZE
	row = clampi(row + row_delta, 0, Rules.SIZE - 1)
	col = clampi(col + col_delta, 0, Rules.SIZE - 1)
	_selected_index = row * Rules.SIZE + col
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_R:
		_restart_game()
	elif key_event.keycode == KEY_N:
		_next_puzzle()
	elif key_event.keycode == KEY_LEFT:
		_move_cursor(0, -1)
	elif key_event.keycode == KEY_RIGHT:
		_move_cursor(0, 1)
	elif key_event.keycode == KEY_UP:
		_move_cursor(-1, 0)
	elif key_event.keycode == KEY_DOWN:
		_move_cursor(1, 0)
	elif key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER:
		_on_cell_pressed(_selected_index)

func _format_clues(clue_value: Variant, vertical: bool) -> String:
	if not (clue_value is Array):
		return ""
	var clue_list: Array = clue_value
	var parts: Array[String] = []
	for clue in clue_list:
		parts.append(str(clue))
	return "\n".join(parts) if vertical else " ".join(parts)

func _refresh_ui() -> void:
	if _status_label == null:
		return
	var row_clues: Array = game_state.get("row_clues", [])
	var col_clues: Array = game_state.get("col_clues", [])
	var marks: Array = game_state.get("marks", [])
	_status_label.text = "GRID %d  |  MOVES %d/%d  |  %s\n%s" % [
		int(game_state.get("puzzle_index", 0)) + 1,
		int(game_state.get("moves", 0)),
		Rules.MAX_MOVES,
		str(game_state.get("status", "playing")).to_upper(),
		str(game_state.get("message", ""))
	]
	for row in range(_row_clue_labels.size()):
		_row_clue_labels[row].text = _format_clues(row_clues[row], false)
	for col in range(_col_clue_labels.size()):
		_col_clue_labels[col].text = _format_clues(col_clues[col], true)
	for index in range(_cell_buttons.size()):
		var mark: int = int(marks[index])
		if mark == 1:
			_cell_buttons[index].text = "■"
		elif mark == 2:
			_cell_buttons[index].text = "×"
		else:
			_cell_buttons[index].text = "◇" if index == _selected_index else ""
		_cell_buttons[index].modulate = Color(0.35, 0.92, 1.0) if index == _selected_index else Color.WHITE
		_cell_buttons[index].disabled = str(game_state.get("status", "playing")) != "playing"

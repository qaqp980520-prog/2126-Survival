extends Control

var _rules: RefCounted
var _current_puzzle_index: int = 0
var _puzzle: Dictionary = {}
var _board: PackedStringArray = PackedStringArray()
var _selected_from: Vector2i = Vector2i(-1, -1)
var _cursor: Vector2i = Vector2i(4, 7)
var _status: String = "playing"
var _strikes: int = 0
var _score: int = 0
var _awarded: Array[bool] = []
var _message: String = "Find the unique rook move that delivers checkmate."
var _title_label: Label
var _subtitle_label: Label
var _status_label: Label
var _score_label: Label
var _board_buttons: Array[Button] = []
var _action_buttons: Array[Button] = []
var _reset_button: Button
var _next_button: Button
var _restart_button: Button

func _ready() -> void:
	var attached_script: Script = get_script() as Script
	if attached_script == null:
		push_error("Endgame Tactics main script is unavailable.")
		return
	var rules_path: String = attached_script.resource_path.get_base_dir().path_join("rules.gd")
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("Endgame Tactics could not load rules: " + rules_path)
		return
	_rules = rules_script.new() as RefCounted
	if _rules == null:
		push_error("Endgame Tactics rules could not be instantiated.")
		return
	_awarded.resize(_rules.get_puzzle_count())
	for index in range(_awarded.size()):
		_awarded[index] = false
	_build_ui()
	_load_puzzle(0)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.035, 0.065)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var compact_layout: bool = get_viewport_rect().size.x < 520.0
	var inset: int = 8 if compact_layout else 22
	margin.add_theme_constant_override("margin_left", inset)
	margin.add_theme_constant_override("margin_right", inset)
	margin.add_theme_constant_override("margin_top", inset)
	margin.add_theme_constant_override("margin_bottom", inset)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "TacticsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)

	_title_label = Label.new()
	_title_label.text = "KROLL // ENDGAME TACTICS"
	_title_label.add_theme_font_size_override("font_size", 26 if compact_layout else 32)
	_title_label.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))
	column.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_color_override("font_color", Color(0.84, 0.9, 0.98))
	column.add_child(_subtitle_label)

	var board_panel := PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(board_panel)
	var board_grid := GridContainer.new()
	board_grid.name = "ChessBoard"
	board_grid.columns = 8
	board_grid.add_theme_constant_override("h_separation", 2)
	board_grid.add_theme_constant_override("v_separation", 2)
	board_panel.add_child(board_grid)
	var square_size: float = 34.0 if compact_layout else 58.0
	for y in range(8):
		for x in range(8):
			var square := Button.new()
			square.custom_minimum_size = Vector2(square_size, square_size)
			square.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			square.size_flags_vertical = Control.SIZE_EXPAND_FILL
			square.add_theme_font_size_override("font_size", 12 if compact_layout else 17)
			square.pressed.connect(_on_square_pressed.bind(Vector2i(x, y)))
			_board_buttons.append(square)
			board_grid.add_child(square)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.54))
	column.add_child(_status_label)

	_score_label = Label.new()
	_score_label.add_theme_color_override("font_color", Color(0.63, 0.9, 1.0))
	column.add_child(_score_label)

	var action_row := GridContainer.new()
	action_row.columns = 2 if compact_layout else 3
	action_row.add_theme_constant_override("h_separation", 8)
	action_row.add_theme_constant_override("v_separation", 8)
	column.add_child(action_row)
	_reset_button = _add_action_button(action_row, "RESET POSITION", Callable(self, "reset_puzzle"))
	_next_button = _add_action_button(action_row, "NEXT PUZZLE", Callable(self, "advance_puzzle"))
	_restart_button = _add_action_button(action_row, "RESTART CAMPAIGN", Callable(self, "restart_campaign"))

func _add_action_button(parent: GridContainer, label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(145.0, 42.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	_action_buttons.append(button)
	parent.add_child(button)
	return button

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_LEFT: _cursor.x = maxi(0, _cursor.x - 1)
		KEY_RIGHT: _cursor.x = mini(7, _cursor.x + 1)
		KEY_UP: _cursor.y = maxi(0, _cursor.y - 1)
		KEY_DOWN: _cursor.y = mini(7, _cursor.y + 1)
		KEY_ENTER, KEY_KP_ENTER: _on_square_pressed(_cursor)
		KEY_ESCAPE:
			_selected_from = Vector2i(-1, -1)
			_refresh_ui()
		KEY_R: reset_puzzle()
		KEY_N: advance_puzzle()
		KEY_C: restart_campaign()
	if key_event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		_refresh_ui()

func _on_square_pressed(position: Vector2i) -> void:
	if _status != "playing" or not _inside(position):
		return
	_cursor = position
	if _selected_from.x < 0:
		if _board[_index(position)] == "WR":
			_selected_from = position
			_message = "Rook selected. Choose a legal straight-line destination."
			_refresh_ui()
		else:
			_message = "Select the white rook (WR) first."
			_refresh_ui()
		return
	if position == _selected_from:
		_selected_from = Vector2i(-1, -1)
		_message = "Rook selection cleared."
		_refresh_ui()
		return
	var previous_from: Vector2i = _selected_from
	if not attempt_move(previous_from, position) and _board[_index(position)] == "WR":
		_selected_from = position
		_message = "Rook selection changed."
		_refresh_ui()

func attempt_move(from: Vector2i, to: Vector2i) -> bool:
	if _status != "playing" or _rules == null:
		return false
	var report: Dictionary = _rules.evaluate_move(_board, from, to)
	if not bool(report.get("ok", false)):
		_message = "Illegal rook move. The rook moves in straight lines and cannot pass through pieces."
		_refresh_ui()
		return false
	_selected_from = Vector2i(-1, -1)
	if bool(report.get("mate", false)):
		_board = report["board"].duplicate()
		if not _awarded[_current_puzzle_index]:
			_awarded[_current_puzzle_index] = true
			_score += 100
		_status = "won" if _current_puzzle_index == _rules.get_puzzle_count() - 1 else "solved"
		_message = "CHECKMATE. Puzzle secured for 100 points."
	else:
		_strikes += 1
		if _strikes >= 3:
			_status = "failed"
			_message = "Three non-mating moves used. Reset this puzzle to try again."
		else:
			var fresh: Dictionary = _rules.get_puzzle(_current_puzzle_index)
			_board = fresh["board"].duplicate()
			_message = "That move is legal, but it is not mate. Position restored; %d attempt(s) remain." % (3 - _strikes)
	_refresh_ui()
	return true

func reset_puzzle() -> bool:
	if _status == "solved" or _status == "won":
		return false
	_load_puzzle(_current_puzzle_index)
	return true

func advance_puzzle() -> bool:
	if _status != "solved" or _current_puzzle_index >= _rules.get_puzzle_count() - 1:
		return false
	_load_puzzle(_current_puzzle_index + 1)
	return true

func restart_campaign() -> bool:
	_score = 0
	for index in range(_awarded.size()):
		_awarded[index] = false
	_load_puzzle(0)
	return true

func _load_puzzle(index: int) -> void:
	_current_puzzle_index = index
	_puzzle = _rules.get_puzzle(index)
	_board = _puzzle.get("board", PackedStringArray()).duplicate()
	_selected_from = Vector2i(-1, -1)
	_cursor = _puzzle.get("mate_from", Vector2i(4, 7))
	_strikes = 0
	_status = "playing"
	_message = "Find the unique rook move that delivers checkmate."
	_refresh_ui()

func _refresh_ui() -> void:
	if _rules == null:
		return
	if is_instance_valid(_subtitle_label):
		_subtitle_label.text = "PUZZLE %d / %d  ·  %s  ·  Find the unique rook mate-in-one." % [
			_current_puzzle_index + 1,
			_rules.get_puzzle_count(),
			str(_puzzle.get("name", ""))
		]
	if is_instance_valid(_status_label):
		_status_label.text = "%s\nState: %s  ·  Attempts remaining: %d" % [_message, _status.to_upper(), maxi(0, 3 - _strikes)]
	if is_instance_valid(_score_label):
		_score_label.text = "CAMPAIGN SCORE  %03d / 300" % _score
	for index in range(_board_buttons.size()):
		var position := Vector2i(index % 8, int(index / 8))
		var piece: String = _board[index]
		var button: Button = _board_buttons[index]
		button.text = piece if not piece.is_empty() else "·"
		button.disabled = _status != "playing"
		var light_square: bool = (position.x + position.y) % 2 == 0
		var shade: Color = Color(0.76, 0.82, 0.9) if light_square else Color(0.28, 0.39, 0.53)
		if position == _selected_from:
			shade = Color(0.48, 0.82, 0.55)
		elif position == _cursor:
			shade = Color(0.95, 0.72, 0.32)
		button.modulate = shade
	if is_instance_valid(_reset_button):
		_reset_button.disabled = _status == "solved" or _status == "won"
	if is_instance_valid(_next_button):
		_next_button.disabled = _status != "solved"
	if is_instance_valid(_restart_button):
		_restart_button.disabled = false

func get_title_text() -> String:
	return "KROLL // ENDGAME TACTICS"

func get_puzzle_count() -> int:
	return _rules.get_puzzle_count() if _rules != null else 0

func get_current_puzzle_index() -> int:
	return _current_puzzle_index

func get_score() -> int:
	return _score

func get_strikes() -> int:
	return _strikes

func get_status() -> String:
	return _status

func get_board_button_count() -> int:
	return _board_buttons.size()

func get_control_button_count() -> int:
	return _action_buttons.size()

func get_current_state() -> Dictionary:
	return {
		"puzzle_index": _current_puzzle_index,
		"puzzle_id": str(_puzzle.get("id", "")),
		"status": _status,
		"score": _score,
		"strikes": _strikes,
		"board": _board.duplicate(),
		"selected_from": _selected_from
	}

func _inside(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < 8 and position.y >= 0 and position.y < 8

func _index(position: Vector2i) -> int:
	return position.y * 8 + position.x

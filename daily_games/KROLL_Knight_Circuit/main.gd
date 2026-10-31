extends Control
const Rules = preload("res://daily_games/KROLL_Knight_Circuit/rules.gd")
const BOARD_ORIGIN := Vector2(230.0, 148.0)
const CELL_SIZE: float = 96.0
var _state: Dictionary = {}
var _selected := Vector2i.ZERO
var _hint := Vector2i(-1, -1)
var _message: String = ""
var _status_label: Label
var _progress_label: Label
func _ready() -> void:
	_state = Rules.new_game(0)
	_selected = _state["position"]
	_build_ui()
	_update_hud()
	queue_redraw()
func _build_ui() -> void:
	var title := Label.new()
	title.position = Vector2(24.0, 16.0)
	title.size = Vector2(680.0, 34.0)
	title.text = "KROLL KNIGHT CIRCUIT  //  THE 25-SQUARE TOUR"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#83e6ff"))
	add_child(title)
	_progress_label = Label.new()
	_progress_label.position = Vector2(24.0, 54.0)
	_progress_label.size = Vector2(680.0, 28.0)
	_progress_label.add_theme_font_size_override("font_size", 17)
	_progress_label.add_theme_color_override("font_color", Color("#e8f2f7"))
	add_child(_progress_label)
	_status_label = Label.new()
	_status_label.position = Vector2(24.0, 86.0)
	_status_label.size = Vector2(700.0, 34.0)
	_status_label.add_theme_color_override("font_color", Color("#a8c5d0"))
	add_child(_status_label)
	_add_action_button("UndoButton", "UNDO", Vector2(744.0, 170.0), _undo)
	_add_action_button("HintButton", "HINT", Vector2(744.0, 226.0), _show_hint)
	_add_action_button("ResetButton", "RESET", Vector2(744.0, 282.0), _reset)
	_add_action_button("NextButton", "NEXT", Vector2(744.0, 338.0), _next_level)
func _add_action_button(node_name: String, label_text: String, button_position: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = label_text
	button.position = button_position
	button.size = Vector2(150.0, 44.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	add_child(button)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_board_click(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_try_board_click(event.position)
func _try_board_click(local_position: Vector2) -> void:
	var local: Vector2 = local_position - BOARD_ORIGIN
	var cell := Vector2i(floori(local.x / CELL_SIZE), floori(local.y / CELL_SIZE))
	if not Rules.is_in_bounds(cell):
		return
	_attempt_move(cell)
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT:
			_selected.x = maxi(0, _selected.x - 1)
		KEY_RIGHT:
			_selected.x = mini(Rules.BOARD_SIZE - 1, _selected.x + 1)
		KEY_UP:
			_selected.y = maxi(0, _selected.y - 1)
		KEY_DOWN:
			_selected.y = mini(Rules.BOARD_SIZE - 1, _selected.y + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_attempt_move(_selected)
		KEY_U:
			_undo()
		KEY_H:
			_show_hint()
		KEY_R:
			_reset()
		KEY_N:
			_next_level()
		_:
			return
	queue_redraw()
func _attempt_move(target: Vector2i) -> void:
	var before_moves: int = int(_state.get("moves", 0))
	_state = Rules.move(_state, target)
	_hint = Vector2i(-1, -1)
	if int(_state.get("moves", 0)) == before_moves:
		_message = "Illegal move: the knight moves in an L and cannot revisit a square."
	else:
		_selected = target
		_message = "Circuit complete!" if str(_state.get("status", "")) == "complete" else "Valid jump recorded."
	_update_hud()
	queue_redraw()
func _undo() -> void:
	_state = Rules.undo(_state)
	_selected = _state["position"]
	_hint = Vector2i(-1, -1)
	_message = "Last jump undone."
	_update_hud()
	queue_redraw()
func _show_hint() -> void:
	_hint = Rules.solution_next_move(_state)
	_message = "Suggested square highlighted." if Rules.is_in_bounds(_hint) else "Your route differs from the built-in tour; reset to use a route hint."
	_update_hud()
	queue_redraw()
func _reset() -> void:
	_state = Rules.reset(_state)
	_selected = _state["position"]
	_hint = Vector2i(-1, -1)
	_message = "Circuit reset."
	_update_hud()
	queue_redraw()
func _next_level() -> void:
	var next_state: Dictionary = Rules.next_level(_state)
	if int(next_state.get("level_index", 0)) == int(_state.get("level_index", 0)):
		_message = "Visit all 25 squares before advancing."
	else:
		_state = next_state
		_selected = _state["position"]
		_hint = Vector2i(-1, -1)
		_message = "New circuit loaded."
	_update_hud()
	queue_redraw()
func get_current_state() -> Dictionary:
	return _state.duplicate(true)
func get_hint_target() -> Vector2i:
	return _hint
func _update_hud() -> void:
	if _progress_label == null or _status_label == null:
		return
	var level: Dictionary = Rules.get_level(int(_state.get("level_index", 0)))
	var visited: Array = _state.get("visited", [])
	_progress_label.text = "%s   VISITED %02d/%02d   MOVES %02d" % [str(level.get("name", "CIRCUIT")), visited.size(), Rules.CELL_COUNT, int(_state.get("moves", 0))]
	if str(_state.get("status", "")) == "complete":
		_status_label.text = "ALL SQUARES VISITED  //  Press NEXT for another circuit."
	else:
		_status_label.text = _message if not _message.is_empty() else "CLICK / TOUCH A SQUARE  •  ARROWS + ENTER  •  U UNDO  •  H HINT  •  R RESET"
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960.0, 720.0)), Color("#08131d"), true)
	var visited: Array = _state.get("visited", [])
	var visited_order: Dictionary = {}
	for index in range(visited.size()):
		visited_order[visited[index]] = index + 1
	var legal_moves: Array[Vector2i] = []
	for x in range(Rules.BOARD_SIZE):
		for y in range(Rules.BOARD_SIZE):
			var cell := Vector2i(x, y)
			var rect := Rect2(BOARD_ORIGIN + Vector2(x, y) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
			var shade: Color = Color("#223b4a") if (x + y) % 2 == 0 else Color("#172b38")
			if visited_order.has(cell):
				shade = Color("#1d6a70") if cell != _state["position"] else Color("#b78335")
			draw_rect(rect, shade, true)
			draw_rect(rect, Color("#7898a6"), false, 1.5)
			if visited_order.has(cell):
				var font: Font = get_theme_default_font()
				if font != null:
					draw_string(font, rect.position + Vector2(8.0, 21.0), "%02d" % int(visited_order[cell]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("#f3f7fa"))
			if Rules.can_move(_state, cell):
				legal_moves.append(cell)
				draw_circle(rect.get_center(), 8.0, Color("#8be0a8"))
			if cell == _hint:
				draw_arc(rect.get_center(), 30.0, 0.0, TAU, 36, Color("#ffd66b"), 4.0, true)
			if cell == _selected:
				draw_rect(rect.grow(-5.0), Color("#ffffff"), false, 3.0)
	var current_rect := Rect2(BOARD_ORIGIN + Vector2(_state["position"]) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
	draw_circle(current_rect.get_center(), 24.0, Color("#f5d06c"))
	var font: Font = get_theme_default_font()
	if font != null:
		draw_string(font, current_rect.get_center() + Vector2(-7.0, 7.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color("#10212a"))
	for index in range(Rules.BOARD_SIZE):
		if font != null:
			draw_string(font, BOARD_ORIGIN + Vector2(index * CELL_SIZE + 42.0, -10.0), char(65 + index), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("#c5d9e0"))
			draw_string(font, BOARD_ORIGIN + Vector2(-18.0, index * CELL_SIZE + 54.0), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("#c5d9e0"))

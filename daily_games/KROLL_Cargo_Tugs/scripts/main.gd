extends Control

const Rules = preload("res://scripts/rules.gd")
const CELL_SIZE: float = 52.0

var level_index: int = 0
var rows: Array[String] = []
var player_pos: Vector2i = Vector2i.ZERO
var crates: Array[Vector2i] = []
var goals: Array[Vector2i] = []
var history: Array[Dictionary] = []
var state: String = "playing"
var feedback_text: String = "Move cargo onto every docking pad."

func _ready() -> void:
	load_level(0)

func load_level(index: int) -> void:
	level_index = clampi(index, 0, Rules.LEVEL_COUNT - 1)
	var level_data: Dictionary = Rules.make_level(level_index)
	rows.clear()
	for row in level_data["rows"]:
		rows.append(str(row))
	player_pos = level_data["player"]
	crates.clear()
	for crate in level_data["crates"]:
		var crate_position: Vector2i = crate
		crates.append(crate_position)
	goals.clear()
	for goal in level_data["goals"]:
		var goal_position: Vector2i = goal
		goals.append(goal_position)
	history.clear()
	state = "playing"
	feedback_text = "Push each cargo crate onto a matching pad."
	queue_redraw()

func attempt_move(direction: Vector2i) -> bool:
	if state != "playing":
		return false
	var result: Dictionary = Rules.attempt_move(rows, player_pos, crates, direction)
	if not bool(result.get("moved", false)):
		return false
	history.append({"player": player_pos, "crates": crates.duplicate()})
	var moved_player: Vector2i = result["player"]
	player_pos = moved_player
	var moved_crates: Array[Vector2i] = result["crates"]
	crates = moved_crates
	if Rules.is_solved(crates, goals):
		state = "complete" if level_index == Rules.LEVEL_COUNT - 1 else "won"
		feedback_text = "All cargo docked. Press N for next shift." if state == "won" else "All three shifts complete. Press R to replay."
	else:
		feedback_text = "Cargo moved. Z undoes the last move."
	queue_redraw()
	return true

func undo_move() -> bool:
	if history.is_empty():
		return false
	var previous: Dictionary = history.pop_back()
	var previous_player: Vector2i = previous["player"]
	player_pos = previous_player
	var previous_crates: Array[Vector2i] = previous["crates"]
	crates = previous_crates.duplicate()
	state = "playing"
	feedback_text = "Move undone."
	queue_redraw()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_UP, KEY_W:
				attempt_move(Vector2i(0, -1))
			KEY_DOWN, KEY_S:
				attempt_move(Vector2i(0, 1))
			KEY_LEFT, KEY_A:
				attempt_move(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D:
				attempt_move(Vector2i(1, 0))
			KEY_Z:
				undo_move()
			KEY_R:
				load_level(level_index)
			KEY_N:
				if state == "won":
					load_level(level_index + 1)
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_handle_pointer(mouse_event.position)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_handle_pointer(touch_event.position)

func _handle_pointer(position: Vector2) -> void:
	var direction: Vector2i = _direction_at(position)
	if direction != Vector2i.ZERO:
		attempt_move(direction)
		return
	var cell: Vector2i = _cell_at(position)
	if cell.x < 0:
		return
	var delta: Vector2i = cell - player_pos
	if (delta.x == 0 and absi(delta.y) == 1) or (delta.y == 0 and absi(delta.x) == 1):
		attempt_move(delta)

func _board_origin() -> Vector2:
	return Vector2((size.x - Rules.BOARD_SIZE * CELL_SIZE) / 2.0, 112.0)

func _cell_at(position: Vector2) -> Vector2i:
	var local: Vector2 = position - _board_origin()
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	var cell := Vector2i(floori(local.x / CELL_SIZE), floori(local.y / CELL_SIZE))
	if cell.x < 0 or cell.x >= Rules.BOARD_SIZE or cell.y < 0 or cell.y >= Rules.BOARD_SIZE:
		return Vector2i(-1, -1)
	return cell

func _button_rect(name: String) -> Rect2:
	var center := Vector2(size.x / 2.0, 628.0)
	match name:
		"up":
			center = Vector2(size.x / 2.0, 570.0)
		"left":
			center.x -= 56.0
		"right":
			center.x += 56.0
	return Rect2(center - Vector2(23.0, 23.0), Vector2(46.0, 46.0))

func _direction_at(position: Vector2) -> Vector2i:
	if _button_rect("up").has_point(position):
		return Vector2i(0, -1)
	if _button_rect("down").has_point(position):
		return Vector2i(0, 1)
	if _button_rect("left").has_point(position):
		return Vector2i(-1, 0)
	if _button_rect("right").has_point(position):
		return Vector2i(1, 0)
	return Vector2i.ZERO

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.028, 0.055), true)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(24.0, 38.0), "KROLL // CARGO TUGS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 27, Color(0.43, 0.94, 1.0))
	draw_string(font, Vector2(24.0, 70.0), "SHIFT %d / %d   CARGO %d   MOVES %d" % [level_index + 1, Rules.LEVEL_COUNT, crates.size(), history.size()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(0.75, 0.9, 1.0))
	draw_string(font, Vector2(24.0, 98.0), feedback_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 48.0, 15, Color(0.45, 0.92, 0.7))
	var origin := _board_origin()
	for y in range(Rules.BOARD_SIZE):
		for x in range(Rules.BOARD_SIZE):
			var cell := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(x * CELL_SIZE, y * CELL_SIZE), Vector2(CELL_SIZE - 2.0, CELL_SIZE - 2.0))
			var wall: bool = Rules.tile_at(rows, cell) == "#"
			draw_rect(rect, Color(0.055, 0.09, 0.14) if wall else Color(0.075, 0.13, 0.18), true)
			if goals.has(cell):
				draw_circle(rect.get_center(), 8.0, Color(0.35, 0.95, 0.65))
			if crates.has(cell):
				draw_rect(rect.grow(-8.0), Color(0.95, 0.62, 0.22), true)
				draw_string(font, rect.get_center() + Vector2(-5.0, 6.0), "C", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.08, 0.1, 0.12))
			if player_pos == cell:
				draw_circle(rect.get_center(), 13.0, Color(0.24, 0.82, 1.0))
				draw_string(font, rect.get_center() + Vector2(-5.0, 6.0), "P", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.01, 0.05, 0.08))
	_draw_button("up", "↑", font)
	_draw_button("left", "←", font)
	_draw_button("down", "↓", font)
	_draw_button("right", "→", font)
	draw_string(font, Vector2(24.0, size.y - 18.0), "WASD / arrows move   Z undo   R reset   N next solved shift", HORIZONTAL_ALIGNMENT_LEFT, size.x - 48.0, 14, Color(0.6, 0.72, 0.82))

func _draw_button(name: String, label: String, font: Font) -> void:
	var rect := _button_rect(name)
	draw_rect(rect, Color(0.08, 0.18, 0.25), true)
	draw_rect(rect, Color(0.28, 0.75, 0.9), false, 2.0)
	draw_string(font, rect.position + Vector2(0.0, 31.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 25, Color(0.75, 0.96, 1.0))

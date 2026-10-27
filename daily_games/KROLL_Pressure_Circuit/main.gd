extends Node2D

const Rules = preload("res://rules.gd")
const CELL_SIZE: float = 74.0
const ORIGIN := Vector2(290.0, 142.0)

var state: Dictionary = {}
var selected_cell := Vector2i(0, 2)
var banner: String = "Rotate pipe tiles to connect IN to OUT."

func _ready() -> void:
	_reset_game()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1024.0, 720.0)), Color("#06111d"))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(48.0, 52.0), "KROLL // PRESSURE CIRCUIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#5cf3ff"))
	draw_string(font, Vector2(50.0, 82.0), "ROTATE THE CONDUITS BEFORE PRESSURE RUNS OUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#8aaebb"))

	if state.is_empty():
		return

	var masks: Array = state.get("masks", [])
	var source: Vector2i = state.get("source", Vector2i.ZERO)
	var target: Vector2i = state.get("target", Vector2i.ZERO)
	var reachability: Dictionary = Rules._reachable_cells(state)
	for y in range(Rules.ROWS):
		for x in range(Rules.COLS):
			var cell := Vector2i(x, y)
			var rect := Rect2(ORIGIN + Vector2(float(x) * CELL_SIZE, float(y) * CELL_SIZE), Vector2(CELL_SIZE - 3.0, CELL_SIZE - 3.0))
			draw_rect(rect, Color("#102537"))
			draw_rect(rect, Color("#21485b"), false, 1.0)
			if cell == selected_cell:
				draw_rect(rect, Color("#f6c85f"), false, 3.0)
			var mask := Rules.get_mask(state, cell)
			if mask == 0:
				draw_circle(rect.position + rect.size * 0.5, 2.0, Color("#1b3545"))
				continue
			var center: Vector2 = rect.position + rect.size * 0.5
			var pipe_color := Color("#55e7eb")
			if reachability.has(y * Rules.COLS + x):
				pipe_color = Color("#7dffad")
			draw_circle(center, 7.0, pipe_color)
			if (mask & Rules.DIR_N) != 0:
				draw_line(center, center + Vector2(0.0, -CELL_SIZE * 0.34), pipe_color, 8.0, true)
			if (mask & Rules.DIR_E) != 0:
				draw_line(center, center + Vector2(CELL_SIZE * 0.34, 0.0), pipe_color, 8.0, true)
			if (mask & Rules.DIR_S) != 0:
				draw_line(center, center + Vector2(0.0, CELL_SIZE * 0.34), pipe_color, 8.0, true)
			if (mask & Rules.DIR_W) != 0:
				draw_line(center, center + Vector2(-CELL_SIZE * 0.34, 0.0), pipe_color, 8.0, true)
			if cell == source:
				draw_circle(center, 11.0, Color("#071b20"))
				draw_string(font, center + Vector2(-10.0, 5.0), "IN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#7dffad"))
			elif cell == target:
				draw_circle(center, 11.0, Color("#30270c"))
				draw_string(font, center + Vector2(-14.0, 5.0), "OUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ffd166"))

	var solved := Rules.is_solved(state)
	var failed := Rules.is_failed(state)
	var status_color := Color("#7dffad") if solved else Color("#ff7474") if failed else Color("#d5e7ee")
	var status_text := "FLOW RESTORED" if solved else "PRESSURE LOST — PRESS R TO RETRY" if failed else banner
	draw_string(font, Vector2(50.0, 610.0), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, status_color)
	draw_string(font, Vector2(50.0, 644.0), "Moves: %d / %d" % [int(state.get("moves", 0)), Rules.MAX_MOVES], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#8aaebb"))
	draw_string(font, Vector2(50.0, 680.0), "Click/tap a pipe or select it with WASD and press SPACE. R resets the puzzle.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#8aaebb"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_reset_game()
			KEY_SPACE, KEY_ENTER:
				_rotate_selected()
			KEY_A, KEY_LEFT:
				_move_selection(Vector2i(-1, 0))
			KEY_D, KEY_RIGHT:
				_move_selection(Vector2i(1, 0))
			KEY_W, KEY_UP:
				_move_selection(Vector2i(0, -1))
			KEY_S, KEY_DOWN:
				_move_selection(Vector2i(0, 1))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_pointer(event.position)

func _handle_pointer(position: Vector2) -> void:
	var local := position - ORIGIN
	if local.x < 0.0 or local.y < 0.0 or local.x >= CELL_SIZE * Rules.COLS or local.y >= CELL_SIZE * Rules.ROWS:
		return
	var cell := Vector2i(floori(local.x / CELL_SIZE), floori(local.y / CELL_SIZE))
	selected_cell = cell
	_rotate_selected()

func _move_selection(delta: Vector2i) -> void:
	selected_cell.x = clampi(selected_cell.x + delta.x, 0, Rules.COLS - 1)
	selected_cell.y = clampi(selected_cell.y + delta.y, 0, Rules.ROWS - 1)
	queue_redraw()

func _rotate_selected() -> void:
	if Rules.rotate_tile(state, selected_cell):
		_update_banner()
		queue_redraw()

func _update_banner() -> void:
	if Rules.is_solved(state):
		banner = "FLOW RESTORED"
	elif Rules.is_failed(state):
		banner = "PRESSURE LOST — PRESS R TO RETRY"
	else:
		banner = "Rotate the pipe tiles to connect IN to OUT."

func _reset_game() -> void:
	state = Rules.create_puzzle(Time.get_ticks_msec())
	selected_cell = state.get("source", Vector2i(0, 2))
	banner = "Rotate the pipe tiles to connect IN to OUT."
	queue_redraw()

extends Node2D

const Rules = preload("res://rules.gd")
const CELL_SIZE: float = 64.0
const BOARD_ORIGIN: Vector2 = Vector2(88.0, 150.0)

var state: Dictionary
var remaining_time: float = Rules.TIME_LIMIT

func _ready() -> void:
	_reset_game()

func _process(delta: float) -> void:
	if str(state.get("status", "playing")) != "playing":
		return
	remaining_time = maxf(0.0, remaining_time - delta)
	if remaining_time <= 0.0:
		state = Rules.expire(state)
		queue_redraw()
	else:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reset_game()
			return
		if str(state.get("status", "playing")) != "playing":
			return
		var direction := Vector2i.ZERO
		match event.keycode:
			KEY_W, KEY_UP:
				direction = Vector2i.UP
			KEY_S, KEY_DOWN:
				direction = Vector2i.DOWN
			KEY_A, KEY_LEFT:
				direction = Vector2i.LEFT
			KEY_D, KEY_RIGHT:
				direction = Vector2i.RIGHT
		if direction != Vector2i.ZERO:
			state = Rules.step(state, direction)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_tap_cell(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_try_tap_cell(event.position)

func _try_tap_cell(screen_position: Vector2) -> void:
	if str(state.get("status", "playing")) != "playing":
		return
	var local := (screen_position - BOARD_ORIGIN) / CELL_SIZE
	var target := Vector2i(floori(local.x), floori(local.y))
	if not Rules.is_inside(target):
		return
	var current: Vector2i = state.get("position", Rules.START)
	var delta: Vector2i = target - current
	if absi(delta.x) + absi(delta.y) != 1:
		return
	state = Rules.step(state, delta)
	queue_redraw()

func _reset_game() -> void:
	state = Rules.new_state()
	remaining_time = Rules.TIME_LIMIT
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#07111f"), true)
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(88, 54), "KROLL // STAR CHART EXPEDITION", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("#8deaff"))
	draw_string(font, Vector2(88, 86), "Recover 3 survey beacons, then reach the extraction gate.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#c4d6e5"))

	var collected: Array = state.get("collected", [])
	for y in range(Rules.GRID_HEIGHT):
		for x in range(Rules.GRID_WIDTH):
			var cell := Vector2i(x, y)
			var rect := Rect2(BOARD_ORIGIN + Vector2(x, y) * CELL_SIZE, Vector2(CELL_SIZE - 3.0, CELL_SIZE - 3.0))
			var fill := Color("#10263a")
			if Rules.ASTEROIDS.has(cell):
				fill = Color("#344252")
			draw_rect(rect, fill, true)
			draw_rect(rect, Color("#29465b"), false, 1.0)
			if cell == Rules.EXIT:
				draw_rect(rect.grow(-8.0), Color("#8deaff"), false, 3.0)
				draw_string(font, rect.position + Vector2(18, 39), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#8deaff"))
			if Rules.BEACONS.has(cell) and not collected.has(cell):
				draw_circle(rect.position + Vector2(CELL_SIZE * 0.5 - 1.5, CELL_SIZE * 0.5 - 1.5), 12.0, Color("#ffd166"))
				draw_circle(rect.position + Vector2(CELL_SIZE * 0.5 - 1.5, CELL_SIZE * 0.5 - 1.5), 5.0, Color("#fff3c4"))
			if cell == state.get("position", Rules.START):
				draw_circle(rect.position + Vector2(CELL_SIZE * 0.5 - 1.5, CELL_SIZE * 0.5 - 1.5), 15.0, Color("#50e3c2"))
				draw_circle(rect.position + Vector2(CELL_SIZE * 0.5 - 1.5, CELL_SIZE * 0.5 - 1.5), 6.0, Color("#e6fff9"))

	var status := str(state.get("status", "playing"))
	draw_string(font, Vector2(590, 170), "FUEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#8deaff"))
	draw_string(font, Vector2(590, 205), str(state.get("fuel", 0)) + " / " + str(Rules.FUEL_START), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#ffffff"))
	draw_string(font, Vector2(590, 258), "SURVEY DATA", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#8deaff"))
	draw_string(font, Vector2(590, 292), str(collected.size()) + " / " + str(Rules.BEACONS.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#ffffff"))
	draw_string(font, Vector2(590, 345), "TIME", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#8deaff"))
	draw_string(font, Vector2(590, 379), str(ceili(remaining_time)) + " s", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#ffffff"))
	draw_string(font, Vector2(590, 435), "MOVES  " + str(state.get("moves", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#c4d6e5"))
	draw_string(font, Vector2(590, 492), "WASD / ARROWS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#c4d6e5"))
	draw_string(font, Vector2(590, 519), "Tap an adjacent tile to move.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c4d6e5"))
	draw_string(font, Vector2(590, 546), "R  restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c4d6e5"))
	if status == "won":
		draw_string(font, Vector2(590, 610), "MISSION COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#50e3c2"))
	elif status == "failed":
		draw_string(font, Vector2(590, 610), "MISSION FAILED", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ff6b6b"))

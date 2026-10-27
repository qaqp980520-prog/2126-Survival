extends Node2D

const Rules = preload("res://rules.gd")
const CELL_SIZE: float = 62.0
const BOARD_ORIGIN: Vector2 = Vector2(54.0, 142.0)
const SONAR_BUTTON: Rect2 = Rect2(Vector2(620.0, 580.0), Vector2(270.0, 54.0))
const RESTART_BUTTON: Rect2 = Rect2(Vector2(620.0, 646.0), Vector2(270.0, 42.0))

var state: Dictionary = {}
var remaining_time: float = Rules.TIME_LIMIT
var sonar_remaining: float = 0.0

func _ready() -> void:
	_reset_game()

func _process(delta: float) -> void:
	if str(state.get("status", "playing")) == "playing":
		remaining_time = maxf(0.0, remaining_time - delta)
		if remaining_time <= 0.0:
			state = Rules.expire(state)
	if sonar_remaining > 0.0:
		sonar_remaining = maxf(0.0, sonar_remaining - delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_R:
			_reset_game()
			return
		if str(state.get("status", "playing")) != "playing":
			return
		if key_event.keycode == KEY_E or key_event.keycode == KEY_SPACE:
			_pulse_sonar()
			return
		var direction := Vector2i.ZERO
		match key_event.keycode:
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
		_handle_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)

func _handle_tap(screen_position: Vector2) -> void:
	if RESTART_BUTTON.has_point(screen_position):
		_reset_game()
		return
	if str(state.get("status", "playing")) != "playing":
		return
	if SONAR_BUTTON.has_point(screen_position):
		_pulse_sonar()
		return
	var local: Vector2 = (screen_position - BOARD_ORIGIN) / CELL_SIZE
	var target := Vector2i(floori(local.x), floori(local.y))
	if not Rules.is_inside(target):
		return
	var current: Vector2i = state.get("position", Rules.START)
	var direction: Vector2i = target - current
	if absi(direction.x) + absi(direction.y) != 1:
		return
	state = Rules.step(state, direction)
	queue_redraw()

func _pulse_sonar() -> void:
	var old_charges: int = int(state.get("sonar_charges", 0))
	state = Rules.pulse_sonar(state)
	if int(state.get("sonar_charges", 0)) < old_charges:
		sonar_remaining = 2.4
	queue_redraw()

func _reset_game() -> void:
	state = Rules.new_state()
	remaining_time = Rules.TIME_LIMIT
	sonar_remaining = 0.0
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#06131f"), true)
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(54, 48), "KROLL // ECHO DIVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#78e8ff"))
	draw_string(font, Vector2(54, 82), "Pulse sonar. Recover three data beacons. Reach the extraction lock.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#c2d9e6"))
	var visible_hazards: Array[Vector2i] = []
	if sonar_remaining > 0.0:
		visible_hazards = Rules.visible_hazards(state.get("position", Rules.START))
	for y in range(Rules.GRID_HEIGHT):
		for x in range(Rules.GRID_WIDTH):
			var cell := Vector2i(x, y)
			var rect := Rect2(BOARD_ORIGIN + Vector2(x, y) * CELL_SIZE, Vector2(CELL_SIZE - 3.0, CELL_SIZE - 3.0))
			var fill := Color("#102a3a")
			if Rules.WALLS.has(cell):
				fill = Color("#3c5260")
			draw_rect(rect, fill, true)
			draw_rect(rect, Color("#29495a"), false, 1.0)
			if Rules.WALLS.has(cell):
				draw_line(rect.position + Vector2(12, 12), rect.position + Vector2(CELL_SIZE - 16, CELL_SIZE - 16), Color("#68818e"), 3.0)
				draw_line(rect.position + Vector2(CELL_SIZE - 16, 12), rect.position + Vector2(12, CELL_SIZE - 16), Color("#68818e"), 3.0)
			if cell == Rules.EXIT:
				draw_rect(rect.grow(-7.0), Color("#78e8ff"), false, 3.0)
				draw_string(font, rect.position + Vector2(18, 38), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#78e8ff"))
			var collected: Array = state.get("collected", [])
			if Rules.BEACONS.has(cell) and not collected.has(cell):
				draw_circle(rect.position + Vector2(29.5, 29.5), 12.0, Color("#ffd166"))
				draw_circle(rect.position + Vector2(29.5, 29.5), 4.5, Color("#fff3c4"))
			if visible_hazards.has(cell):
				draw_circle(rect.position + Vector2(29.5, 29.5), 15.0, Color("#ff5c77"))
				draw_string(font, rect.position + Vector2(22, 37), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#2b0b18"))
			if cell == state.get("position", Rules.START):
				draw_circle(rect.position + Vector2(29.5, 29.5), 15.0, Color("#50e3c2"))
				draw_circle(rect.position + Vector2(29.5, 29.5), 5.0, Color("#e6fff9"))
	var fuel: int = int(state.get("fuel", 0))
	var collected_count: int = (state.get("collected", []) as Array).size()
	draw_string(font, Vector2(620, 160), "DIVE SYSTEMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#78e8ff"))
	draw_string(font, Vector2(620, 205), "FUEL  %d / %d" % [fuel, Rules.FUEL_START], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#ffffff"))
	draw_string(font, Vector2(620, 250), "BEACONS  %d / %d" % [collected_count, Rules.BEACONS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffd166"))
	draw_string(font, Vector2(620, 294), "TIME  %d s" % ceili(remaining_time), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffffff"))
	draw_string(font, Vector2(620, 340), "SONAR  %d pulses" % int(state.get("sonar_charges", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#a8c4d3"))
	draw_string(font, Vector2(620, 386), "E / SPACE: pulse sonar", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#a8c4d3"))
	draw_string(font, Vector2(620, 411), "Hazards stay hidden between pulses.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a8c4d3"))
	draw_rect(SONAR_BUTTON, Color("#16485a"), true)
	draw_rect(SONAR_BUTTON, Color("#78e8ff"), false, 2.0)
	draw_string(font, Vector2(SONAR_BUTTON.position.x + 58.0, SONAR_BUTTON.position.y + 34.0), "PULSE SONAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#e9fbff"))
	draw_rect(RESTART_BUTTON, Color("#203847"), true)
	draw_rect(RESTART_BUTTON, Color("#668391"), false, 1.0)
	draw_string(font, Vector2(RESTART_BUTTON.position.x + 84.0, RESTART_BUTTON.position.y + 27.0), "RESTART  (R)", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#e9fbff"))
	var status: String = str(state.get("status", "playing"))
	if status == "won":
		draw_string(font, Vector2(620, 500), "EXTRACTION COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#50e3c2"))
	elif status == "failed":
		draw_string(font, Vector2(620, 500), "DIVE FAILED — PRESS R", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ff6b81"))
	elif sonar_remaining > 0.0:
		draw_string(font, Vector2(620, 535), "SONAR RETURN: HAZARDS REVEALED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ff9aa9"))

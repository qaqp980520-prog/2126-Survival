extends Node2D

const Rules = preload("res://rules.gd")
const TILE_SIZE := 64.0
const BOARD_ORIGIN := Vector2(24.0, 72.0)
const BOARD_SIZE := Vector2(Rules.BOARD_COLUMNS * TILE_SIZE, Rules.BOARD_ROWS * TILE_SIZE)
const START_WAVE_RECT := Rect2(Vector2(690.0, 250.0), Vector2(286.0, 54.0))
const RESET_RECT := Rect2(Vector2(690.0, 320.0), Vector2(286.0, 50.0))

var state: Dictionary = {}

func _ready() -> void:
	restart_game()

func _process(delta: float) -> void:
	Rules.advance(state, delta)
	queue_redraw()

func restart_game() -> void:
	state = Rules.create_state()
	queue_redraw()

func place_relay_at(cell: Vector2i) -> bool:
	var placed := Rules.place_relay(state, cell)
	queue_redraw()
	return placed

func start_wave() -> bool:
	var started := Rules.start_next_wave(state)
	queue_redraw()
	return started

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_SPACE:
			start_wave()
		elif key_event.keycode == KEY_R:
			restart_game()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		var point := mouse_event.position
		if START_WAVE_RECT.has_point(point):
			start_wave()
		elif RESET_RECT.has_point(point):
			restart_game()
		elif Rect2(BOARD_ORIGIN, BOARD_SIZE).has_point(point):
			var local_point: Vector2 = point - BOARD_ORIGIN
			var cell := Vector2i(floori(local_point.x / TILE_SIZE), floori(local_point.y / TILE_SIZE))
			place_relay_at(cell)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1024.0, 680.0)), Color(0.018, 0.028, 0.05), true)
	draw_string(ThemeDB.fallback_font, Vector2(24.0, 38.0), "KROLL // NETWORK STABILIZER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 25, Color(0.42, 0.92, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(24.0, 58.0), "PLACE RELAYS · START PACKET WAVES · PROTECT THE CORE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.62, 0.72, 0.82))

	for y in range(Rules.BOARD_ROWS):
		for x in range(Rules.BOARD_COLUMNS):
			var cell := Vector2i(x, y)
			var rect := Rect2(BOARD_ORIGIN + Vector2(x, y) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))
			var fill := Color(0.055, 0.09, 0.13)
			if Rules.is_path_cell(cell):
				fill = Color(0.20, 0.16, 0.10)
			draw_rect(rect, fill, true)
			draw_rect(rect, Color(0.14, 0.22, 0.28), false, 1.0)
			if cell == Rules.PATH_CELLS[0]:
				draw_circle(rect.get_center(), 12.0, Color(1.0, 0.58, 0.22))
			elif cell == Rules.PATH_CELLS[Rules.PATH_CELLS.size() - 1]:
				draw_circle(rect.get_center(), 14.0, Color(0.32, 1.0, 0.62))

	for relay_value in state.get("relays", []):
		var relay: Dictionary = relay_value
		var center := BOARD_ORIGIN + (Vector2(relay["cell"]) + Vector2(0.5, 0.5)) * TILE_SIZE
		draw_circle(center, 20.0, Color(0.10, 0.58, 0.72))
		draw_circle(center, 11.0, Color(0.60, 0.96, 1.0))
		draw_line(center, center + Vector2(0.0, -17.0), Color(0.04, 0.15, 0.20), 4.0)

	for packet_value in state.get("packets", []):
		var packet: Dictionary = packet_value
		var grid_pos: Vector2 = Rules.packet_grid_position(packet)
		var center := BOARD_ORIGIN + (grid_pos + Vector2(0.5, 0.5)) * TILE_SIZE
		draw_circle(center, 15.0, Color(0.92, 0.22, 0.30))
		draw_circle(center, 6.0, Color(1.0, 0.74, 0.70))
		var checks_ratio := clampf(float(packet["checks"]) / maxf(1.0, float(packet["max_checks"])), 0.0, 1.0)
		draw_rect(Rect2(center + Vector2(-16.0, -24.0), Vector2(32.0, 4.0)), Color(0.25, 0.05, 0.08), true)
		draw_rect(Rect2(center + Vector2(-16.0, -24.0), Vector2(32.0 * checks_ratio, 4.0)), Color(0.40, 1.0, 0.48), true)

	draw_string(ThemeDB.fallback_font, Vector2(690.0, 50.0), "DEFENSE STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.70, 0.91, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(690.0, 86.0), "CREDITS   %d" % int(state.get("credits", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(1.0, 0.80, 0.34))
	draw_string(ThemeDB.fallback_font, Vector2(690.0, 116.0), "CORE INTEGRITY   %d" % int(state.get("integrity", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(1.0, 0.42, 0.44))
	draw_string(ThemeDB.fallback_font, Vector2(690.0, 146.0), "WAVE      %d / %d" % [int(state.get("wave", 0)), Rules.WAVE_COUNTS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(0.55, 0.91, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(690.0, 176.0), "PACKETS CLEANED     %d" % int(state.get("cleaned", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(0.68, 1.0, 0.70))
	draw_rect(START_WAVE_RECT, Color(0.08, 0.34, 0.42), true)
	draw_rect(START_WAVE_RECT, Color(0.30, 0.86, 1.0), false, 2.0)
	var start_label := "START PACKET WAVE [SPACE]" if str(state.get("phase", "")) == "build" and int(state.get("wave", 0)) < Rules.WAVE_COUNTS.size() else str(state.get("phase", "")).to_upper()
	draw_string(ThemeDB.fallback_font, START_WAVE_RECT.position + Vector2(18.0, 33.0), start_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.90, 1.0, 1.0))
	draw_rect(RESET_RECT, Color(0.13, 0.17, 0.23), true)
	draw_rect(RESET_RECT, Color(0.36, 0.50, 0.62), false, 1.0)
	draw_string(ThemeDB.fallback_font, RESET_RECT.position + Vector2(18.0, 31.0), "RESTART [R]", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.78, 0.88, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(690.0, 410.0), "RELAY COST: %d" % Rules.RELAY_COST, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.64, 0.85, 0.92))
	draw_string(ThemeDB.fallback_font, Vector2(690.0, 442.0), "Click a free tile to place a relay.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.70, 0.78, 0.86))
	draw_string(ThemeDB.fallback_font, Vector2(690.0, 466.0), "Relays auto-scan within range.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.70, 0.78, 0.86))
	draw_string(ThemeDB.fallback_font, Vector2(690.0, 490.0), "Each cleaned packet grants %d credits." % Rules.CLEAN_REWARD, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.70, 0.78, 0.86))
	if str(state.get("phase", "")) == "won":
		draw_string(ThemeDB.fallback_font, Vector2(690.0, 555.0), "CORE SECURED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.35, 1.0, 0.60))
	elif str(state.get("phase", "")) == "lost":
		draw_string(ThemeDB.fallback_font, Vector2(690.0, 555.0), "NETWORK BREACHED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(1.0, 0.30, 0.38))

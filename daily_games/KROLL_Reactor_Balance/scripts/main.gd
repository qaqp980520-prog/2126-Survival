extends Control

const Rules = preload("res://scripts/rules.gd")

var outputs: Array = [52.0, 50.0, 48.0]
var heats: Array = [35.0, 40.0, 38.0]
var time_left: float = Rules.ROUND_SECONDS
var stable_seconds: int = 0
var game_state: String = "running"
var _tick_accumulator: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if game_state != "running":
		return
	_tick_accumulator += delta
	while _tick_accumulator >= 1.0 and game_state == "running":
		_tick_accumulator -= 1.0
		var drift: Array = []
		for index in range(Rules.REACTOR_COUNT):
			drift.append(_rng.randf_range(-4.0, 4.0))
		_tick_with_drift(drift)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if game_state != "running":
			if key_event.keycode == KEY_R:
				restart_game()
			return
		match key_event.keycode:
			KEY_1: debug_action(0, "vent")
			KEY_2: debug_action(1, "vent")
			KEY_3: debug_action(2, "vent")
			KEY_Q: debug_action(0, "boost")
			KEY_W: debug_action(1, "boost")
			KEY_E: debug_action(2, "boost")
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_handle_pointer(mouse_event.position)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_handle_pointer(touch_event.position)

func _handle_pointer(position: Vector2) -> void:
	if game_state != "running":
		return
	if position.x < 35.0 or position.x >= 935.0:
		return
	var reactor_index: int = floori((position.x - 35.0) / 300.0)
	if reactor_index < 0 or reactor_index >= Rules.REACTOR_COUNT:
		return
	if position.y >= 310.0 and position.y < 385.0:
		debug_action(reactor_index, "vent")
	elif position.y >= 398.0 and position.y < 473.0:
		debug_action(reactor_index, "boost")

func debug_action(reactor_index: int, action: String) -> bool:
	if game_state != "running":
		return false
	var result: Dictionary = Rules.apply_action(outputs, heats, reactor_index, action)
	if not bool(result.get("ok", false)):
		return false
	outputs = result["outputs"]
	heats = result["heats"]
	if Rules.is_overheated(heats):
		game_state = "meltdown"
	queue_redraw()
	return true

func debug_tick(drift: Array) -> bool:
	return _tick_with_drift(drift)

func _tick_with_drift(drift: Array) -> bool:
	if game_state != "running":
		return false
	var result: Dictionary = Rules.advance(outputs, heats, drift, 1.0)
	if not bool(result.get("ok", false)):
		return false
	outputs = result["outputs"]
	heats = result["heats"]
	time_left = maxf(0.0, time_left - 1.0)
	if Rules.is_overheated(heats):
		game_state = "meltdown"
	elif Rules.is_grid_stable(outputs):
		stable_seconds += 1
	else:
		stable_seconds = 0
	if stable_seconds >= Rules.REQUIRED_STABLE_SECONDS:
		game_state = "victory"
	elif time_left <= 0.0:
		game_state = "timeout"
	queue_redraw()
	return true

func get_game_state() -> String:
	return game_state

func restart_game() -> void:
	outputs = [52.0, 50.0, 48.0]
	heats = [35.0, 40.0, 38.0]
	time_left = Rules.ROUND_SECONDS
	stable_seconds = 0
	game_state = "running"
	_tick_accumulator = 0.0
	queue_redraw()

func _draw() -> void:
	var size: Vector2 = get_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		size = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.022, 0.04))
	for x in range(0, int(size.x) + 1, 40):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.08, 0.18, 0.23, 0.28), 1.0)
	for y in range(0, int(size.y) + 1, 40):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.08, 0.18, 0.23, 0.28), 1.0)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, Vector2(30, 38), "KROLL // REACTOR BALANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.35, 0.92, 1.0))
	var total_output: float = float(outputs[0]) + float(outputs[1]) + float(outputs[2])
	draw_string(font, Vector2(30, 70), "GRID %.0f / TARGET 135-165     STABLE %02d / %02d s     TIME %02d s" % [total_output, stable_seconds, Rules.REQUIRED_STABLE_SECONDS, int(ceil(time_left))], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.82, 0.94, 0.96))
	for index in range(Rules.REACTOR_COUNT):
		var card := Rect2(Vector2(35.0 + index * 300.0, 120.0), Vector2(270.0, 390.0))
		draw_rect(card, Color(0.035, 0.075, 0.10))
		draw_rect(card, Color(0.18, 0.52, 0.61, 0.8), false, 2.0)
		draw_string(font, Vector2(card.position.x + 18.0, card.position.y + 34.0), "REACTOR %d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.46, 0.94, 1.0))
		draw_string(font, Vector2(card.position.x + 18.0, card.position.y + 68.0), "OUTPUT  %3.0f%%" % float(outputs[index]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.90, 0.97, 0.98))
		draw_rect(Rect2(card.position.x + 18.0, card.position.y + 82.0, 234.0, 13.0), Color(0.10, 0.17, 0.20))
		draw_rect(Rect2(card.position.x + 18.0, card.position.y + 82.0, 234.0 * float(outputs[index]) / 100.0, 13.0), Color(0.14, 0.82, 0.92))
		draw_string(font, Vector2(card.position.x + 18.0, card.position.y + 132.0), "HEAT  %3.0f / 100" % float(heats[index]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.66, 0.36) if float(heats[index]) >= 75.0 else Color(0.73, 0.90, 0.85))
		draw_rect(Rect2(card.position.x + 18.0, card.position.y + 145.0, 234.0, 13.0), Color(0.10, 0.17, 0.20))
		draw_rect(Rect2(card.position.x + 18.0, card.position.y + 145.0, 234.0 * clampf(float(heats[index]) / 100.0, 0.0, 1.0), 13.0), Color(0.96, 0.32, 0.22) if float(heats[index]) >= 75.0 else Color(0.95, 0.66, 0.24))
		draw_rect(Rect2(card.position.x + 12.0, card.position.y + 190.0, 246.0, 74.0), Color(0.08, 0.19, 0.22))
		draw_string(font, Vector2(card.position.x + 24.0, card.position.y + 218.0), "%s / 1  VENT -12 / COOL -18" % ["1", "2", "3"][index], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.48, 0.95, 1.0))
		draw_string(font, Vector2(card.position.x + 24.0, card.position.y + 244.0), "TAP UPPER HALF TO VENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.82, 0.85))
		draw_rect(Rect2(card.position.x + 12.0, card.position.y + 278.0, 246.0, 74.0), Color(0.13, 0.14, 0.10))
		draw_string(font, Vector2(card.position.x + 24.0, card.position.y + 306.0), "%s / %s  BOOST +10 / HEAT +12" % [["Q", "W", "E"][index], "BOOST"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.80, 0.43))
		draw_string(font, Vector2(card.position.x + 24.0, card.position.y + 332.0), "TAP LOWER HALF TO BOOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.78, 0.62))
	if game_state != "running":
		var title := "GRID STABILIZED" if game_state == "victory" else ("REACTOR OVERHEAT" if game_state == "meltdown" else "STABILITY WINDOW CLOSED")
		draw_rect(Rect2(150.0, 250.0, size.x - 300.0, 110.0), Color(0.01, 0.025, 0.04, 0.94))
		draw_rect(Rect2(150.0, 250.0, size.x - 300.0, 110.0), Color(0.28, 0.82, 0.9), false, 2.0)
		draw_string(font, Vector2(size.x * 0.5 - 115.0, 292.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.45, 0.96, 1.0))
		draw_string(font, Vector2(size.x * 0.5 - 115.0, 330.0), "PRESS R TO RESTART", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.95, 0.96))
	draw_string(font, Vector2(30.0, size.y - 22.0), "1/2/3 VENT   Q/W/E BOOST   KEEP GRID 135-165   AVOID HEAT 100", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.47, 0.70, 0.76))

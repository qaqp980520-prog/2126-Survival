extends Node2D

const Rules = preload("res://rules.gd")
const MAP_ORIGIN: Vector2 = Vector2(160.0, 100.0)
const PAN_STEP: float = 20.0

var scenario_index: int = 0
var state: Dictionary = {}
var touch_buttons: Dictionary = {}
var hud_label: Label

func _ready() -> void:
	state = Rules.create_state(scenario_index)
	_build_ui()
	_refresh_ui()
	queue_redraw()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud_label = Label.new()
	hud_label.name = "Status"
	hud_label.position = Vector2(18.0, 12.0)
	hud_label.size = Vector2(920.0, 76.0)
	hud_label.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	hud_label.add_theme_font_size_override("font_size", 15)
	layer.add_child(hud_label)
	var row := HBoxContainer.new()
	row.name = "TouchControls"
	row.position = Vector2(118.0, 548.0)
	row.size = Vector2(724.0, 54.0)
	row.add_theme_constant_override("separation", 6)
	layer.add_child(row)
	_add_button(row, "left", "LEFT")
	_add_button(row, "right", "RIGHT")
	_add_button(row, "up", "UP")
	_add_button(row, "down", "DOWN")
	_add_button(row, "zoom_out", "ZOOM -")
	_add_button(row, "zoom_in", "ZOOM +")
	_add_button(row, "capture", "SHUTTER")
	_add_button(row, "reset", "RESET")
	_add_button(row, "next", "NEXT")

func _add_button(parent: HBoxContainer, key: String, caption: String) -> void:
	var button := Button.new()
	button.name = "Touch_" + key
	button.text = caption
	button.custom_minimum_size = Vector2(74.0, 42.0)
	button.add_theme_font_size_override("font_size", 12)
	parent.add_child(button)
	touch_buttons[key] = button
	match key:
		"left":
			button.pressed.connect(_pan.bind(Vector2(-PAN_STEP, 0.0)))
		"right":
			button.pressed.connect(_pan.bind(Vector2(PAN_STEP, 0.0)))
		"up":
			button.pressed.connect(_pan.bind(Vector2(0.0, -PAN_STEP)))
		"down":
			button.pressed.connect(_pan.bind(Vector2(0.0, PAN_STEP)))
		"zoom_out":
			button.pressed.connect(_zoom.bind(-1))
		"zoom_in":
			button.pressed.connect(_zoom.bind(1))
		"capture":
			button.pressed.connect(_capture)
		"reset":
			button.pressed.connect(_reset)
		"next":
			button.pressed.connect(_next)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_A, KEY_LEFT:
			_pan(Vector2(-PAN_STEP, 0.0))
		KEY_D, KEY_RIGHT:
			_pan(Vector2(PAN_STEP, 0.0))
		KEY_W, KEY_UP:
			_pan(Vector2(0.0, -PAN_STEP))
		KEY_S, KEY_DOWN:
			_pan(Vector2(0.0, PAN_STEP))
		KEY_Q:
			_zoom(-1)
		KEY_E:
			_zoom(1)
		KEY_SPACE:
			_capture()
		KEY_R:
			_reset()
		KEY_N:
			_next()

func _pan(offset: Vector2) -> void:
	if str(state.get("status", "")) != "aiming":
		return
	var center: Vector2 = state.get("center", Rules.MAP_SIZE * 0.5)
	center += offset
	center.x = clampf(center.x, 0.0, Rules.MAP_SIZE.x)
	center.y = clampf(center.y, 0.0, Rules.MAP_SIZE.y)
	state["center"] = center
	_refresh_ui()
	queue_redraw()

func _zoom(amount: int) -> void:
	if str(state.get("status", "")) != "aiming":
		return
	state["zoom"] = clampi(int(state.get("zoom", 0)) + amount, Rules.MIN_ZOOM, Rules.MAX_ZOOM)
	_refresh_ui()
	queue_redraw()

func _capture() -> Dictionary:
	if str(state.get("status", "")) != "aiming":
		return {"ok": false, "reason": "round_finished"}
	var center: Vector2 = state.get("center", Rules.MAP_SIZE * 0.5)
	var zoom_level: int = int(state.get("zoom", 0))
	var result: Dictionary = Rules.evaluate_capture(scenario_index, center, zoom_level)
	state["shots_left"] = maxi(0, int(state.get("shots_left", 0)) - 1)
	if bool(result.get("ok", false)):
		state["status"] = "won"
		state["feedback"] = "CAPTURE ACCEPTED // all targets framed, no interference."
	elif int(state["shots_left"]) <= 0:
		state["status"] = "failed"
		state["feedback"] = "FILM EXHAUSTED // reset and reframe the survey."
	else:
		var reason: String = str(result.get("reason", "invalid_camera"))
		state["feedback"] = "REJECTED // " + reason.replace("_", " ").to_upper()
	_refresh_ui()
	queue_redraw()
	return result

func _reset() -> void:
	state = Rules.create_state(scenario_index)
	_refresh_ui()
	queue_redraw()

func _next() -> void:
	scenario_index = posmod(scenario_index + 1, Rules.get_scenario_count())
	_reset()

func _refresh_ui() -> void:
	if hud_label == null:
		return
	var scenario: Dictionary = Rules.get_scenario(scenario_index)
	var center: Vector2 = state.get("center", Rules.MAP_SIZE * 0.5)
	var zoom_level: int = int(state.get("zoom", 0))
	var preview: Dictionary = Rules.evaluate_capture(scenario_index, center, zoom_level)
	var state_name: String = str(state.get("status", "aiming")).to_upper()
	hud_label.text = "KROLL ORBITAL IMAGER // %s\nWASD pan · Q/E zoom · SPACE shutter · R reset · N next\nZoom %d/%d · Shots %d · Targets %d/%d · Interference %d · %s\n%s" % [
		str(scenario.get("name", "SURVEY")),
		zoom_level,
		Rules.MAX_ZOOM,
		int(state.get("shots_left", 0)),
		int(preview.get("targets_inside", 0)),
		int(preview.get("total_targets", 0)),
		int(preview.get("hazards_inside", 0)),
		state_name,
		str(state.get("feedback", ""))
	]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960.0, 640.0)), Color(0.012, 0.025, 0.045), true)
	draw_rect(Rect2(MAP_ORIGIN, Rules.MAP_SIZE), Color(0.035, 0.075, 0.095), true)
	for x in range(0, 641, 40):
		var screen_x: float = MAP_ORIGIN.x + float(x)
		draw_line(Vector2(screen_x, MAP_ORIGIN.y), Vector2(screen_x, MAP_ORIGIN.y + Rules.MAP_SIZE.y), Color(0.10, 0.22, 0.26, 0.75), 1.0)
	for y in range(0, 361, 40):
		var screen_y: float = MAP_ORIGIN.y + float(y)
		draw_line(Vector2(MAP_ORIGIN.x, screen_y), Vector2(MAP_ORIGIN.x + Rules.MAP_SIZE.x, screen_y), Color(0.10, 0.22, 0.26, 0.75), 1.0)
	draw_rect(Rect2(MAP_ORIGIN, Rules.MAP_SIZE), Color(0.22, 0.64, 0.72), false, 2.0)
	var scenario: Dictionary = Rules.get_scenario(scenario_index)
	var targets: Array = scenario.get("targets", [])
	for index in range(targets.size()):
		var target_position: Vector2 = MAP_ORIGIN + targets[index]
		draw_circle(target_position, 9.0, Color(0.25, 0.92, 0.66))
		draw_circle(target_position, 15.0, Color(0.25, 0.92, 0.66, 0.16))
		draw_string(ThemeDB.fallback_font, target_position + Vector2(13.0, 5.0), "T%d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.76, 1.0, 0.9))
	var hazards: Array = scenario.get("hazards", [])
	for hazard_value in hazards:
		var hazard_position: Vector2 = MAP_ORIGIN + hazard_value
		draw_circle(hazard_position, 10.0, Color(1.0, 0.32, 0.30))
		draw_line(hazard_position + Vector2(-15.0, -15.0), hazard_position + Vector2(15.0, 15.0), Color(1.0, 0.5, 0.42), 2.0)
		draw_line(hazard_position + Vector2(-15.0, 15.0), hazard_position + Vector2(15.0, -15.0), Color(1.0, 0.5, 0.42), 2.0)
	var center: Vector2 = state.get("center", Rules.MAP_SIZE * 0.5)
	var half_extents: Vector2 = Rules.frame_half_extents(int(state.get("zoom", 0)))
	var frame_rect := Rect2(MAP_ORIGIN + center - half_extents, half_extents * 2.0)
	draw_rect(frame_rect, Color(0.10, 0.72, 0.92, 0.08), true)
	draw_rect(frame_rect, Color(0.22, 0.88, 1.0), false, 3.0)
	var reticle: Vector2 = MAP_ORIGIN + center
	draw_line(reticle + Vector2(-18.0, 0.0), reticle + Vector2(18.0, 0.0), Color(0.84, 0.98, 1.0), 2.0)
	draw_line(reticle + Vector2(0.0, -18.0), reticle + Vector2(0.0, 18.0), Color(0.84, 0.98, 1.0), 2.0)
	draw_circle(reticle, 4.0, Color(0.84, 0.98, 1.0))
	draw_string(ThemeDB.fallback_font, MAP_ORIGIN + Vector2(8.0, Rules.MAP_SIZE.y + 22.0), "GREEN = REQUIRED TARGET    RED = SIGNAL INTERFERENCE    CYAN = CAMERA FRAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.66, 0.82, 0.9))

extends Control

const RULES_PATH: String = "res://daily_games/KROLL_Thermal_Glider/rules.gd"
const GROUND_Y: float = 452.0

var _rules: RefCounted
var _state: Dictionary = {}
var _course_index: int = 0
var _touch_pitch: int = 0
var _touch_boost: bool = false
var _touch_brake: bool = false
var _status_label: Label
var _detail_label: Label
var _camera_x: float = 0.0
var _buttons: Dictionary = {}

func _ready() -> void:
	var rules_path: String = RULES_PATH
	if not ResourceLoader.exists(rules_path):
		rules_path = "res://rules.gd"
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("KROLL Thermal Glider could not load its rules module.")
		return
	_rules = rules_script.new()
	_state = _rules.call("new_run", _course_index)
	_build_ui()
	_refresh()
	queue_redraw()

func _process(delta: float) -> void:
	if _rules == null or str(_state.get("status", "")) != "flying":
		return
	var pitch_input: int = _touch_pitch
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pitch_input += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pitch_input -= 1
	pitch_input = clampi(pitch_input, -1, 1)
	var controls := {
		"pitch": pitch_input,
		"boost": _touch_boost or Input.is_key_pressed(KEY_SPACE),
		"brake": _touch_brake or Input.is_key_pressed(KEY_SHIFT)
	}
	_state = _rules.call("step", _state, controls, delta)
	_refresh()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_R:
			reset_course()
		KEY_N:
			next_course()

func _build_ui() -> void:
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.position = Vector2(22.0, 16.0)
	_status_label.size = Vector2(1040.0, 32.0)
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color("#e9f6ff"))
	add_child(_status_label)

	_detail_label = Label.new()
	_detail_label.position = Vector2(22.0, 50.0)
	_detail_label.size = Vector2(1040.0, 34.0)
	_detail_label.add_theme_font_size_override("font_size", 13)
	_detail_label.add_theme_color_override("font_color", Color("#a9c4d6"))
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_detail_label)

	var bar := HBoxContainer.new()
	bar.name = "FlightControls"
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -500.0
	bar.offset_right = 500.0
	bar.offset_top = -66.0
	bar.offset_bottom = -10.0
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	_add_hold_button(bar, "NOSE UP", "up", 1)
	_add_hold_button(bar, "NOSE DOWN", "down", -1)
	_add_hold_button(bar, "BOOST", "boost", 0)
	_add_hold_button(bar, "AIRBRAKE", "brake", 0)
	_add_action_button(bar, "RESET", "reset", reset_course)
	_add_action_button(bar, "NEXT", "next", next_course)

func _add_hold_button(parent: HBoxContainer, label_text: String, key: String, pitch_value: int) -> void:
	var button := Button.new()
	button.name = "Control_" + key
	button.text = label_text
	button.custom_minimum_size = Vector2(120.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.button_down.connect(_set_hold_control.bind(key, pitch_value, true))
	button.button_up.connect(_set_hold_control.bind(key, pitch_value, false))
	parent.add_child(button)
	_buttons[key] = button

func _add_action_button(parent: HBoxContainer, label_text: String, key: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = "Action_" + key
	button.text = label_text
	button.custom_minimum_size = Vector2(105.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	_buttons[key] = button

func _set_hold_control(key: String, pitch_value: int, pressed: bool) -> void:
	match key:
		"up", "down":
			_touch_pitch = pitch_value if pressed else (0 if _touch_pitch == pitch_value else _touch_pitch)
		"boost":
			_touch_boost = pressed
		"brake":
			_touch_brake = pressed

func set_control_state(pitch_input: int, boost: bool, brake: bool) -> void:
	_touch_pitch = clampi(pitch_input, -1, 1)
	_touch_boost = boost
	_touch_brake = brake

func step_simulation(delta: float) -> Dictionary:
	if _rules == null:
		return {}
	_state = _rules.call("step", _state, {
		"pitch": _touch_pitch,
		"boost": _touch_boost,
		"brake": _touch_brake
	}, delta)
	_refresh()
	queue_redraw()
	return get_current_state()

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func reset_course() -> void:
	_state = _rules.call("new_run", _course_index)
	_touch_pitch = 0
	_touch_boost = false
	_touch_brake = false
	_refresh()
	queue_redraw()

func next_course() -> void:
	_course_index = posmod(_course_index + 1, int(_rules.call("get_course_count")))
	reset_course()

func _refresh() -> void:
	if _status_label == null or _rules == null:
		return
	var course: Dictionary = _rules.call("get_course", _course_index)
	var position: Vector2 = _state.get("position", Vector2.ZERO)
	var velocity: Vector2 = _state.get("velocity", Vector2.ZERO)
	var checkpoint: int = int(_state.get("checkpoint", 0))
	var battery: float = float(_state.get("battery", 0.0))
	_status_label.text = "KROLL THERMAL GLIDER  |  %s  |  BEACONS %d/3  |  BATTERY %03d%%" % [
		str(course.get("name", "FLIGHT")).to_upper(), checkpoint, roundi(battery)
	]
	_detail_label.text = "%s  |  SPEED %.0f  |  VERTICAL %.0f  |  PITCH %.0f°" % [
		str(_rules.call("get_status_message", _state)), velocity.x, velocity.y, float(_state.get("pitch", 0.0))
	]
	if str(_state.get("status", "")) != "flying":
		_detail_label.text = str(_rules.call("get_status_message", _state))
	for key in ["up", "down", "boost", "brake"]:
		if _buttons.has(key):
			(_buttons[key] as Button).disabled = str(_state.get("status", "")) != "flying"

func _draw() -> void:
	if _rules != null:
		var current_position: Vector2 = _state.get("position", Vector2.ZERO)
		_camera_x = maxf(0.0, current_position.x - size.x * 0.28)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#071624"))
	draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(size.x, 7.0)), Color("#4bd5d0"))
	for grid_x in range(0, 2200, 100):
		var screen_x: float = float(grid_x) - _camera_x
		if screen_x >= -20.0 and screen_x <= size.x + 20.0:
			draw_line(Vector2(screen_x, 92.0), Vector2(screen_x, GROUND_Y), Color(0.18, 0.31, 0.39, 0.24), 1.0)
	for grid_y in range(100, 451, 70):
		draw_line(Vector2(0.0, float(grid_y)), Vector2(size.x, float(grid_y)), Color(0.18, 0.31, 0.39, 0.24), 1.0)
	var course: Dictionary = _rules.call("get_course", _course_index) if _rules != null else {}
	var thermals: Array = course.get("thermals", [])
	for thermal_value in thermals:
		if not (thermal_value is Dictionary):
			continue
		var thermal: Dictionary = thermal_value
		var center: Vector2 = thermal.get("position", Vector2.ZERO) - Vector2(_camera_x, 0.0)
		var radius: float = float(thermal.get("radius", 0.0))
		if center.x > -radius and center.x < size.x + radius:
			draw_arc(center, radius, PI, TAU, 48, Color(0.25, 0.85, 0.76, 0.3), 2.0, true)
			draw_arc(center, radius * 0.65, PI, TAU, 36, Color(0.25, 0.85, 0.76, 0.22), 1.0, true)
			draw_string(ThemeDB.fallback_font, center + Vector2(-36.0, -radius * 0.45), "THERMAL", HORIZONTAL_ALIGNMENT_LEFT, 90.0, 11, Color("#74d9c7"))
	var beacons: Array = course.get("beacons", [])
	var checkpoint: int = int(_state.get("checkpoint", 0))
	for index in range(beacons.size()):
		var beacon: Vector2 = beacons[index] - Vector2(_camera_x, 0.0)
		if beacon.x < -60.0 or beacon.x > size.x + 60.0:
			continue
		var color: Color = Color("#7d9ba8") if index < checkpoint else Color("#ffc66d")
		draw_line(Vector2(beacon.x, 90.0), Vector2(beacon.x, GROUND_Y), Color(color.r, color.g, color.b, 0.28), 2.0)
		draw_circle(beacon, 12.0, color)
		draw_arc(beacon, 22.0, 0.0, TAU, 32, color, 2.0, true)
		draw_string(ThemeDB.fallback_font, beacon + Vector2(-16.0, -30.0), "B%d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, 42.0, 15, color)
	var runway_x: float = float(course.get("runway_x", 1700.0)) - _camera_x
	var runway_y: float = float(course.get("runway_y", 300.0))
	if runway_x > -100.0 and runway_x < size.x + 100.0:
		draw_line(Vector2(runway_x - 55.0, runway_y), Vector2(runway_x + 75.0, runway_y), Color("#e8f1f4"), 5.0)
		draw_line(Vector2(runway_x - 55.0, runway_y - 15.0), Vector2(runway_x - 55.0, runway_y + 15.0), Color("#f1bd68"), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(runway_x - 30.0, runway_y - 28.0), "RUNWAY", HORIZONTAL_ALIGNMENT_LEFT, 100.0, 14, Color("#e8f1f4"))
	draw_rect(Rect2(0.0, GROUND_Y, size.x, size.y - GROUND_Y), Color("#142b35"))
	draw_line(Vector2(0.0, GROUND_Y), Vector2(size.x, GROUND_Y), Color("#64a7a0"), 3.0)
	if _rules != null:
		var position: Vector2 = _state.get("position", Vector2.ZERO)
		var velocity: Vector2 = _state.get("velocity", Vector2.ZERO)
		var plane_position: Vector2 = position - Vector2(_camera_x, 0.0)
		var angle: float = deg_to_rad(-float(_state.get("pitch", 0.0)))
		var forward: Vector2 = Vector2(cos(angle), sin(angle))
		var side: Vector2 = Vector2(-forward.y, forward.x)
		var nose: Vector2 = plane_position + forward * 22.0
		var tail: Vector2 = plane_position - forward * 17.0
		var wing_a: Vector2 = plane_position + side * 15.0
		var wing_b: Vector2 = plane_position - side * 15.0
		draw_colored_polygon(PackedVector2Array([nose, wing_a, tail, wing_b]), Color("#f5f7fa"))
		draw_line(tail, nose, Color("#54d8d2"), 3.0)
		draw_line(plane_position, plane_position + Vector2(velocity.x * 0.35, velocity.y * 0.35), Color("#f2bf71"), 2.0)
		var battery_width: float = 170.0 * float(_state.get("battery", 0.0)) / 100.0
		draw_rect(Rect2(22.0, 96.0, 174.0, 10.0), Color("#263c4a"))
		draw_rect(Rect2(22.0, 96.0, battery_width, 10.0), Color("#57d3b6"))
		draw_string(ThemeDB.fallback_font, Vector2(22.0, 124.0), "ASSIST BATTERY", HORIZONTAL_ALIGNMENT_LEFT, 160.0, 11, Color("#9fc1d0"))

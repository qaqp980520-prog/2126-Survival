extends Control
const Rules = preload("res://daily_games/KROLL_Vector_Rally/rules.gd")
var _state: Dictionary = {}
var _touch_input: Dictionary = {"steer":0.0,"throttle":false,"brake":false,"handbrake":false}
var _telemetry_label: Label
var _status_label: Label
var _notice: String = ""
func _ready() -> void:
	_state = Rules.new_race(0)
	_build_ui()
	_update_hud()
	queue_redraw()
func _process(delta: float) -> void:
	_advance_simulation(delta)
func _advance_simulation(delta: float) -> void:
	var steer: float = float(_touch_input.get("steer", 0.0))
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		steer = -1.0
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		steer = 1.0
	var input := {"steer":steer,"throttle":bool(_touch_input.get("throttle", false)) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP),"brake":bool(_touch_input.get("brake", false)) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN),"handbrake":bool(_touch_input.get("handbrake", false)) or Input.is_key_pressed(KEY_SPACE)}
	_state = Rules.step(_state, input, delta)
	_update_hud()
	queue_redraw()
func _build_ui() -> void:
	var title := Label.new()
	title.position = Vector2(20.0, 12.0)
	title.size = Vector2(680.0, 30.0)
	title.text = "KROLL VECTOR RALLY  //  TIME TRIAL"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#79e8ff"))
	add_child(title)
	_telemetry_label = Label.new()
	_telemetry_label.position = Vector2(20.0, 46.0)
	_telemetry_label.size = Vector2(850.0, 28.0)
	_telemetry_label.add_theme_font_size_override("font_size", 17)
	_telemetry_label.add_theme_color_override("font_color", Color("#e5f1f6"))
	add_child(_telemetry_label)
	_status_label = Label.new()
	_status_label.position = Vector2(20.0, 78.0)
	_status_label.size = Vector2(800.0, 26.0)
	_status_label.add_theme_color_override("font_color", Color("#a9c5d0"))
	add_child(_status_label)
	_add_hold_button("SteerLeftButton", "LEFT", Vector2(24.0, 628.0), "steer", -1.0, 0.0, Vector2(78.0, 60.0))
	_add_hold_button("SteerRightButton", "RIGHT", Vector2(110.0, 628.0), "steer", 1.0, 0.0, Vector2(78.0, 60.0))
	_add_hold_button("BrakeButton", "BRAKE", Vector2(748.0, 628.0), "brake", true, false, Vector2(82.0, 60.0))
	_add_hold_button("ThrottleButton", "THROTTLE", Vector2(838.0, 628.0), "throttle", true, false, Vector2(100.0, 60.0))
	_add_hold_button("HandbrakeButton", "DRIFT", Vector2(838.0, 562.0), "handbrake", true, false, Vector2(100.0, 54.0))
	var restart := Button.new()
	restart.name = "RestartButton"
	restart.text = "RESTART"
	restart.position = Vector2(790.0, 16.0)
	restart.size = Vector2(78.0, 36.0)
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(_restart)
	add_child(restart)
	var next := Button.new()
	next.name = "NextTrackButton"
	next.text = "NEXT"
	next.position = Vector2(876.0, 16.0)
	next.size = Vector2(70.0, 36.0)
	next.focus_mode = Control.FOCUS_NONE
	next.pressed.connect(_next_track)
	add_child(next)
func _add_hold_button(node_name: String, label_text: String, button_position: Vector2, control_name: String, pressed_value: Variant, released_value: Variant, button_size: Vector2) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = label_text
	button.position = button_position
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.button_down.connect(_set_touch_control.bind(control_name, pressed_value))
	button.button_up.connect(_set_touch_control.bind(control_name, released_value))
	add_child(button)
func _set_touch_control(control_name: String, value: Variant) -> void:
	_touch_input[control_name] = value
func _restart() -> void:
	_state = Rules.new_race(int(_state.get("track_index", 0)))
	_notice = ""
	_update_hud()
	queue_redraw()
func _next_track() -> void:
	var next_state: Dictionary = Rules.next_track(_state)
	if int(next_state.get("track_index", 0)) == int(_state.get("track_index", 0)):
		_notice = "Complete the lap before advancing."
	else:
		_state = next_state
		_notice = ""
	_update_hud()
	queue_redraw()
func get_current_state() -> Dictionary:
	return _state.duplicate(true)
func _update_hud() -> void:
	if _telemetry_label == null or _status_label == null:
		return
	var track: Dictionary = Rules.get_track(int(_state.get("track_index", 0)))
	var speed: int = roundi(Vector2(_state.get("velocity", Vector2.ZERO)).length())
	var checkpoints: Array = track.get("checkpoints", [])
	var checkpoint_number: int = mini(int(_state.get("next_checkpoint", 0)) + 1, checkpoints.size())
	_telemetry_label.text = "%s   SPEED %03d   TIME %05.2f   CHECKPOINT %d/%d" % [str(track.get("name", "TRACK")), speed, float(_state.get("elapsed", 0.0)), checkpoint_number, checkpoints.size()]
	if str(_state.get("status", "")) == "finished":
		_status_label.text = "LAP COMPLETE  //  Press NEXT for the next course."
	else:
		_status_label.text = _notice if not _notice.is_empty() else "WASD / ARROWS: DRIVE    SPACE: DRIFT    R: RESTART    N: NEXT AFTER FINISH"
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960.0, 720.0)), Color("#08121a"), true)
	if _state.is_empty():
		return
	var track: Dictionary = Rules.get_track(int(_state.get("track_index", 0)))
	var center: Vector2 = track["center"]
	var outer: Vector2 = track["outer"]
	var inner: Vector2 = track["inner"]
	var outer_points: PackedVector2Array = Rules.ellipse_points(center, outer)
	var inner_points: PackedVector2Array = Rules.ellipse_points(center, inner)
	var mid_points: PackedVector2Array = Rules.ellipse_points(center, (outer + inner) * 0.5)
	draw_colored_polygon(outer_points, Color("#263945"))
	draw_colored_polygon(inner_points, Color("#08121a"))
	draw_polyline(_close_points(outer_points), Color("#78c7d8"), 4.0, true)
	draw_polyline(_close_points(inner_points), Color("#78c7d8"), 4.0, true)
	draw_polyline(_close_points(mid_points), Color("#526b76"), 2.0, true)
	var checkpoints: Array = track.get("checkpoints", [])
	for index in range(checkpoints.size()):
		var point: Vector2 = checkpoints[index]
		var active: bool = index == int(_state.get("next_checkpoint", 0)) and str(_state.get("status", "")) == "racing"
		draw_circle(point, 19.0, Color("#f5b84c") if active else Color("#315e6b"))
		draw_arc(point, 26.0, 0.0, TAU, 32, Color("#f4f7fa"), 2.0, true)
		var font: Font = get_theme_default_font()
		if font != null:
			draw_string(font, point + Vector2(-4.0, 5.0), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("#07121a"))
	var start: Vector2 = track["start"]
	draw_line(start + Vector2(-34.0, 0.0), start + Vector2(34.0, 0.0), Color("#ffffff"), 4.0)
	var car_position: Vector2 = _state.get("position", start)
	var car_heading: float = float(_state.get("heading", PI))
	draw_set_transform(car_position, car_heading, Vector2.ONE)
	draw_rect(Rect2(-16.0, -9.0, 32.0, 18.0), Color("#4de0ff"), true)
	draw_rect(Rect2(5.0, -6.0, 8.0, 12.0), Color("#f5b84c"), true)
	draw_rect(Rect2(-10.0, -6.0, 7.0, 12.0), Color("#1a3542"), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
func _close_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed

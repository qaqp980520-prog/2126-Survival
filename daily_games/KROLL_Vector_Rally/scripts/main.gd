extends Node2D

const Rules = preload("res://scripts/rules.gd")
const VIEW_SIZE := Vector2(800.0, 650.0)
const TRACK_CENTER := Vector2(400.0, 350.0)
const TRACK_RADIUS_X: float = 240.0
const TRACK_RADIUS_Y: float = 168.0
const MAX_SPEED: float = 300.0
const CHECKPOINTS: Array[Vector2] = [
	Vector2(400.0, 518.0),
	Vector2(640.0, 350.0),
	Vector2(400.0, 182.0),
	Vector2(160.0, 350.0)
]
const BOOST_PADS: Array[Vector2] = [Vector2(550.0, 468.0), Vector2(250.0, 232.0)]

var car_position: Vector2 = Vector2(400.0, 518.0)
var car_velocity: Vector2 = Vector2.ZERO
var car_angle: float = 0.0
var elapsed_seconds: float = 0.0
var lap_count: int = 0
var next_checkpoint: int = 1
var boost_cooldown: float = 0.0
var boost_count: int = 0
var off_track: bool = false
var finished: bool = false
var time_up: bool = false
var _touch_controls: Dictionary = {}

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	var controls: Dictionary = _read_controls()
	step_game(delta, float(controls.get("steer", 0.0)), bool(controls.get("accelerate", false)), bool(controls.get("brake", false)))

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			start_game()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var control_name: String = _control_at(touch.position)
			if not control_name.is_empty():
				_touch_controls[touch.index] = control_name
		else:
			_touch_controls.erase(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var control_name: String = _control_at(drag.position)
		if control_name.is_empty():
			_touch_controls.erase(drag.index)
		else:
			_touch_controls[drag.index] = control_name
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				var control_name: String = _control_at(mouse_event.position)
				if not control_name.is_empty():
					_touch_controls[-1] = control_name
			else:
				_touch_controls.erase(-1)

func _read_controls() -> Dictionary:
	var steer := 0.0
	var left_down: bool = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var right_down: bool = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var accelerate_down: bool = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var brake_down: bool = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	for value in _touch_controls.values():
		match str(value):
			"left":
				left_down = true
			"right":
				right_down = true
			"accelerate":
				accelerate_down = true
			"brake":
				brake_down = true
	if left_down:
		steer -= 1.0
	if right_down:
		steer += 1.0
	return {"steer": steer, "accelerate": accelerate_down, "brake": brake_down}

func _control_at(position: Vector2) -> String:
	if position.y < 560.0:
		return ""
	if position.x >= 18.0 and position.x < 150.0:
		return "left"
	if position.x >= 158.0 and position.x < 300.0:
		return "right"
	if position.x >= 520.0 and position.x < 646.0:
		return "accelerate"
	if position.x >= 654.0 and position.x < 780.0:
		return "brake"
	return ""

func step_game(delta: float, steer: float, accelerate: bool, brake: bool) -> void:
	if finished or time_up or delta <= 0.0:
		return
	elapsed_seconds += delta
	if elapsed_seconds >= Rules.TIME_LIMIT_SECONDS:
		elapsed_seconds = maxf(elapsed_seconds, Rules.TIME_LIMIT_SECONDS)
		time_up = true
		queue_redraw()
		return
	boost_cooldown = maxf(0.0, boost_cooldown - delta)
	var speed_before_turn: float = car_velocity.length()
	if absf(steer) > 0.01 and speed_before_turn > 8.0:
		var steering_factor: float = clampf(speed_before_turn / 90.0, 0.25, 1.2)
		car_angle += steer * 2.35 * steering_factor * delta
	var forward := Vector2(cos(car_angle), sin(car_angle))
	if accelerate:
		car_velocity += forward * 245.0 * delta
	if brake:
		car_velocity = car_velocity.move_toward(Vector2.ZERO, 330.0 * delta)
	car_velocity = car_velocity.move_toward(Vector2.ZERO, 14.0 * delta)
	var speed: float = car_velocity.length()
	if speed > MAX_SPEED:
		car_velocity = car_velocity.normalized() * MAX_SPEED
	car_position += car_velocity * delta
	var normalized_radius: float = _normalized_track_radius(car_position)
	off_track = Rules.is_off_track(normalized_radius)
	if off_track:
		car_velocity *= pow(0.82, delta * 60.0)
	for gate_index in range(CHECKPOINTS.size()):
		if car_position.distance_to(CHECKPOINTS[gate_index]) <= 36.0:
			_try_checkpoint(gate_index)
			break
	for pad_position in BOOST_PADS:
		if car_position.distance_to(pad_position) <= 28.0 and Rules.can_activate_boost(car_velocity.length(), boost_cooldown):
			car_velocity += forward * 100.0
			if car_velocity.length() > MAX_SPEED:
				car_velocity = car_velocity.normalized() * MAX_SPEED
			boost_cooldown = 1.2
			boost_count += 1
			break
	if lap_count >= Rules.LAPS_TO_WIN:
		finished = true
	queue_redraw()

func _normalized_track_radius(position: Vector2) -> float:
	var relative: Vector2 = position - TRACK_CENTER
	var normalized_x: float = relative.x / TRACK_RADIUS_X
	var normalized_y: float = relative.y / TRACK_RADIUS_Y
	return sqrt(normalized_x * normalized_x + normalized_y * normalized_y)

func _try_checkpoint(gate_index: int) -> bool:
	var result: Dictionary = Rules.apply_checkpoint(next_checkpoint, lap_count, gate_index)
	if not bool(result.get("accepted", false)):
		return false
	next_checkpoint = int(result["next_checkpoint"])
	lap_count = int(result["lap_count"])
	finished = bool(result["finished"])
	queue_redraw()
	return true

func debug_enter_checkpoint(gate_index: int) -> bool:
	return _try_checkpoint(gate_index)

func debug_set_car_state(position: Vector2, velocity: Vector2, angle: float = 0.0) -> void:
	car_position = position
	car_velocity = velocity
	car_angle = angle
	queue_redraw()

func debug_step(delta: float, steer: float = 0.0, accelerate: bool = false, brake: bool = false) -> void:
	step_game(delta, steer, accelerate, brake)

func start_game() -> void:
	car_position = Vector2(400.0, 518.0)
	car_velocity = Vector2.ZERO
	car_angle = 0.0
	elapsed_seconds = 0.0
	lap_count = 0
	next_checkpoint = 1
	boost_cooldown = 0.0
	boost_count = 0
	off_track = false
	finished = false
	time_up = false
	_touch_controls.clear()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.012, 0.022, 0.04))
	draw_circle(TRACK_CENTER, 286.0, Color(0.025, 0.055, 0.075))
	draw_set_transform(TRACK_CENTER, 0.0, Vector2(1.0, 0.7))
	draw_arc(Vector2.ZERO, 240.0, 0.0, TAU, 144, Color(0.10, 0.16, 0.22), 58.0, true)
	draw_arc(Vector2.ZERO, 210.0, 0.0, TAU, 144, Color(0.18, 0.25, 0.31), 2.0, true)
	draw_arc(Vector2.ZERO, 270.0, 0.0, TAU, 144, Color(0.18, 0.25, 0.31), 2.0, true)
	draw_arc(Vector2.ZERO, 240.0, 0.0, TAU, 144, Color(0.22, 0.45, 0.52), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for gate_index in range(CHECKPOINTS.size()):
		var gate_color: Color = Color(0.18, 0.88, 1.0) if gate_index == next_checkpoint else Color(0.24, 0.34, 0.42)
		match gate_index:
			0:
				draw_line(Vector2(400.0, 482.0), Vector2(400.0, 552.0), gate_color, 5.0, true)
			1:
				draw_line(Vector2(604.0, 350.0), Vector2(676.0, 350.0), gate_color, 5.0, true)
			2:
				draw_line(Vector2(400.0, 148.0), Vector2(400.0, 218.0), gate_color, 5.0, true)
			3:
				draw_line(Vector2(124.0, 350.0), Vector2(196.0, 350.0), gate_color, 5.0, true)
	for pad_position in BOOST_PADS:
		draw_circle(pad_position, 18.0, Color(0.08, 0.65, 0.38, 0.8))
		draw_circle(pad_position, 8.0, Color(0.3, 1.0, 0.62))
	draw_set_transform(car_position, car_angle, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(19.0, 0.0), Vector2(-12.0, -10.0), Vector2(-8.0, 0.0), Vector2(-12.0, 10.0)]), Color(0.28, 0.9, 1.0))
	draw_line(Vector2(-8.0, -5.0), Vector2(-8.0, 5.0), Color(0.02, 0.08, 0.12), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var remaining: float = maxf(0.0, Rules.TIME_LIMIT_SECONDS - elapsed_seconds)
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 30.0), "KROLL VECTOR RALLY", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.45, 0.94, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 57.0), "LAP %d/%d   TIME %.1f   BOOSTS %d" % [mini(lap_count + 1, Rules.LAPS_TO_WIN), Rules.LAPS_TO_WIN, remaining, boost_count], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.78, 0.9, 0.95))
	var next_label: String = "FINISH" if finished else ("TIME UP" if time_up else "NEXT GATE %d" % next_checkpoint)
	if off_track and not finished and not time_up:
		next_label += "   OFF TRACK - SLOW"
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 82.0), next_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.7, 0.3) if off_track else Color(0.58, 0.76, 0.84))
	_draw_button(Rect2(18.0, 570.0, 132.0, 62.0), "LEFT", Color(0.12, 0.28, 0.36))
	_draw_button(Rect2(158.0, 570.0, 132.0, 62.0), "RIGHT", Color(0.12, 0.28, 0.36))
	_draw_button(Rect2(520.0, 570.0, 126.0, 62.0), "THROTTLE", Color(0.08, 0.34, 0.24))
	_draw_button(Rect2(654.0, 570.0, 126.0, 62.0), "BRAKE", Color(0.35, 0.18, 0.16))
	if finished:
		draw_string(ThemeDB.fallback_font, Vector2(255.0, 330.0), "RACE COMPLETE - PRESS R", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.5, 1.0, 0.72))
	elif time_up:
		draw_string(ThemeDB.fallback_font, Vector2(285.0, 330.0), "TIME UP - PRESS R", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.55, 0.38))

func _draw_button(rect: Rect2, label: String, color: Color) -> void:
	draw_rect(rect, color, true, 8.0)
	draw_rect(rect, Color(0.35, 0.7, 0.82), false, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(18.0, 38.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.88, 0.97, 1.0))

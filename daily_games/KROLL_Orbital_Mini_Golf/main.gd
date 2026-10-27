extends Node2D

const Rules = preload("res://rules.gd")
const COURSE_RECT := Rect2(Vector2(36.0, 72.0), Vector2(888.0, 600.0))
const INNER_MIN := Vector2(45.0, 81.0)
const INNER_MAX := Vector2(915.0, 663.0)

var course_index: int = 0
var ball_position: Vector2 = Vector2(100.0, 610.0)
var ball_velocity: Vector2 = Vector2.ZERO
var hole_position: Vector2 = Vector2(840.0, 110.0)
var obstacles: Array[Rect2] = []
var shots_this_course: int = 0
var total_shots: int = 0
var elapsed_seconds: float = 0.0
var status: String = "playing"
var message: String = "Pull back from the ball, then release to shoot."
var _dragging: bool = false
var _drag_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_reset_game()

func _process(delta: float) -> void:
	if status != "playing":
		return
	elapsed_seconds = minf(Rules.TIME_LIMIT, elapsed_seconds + maxf(delta, 0.0))
	if elapsed_seconds >= Rules.TIME_LIMIT:
		status = "failed"
		message = "Time expired. Press R to retry."
	queue_redraw()

func _physics_process(delta: float) -> void:
	if status != "playing":
		return
	if ball_velocity.length_squared() > 0.0:
		ball_position += ball_velocity * delta
		_collide_bounds()
		for obstacle in obstacles:
			_collide_obstacle(obstacle)
		ball_velocity = Rules.apply_friction(ball_velocity, delta)
	if shots_this_course > 0 and Rules.can_sink(ball_position.distance_to(hole_position), ball_velocity.length()):
		_sink_course()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_R:
			_reset_game()
			return
		if status != "playing" or ball_velocity.length() >= Rules.STOP_SPEED:
			return
		var direction := Vector2.ZERO
		match key_event.keycode:
			KEY_W, KEY_UP:
				direction = Vector2.UP
			KEY_S, KEY_DOWN:
				direction = Vector2.DOWN
			KEY_A, KEY_LEFT:
				direction = Vector2.LEFT
			KEY_D, KEY_RIGHT:
				direction = Vector2.RIGHT
			KEY_SPACE:
				direction = (hole_position - ball_position).normalized()
		if direction != Vector2.ZERO:
			_launch(direction * 320.0)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_begin_aim(mouse_event.position)
		elif _dragging:
			_drag_position = mouse_event.position
			_launch(Rules.calculate_shot_velocity(ball_position, _drag_position))
	elif event is InputEventMouseMotion and _dragging:
		_drag_position = (event as InputEventMouseMotion).position
		queue_redraw()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_aim(touch_event.position)
		elif _dragging:
			_drag_position = touch_event.position
			_launch(Rules.calculate_shot_velocity(ball_position, _drag_position))
	elif event is InputEventScreenDrag and _dragging:
		_drag_position = (event as InputEventScreenDrag).position
		queue_redraw()

func _begin_aim(pointer_position: Vector2) -> void:
	if status != "playing" or ball_velocity.length() >= Rules.STOP_SPEED:
		return
	if pointer_position.distance_to(ball_position) > 42.0:
		return
	_dragging = true
	_drag_position = pointer_position
	queue_redraw()

func _launch(velocity: Vector2) -> void:
	if status != "playing" or ball_velocity.length() >= Rules.STOP_SPEED:
		return
	if velocity.length() < Rules.STOP_SPEED:
		_dragging = false
		queue_redraw()
		return
	ball_velocity = velocity.limit_length(Rules.MAX_SHOT_SPEED)
	shots_this_course += 1
	total_shots += 1
	_dragging = false
	message = "Shot %d on course %d." % [shots_this_course, course_index + 1]
	queue_redraw()

func _collide_bounds() -> void:
	if ball_position.x < INNER_MIN.x:
		ball_position.x = INNER_MIN.x
		ball_velocity.x = absf(ball_velocity.x) * Rules.WALL_RESTITUTION
	elif ball_position.x > INNER_MAX.x:
		ball_position.x = INNER_MAX.x
		ball_velocity.x = -absf(ball_velocity.x) * Rules.WALL_RESTITUTION
	if ball_position.y < INNER_MIN.y:
		ball_position.y = INNER_MIN.y
		ball_velocity.y = absf(ball_velocity.y) * Rules.WALL_RESTITUTION
	elif ball_position.y > INNER_MAX.y:
		ball_position.y = INNER_MAX.y
		ball_velocity.y = -absf(ball_velocity.y) * Rules.WALL_RESTITUTION

func _collide_obstacle(rect: Rect2) -> void:
	var closest := Vector2(
		clampf(ball_position.x, rect.position.x, rect.end.x),
		clampf(ball_position.y, rect.position.y, rect.end.y)
	)
	var offset: Vector2 = ball_position - closest
	if offset.length() >= Rules.BALL_RADIUS:
		return
	var normal: Vector2
	if offset.length_squared() <= 0.000001:
		normal = -ball_velocity.normalized() if ball_velocity.length_squared() > 0.000001 else Vector2.UP
	else:
		normal = offset.normalized()
	ball_position = closest + normal * Rules.BALL_RADIUS
	if ball_velocity.dot(normal) < 0.0:
		ball_velocity = Rules.reflect_velocity(ball_velocity, normal, Rules.OBSTACLE_RESTITUTION)

func _sink_course() -> void:
	if shots_this_course > Rules.MAX_STROKES_PER_COURSE:
		status = "failed"
		message = "Too many strokes. Press R to retry."
		return
	course_index += 1
	if course_index >= Rules.COURSE_COUNT:
		status = "won"
		message = "All three courses cleared!"
		return
	_load_course()
	message = "Course %d cleared. Next tee!" % course_index

func _reset_game() -> void:
	course_index = 0
	total_shots = 0
	elapsed_seconds = 0.0
	status = "playing"
	_dragging = false
	message = "Pull back from the ball, then release to shoot."
	_load_course()
	queue_redraw()

func _load_course() -> void:
	var data: Dictionary = _course_data(course_index)
	ball_position = data["start"]
	ball_velocity = Vector2.ZERO
	hole_position = data["hole"]
	obstacles.clear()
	for obstacle in data["obstacles"]:
		obstacles.append(obstacle)
	shots_this_course = 0
	_dragging = false
	queue_redraw()

func _course_data(index: int) -> Dictionary:
	match index:
		0:
			return {
				"start": Vector2(100.0, 610.0),
				"hole": Vector2(840.0, 110.0),
				"obstacles": [
					Rect2(200.0, 500.0, 270.0, 24.0),
					Rect2(470.0, 340.0, 24.0, 184.0),
					Rect2(590.0, 230.0, 220.0, 24.0)
				]
			}
		1:
			return {
				"start": Vector2(110.0, 110.0),
				"hole": Vector2(840.0, 610.0),
				"obstacles": [
					Rect2(220.0, 160.0, 24.0, 300.0),
					Rect2(300.0, 438.0, 270.0, 24.0),
					Rect2(620.0, 300.0, 24.0, 260.0)
				]
			}
		_:
			return {
				"start": Vector2(100.0, 610.0),
				"hole": Vector2(840.0, 110.0),
				"obstacles": [
					Rect2(200.0, 540.0, 24.0, 80.0),
					Rect2(200.0, 500.0, 260.0, 24.0),
					Rect2(440.0, 360.0, 24.0, 164.0),
					Rect2(500.0, 360.0, 250.0, 24.0),
					Rect2(730.0, 190.0, 24.0, 170.0)
				]
			}

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960.0, 720.0)), Color("#07111e"), true)
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(36.0, 35.0), "KROLL // ORBITAL MINI GOLF", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#8deaff"))
	draw_string(font, Vector2(36.0, 57.0), "Three courses • pull back and release • sink slowly to score", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c2d7e8"))
	draw_rect(COURSE_RECT, Color("#102d35"), true)
	draw_rect(COURSE_RECT, Color("#62e8ce"), false, 3.0)
	for x in range(60, 920, 40):
		draw_line(Vector2(float(x), 75.0), Vector2(float(x), 669.0), Color(0.18, 0.39, 0.41, 0.22), 1.0)
	for y in range(100, 670, 40):
		draw_line(Vector2(40.0, float(y)), Vector2(920.0, float(y)), Color(0.18, 0.39, 0.41, 0.22), 1.0)
	for obstacle in obstacles:
		draw_rect(obstacle.grow(4.0), Color(0.1, 0.72, 0.7, 0.18), true)
		draw_rect(obstacle, Color("#23646a"), true)
		draw_rect(obstacle, Color("#63d8d0"), false, 2.0)
	draw_circle(hole_position, Rules.HOLE_RADIUS + 5.0, Color(0.2, 0.95, 0.84, 0.2))
	draw_circle(hole_position, Rules.HOLE_RADIUS, Color("#02070c"))
	draw_circle(hole_position, 7.0, Color("#142b36"))
	if _dragging:
		draw_line(ball_position, _drag_position, Color("#ffd166"), 3.0)
		var preview: Vector2 = Rules.calculate_shot_velocity(ball_position, _drag_position)
		if preview.length() > 0.0:
			draw_line(ball_position, ball_position + preview.normalized() * minf(preview.length() * 0.22, 100.0), Color(1.0, 0.82, 0.35, 0.75), 2.0)
	draw_circle(ball_position, Rules.BALL_RADIUS + 4.0, Color(0.55, 0.93, 1.0, 0.22))
	draw_circle(ball_position, Rules.BALL_RADIUS, Color("#eaf8ff"))
	draw_circle(ball_position + Vector2(-2.5, -2.5), 2.5, Color("#ffffff"))
	draw_string(font, Vector2(680.0, 35.0), "COURSE %d / %d" % [mini(course_index + 1, Rules.COURSE_COUNT), Rules.COURSE_COUNT], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ffd166"))
	draw_string(font, Vector2(680.0, 58.0), "STROKES %d   TOTAL %d" % [shots_this_course, total_shots], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d8eaf5"))
	draw_string(font, Vector2(36.0, 698.0), "TIME %ds   WASD/ARROWS shoot • SPACE aims at hole • drag ball backwards • R restart" % ceili(maxf(0.0, Rules.TIME_LIMIT - elapsed_seconds)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c2d7e8"))
	draw_string(font, Vector2(36.0, 718.0), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#63d8d0") if status == "playing" else (Color("#63e6ba") if status == "won" else Color("#ff7a86")))
	if status == "won":
		draw_string(font, Vector2(380.0, 390.0), "EXPEDITION COMPLETE", HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color("#63e6ba"))
	elif status == "failed":
		draw_string(font, Vector2(420.0, 390.0), "COURSE FAILED — R TO RETRY", HORIZONTAL_ALIGNMENT_CENTER, -1, 23, Color("#ff7a86"))

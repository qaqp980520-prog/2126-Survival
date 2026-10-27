extends Node2D

const Rules = preload("res://rules.gd")
const BALL_RADIUS: float = 8.0
const PADDLE_SIZE := Vector2(112.0, 14.0)
const BRICK_COLUMNS: int = 8
const BRICK_ROWS: int = 5
const BRICK_GAP: float = 7.0
const BRICK_HEIGHT: float = 22.0
const PADDLE_SPEED: float = 560.0
const ROUND_SECONDS: float = 60.0

var bricks: Array[Dictionary] = []
var paddle_center_x: float = 480.0
var ball_position: Vector2 = Vector2(480.0, 500.0)
var ball_velocity: Vector2 = Vector2.ZERO
var score: int = 0
var lives: int = 3
var time_left: float = ROUND_SECONDS
var state: String = "ready"

func _ready() -> void:
	restart_game()

func _process(delta: float) -> void:
	var field_size := get_viewport_rect().size
	if state != "won" and state != "lost":
		time_left = maxf(0.0, time_left - delta)
		if Rules.time_expired(time_left):
			state = "lost"

	if state == "playing":
		var direction := 0.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			direction -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			direction += 1.0
		paddle_center_x += direction * PADDLE_SPEED * delta
		paddle_center_x = Rules.clamp_paddle_center(paddle_center_x, PADDLE_SIZE.x * 0.5, field_size.x)
		_advance_ball(delta)
	elif state == "ready":
		paddle_center_x = Rules.clamp_paddle_center(paddle_center_x, PADDLE_SIZE.x * 0.5, field_size.x)
		ball_position = Vector2(paddle_center_x, _paddle_y() - BALL_RADIUS - 2.0)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			restart_game()
			return
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			launch_ball()
			return

	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		if mouse_event.position.y < get_viewport_rect().size.y - 78.0:
			paddle_center_x = Rules.clamp_paddle_center(mouse_event.position.x, PADDLE_SIZE.x * 0.5, get_viewport_rect().size.x)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer_press((event as InputEventMouseButton).position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_pointer_press((event as InputEventScreenTouch).position)

func _handle_pointer_press(position: Vector2) -> void:
	var size := get_viewport_rect().size
	var left_button := Rect2(Vector2(18.0, size.y - 62.0), Vector2(88.0, 42.0))
	var right_button := Rect2(Vector2(112.0, size.y - 62.0), Vector2(88.0, 42.0))
	var launch_button := Rect2(Vector2(size.x - 142.0, size.y - 62.0), Vector2(124.0, 42.0))
	if left_button.has_point(position):
		paddle_center_x -= 58.0
	elif right_button.has_point(position):
		paddle_center_x += 58.0
	elif launch_button.has_point(position):
		launch_ball()
	else:
		paddle_center_x = Rules.clamp_paddle_center(position.x, PADDLE_SIZE.x * 0.5, size.x)
		if state == "ready":
			launch_ball()

func launch_ball() -> bool:
	if state != "ready" or time_left <= 0.0 or lives <= 0:
		return false
	ball_position = Vector2(paddle_center_x, _paddle_y() - BALL_RADIUS - 2.0)
	ball_velocity = Vector2(190.0, -350.0)
	state = "playing"
	return true

func restart_game() -> void:
	score = 0
	lives = 3
	time_left = ROUND_SECONDS
	state = "ready"
	paddle_center_x = get_viewport_rect().size.x * 0.5
	ball_velocity = Vector2.ZERO
	_build_bricks()
	_reset_ball()
	queue_redraw()

func _build_bricks() -> void:
	bricks.clear()
	var width := get_viewport_rect().size.x
	var margin := 34.0
	var brick_width := (width - margin * 2.0 - BRICK_GAP * float(BRICK_COLUMNS - 1)) / float(BRICK_COLUMNS)
	for row in range(BRICK_ROWS):
		for column in range(BRICK_COLUMNS):
			var rect := Rect2(
				Vector2(margin + float(column) * (brick_width + BRICK_GAP), 76.0 + float(row) * (BRICK_HEIGHT + BRICK_GAP)),
				Vector2(brick_width, BRICK_HEIGHT)
			)
			var tint := Color.from_hsv(float(row) / float(BRICK_ROWS), 0.72, 0.98)
			bricks.append({"rect": rect, "color": tint})

func _reset_ball() -> void:
	ball_position = Vector2(paddle_center_x, _paddle_y() - BALL_RADIUS - 2.0)
	ball_velocity = Vector2.ZERO

func _paddle_y() -> float:
	return get_viewport_rect().size.y - 112.0

func _paddle_rect() -> Rect2:
	return Rect2(Vector2(paddle_center_x - PADDLE_SIZE.x * 0.5, _paddle_y()), PADDLE_SIZE)

func _advance_ball(delta: float) -> void:
	if delta <= 0.0 or state != "playing":
		return
	var field_size := get_viewport_rect().size
	var previous_position := ball_position
	ball_position += ball_velocity * delta

	if ball_position.x - BALL_RADIUS < 12.0:
		ball_position.x = 12.0 + BALL_RADIUS
		ball_velocity.x = absf(ball_velocity.x)
	elif ball_position.x + BALL_RADIUS > field_size.x - 12.0:
		ball_position.x = field_size.x - 12.0 - BALL_RADIUS
		ball_velocity.x = -absf(ball_velocity.x)

	if ball_position.y - BALL_RADIUS < 12.0:
		ball_position.y = 12.0 + BALL_RADIUS
		ball_velocity.y = absf(ball_velocity.y)

	var paddle := _paddle_rect()
	if ball_velocity.y > 0.0 and paddle.grow(BALL_RADIUS).has_point(ball_position) and previous_position.y <= paddle.position.y + BALL_RADIUS:
		ball_position.y = paddle.position.y - BALL_RADIUS - 1.0
		var offset := (ball_position.x - paddle_center_x) / (PADDLE_SIZE.x * 0.5)
		ball_velocity = Rules.paddle_bounce(offset, 62.0, maxf(360.0, ball_velocity.length()))

	for index in range(bricks.size() - 1, -1, -1):
		var brick: Dictionary = bricks[index]
		var rect: Rect2 = brick["rect"]
		if not rect.grow(BALL_RADIUS).has_point(ball_position):
			continue
		if previous_position.y + BALL_RADIUS <= rect.position.y or previous_position.y - BALL_RADIUS >= rect.end.y:
			ball_velocity.y = -ball_velocity.y
		else:
			ball_velocity.x = -ball_velocity.x
		bricks.remove_at(index)
		score += 10
		if Rules.all_bricks_cleared(bricks.size()):
			state = "won"
		break

	if Rules.has_lost_ball(ball_position.y, field_size.y - 78.0, BALL_RADIUS):
		lives = Rules.remaining_lives(lives)
		if lives <= 0:
			state = "lost"
			ball_velocity = Vector2.ZERO
		else:
			state = "ready"
			_reset_ball()

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.03, 0.075, 1.0), true)
	for x in range(0, int(size.x), 40):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), size.y - 76.0), Color(0.12, 0.2, 0.32, 0.18), 1.0)
	for y in range(0, int(size.y - 76.0), 40):
		draw_line(Vector2(0.0, float(y)), Vector2(size.x, float(y)), Color(0.12, 0.2, 0.32, 0.18), 1.0)

	_draw_text("KROLL // NEON BREAKER", Vector2(22.0, 30.0), 22, Color(0.36, 0.92, 1.0))
	_draw_text("SCORE %04d     LIVES %d     TIME %02d     BRICKS %02d" % [score, lives, int(ceil(time_left)), bricks.size()], Vector2(22.0, 54.0), 15, Color(0.82, 0.9, 1.0))

	for brick in bricks:
		var rect: Rect2 = brick["rect"]
		var tint: Color = brick["color"]
		draw_rect(rect, tint.darkened(0.48), true)
		draw_rect(rect, tint, false, 2.0)
		draw_line(rect.position + Vector2(5.0, 4.0), Vector2(rect.end.x - 5.0, rect.position.y + 4.0), tint.lightened(0.3), 1.0)

	var paddle := _paddle_rect()
	draw_rect(paddle.grow(3.0), Color(0.08, 0.7, 0.95, 0.18), true)
	draw_rect(paddle, Color(0.35, 0.92, 1.0), true)
	draw_circle(ball_position, BALL_RADIUS + 4.0, Color(0.4, 0.9, 1.0, 0.15))
	draw_circle(ball_position, BALL_RADIUS, Color(0.94, 0.98, 1.0))

	var control_y := size.y - 62.0
	_draw_button(Rect2(Vector2(18.0, control_y), Vector2(88.0, 42.0)), "◀ LEFT")
	_draw_button(Rect2(Vector2(112.0, control_y), Vector2(88.0, 42.0)), "RIGHT ▶")
	_draw_button(Rect2(Vector2(size.x - 142.0, control_y), Vector2(124.0, 42.0)), "SPACE / LAUNCH")

	if state == "ready":
		_draw_text("PRESS SPACE OR TAP TO LAUNCH", Vector2(size.x * 0.5 - 172.0, size.y * 0.57), 18, Color(0.98, 0.82, 0.42))
	elif state == "won":
		_draw_text("SECTOR CLEARED  //  R TO REPLAY", Vector2(size.x * 0.5 - 178.0, size.y * 0.57), 20, Color(0.5, 1.0, 0.65))
	elif state == "lost":
		_draw_text("RUN ENDED  //  R TO REPLAY", Vector2(size.x * 0.5 - 160.0, size.y * 0.57), 20, Color(1.0, 0.42, 0.48))

func _draw_button(rect: Rect2, label: String) -> void:
	draw_rect(rect, Color(0.06, 0.16, 0.25, 0.95), true)
	draw_rect(rect, Color(0.24, 0.72, 0.88), false, 2.0)
	_draw_text(label, rect.position + Vector2(9.0, 26.0), 13, Color(0.82, 0.96, 1.0))

func _draw_text(text_value: String, position: Vector2, font_size: int, tint: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, tint)

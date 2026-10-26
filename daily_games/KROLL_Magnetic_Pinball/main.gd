extends Node2D

const Rules = preload("res://rules.gd")
const BALL_RADIUS: float = 11.0
const LEFT_PIVOT: Vector2 = Vector2(290.0, 820.0)
const RIGHT_PIVOT: Vector2 = Vector2(510.0, 820.0)
const FLIPPER_LENGTH: float = 132.0
const BUMPER_RADIUS: float = 31.0
const BUMPER_POSITIONS: Array[Vector2] = [
	Vector2(230.0, 285.0),
	Vector2(400.0, 230.0),
	Vector2(570.0, 330.0),
	Vector2(315.0, 470.0),
	Vector2(495.0, 510.0)
]

var ball_position: Vector2 = Vector2(700.0, 840.0)
var ball_velocity: Vector2 = Vector2.ZERO
var lives: int = 3
var score: int = 0
var ball_in_play: bool = false
var game_over: bool = false
var left_flipper_active: bool = false
var right_flipper_active: bool = false
var _bumper_cooldowns: Dictionary = {}
var _touch_points: Dictionary = {}
var _launch_count: int = 0

func _ready() -> void:
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_R:
		reset_game()
	elif event.keycode == KEY_SPACE and not ball_in_play and lives > 0:
		start_ball()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
			# The shooter lane is a dedicated touch launch area above the flippers.
			if not ball_in_play and not game_over and event.position.x >= 675.0 and event.position.y > 600.0 and event.position.y < 820.0:
				start_ball()
		else:
			_touch_points.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		_touch_points[event.index] = event.position
		queue_redraw()

func _physics_process(delta: float) -> void:
	left_flipper_active = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	right_flipper_active = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	for touch_value in _touch_points.values():
		var touch_position: Vector2 = touch_value
		if touch_position.y >= 850.0:
			if touch_position.x < 400.0:
				left_flipper_active = true
			else:
				right_flipper_active = true
	if ball_in_play and not game_over:
		step_simulation(delta)
	else:
		queue_redraw()

func start_ball() -> void:
	if lives <= 0 or game_over:
		return
	ball_position = Vector2(700.0, 840.0)
	ball_velocity = Vector2(-150.0, -620.0)
	ball_in_play = true
	_launch_count += 1
	queue_redraw()

func reset_game() -> void:
	ball_position = Vector2(700.0, 840.0)
	ball_velocity = Vector2.ZERO
	lives = 3
	score = 0
	ball_in_play = false
	game_over = false
	left_flipper_active = false
	right_flipper_active = false
	_bumper_cooldowns.clear()
	_touch_points.clear()
	_launch_count = 0
	queue_redraw()

func step_simulation(delta: float) -> void:
	if not ball_in_play or game_over:
		return
	var dt: float = clampf(delta, 0.0, 0.05)
	for key in _bumper_cooldowns.keys():
		_bumper_cooldowns[key] = maxf(0.0, float(_bumper_cooldowns[key]) - dt)

	ball_velocity.y += 520.0 * dt
	ball_position += ball_velocity * dt

	if ball_position.x < 60.0:
		ball_position.x = 60.0
		ball_velocity.x = absf(ball_velocity.x) * 0.82
	if ball_position.x > 740.0:
		ball_position.x = 740.0
		ball_velocity.x = -absf(ball_velocity.x) * 0.82
	if ball_position.y < 50.0:
		ball_position.y = 50.0
		ball_velocity.y = absf(ball_velocity.y) * 0.82

	# The right-hand shooter lane is separated from the playfield above the launch opening.
	if ball_position.y < 720.0 and ball_position.x > 675.0:
		ball_position.x = 675.0
		if ball_velocity.x > 0.0:
			ball_velocity.x = -absf(ball_velocity.x) * 0.8

	for index in range(BUMPER_POSITIONS.size()):
		var bumper: Vector2 = BUMPER_POSITIONS[index]
		if float(_bumper_cooldowns.get(index, 0.0)) > 0.0:
			continue
		var delta_to_bumper: Vector2 = ball_position - bumper
		var contact_distance: float = BALL_RADIUS + BUMPER_RADIUS
		if delta_to_bumper.length() >= contact_distance:
			continue
		var normal: Vector2 = delta_to_bumper.normalized()
		if normal.length_squared() < 0.001:
			normal = Vector2.UP
		ball_position = bumper + normal * (contact_distance + 0.5)
		ball_velocity = Rules.reflect_velocity(ball_velocity, normal, 0.9)
		ball_velocity += normal * 220.0
		score = Rules.bump_score(score, 100)
		_bumper_cooldowns[index] = 0.32

	var left_angle: float = -0.2 if not left_flipper_active else -0.82
	var right_angle: float = PI + 0.2 if not right_flipper_active else PI + 0.82
	_collide_flipper(LEFT_PIVOT, left_angle, 1, left_flipper_active)
	_collide_flipper(RIGHT_PIVOT, right_angle, -1, right_flipper_active)

	if Rules.is_ball_lost(ball_position.y, 955.0):
		lives -= 1
		ball_in_play = false
		ball_velocity = Vector2.ZERO
		ball_position = Vector2(700.0, 840.0)
		if lives <= 0:
			game_over = true
	queue_redraw()

func _collide_flipper(pivot: Vector2, angle: float, side: int, active: bool) -> void:
	if ball_velocity.y <= 0.0:
		return
	var endpoint: Vector2 = pivot + Vector2(cos(angle), sin(angle)) * FLIPPER_LENGTH
	if Rules.distance_to_segment(ball_position, pivot, endpoint) > BALL_RADIUS + 9.0:
		return
	var closest: Vector2 = _closest_point_on_segment(ball_position, pivot, endpoint)
	ball_position = closest + Vector2(0.0, -BALL_RADIUS - 1.0)
	ball_velocity = Rules.flipper_kick(ball_velocity, side, active)

func _closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var length_squared: float = ab.length_squared()
	if length_squared <= 0.0001:
		return a
	var t: float = clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return a + ab * t

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 800.0, 1000.0), Color("#07111e"))
	draw_rect(Rect2(40.0, 30.0, 720.0, 920.0), Color("#0b1b2b"))
	draw_rect(Rect2(40.0, 30.0, 720.0, 920.0), Color("#39d8d0"), false, 6.0)
	draw_line(Vector2(675.0, 50.0), Vector2(675.0, 720.0), Color("#27516a"), 5.0)
	draw_line(Vector2(60.0, 670.0), Vector2(270.0, 920.0), Color("#173c50"), 3.0)
	draw_line(Vector2(740.0, 670.0), Vector2(530.0, 920.0), Color("#173c50"), 3.0)

	for bumper in BUMPER_POSITIONS:
		draw_circle(bumper, BUMPER_RADIUS + 8.0, Color("#123b50"))
		draw_circle(bumper, BUMPER_RADIUS, Color("#21d4c8"))
		draw_circle(bumper, BUMPER_RADIUS - 10.0, Color("#e0fff9"))
		draw_circle(bumper, 5.0, Color("#ffffff"))

	var left_angle: float = -0.2 if not left_flipper_active else -0.82
	var right_angle: float = PI + 0.2 if not right_flipper_active else PI + 0.82
	var left_end: Vector2 = LEFT_PIVOT + Vector2(cos(left_angle), sin(left_angle)) * FLIPPER_LENGTH
	var right_end: Vector2 = RIGHT_PIVOT + Vector2(cos(right_angle), sin(right_angle)) * FLIPPER_LENGTH
	draw_line(LEFT_PIVOT, left_end, Color("#102e42"), 23.0, true)
	draw_line(LEFT_PIVOT, left_end, Color("#f3c969") if left_flipper_active else Color("#55e3d8"), 14.0, true)
	draw_line(RIGHT_PIVOT, right_end, Color("#102e42"), 23.0, true)
	draw_line(RIGHT_PIVOT, right_end, Color("#f3c969") if right_flipper_active else Color("#55e3d8"), 14.0, true)
	draw_circle(LEFT_PIVOT, 13.0, Color("#f6f8ff"))
	draw_circle(RIGHT_PIVOT, 13.0, Color("#f6f8ff"))

	draw_circle(ball_position, BALL_RADIUS + 3.0, Color("#5b8297"))
	draw_circle(ball_position, BALL_RADIUS, Color("#ffffff"))
	draw_circle(ball_position + Vector2(-3.0, -3.0), 3.0, Color("#8ffff2"))

	draw_string(ThemeDB.fallback_font, Vector2(70.0, 80.0), "KROLL // MAGNETIC PINBALL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 25, Color("#b9fff5"))
	draw_string(ThemeDB.fallback_font, Vector2(70.0, 116.0), "SCORE %06d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color("#ffffff"))
	draw_string(ThemeDB.fallback_font, Vector2(475.0, 116.0), "BALLS %d" % lives, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color("#f3c969"))
	draw_rect(Rect2(65.0, 850.0, 290.0, 72.0), Color(0.05, 0.15, 0.22, 0.88))
	draw_rect(Rect2(65.0, 850.0, 290.0, 72.0), Color("#55e3d8"), false, 2.0)
	draw_rect(Rect2(445.0, 850.0, 290.0, 72.0), Color(0.05, 0.15, 0.22, 0.88))
	draw_rect(Rect2(445.0, 850.0, 290.0, 72.0), Color("#55e3d8"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(82.0, 892.0), "A / LEFT  •  TOUCH", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("#b9fff5"))
	draw_string(ThemeDB.fallback_font, Vector2(462.0, 892.0), "D / RIGHT  •  TOUCH", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("#b9fff5"))
	draw_string(ThemeDB.fallback_font, Vector2(515.0, 610.0), "TOUCH TO LAUNCH", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("#8fb8c9"))
	if not ball_in_play and not game_over:
		draw_string(ThemeDB.fallback_font, Vector2(150.0, 600.0), "PRESS SPACE TO LAUNCH", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color("#ffffff"))
	if game_over:
		draw_rect(Rect2(110.0, 410.0, 580.0, 150.0), Color("#07111e"))
		draw_rect(Rect2(110.0, 410.0, 580.0, 150.0), Color("#f3c969"), false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(235.0, 465.0), "TABLE OVERLOAD", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, Color("#ffffff"))
		draw_string(ThemeDB.fallback_font, Vector2(220.0, 515.0), "PRESS R TO RESTART", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color("#55e3d8"))

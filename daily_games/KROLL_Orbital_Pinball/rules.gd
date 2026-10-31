extends RefCounted

const BOARD_WIDTH: float = 400.0
const BOARD_HEIGHT: float = 620.0
const BALL_RADIUS: float = 8.0
const GRAVITY: float = 520.0
const LEFT_WALL: float = 24.0
const RIGHT_WALL: float = 376.0
const TOP_WALL: float = 24.0
const DRAIN_Y: float = 610.0
const MAX_LIVES: int = 3

static func create_state(table_index: int = 0) -> Dictionary:
	var safe_table: int = posmod(table_index, 3)
	return {
		"table_index": safe_table,
		"ball": Vector2(340.0, 548.0),
		"velocity": Vector2.ZERO,
		"launched": false,
		"score": 0,
		"lives": MAX_LIVES,
		"game_over": false,
		"bumpers": get_bumpers(safe_table),
		"bumper_hits": 0
	}

static func get_bumpers(table_index: int) -> Array[Dictionary]:
	match posmod(table_index, 3):
		0:
			return [
				{"position": Vector2(110.0, 170.0), "radius": 24.0},
				{"position": Vector2(290.0, 170.0), "radius": 24.0},
				{"position": Vector2(200.0, 260.0), "radius": 28.0},
				{"position": Vector2(105.0, 355.0), "radius": 22.0},
				{"position": Vector2(295.0, 355.0), "radius": 22.0}
			]
		1:
			return [
				{"position": Vector2(200.0, 145.0), "radius": 30.0},
				{"position": Vector2(120.0, 250.0), "radius": 24.0},
				{"position": Vector2(280.0, 250.0), "radius": 24.0},
				{"position": Vector2(150.0, 370.0), "radius": 22.0},
				{"position": Vector2(250.0, 370.0), "radius": 22.0}
			]
		_:
			return [
				{"position": Vector2(85.0, 200.0), "radius": 22.0},
				{"position": Vector2(200.0, 190.0), "radius": 30.0},
				{"position": Vector2(315.0, 200.0), "radius": 22.0},
				{"position": Vector2(140.0, 340.0), "radius": 24.0},
				{"position": Vector2(260.0, 340.0), "radius": 24.0}
			]

static func launch(state: Dictionary) -> bool:
	if bool(state.get("launched", false)) or bool(state.get("game_over", false)) or int(state.get("lives", 0)) <= 0:
		return false
	state["ball"] = Vector2(340.0, 548.0)
	state["velocity"] = Vector2(-95.0, -560.0)
	state["launched"] = true
	return true

static func step(state: Dictionary, delta: float, left_flipper: bool, right_flipper: bool) -> Dictionary:
	if not bool(state.get("launched", false)) or bool(state.get("game_over", false)):
		return state
	var dt: float = clampf(delta, 0.0, 0.04)
	if dt <= 0.0:
		return state
	var ball: Vector2 = state.get("ball", Vector2(340.0, 548.0))
	var velocity: Vector2 = state.get("velocity", Vector2.ZERO)
	velocity.y += GRAVITY * dt
	ball += velocity * dt

	if ball.x < LEFT_WALL + BALL_RADIUS:
		ball.x = LEFT_WALL + BALL_RADIUS
		velocity.x = absf(velocity.x) * 0.88
	elif ball.x > RIGHT_WALL - BALL_RADIUS:
		ball.x = RIGHT_WALL - BALL_RADIUS
		velocity.x = -absf(velocity.x) * 0.88
	if ball.y < TOP_WALL + BALL_RADIUS:
		ball.y = TOP_WALL + BALL_RADIUS
		velocity.y = absf(velocity.y) * 0.82

	for bumper in state.get("bumpers", []):
		var center: Vector2 = bumper.get("position", Vector2.ZERO)
		var radius: float = float(bumper.get("radius", 24.0))
		var offset: Vector2 = ball - center
		var distance: float = offset.length()
		var contact_distance: float = radius + BALL_RADIUS
		if distance < contact_distance:
			var normal: Vector2 = offset.normalized() if distance > 0.001 else Vector2.UP
			velocity = velocity.bounce(normal) * 1.08 + normal * 90.0
			ball = center + normal * (contact_distance + 1.0)
			state["score"] = int(state.get("score", 0)) + 100
			state["bumper_hits"] = int(state.get("bumper_hits", 0)) + 1
			break

	if ball.y >= 500.0 and ball.y <= 570.0:
		if left_flipper and ball.x >= 45.0 and ball.x <= 190.0:
			ball.y = 490.0
			velocity = Vector2(190.0, -540.0)
			state["score"] = int(state.get("score", 0)) + 10
		elif right_flipper and ball.x >= 210.0 and ball.x <= 355.0:
			ball.y = 490.0
			velocity = Vector2(-190.0, -540.0)
			state["score"] = int(state.get("score", 0)) + 10

	if ball.y > DRAIN_Y:
		state["lives"] = maxi(0, int(state.get("lives", 0)) - 1)
		state["launched"] = false
		state["game_over"] = int(state["lives"]) <= 0
		ball = Vector2(340.0, 548.0)
		velocity = Vector2.ZERO

	state["ball"] = ball
	state["velocity"] = velocity
	return state

static func reset(state: Dictionary) -> Dictionary:
	return create_state(int(state.get("table_index", 0)))

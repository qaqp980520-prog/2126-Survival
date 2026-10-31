extends RefCounted

## Small, deterministic air-hockey simulation. All coordinates use an 800x600 arena.
const LEFT: float = 40.0
const RIGHT: float = 760.0
const TOP: float = 48.0
const BOTTOM: float = 552.0
const CENTER_X: float = 400.0
const CENTER_Y: float = 300.0
const PUCK_RADIUS: float = 11.0
const PADDLE_HALF_WIDTH: float = 58.0
const PADDLE_HALF_HEIGHT: float = 10.0
const PLAYER_PADDLE_Y: float = 520.0
const AI_PADDLE_Y: float = 80.0
const GOAL_HALF_WIDTH: float = 88.0
const BUMPER_RADIUS: float = 22.0
const PLAYER_SPEED: float = 620.0
const AI_SPEED: float = 390.0
const MAX_PUCK_SPEED: float = 620.0
const TARGET_SCORE: int = 5

const ARENAS: Array[Dictionary] = [
	{"name": "Dock Ring", "bumpers": []},
	{"name": "Reactor Pair", "bumpers": [Vector2(300.0, 300.0), Vector2(500.0, 300.0)]},
	{"name": "Split Orbit", "bumpers": [Vector2(400.0, 220.0), Vector2(400.0, 380.0), Vector2(270.0, 300.0), Vector2(530.0, 300.0)]}
]

static func create_state(arena_index: int = 0) -> Dictionary:
	var index: int = posmod(arena_index, ARENAS.size())
	return {
		"arena_index": index,
		"player_score": 0,
		"ai_score": 0,
		"player_x": CENTER_X,
		"ai_x": CENTER_X,
		"puck_position": Vector2(CENTER_X, CENTER_Y),
		"puck_velocity": Vector2(235.0, 205.0),
		"winner": ""
	}

static func get_arena(arena_index: int) -> Dictionary:
	return ARENAS[posmod(arena_index, ARENAS.size())].duplicate(true)

static func get_arena_name(arena_index: int) -> String:
	return str(get_arena(arena_index).get("name", "Unknown Arena"))

static func next_arena(state: Dictionary) -> Dictionary:
	return create_state(int(state.get("arena_index", 0)) + 1)

static func reset_match(state: Dictionary) -> Dictionary:
	return create_state(int(state.get("arena_index", 0)))

static func award_goal(state: Dictionary, player_scored: bool) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("winner", "")) != "":
		return next
	if player_scored:
		next["player_score"] = int(next.get("player_score", 0)) + 1
		if int(next["player_score"]) >= TARGET_SCORE:
			next["winner"] = "PLAYER"
	else:
		next["ai_score"] = int(next.get("ai_score", 0)) + 1
		if int(next["ai_score"]) >= TARGET_SCORE:
			next["winner"] = "AI"
	next["puck_position"] = Vector2(CENTER_X, CENTER_Y)
	next["puck_velocity"] = Vector2(0.0, 240.0 if player_scored else -240.0)
	return next

static func step(state: Dictionary, target_x: float, delta: float) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("winner", "")) != "":
		return next
	if not is_finite(delta) or delta <= 0.0 or not is_finite(target_x):
		return next
	var dt: float = minf(delta, 0.05)
	var player_x: float = float(next.get("player_x", CENTER_X))
	var ai_x: float = float(next.get("ai_x", CENTER_X))
	var puck_position: Vector2 = next.get("puck_position", Vector2(CENTER_X, CENTER_Y))
	var puck_velocity: Vector2 = next.get("puck_velocity", Vector2(0.0, 200.0))

	var player_target: float = clampf(target_x, LEFT + PADDLE_HALF_WIDTH, RIGHT - PADDLE_HALF_WIDTH)
	player_x = move_toward(player_x, player_target, PLAYER_SPEED * dt)
	if absf(puck_position.x - ai_x) > 7.0:
		ai_x = move_toward(ai_x, puck_position.x, AI_SPEED * dt)
	ai_x = clampf(ai_x, LEFT + PADDLE_HALF_WIDTH, RIGHT - PADDLE_HALF_WIDTH)

	puck_position += puck_velocity * dt
	if puck_position.x < LEFT + PUCK_RADIUS:
		puck_position.x = LEFT + PUCK_RADIUS
		puck_velocity.x = absf(puck_velocity.x)
	elif puck_position.x > RIGHT - PUCK_RADIUS:
		puck_position.x = RIGHT - PUCK_RADIUS
		puck_velocity.x = -absf(puck_velocity.x)

	var arena: Dictionary = get_arena(int(next.get("arena_index", 0)))
	var bumpers: Array = arena.get("bumpers", [])
	for bumper_value in bumpers:
		if not (bumper_value is Vector2):
			continue
		var bumper: Vector2 = bumper_value
		var offset: Vector2 = puck_position - bumper
		var minimum_distance: float = PUCK_RADIUS + BUMPER_RADIUS
		if offset.length() < minimum_distance:
			var normal: Vector2 = offset.normalized()
			if normal.length_squared() < 0.001:
				normal = Vector2.UP
			puck_position = bumper + normal * minimum_distance
			if puck_velocity.dot(normal) < 0.0:
				puck_velocity = puck_velocity.bounce(normal)

	if puck_velocity.y > 0.0 and puck_position.y + PUCK_RADIUS >= PLAYER_PADDLE_Y - PADDLE_HALF_HEIGHT and puck_position.y < PLAYER_PADDLE_Y and absf(puck_position.x - player_x) <= PADDLE_HALF_WIDTH + PUCK_RADIUS:
		var player_offset: float = clampf((puck_position.x - player_x) / PADDLE_HALF_WIDTH, -1.0, 1.0)
		puck_position.y = PLAYER_PADDLE_Y - PADDLE_HALF_HEIGHT - PUCK_RADIUS
		var player_bounce: Vector2 = Vector2(player_offset * 260.0, -maxf(absf(puck_velocity.y), 180.0)).normalized()
		puck_velocity = player_bounce * minf(MAX_PUCK_SPEED, maxf(260.0, puck_velocity.length() * 1.035))
	elif puck_velocity.y < 0.0 and puck_position.y - PUCK_RADIUS <= AI_PADDLE_Y + PADDLE_HALF_HEIGHT and puck_position.y > AI_PADDLE_Y and absf(puck_position.x - ai_x) <= PADDLE_HALF_WIDTH + PUCK_RADIUS:
		var ai_offset: float = clampf((puck_position.x - ai_x) / PADDLE_HALF_WIDTH, -1.0, 1.0)
		puck_position.y = AI_PADDLE_Y + PADDLE_HALF_HEIGHT + PUCK_RADIUS
		var ai_bounce: Vector2 = Vector2(ai_offset * 210.0, maxf(absf(puck_velocity.y), 180.0)).normalized()
		puck_velocity = ai_bounce * minf(MAX_PUCK_SPEED, maxf(250.0, puck_velocity.length() * 1.025))

	if puck_position.y < TOP - PUCK_RADIUS:
		if absf(puck_position.x - CENTER_X) <= GOAL_HALF_WIDTH:
			next["player_x"] = player_x
			next["ai_x"] = ai_x
			return award_goal(next, true)
		puck_position.y = TOP + PUCK_RADIUS
		puck_velocity.y = absf(puck_velocity.y)
	elif puck_position.y > BOTTOM + PUCK_RADIUS:
		if absf(puck_position.x - CENTER_X) <= GOAL_HALF_WIDTH:
			next["player_x"] = player_x
			next["ai_x"] = ai_x
			return award_goal(next, false)
		puck_position.y = BOTTOM - PUCK_RADIUS
		puck_velocity.y = -absf(puck_velocity.y)

	next["player_x"] = player_x
	next["ai_x"] = ai_x
	next["puck_position"] = puck_position
	next["puck_velocity"] = puck_velocity
	return next

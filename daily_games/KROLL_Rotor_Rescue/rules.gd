extends RefCounted
class_name RotorRescueRules

const MAX_SPEED: float = 180.0
const RESCUE_RADIUS: float = 28.0
const SAFE_RESCUE_SPEED: float = 60.0
const LANDING_RADIUS: float = 36.0
const SAFE_LANDING_SPEED: float = 45.0
const PAD_POSITION: Vector2 = Vector2(900.0, 430.0)
const WORLD_MIN: Vector2 = Vector2(24.0, 36.0)
const WORLD_MAX: Vector2 = Vector2(936.0, 460.0)

static func survivor_positions(seed_value: int) -> Array[Vector2]:
	match posmod(seed_value, 3):
		0:
			return [Vector2(180.0, 380.0), Vector2(430.0, 190.0), Vector2(820.0, 350.0)]
		1:
			return [Vector2(160.0, 390.0), Vector2(540.0, 150.0), Vector2(760.0, 390.0)]
		_:
			return [Vector2(150.0, 100.0), Vector2(560.0, 380.0), Vector2(760.0, 140.0)]

static func obstacle_rects(seed_value: int) -> Array[Rect2]:
	match posmod(seed_value, 3):
		0:
			return [Rect2(280.0, 280.0, 80.0, 100.0), Rect2(500.0, 110.0, 75.0, 150.0), Rect2(720.0, 150.0, 75.0, 100.0)]
		1:
			return [Rect2(230.0, 70.0, 70.0, 150.0), Rect2(420.0, 260.0, 100.0, 110.0), Rect2(650.0, 90.0, 75.0, 140.0)]
		_:
			return [Rect2(190.0, 190.0, 90.0, 110.0), Rect2(410.0, 65.0, 80.0, 130.0), Rect2(680.0, 240.0, 70.0, 100.0)]

static func new_game(seed_value: int) -> Dictionary:
	return {
		"seed": seed_value,
		"position": Vector2(70.0, 250.0),
		"velocity": Vector2.ZERO,
		"fuel": 100.0,
		"time_left": 90.0,
		"survivor_positions": survivor_positions(seed_value),
		"rescued": [false, false, false],
		"won": false,
		"failed": false,
		"reason": ""
	}

static func step(state: Dictionary, input_vector: Vector2, delta: float) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if bool(state.get("won", false)) or bool(state.get("failed", false)):
		return next
	if not is_finite(delta) or delta <= 0.0:
		return next
	if not is_finite(input_vector.x) or not is_finite(input_vector.y):
		return next

	var dt: float = minf(delta, 0.1)
	var thrust: Vector2 = input_vector
	if thrust.length() > 1.0:
		thrust = thrust.normalized()
	var position: Vector2 = state.get("position", Vector2(70.0, 250.0))
	var velocity: Vector2 = state.get("velocity", Vector2.ZERO)
	velocity += thrust * 150.0 * dt
	velocity *= pow(0.985, dt * 60.0)
	velocity = velocity.limit_length(MAX_SPEED)
	position += velocity * dt
	var fuel: float = float(state.get("fuel", 0.0)) - dt * (0.2 + thrust.length() * 0.9)
	var time_left: float = float(state.get("time_left", 0.0)) - dt

	next["position"] = position
	next["velocity"] = velocity
	next["fuel"] = maxf(0.0, fuel)
	next["time_left"] = maxf(0.0, time_left)

	for obstacle: Rect2 in obstacle_rects(int(state.get("seed", 1))):
		if obstacle.has_point(position):
			next["failed"] = true
			next["reason"] = "obstacle"
			return next
	if position.x < WORLD_MIN.x or position.y < WORLD_MIN.y or position.x > WORLD_MAX.x or position.y > WORLD_MAX.y:
		next["failed"] = true
		next["reason"] = "bounds"
		return next
	if fuel <= 0.0:
		next["failed"] = true
		next["reason"] = "fuel"
		return next
	if time_left <= 0.0:
		next["failed"] = true
		next["reason"] = "time"
		return next

	var rescued: Array = next.get("rescued", []).duplicate()
	var survivors: Array = next.get("survivor_positions", [])
	for index in range(mini(rescued.size(), survivors.size())):
		var survivor_position: Vector2 = survivors[index]
		if not bool(rescued[index]) and position.distance_to(survivor_position) <= RESCUE_RADIUS and velocity.length() <= SAFE_RESCUE_SPEED:
			rescued[index] = true
	next["rescued"] = rescued
	var all_rescued: bool = rescued.size() == 3 and bool(rescued[0]) and bool(rescued[1]) and bool(rescued[2])
	if all_rescued and position.distance_to(PAD_POSITION) <= LANDING_RADIUS and velocity.length() <= SAFE_LANDING_SPEED:
		next["won"] = true
	return next

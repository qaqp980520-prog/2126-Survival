extends RefCounted
class_name KrollTidalSurveyRules

const ARENA_SIZE: Vector2 = Vector2(640.0, 420.0)
const PLAYER_RADIUS: float = 9.0
const BEACON_RADIUS: float = 15.0
const DOCK_RADIUS: float = 25.0
const HAZARD_RADIUS: float = 20.0
const MAX_OXYGEN: float = 100.0
const THRUST_ACCELERATION: float = 190.0
const MAX_SPEED: float = 230.0
const DRAG_PER_60_FRAMES: float = 0.985
const OXYGEN_DRAIN_PER_SECOND: float = 0.8
const HAZARD_OXYGEN_PENALTY: float = 12.0
const HAZARD_COOLDOWN_SECONDS: float = 0.9

const LAYOUTS: Array[Dictionary] = [
	{
		"name": "Kelp Trench",
		"start": Vector2(62.0, 354.0),
		"dock": Vector2(62.0, 354.0),
		"beacons": [Vector2(165.0, 292.0), Vector2(348.0, 112.0), Vector2(555.0, 330.0)],
		"hazards": [Vector2(255.0, 235.0), Vector2(468.0, 210.0)],
		"currents": [
			{"center": Vector2(250.0, 120.0), "radius": 112.0, "force": Vector2(42.0, -62.0)},
			{"center": Vector2(470.0, 320.0), "radius": 92.0, "force": Vector2(-54.0, 24.0)}
		]
	},
	{
		"name": "Basalt Channel",
		"start": Vector2(62.0, 64.0),
		"dock": Vector2(62.0, 64.0),
		"beacons": [Vector2(175.0, 355.0), Vector2(360.0,  seventy), Vector2(560.0, 345.0)],
		"hazards": [Vector2(265.0, 190.0), Vector2(470.0, 250.0)],
		"currents": [
			{"center": Vector2(185.0, 210.0), "radius": 105.0, "force": Vector2(54.0, 30.0)},
			{"center": Vector2(430.0, 115.0), "radius": 112.0, "force": Vector2(-38.0, 68.0)}
		]
	},
	{
		"name": "Abyssal Shelf",
		"start": Vector2(575.0, 354.0),
		"dock": Vector2(575.0, 354.0),
		"beacons": [Vector2(470.0, 300.0), Vector2(285.0, 90.0), Vector2(72.0, 260.0)],
		"hazards": [Vector2(400.0, 215.0), Vector2(190.0, 210.0)],
		"currents": [
			{"center": Vector2(420.0, 110.0), "radius": 110.0, "force": Vector2(-48.0, -54.0)},
			{"center": Vector2(215.0, 315.0), "radius": 95.0, "force": Vector2(58.0, -20.0)}
		]
	}
]

func layout_count() -> int:
	return LAYOUTS.size()

func get_layout(index: int) -> Dictionary:
	return LAYOUTS[posmod(index, LAYOUTS.size())].duplicate(true)

func create_state(layout: Dictionary) -> Dictionary:
	var cooldowns: Array[float] = []
	var hazards: Array = layout.get("hazards", [])
	for _hazard in hazards:
		cooldowns.append(0.0)
	return {
		"position": layout.get("start", Vector2(32.0, 32.0)),
		"velocity": Vector2.ZERO,
		"oxygen": MAX_OXYGEN,
		"collected": 0,
		"hits": 0,
		"hazard_cooldowns": cooldowns,
		"finished": false,
		"won": false
	}

func step(state: Dictionary, thrust: Vector2, delta_seconds: float, layout: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if bool(next.get("finished", false)):
		return next
	if not is_finite(delta_seconds) or delta_seconds <= 0.0:
		return next
	var delta: float = minf(delta_seconds, 0.25)
	var position: Vector2 = next.get("position", Vector2.ZERO)
	var velocity: Vector2 = next.get("velocity", Vector2.ZERO)
	var input_direction: Vector2 = thrust
	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()
	velocity += input_direction * THRUST_ACCELERATION * delta
	var currents: Array = layout.get("currents", [])
	for current_value in currents:
		if not (current_value is Dictionary):
			continue
		var current: Dictionary = current_value
		var center: Vector2 = current.get("center", Vector2.ZERO)
		var radius: float = float(current.get("radius", 0.0))
		var force: Vector2 = current.get("force", Vector2.ZERO)
		if radius > 0.0 and position.distance_to(center) <= radius:
			velocity += force * delta
	velocity *= pow(DRAG_PER_60_FRAMES, delta * 60.0)
	if velocity.length() > MAX_SPEED:
		velocity = velocity.normalized() * MAX_SPEED
	position += velocity * delta

	if position.x < PLAYER_RADIUS:
		position.x = PLAYER_RADIUS
		velocity.x = absf(velocity.x) * 0.35
	elif position.x > ARENA_SIZE.x - PLAYER_RADIUS:
		position.x = ARENA_SIZE.x - PLAYER_RADIUS
		velocity.x = -absf(velocity.x) * 0.35
	if position.y < PLAYER_RADIUS:
		position.y = PLAYER_RADIUS
		velocity.y = absf(velocity.y) * 0.35
	elif position.y > ARENA_SIZE.y - PLAYER_RADIUS:
		position.y = ARENA_SIZE.y - PLAYER_RADIUS
		velocity.y = -absf(velocity.y) * 0.35

	var hazards: Array = layout.get("hazards", [])
	var cooldowns: Array = next.get("hazard_cooldowns", []).duplicate(true)
	while cooldowns.size() < hazards.size():
		cooldowns.append(0.0)
	for index in range(hazards.size()):
		var hazard: Vector2 = hazards[index]
		var cooldown: float = maxf(0.0, float(cooldowns[index]) - delta)
		var offset: Vector2 = position - hazard
		var collision_distance: float = HAZARD_RADIUS + PLAYER_RADIUS
		if offset.length() < collision_distance:
			var normal: Vector2 = offset.normalized() if offset.length_squared() > 0.001 else Vector2.UP
			position = hazard + normal * (collision_distance + 0.5)
			velocity = velocity.bounce(normal) * 0.38
			if cooldown <= 0.0:
				next["oxygen"] = float(next.get("oxygen", MAX_OXYGEN)) - HAZARD_OXYGEN_PENALTY
				next["hits"] = int(next.get("hits", 0)) + 1
				cooldown = HAZARD_COOLDOWN_SECONDS
		cooldowns[index] = cooldown
	next["hazard_cooldowns"] = cooldowns

	var beacons: Array = layout.get("beacons", [])
	var collected: int = int(next.get("collected", 0))
	if collected < beacons.size():
		var target: Vector2 = beacons[collected]
		if position.distance_to(target) <= BEACON_RADIUS + PLAYER_RADIUS:
			collected += 1
	next["collected"] = collected
	next["oxygen"] = float(next.get("oxygen", MAX_OXYGEN)) - OXYGEN_DRAIN_PER_SECOND * delta
	if float(next["oxygen"]) <= 0.0:
		next["oxygen"] = 0.0
		next["finished"] = true
		next["won"] = false
	elif collected >= beacons.size():
		var dock: Vector2 = layout.get("dock", Vector2.ZERO)
		if position.distance_to(dock) <= DOCK_RADIUS + PLAYER_RADIUS:
			next["finished"] = true
			next["won"] = true
	next["position"] = position
	next["velocity"] = velocity
	return next

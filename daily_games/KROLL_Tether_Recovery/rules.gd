extends RefCounted

const ARENA_SIZE: Vector2 = Vector2(900.0, 620.0)
const DRONE_RADIUS: float = 15.0
const DOCK_RADIUS: float = 48.0
const TETHER_RANGE: float = 92.0
const TETHER_REST_LENGTH: float = 96.0
const THRUST_ACCELERATION: float = 260.0
const BRAKE_ACCELERATION: float = 360.0
const MAX_SPEED: float = 250.0
const FUEL_DRAIN_PER_SECOND: float = 5.0
const MAX_HULL: int = 3

static func create_state(mission_index: int = 0) -> Dictionary:
	var safe_mission: int = posmod(mission_index, 3)
	var cargo_positions: Array[Vector2] = []
	var hazard_data: Array[Dictionary] = []
	var dock_position := Vector2(790.0, 310.0)
	match safe_mission:
		0:
			cargo_positions = [Vector2(250.0, 150.0), Vector2(420.0, 470.0), Vector2(610.0, 190.0)]
			hazard_data = [
				{"position": Vector2(365.0, 305.0), "radius": 42.0},
				{"position": Vector2(545.0, 430.0), "radius": 34.0}
			]
		1:
			cargo_positions = [Vector2(280.0, 470.0), Vector2(470.0, 145.0), Vector2(650.0, 440.0)]
			hazard_data = [
				{"position": Vector2(350.0, 300.0), "radius": 38.0},
				{"position": Vector2(570.0, 275.0), "radius": 46.0}
			]
		_:
			cargo_positions = [Vector2(220.0, 250.0), Vector2(470.0, 470.0), Vector2(650.0, 165.0)]
			hazard_data = [
				{"position": Vector2(340.0, 450.0), "radius": 42.0},
				{"position": Vector2(515.0, 290.0), "radius": 38.0},
				{"position": Vector2(700.0, 390.0), "radius": 30.0}
			]
	var cargo: Array[Dictionary] = []
	for index in range(cargo_positions.size()):
		cargo.append({
			"id": "cargo_%d" % index,
			"position": cargo_positions[index],
			"velocity": Vector2.ZERO,
			"delivered": false
		})
	return {
		"mission_index": safe_mission,
		"drone_pos": Vector2(100.0, 310.0),
		"drone_velocity": Vector2.ZERO,
		"dock_pos": dock_position,
		"cargo": cargo,
		"hazards": hazard_data,
		"tethered_index": -1,
		"fuel": 120.0,
		"hull": MAX_HULL,
		"score": 0,
		"time_left": 120.0,
		"damage_cooldown": 0.0,
		"status": "active",
		"message": "Recover all three cargo pods and return them to the KROLL dock."
	}

static func toggle_tether(state: Dictionary) -> bool:
	if str(state.get("status", "active")) != "active":
		return false
	var current_index: int = int(state.get("tethered_index", -1))
	if current_index >= 0:
		state["tethered_index"] = -1
		state["message"] = "Tether released."
		return true
	var drone_position: Vector2 = state.get("drone_pos", Vector2.ZERO)
	var cargo: Array = state.get("cargo", [])
	var nearest_index: int = -1
	var nearest_distance: float = TETHER_RANGE
	for index in range(cargo.size()):
		var item: Dictionary = cargo[index]
		if bool(item.get("delivered", false)):
			continue
		var position: Vector2 = item.get("position", Vector2.ZERO)
		var distance: float = drone_position.distance_to(position)
		if distance <= nearest_distance:
			nearest_index = index
			nearest_distance = distance
	if nearest_index < 0:
		state["message"] = "No cargo pod within tether range."
		return false
	state["tethered_index"] = nearest_index
	state["message"] = "Cargo pod attached. Tow it to the marked dock."
	return true

static func step(state: Dictionary, delta: float, input_state: Dictionary) -> Dictionary:
	if str(state.get("status", "active")) != "active":
		return state
	var dt: float = clampf(delta, 0.0, 0.05)
	if dt <= 0.0:
		return state
	var thrust_value: Variant = input_state.get("thrust", Vector2.ZERO)
	var thrust: Vector2 = thrust_value if thrust_value is Vector2 else Vector2.ZERO
	thrust = thrust.limit_length(1.0)
	var drone_velocity: Vector2 = state.get("drone_velocity", Vector2.ZERO)
	var fuel: float = maxf(0.0, float(state.get("fuel", 0.0)))
	if thrust.length_squared() > 0.0 and fuel > 0.0:
		drone_velocity += thrust * THRUST_ACCELERATION * dt
		fuel = maxf(0.0, fuel - FUEL_DRAIN_PER_SECOND * dt * thrust.length())
	if bool(input_state.get("brake", false)):
		drone_velocity = drone_velocity.move_toward(Vector2.ZERO, BRAKE_ACCELERATION * dt)
	else:
		drone_velocity *= pow(0.985, dt * 60.0)
	drone_velocity = drone_velocity.limit_length(MAX_SPEED)
	var drone_position: Vector2 = state.get("drone_pos", Vector2(100.0, 310.0))
	drone_position += drone_velocity * dt
	drone_position.x = clampf(drone_position.x, DRONE_RADIUS, ARENA_SIZE.x - DRONE_RADIUS)
	drone_position.y = clampf(drone_position.y, DRONE_RADIUS, ARENA_SIZE.y - DRONE_RADIUS)

	var cooldown: float = maxf(0.0, float(state.get("damage_cooldown", 0.0)) - dt)
	var hull: int = int(state.get("hull", MAX_HULL))
	for hazard in state.get("hazards", []):
		var hazard_position: Vector2 = hazard.get("position", Vector2.ZERO)
		var radius: float = float(hazard.get("radius", 30.0)) + DRONE_RADIUS
		var offset: Vector2 = drone_position - hazard_position
		if offset.length() < radius:
			var normal: Vector2 = offset.normalized() if offset.length() > 0.001 else Vector2.UP
			drone_position = hazard_position + normal * (radius + 1.0)
			drone_velocity = drone_velocity.bounce(normal) * 0.55
			if cooldown <= 0.0:
				hull = maxi(0, hull - 1)
				cooldown = 1.0
			break

	var cargo: Array = state.get("cargo", [])
	var tethered_index: int = int(state.get("tethered_index", -1))
	if tethered_index >= 0 and tethered_index < cargo.size():
		var item: Dictionary = cargo[tethered_index]
		if not bool(item.get("delivered", false)):
			var cargo_position: Vector2 = item.get("position", Vector2.ZERO)
			var cargo_velocity: Vector2 = item.get("velocity", Vector2.ZERO)
			var offset: Vector2 = cargo_position - drone_position
			var distance: float = offset.length()
			if distance > TETHER_REST_LENGTH:
				var direction: Vector2 = offset.normalized()
				var pull: float = minf((distance - TETHER_REST_LENGTH) * 6.0, 480.0)
				cargo_velocity -= direction * pull * dt
			cargo_velocity += (drone_velocity - cargo_velocity) * 0.25 * dt
			cargo_velocity *= pow(0.985, dt * 60.0)
			cargo_position += cargo_velocity * dt
			item["position"] = cargo_position
			item["velocity"] = cargo_velocity
			if cargo_position.distance_to(state.get("dock_pos", Vector2(790.0, 310.0))) <= DOCK_RADIUS:
				item["delivered"] = true
				item["velocity"] = Vector2.ZERO
				state["tethered_index"] = -1
				state["score"] = int(state.get("score", 0)) + 100
				state["message"] = "Cargo delivered. Recover the next pod."
				if _all_delivered(cargo):
					state["status"] = "complete"
					state["message"] = "Mission complete. All cargo is safely docked."
	else:
		state["tethered_index"] = -1

	var time_left: float = maxf(0.0, float(state.get("time_left", 120.0)) - dt)
	state["drone_pos"] = drone_position
	state["drone_velocity"] = drone_velocity
	state["fuel"] = fuel
	state["hull"] = hull
	state["time_left"] = time_left
	state["damage_cooldown"] = cooldown
	if hull <= 0 or time_left <= 0.0:
		state["status"] = "failed"
		state["message"] = "Recovery failed. Reset the mission and try another route."
	return state

static func reset(state: Dictionary) -> Dictionary:
	return create_state(int(state.get("mission_index", 0)))

static func next_mission(state: Dictionary) -> Dictionary:
	return create_state(int(state.get("mission_index", 0)) + 1)

static func _all_delivered(cargo: Array) -> bool:
	if cargo.is_empty():
		return false
	for item in cargo:
		if not bool(item.get("delivered", false)):
			return false
	return true

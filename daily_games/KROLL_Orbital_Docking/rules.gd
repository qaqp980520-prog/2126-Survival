extends RefCounted

## Inertial 2D docking model. Thrust changes velocity; position is never snapped.
const TURN_RATE: float = 2.25
const THRUST_ACCELERATION: float = 105.0
const REVERSE_ACCELERATION: float = 72.0
const THRUST_BURN_RATE: float = 16.0
const REVERSE_BURN_RATE: float = 11.0
const LINEAR_DRAG: float = 0.55
const DOCK_RADIUS: float = 30.0
const MAX_DOCK_SPEED: float = 26.0
const MAX_ANGLE_ERROR: float = 0.22

static func get_scenario_count() -> int:
	return 3

static func get_scenario(index: int) -> Dictionary:
	var scenarios: Array[Dictionary] = [
		{
			"name": "TRAINING RING",
			"ship_position": Vector2(140.0, 520.0),
			"ship_velocity": Vector2(12.0, -8.0),
			"ship_angle": -0.25,
			"target_position": Vector2(820.0, 320.0),
			"target_angle": 0.0,
			"fuel": 100.0,
			"time_limit": 90.0
		},
		{
			"name": "CROSSWIND APPROACH",
			"ship_position": Vector2(160.0, 160.0),
			"ship_velocity": Vector2(18.0, 10.0),
			"ship_angle": 0.8,
			"target_position": Vector2(790.0, 500.0),
			"target_angle": 0.5,
			"fuel": 120.0,
			"time_limit": 100.0
		},
		{
			"name": "DEEP ORBIT",
			"ship_position": Vector2(820.0, 520.0),
			"ship_velocity": Vector2(-12.0, -16.0),
			"ship_angle": -2.2,
			"target_position": Vector2(180.0, 170.0),
			"target_angle": -2.4,
			"fuel": 135.0,
			"time_limit": 110.0
		}
	]
	return scenarios[posmod(index, scenarios.size())].duplicate(true)

static func create_state(index: int) -> Dictionary:
	var scenario: Dictionary = get_scenario(index)
	return {
		"position": scenario["ship_position"],
		"velocity": scenario["ship_velocity"],
		"angle": float(scenario["ship_angle"]),
		"fuel": float(scenario["fuel"]),
		"elapsed": 0.0,
		"status": "active"
	}

static func validate_state(state: Dictionary) -> bool:
	if not (state.get("position", null) is Vector2) or not (state.get("velocity", null) is Vector2):
		return false
	for key in ["angle", "fuel", "elapsed"]:
		var value: Variant = state.get(key, null)
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	if not ["active", "docked", "failed", "stranded"].has(str(state.get("status", ""))):
		return false
	var position: Vector2 = state["position"]
	var velocity: Vector2 = state["velocity"]
	return _is_finite_vector(position) and _is_finite_vector(velocity) and float(state["fuel"]) >= 0.0 and float(state["elapsed"]) >= 0.0

static func step(state: Dictionary, input_state: Dictionary, delta: float, scenario: Dictionary) -> Dictionary:
	if not validate_state(state) or not _validate_scenario(scenario) or not is_finite(delta) or delta <= 0.0 or delta > 0.25:
		return state.duplicate(true)
	var next: Dictionary = state.duplicate(true)
	if str(next["status"]) != "active":
		return next
	var dt: float = delta
	var turn: float = float(bool(input_state.get("right", false))) - float(bool(input_state.get("left", false)))
	next["angle"] = wrapf(float(next["angle"]) + turn * TURN_RATE * dt, -PI, PI)
	var direction := Vector2(cos(float(next["angle"])), sin(float(next["angle"])))
	var velocity: Vector2 = next["velocity"]
	var fuel: float = float(next["fuel"])
	if bool(input_state.get("thrust", false)) and fuel > 0.0:
		var active_dt: float = minf(dt, fuel / THRUST_BURN_RATE)
		velocity += direction * THRUST_ACCELERATION * active_dt
		fuel = maxf(0.0, fuel - THRUST_BURN_RATE * active_dt)
	elif bool(input_state.get("reverse", false)) and fuel > 0.0:
		var active_dt: float = minf(dt, fuel / REVERSE_BURN_RATE)
		velocity -= direction * REVERSE_ACCELERATION * active_dt
		fuel = maxf(0.0, fuel - REVERSE_BURN_RATE * active_dt)
	velocity = velocity.move_toward(Vector2.ZERO, LINEAR_DRAG * dt)
	var position: Vector2 = next["position"] + velocity * dt
	next["position"] = position
	next["velocity"] = velocity
	next["fuel"] = fuel
	next["elapsed"] = float(next["elapsed"]) + dt
	if can_dock(next, scenario):
		next["status"] = "docked"
	elif float(next["elapsed"]) >= float(scenario["time_limit"]):
		next["status"] = "failed"
	elif fuel <= 0.0 and velocity.length() < 1.5 and distance_to_target(next, scenario) > DOCK_RADIUS:
		next["status"] = "stranded"
	return next

static func can_dock(state: Dictionary, scenario: Dictionary) -> bool:
	if not validate_state(state) or not _validate_scenario(scenario):
		return false
	if str(state["status"]) != "active":
		return str(state["status"]) == "docked"
	var distance: float = distance_to_target(state, scenario)
	var speed: float = (state["velocity"] as Vector2).length()
	var angle_error: float = absf(wrapf(float(state["angle"]) - float(scenario["target_angle"]), -PI, PI))
	return distance <= DOCK_RADIUS and speed <= MAX_DOCK_SPEED and angle_error <= MAX_ANGLE_ERROR

static func distance_to_target(state: Dictionary, scenario: Dictionary) -> float:
	if not (state.get("position", null) is Vector2) or not (scenario.get("target_position", null) is Vector2):
		return INF
	return (state["position"] as Vector2).distance_to(scenario["target_position"] as Vector2)

static func _validate_scenario(scenario: Dictionary) -> bool:
	for key in ["ship_position", "ship_velocity", "target_position"]:
		if not (scenario.get(key, null) is Vector2) or not _is_finite_vector(scenario[key]):
			return false
	for key in ["ship_angle", "target_angle", "fuel", "time_limit"]:
		var value: Variant = scenario.get(key, null)
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	return float(scenario["fuel"]) > 0.0 and float(scenario["time_limit"]) > 0.0

static func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)

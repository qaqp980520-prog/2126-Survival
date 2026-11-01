extends RefCounted

const THRUST_ACCEL: float = 44.0
const REVERSE_ACCEL: float = 24.0
const BRAKE_ACCEL: float = 58.0
const TURN_RATE: float = 1.8
const THRUST_FUEL_RATE: float = 16.0
const REVERSE_FUEL_RATE: float = 10.0
const BRAKE_FUEL_RATE: float = 5.0
const DRAG_RATE: float = 0.045
const DOCK_RADIUS: float = 25.0
const DOCK_SPEED: float = 15.0
const DOCK_ANGLE: float = 0.32
const DOCK_DWELL: float = 1.0
const SHIP_RADIUS: float = 9.0
const MAX_STEP: float = 0.05

const SCENARIOS: Array[Dictionary] = [
	{
		"id":"cargo_bay",
		"name":"Cargo Bay",
		"brief":"Approach the fixed cargo berth with low relative speed and a level docking nose.",
		"start_position":Vector2(-280.0,-140.0),
		"start_velocity":Vector2(0.0,0.0),
		"target_position":Vector2(260.0,140.0),
		"target_velocity":Vector2(0.0,0.0),
		"target_heading":0.0,
		"fuel":180.0,
		"time_limit":100.0,
		"bounds":Vector2(360.0,220.0),
		"obstacles":[]
	},
	{
		"id":"rotating_ring",
		"name":"Rotating Ring",
		"brief":"Intercept a slowly drifting ring. Its motion means the berth will not wait for you.",
		"start_position":Vector2(-300.0,150.0),
		"start_velocity":Vector2(4.0,-2.0),
		"target_position":Vector2(280.0,-120.0),
		"target_velocity":Vector2(-2.0,1.2),
		"target_heading":0.15,
		"fuel":190.0,
		"time_limit":110.0,
		"bounds":Vector2(360.0,220.0),
		"obstacles":[
			{"position":Vector2(-5.0,55.0),"radius":42.0},
			{"position":Vector2(125.0,-25.0),"radius":34.0}
		]
	},
	{
		"id":"debris_corridor",
		"name":"Debris Corridor",
		"brief":"Thread the central debris field and brake before entering the final docking envelope.",
		"start_position":Vector2(-300.0,0.0),
		"start_velocity":Vector2(0.0,0.0),
		"target_position":Vector2(300.0,0.0),
		"target_velocity":Vector2(0.0,0.0),
		"target_heading":0.0,
		"fuel":220.0,
		"time_limit":120.0,
		"bounds":Vector2(360.0,220.0),
		"obstacles":[
			{"position":Vector2(-70.0,0.0),"radius":38.0},
			{"position":Vector2(70.0,88.0),"radius":36.0},
			{"position":Vector2(70.0,-88.0),"radius":36.0}
		]
	}
]

func get_scenario_count() -> int:
	return SCENARIOS.size()

func get_scenario(index: int) -> Dictionary:
	if index < 0 or index >= SCENARIOS.size():
		return {}
	return SCENARIOS[index].duplicate(true)

func make_state(index: int) -> Dictionary:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return {}
	return {
		"scenario_index":index,
		"position":scenario["start_position"],
		"velocity":scenario["start_velocity"],
		"angle":0.0,
		"fuel":float(scenario["fuel"]),
		"elapsed":0.0,
		"target_base":scenario["target_position"],
		"target_velocity":scenario["target_velocity"],
		"target_heading":float(scenario["target_heading"]),
		"obstacles":scenario["obstacles"].duplicate(true),
		"bounds":scenario["bounds"],
		"time_limit":float(scenario["time_limit"]),
		"dock_progress":0.0,
		"status":"flying",
		"last_event":"launch"
	}

func get_target_position(state: Dictionary) -> Vector2:
	if not _valid_state(state):
		return Vector2.ZERO
	return state["target_base"] + state["target_velocity"] * float(state["elapsed"])

func step(state: Dictionary, controls: Dictionary, delta: float) -> Dictionary:
	if not _valid_state(state) or is_nan(delta) or is_inf(delta) or delta <= 0.0:
		return {"ok":false,"reason":"invalid_state_or_delta"}
	var updated: Dictionary = state.duplicate(true)
	if str(updated["status"]) != "flying":
		return {"ok":true,"state":updated,"event":"inactive"}
	var dt: float = minf(delta, MAX_STEP)
	var fuel: float = float(updated["fuel"])
	var angle: float = float(updated["angle"])
	var turn_direction: float = 0.0
	if bool(controls.get("left", false)):
		turn_direction -= 1.0
	if bool(controls.get("right", false)):
		turn_direction += 1.0
	angle = wrapf(angle + turn_direction * TURN_RATE * dt, -PI, PI)
	updated["angle"] = angle

	var velocity: Vector2 = updated["velocity"]
	var forward := Vector2(cos(angle), sin(angle))
	var thrusting: bool = bool(controls.get("thrust", false)) and fuel > 0.0
	var reversing: bool = bool(controls.get("reverse", false)) and fuel > 0.0
	var braking: bool = bool(controls.get("brake", false)) and fuel > 0.0
	if thrusting:
		velocity += forward * THRUST_ACCEL * dt
		fuel = maxf(0.0, fuel - THRUST_FUEL_RATE * dt)
	if reversing:
		velocity -= forward * REVERSE_ACCEL * dt
		fuel = maxf(0.0, fuel - REVERSE_FUEL_RATE * dt)
	if braking:
		velocity = velocity.move_toward(Vector2.ZERO, BRAKE_ACCEL * dt)
		fuel = maxf(0.0, fuel - BRAKE_FUEL_RATE * dt)
	if not thrusting and not reversing and not braking:
		velocity *= exp(-DRAG_RATE * dt)
	updated["velocity"] = velocity
	updated["fuel"] = fuel
	updated["position"] = updated["position"] + velocity * dt
	updated["elapsed"] = float(updated["elapsed"]) + dt

	var position: Vector2 = updated["position"]
	var bounds: Vector2 = updated["bounds"]
	if absf(position.x) > bounds.x or absf(position.y) > bounds.y:
		updated["status"] = "lost"
		updated["last_event"] = "boundary"
		return {"ok":true,"state":updated,"event":"boundary"}
	for obstacle_value in updated["obstacles"]:
		var obstacle: Dictionary = obstacle_value
		if position.distance_to(obstacle["position"]) <= float(obstacle["radius"]) + SHIP_RADIUS:
			updated["status"] = "crashed"
			updated["last_event"] = "collision"
			return {"ok":true,"state":updated,"event":"collision"}

	var target_position: Vector2 = get_target_position(updated)
	var relative_velocity: Vector2 = velocity - updated["target_velocity"]
	var angle_error: float = absf(wrapf(angle - float(updated["target_heading"]), -PI, PI))
	var dock_ready: bool = (
		position.distance_to(target_position) <= DOCK_RADIUS
		and relative_velocity.length() <= DOCK_SPEED
		and angle_error <= DOCK_ANGLE
	)
	if dock_ready:
		updated["dock_progress"] = float(updated["dock_progress"]) + dt
		if float(updated["dock_progress"]) >= DOCK_DWELL:
			updated["status"] = "docked"
			updated["last_event"] = "docked"
	else:
		updated["dock_progress"] = maxf(0.0, float(updated["dock_progress"]) - dt * 1.5)
		updated["last_event"] = "flying"
	if str(updated["status"]) == "flying" and float(updated["elapsed"]) >= float(updated["time_limit"]):
		updated["status"] = "timeout"
		updated["last_event"] = "timeout"
	return {"ok":true,"state":updated,"event":str(updated["last_event"])}

func reset_state(state: Dictionary) -> Dictionary:
	if not _valid_state(state):
		return {}
	return make_state(int(state["scenario_index"]))

func advance_state(state: Dictionary) -> Dictionary:
	if not _valid_state(state) or str(state["status"]) != "docked":
		return {"ok":false,"reason":"docking_not_complete"}
	var next_index: int = int(state["scenario_index"]) + 1
	if next_index >= SCENARIOS.size():
		var finished: Dictionary = state.duplicate(true)
		finished["status"] = "campaign_complete"
		return {"ok":true,"state":finished}
	return {"ok":true,"state":make_state(next_index)}

func get_status_summary(state: Dictionary) -> Dictionary:
	if not _valid_state(state):
		return {"valid":false,"speed":0.0,"fuel":0.0,"dock_progress":0.0}
	return {
		"valid":true,
		"speed":(state["velocity"] - state["target_velocity"]).length(),
		"fuel":float(state["fuel"]),
		"dock_progress":float(state["dock_progress"]),
		"status":str(state["status"])
	}

func _valid_state(state: Dictionary) -> bool:
	for key in ["scenario_index","position","velocity","angle","fuel","elapsed","target_base","target_velocity","target_heading","obstacles","bounds","time_limit","dock_progress","status"]:
		if not state.has(key):
			return false
	if not (state["scenario_index"] is int) or int(state["scenario_index"]) < 0 or int(state["scenario_index"]) >= SCENARIOS.size():
		return false
	for key in ["position","velocity","target_base","target_velocity","bounds"]:
		if not (state[key] is Vector2):
			return false
		var vector: Vector2 = state[key]
		if is_nan(vector.x) or is_inf(vector.x) or is_nan(vector.y) or is_inf(vector.y):
			return false
	if not (state["obstacles"] is Array) or not (state["angle"] is float or state["angle"] is int):
		return false
	if is_nan(float(state["angle"])) or is_inf(float(state["angle"])):
		return false
	for key in ["fuel","elapsed","target_heading","time_limit","dock_progress"]:
		if not (state[key] is float or state[key] is int):
			return false
		if is_nan(float(state[key])) or is_inf(float(state[key])):
			return false
	if float(state["fuel"]) < 0.0 or float(state["elapsed"]) < 0.0 or float(state["time_limit"]) <= 0.0 or float(state["dock_progress"]) < 0.0:
		return false
	return str(state["status"]) in ["flying","docked","crashed","lost","timeout","campaign_complete"]

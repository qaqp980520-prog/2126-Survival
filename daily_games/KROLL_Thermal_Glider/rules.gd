extends RefCounted

const GRAVITY: float = 32.0
const MAX_PITCH: float = 28.0
const MIN_SPEED: float = 40.0
const MAX_SPEED: float = 230.0
const BEACON_RADIUS: float = 48.0
const COURSES: Array[Dictionary] = [
	{
		"id": "coast",
		"name": "COASTAL THERMALS",
		"headwind": 6.0,
		"runway_x": 1780.0,
		"runway_y": 300.0,
		"beacons": [Vector2(390.0, 190.0), Vector2(850.0, 255.0), Vector2(1280.0, 165.0)],
		"thermals": [
			{"position": Vector2(560.0, 245.0), "radius": 125.0, "lift": 52.0},
			{"position": Vector2(1110.0, 285.0), "radius": 105.0, "lift": 45.0}
		],
		"gusts": [{"x": 720.0, "strength": -12.0}, {"x": 1460.0, "strength": 9.0}]
	},
	{
		"id": "ridge",
		"name": "RIDGE CROSSING",
		"headwind": 13.0,
		"runway_x": 1880.0,
		"runway_y": 330.0,
		"beacons": [Vector2(430.0, 150.0), Vector2(940.0, 205.0), Vector2(1390.0, 245.0)],
		"thermals": [
			{"position": Vector2(670.0, 210.0), "radius": 115.0, "lift": 68.0},
			{"position": Vector2(1210.0, 255.0), "radius": 90.0, "lift": 38.0}
		],
		"gusts": [{"x": 820.0, "strength": 18.0}, {"x": 1550.0, "strength": -17.0}]
	},
	{
		"id": "floodplain",
		"name": "FLOODPLAIN WIND",
		"headwind": 2.0,
		"runway_x": 1740.0,
		"runway_y": 275.0,
		"beacons": [Vector2(360.0, 245.0), Vector2(810.0, 145.0), Vector2(1240.0, 220.0)],
		"thermals": [
			{"position": Vector2(500.0, 300.0), "radius": 100.0, "lift": 42.0},
			{"position": Vector2(1000.0, 220.0), "radius": 145.0, "lift": 58.0},
			{"position": Vector2(1450.0, 270.0), "radius": 100.0, "lift": 34.0}
		],
		"gusts": [{"x": 620.0, "strength": -15.0}, {"x": 1320.0, "strength": 14.0}]
	}
]

func get_course_count() -> int:
	return COURSES.size()

func get_course(index: int) -> Dictionary:
	return COURSES[posmod(index, COURSES.size())].duplicate(true)

func new_run(course_index: int = 0) -> Dictionary:
	var selected: int = posmod(course_index, COURSES.size())
	return {
		"course_index": selected,
		"position": Vector2(80.0, 260.0),
		"velocity": Vector2(145.0, 0.0),
		"pitch": 4.0,
		"battery": 100.0,
		"checkpoint": 0,
		"status": "flying",
		"elapsed": 0.0,
		"stall_time": 0.0,
		"last_thermal_strength": 0.0
	}

func step(state: Dictionary, controls: Dictionary, delta: float) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "crashed")) != "flying":
		return next
	var dt: float = clampf(delta, 0.0, 0.05)
	if dt <= 0.0:
		return next
	var course: Dictionary = get_course(int(next.get("course_index", 0)))
	var position: Vector2 = next.get("position", Vector2.ZERO)
	var velocity: Vector2 = next.get("velocity", Vector2.ZERO)
	var pitch: float = float(next.get("pitch", 0.0))
	var battery: float = clampf(float(next.get("battery", 0.0)), 0.0, 100.0)
	var pitch_input: float = clampf(float(controls.get("pitch", 0.0)), -1.0, 1.0)
	pitch = clampf(pitch + pitch_input * 48.0 * dt, -MAX_PITCH, MAX_PITCH)
	var boost: bool = bool(controls.get("boost", false)) and battery > 0.25
	var brake: bool = bool(controls.get("brake", false))
	var speed: float = maxf(0.0, velocity.x)
	var thrust: float = 82.0 if boost else 0.0
	var headwind: float = float(course.get("headwind", 0.0))
	var drag: float = 4.0 + speed * 0.012 + headwind * 0.05
	if brake:
		drag += 52.0
	velocity.x = clampf(velocity.x + (thrust - drag) * dt, 0.0, MAX_SPEED)
	if boost:
		battery = maxf(0.0, battery - 14.0 * dt)
	var thermal_lift: float = 0.0
	var thermal_strength: float = 0.0
	for thermal_value in course.get("thermals", []):
		if not (thermal_value is Dictionary):
			continue
		var thermal: Dictionary = thermal_value
		var thermal_position: Vector2 = thermal.get("position", Vector2.ZERO)
		var radius: float = maxf(1.0, float(thermal.get("radius", 1.0)))
		var distance: float = position.distance_to(thermal_position)
		var strength: float = clampf(1.0 - distance / radius, 0.0, 1.0)
		if strength > thermal_strength:
			thermal_strength = strength
		thermal_lift += float(thermal.get("lift", 0.0)) * strength
	if thermal_strength > 0.0:
		battery = minf(100.0, battery + 5.0 * thermal_strength * dt)
	var gust: float = 0.0
	for gust_value in course.get("gusts", []):
		if gust_value is Dictionary and absf(position.x - float(gust_value.get("x", -10000.0))) < 90.0:
			gust += float(gust_value.get("strength", 0.0))
	var lift: float = velocity.x * 0.14 + velocity.x * sin(deg_to_rad(pitch)) * 0.85 + thermal_lift
	velocity.y += (GRAVITY - lift + gust) * dt
	position += velocity * dt
	var elapsed: float = float(next.get("elapsed", 0.0)) + dt
	var stall_time: float = float(next.get("stall_time", 0.0))
	if velocity.x < 55.0:
		stall_time += dt
	else:
		stall_time = 0.0
	var beacons: Array = course.get("beacons", [])
	var checkpoint: int = int(next.get("checkpoint", 0))
	if checkpoint < beacons.size() and position.distance_to(beacons[checkpoint]) <= BEACON_RADIUS:
		checkpoint += 1
		battery = minf(100.0, battery + 12.0)
	var status: String = "flying"
	if position.y >= 438.0 or position.y <= 28.0 or stall_time >= 1.6:
		status = "crashed"
	var runway_x: float = float(course.get("runway_x", 1700.0))
	var runway_y: float = float(course.get("runway_y", 300.0))
	if status == "flying" and checkpoint >= beacons.size() and position.x >= runway_x - 35.0:
		var safe_landing: bool = absf(position.y - runway_y) <= 34.0 and absf(velocity.y) <= 55.0 and absf(pitch) <= 10.0 and velocity.x >= 70.0 and velocity.x <= 175.0
		status = "landed" if safe_landing else "crashed"
	elif status == "flying" and position.x > runway_x + 70.0:
		status = "crashed"
	next["position"] = position
	next["velocity"] = velocity
	next["pitch"] = pitch
	next["battery"] = battery
	next["checkpoint"] = checkpoint
	next["status"] = status
	next["elapsed"] = elapsed
	next["stall_time"] = stall_time
	next["last_thermal_strength"] = thermal_strength
	return next

func get_status_message(state: Dictionary) -> String:
	match str(state.get("status", "flying")):
		"landed":
			return "SAFE LANDING — SURVEY COMPLETE"
		"crashed":
			return "FLIGHT LOST — RESET OR TRY ANOTHER COURSE"
	return "COLLECT ALL THREE BEACONS AND LAND INSIDE THE RUNWAY WINDOW"

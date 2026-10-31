extends RefCounted
## Deterministic two-link robotic arm geometry and three pick-and-place jobs.
const BASE: Vector2 = Vector2(150.0,430.0)
const LINK_1: float = 145.0
const LINK_2: float = 120.0
const MAX_REACH: float = LINK_1+LINK_2
const MIN_REACH: float = 25.0
const SHOULDER_MIN: float = -140.0
const SHOULDER_MAX: float = 140.0
const ELBOW_MIN: float = -150.0
const ELBOW_MAX: float = 150.0
const PICKUP_RADIUS: float = 27.0
const DELIVERY_RADIUS: float = 34.0
const JOINT_STEP: float = 5.0
const JOBS: Array[Dictionary] = [
	{"id":"coolant_cartridge","name":"COOLANT CARTRIDGE","cargo":Vector2(280.0,520.0),"target":Vector2(360.0,290.0),"brief":"Lift the coolant cartridge from the lower tray and place it on the upper service dock."},
	{"id":"sensor_cradle","name":"SENSOR CRADLE","cargo":Vector2(350.0,530.0),"target":Vector2(380.0,330.0),"brief":"Move the delicate sensor cradle without releasing it outside the marked receiving ring."},
	{"id":"core_sample","name":"CORE SAMPLE","cargo":Vector2(240.0,260.0),"target":Vector2(400.0,500.0),"brief":"Transfer the sealed core sample to the lower quarantine dock."}
]

static func get_job_count() -> int:
	return JOBS.size()

static func get_job(index: int) -> Dictionary:
	return JOBS[clampi(index,0,JOBS.size()-1)].duplicate(true)

static func clamp_angles(shoulder: float,elbow: float) -> Dictionary:
	return {
		"shoulder":clampf(shoulder,SHOULDER_MIN,SHOULDER_MAX),
		"elbow":clampf(elbow,ELBOW_MIN,ELBOW_MAX)
	}

static func forward_kinematics(shoulder: float,elbow: float) -> Dictionary:
	var shoulder_radians: float = deg_to_rad(shoulder)
	var elbow_radians: float = deg_to_rad(shoulder+elbow)
	var elbow_point: Vector2 = BASE+Vector2(cos(shoulder_radians),sin(shoulder_radians))*LINK_1
	var end_point: Vector2 = elbow_point+Vector2(cos(elbow_radians),sin(elbow_radians))*LINK_2
	return {"elbow":elbow_point,"end":end_point}

static func is_point_reachable(point: Vector2) -> bool:
	var distance: float = point.distance_to(BASE)
	return distance <= MAX_REACH and distance >= MIN_REACH

static func solve_angles_for_target(point: Vector2,elbow_sign: int = 1) -> Dictionary:
	var delta: Vector2 = point-BASE
	var distance: float = delta.length()
	if distance > MAX_REACH or distance < MIN_REACH:
		return {"ok":false,"reason":"unreachable"}
	var cosine: float = clampf((distance*distance-LINK_1*LINK_1-LINK_2*LINK_2)/(2.0*LINK_1*LINK_2),-1.0,1.0)
	var elbow_radians: float = acos(cosine)
	if elbow_sign < 0:
		elbow_radians=-elbow_radians
	var shoulder_radians: float = atan2(delta.y,delta.x)-atan2(LINK_2*sin(elbow_radians),LINK_1+LINK_2*cos(elbow_radians))
	var angles: Dictionary = clamp_angles(rad_to_deg(shoulder_radians),rad_to_deg(elbow_radians))
	var points: Dictionary = forward_kinematics(float(angles["shoulder"]),float(angles["elbow"]))
	var end_point: Vector2 = points["end"]
	var error: float = end_point.distance_to(point)
	return {
		"ok":error <= 0.5,
		"reason":"solved" if error <= 0.5 else "joint_limit",
		"shoulder":float(angles["shoulder"]),
		"elbow":float(angles["elbow"]),
		"end":end_point,
		"error":error
	}

static func is_within_radius(point: Vector2,target: Vector2,radius: float) -> bool:
	return point.distance_to(target) <= radius

static func is_valid_job(index: int) -> bool:
	if index < 0 or index >= JOBS.size():
		return false
	var job: Dictionary = JOBS[index]
	var cargo: Vector2 = job["cargo"]
	var target: Vector2 = job["target"]
	return is_point_reachable(cargo) and is_point_reachable(target) \
		and bool(solve_angles_for_target(cargo).get("ok",false)) \
		and bool(solve_angles_for_target(target).get("ok",false))

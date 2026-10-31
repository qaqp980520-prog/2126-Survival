extends SceneTree
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.get_job_count() == 3,"three precision pick-and-place work orders are authored")
	_expect(Rules.MAX_REACH == Rules.LINK_1+Rules.LINK_2,"maximum reach matches the two link lengths")
	for index in range(Rules.get_job_count()):
		_expect(Rules.is_valid_job(index),"job %d has reachable cargo and receiving dock" % index)
		var job: Dictionary = Rules.get_job(index)
		var cargo: Vector2 = job["cargo"]
		var target: Vector2 = job["target"]
		var pickup: Dictionary = Rules.solve_angles_for_target(cargo)
		var delivery: Dictionary = Rules.solve_angles_for_target(target)
		_expect(bool(pickup.get("ok",false)),"job %d pickup position has a valid inverse-kinematic solution" % index)
		_expect(bool(delivery.get("ok",false)),"job %d receiving dock has a valid inverse-kinematic solution" % index)
		if bool(pickup.get("ok",false)):
			var pickup_points: Dictionary = Rules.forward_kinematics(float(pickup["shoulder"]),float(pickup["elbow"]))
			var pickup_end: Vector2 = pickup_points["end"]
			_expect(pickup_end.distance_to(cargo) <= 0.5,"job %d pickup solution reaches the cargo" % index)
		if bool(delivery.get("ok",false)):
			var delivery_points: Dictionary = Rules.forward_kinematics(float(delivery["shoulder"]),float(delivery["elbow"]))
			var delivery_end: Vector2 = delivery_points["end"]
			_expect(delivery_end.distance_to(target) <= 0.5,"job %d delivery solution reaches the dock" % index)
	var clamped: Dictionary = Rules.clamp_angles(999.0,-999.0)
	_expect(is_equal_approx(float(clamped["shoulder"]),Rules.SHOULDER_MAX),"shoulder angle clamps to its upper joint stop")
	_expect(is_equal_approx(float(clamped["elbow"]),Rules.ELBOW_MIN),"elbow angle clamps to its lower joint stop")
	_expect(not Rules.is_point_reachable(Vector2(900.0,900.0)),"unreachable workbench point is rejected")
	_expect(not bool(Rules.solve_angles_for_target(Vector2(900.0,900.0)).get("ok",true)),"inverse kinematics rejects a point outside arm reach")
	_expect(Rules.is_within_radius(Vector2(10.0,10.0),Vector2(20.0,10.0),10.0),"pickup/delivery radius includes its boundary")
	_expect(not Rules.is_within_radius(Vector2(10.0,10.0),Vector2(20.1,10.0),10.0),"pickup/delivery radius rejects points outside its boundary")
	if failures.is_empty():
		print("KROLL Robotic Arm Operator rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: "+failure)
		quit(1)

func _expect(condition: bool,description: String) -> void:
	if condition:
		print("PASS: "+description)
	else:
		failures.append(description)
		push_error("FAIL: "+description)

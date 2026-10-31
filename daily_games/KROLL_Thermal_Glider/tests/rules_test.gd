extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules: RefCounted = Rules.new()
	_expect(rules.get_course_count() == 3, "three deterministic glider courses are available")
	for index in range(rules.get_course_count()):
		var course: Dictionary = rules.get_course(index)
		var beacons: Array = course.get("beacons", [])
		var thermals: Array = course.get("thermals", [])
		_expect(beacons.size() == 3, "each course has three survey beacons")
		_expect(not thermals.is_empty(), "each course has at least one thermal zone")
		_expect(_run_reference_flight(rules, index) == "landed", "reference flight can collect all beacons and land on course %d" % index)

	var initial: Dictionary = rules.new_run(0)
	_expect(str(initial.get("status", "")) == "flying", "new run starts in the flying state")
	_expect(int(initial.get("checkpoint", -1)) == 0, "new run starts before the first beacon")
	var original_position: Vector2 = initial.get("position", Vector2.ZERO)
	var boosted: Dictionary = rules.step(initial, {"pitch": 1, "boost": true, "brake": false}, 0.05)
	_expect(initial.get("position", Vector2.ZERO) == original_position, "step does not mutate its input state")
	_expect(float(boosted.get("battery", 100.0)) < 100.0, "boost consumes assist battery")
	_expect(float(boosted.get("pitch", 0.0)) > float(initial.get("pitch", 0.0)), "nose-up input increases pitch")

	var neutral_state: Dictionary = rules.new_run(0)
	var nose_up_state: Dictionary = rules.step(neutral_state, {"pitch": 1}, 0.05)
	var level_state: Dictionary = rules.step(neutral_state, {"pitch": 0}, 0.05)
	_expect(float(nose_up_state.get("velocity", Vector2.ZERO).y) < float(level_state.get("velocity", Vector2.ZERO).y), "nose-up pitch increases lift relative to level flight")

	var brake_state: Dictionary = rules.new_run(0)
	brake_state["velocity"] = Vector2(150.0, 0.0)
	var free_state: Dictionary = rules.step(brake_state, {}, 0.05)
	var braked_state: Dictionary = rules.step(brake_state, {"brake": true}, 0.05)
	_expect(float(braked_state.get("velocity", Vector2.ZERO).x) < float(free_state.get("velocity", Vector2.ZERO).x), "airbrake reduces forward speed")

	var thermal_state: Dictionary = rules.new_run(0)
	thermal_state["position"] = Vector2(560.0, 245.0)
	thermal_state["battery"] = 50.0
	var thermal_after: Dictionary = rules.step(thermal_state, {}, 0.05)
	var outside_state: Dictionary = rules.new_run(0)
	outside_state["position"] = Vector2(180.0, 245.0)
	outside_state["battery"] = 50.0
	var outside_after: Dictionary = rules.step(outside_state, {}, 0.05)
	_expect(float(thermal_after.get("last_thermal_strength", 0.0)) > 0.9, "thermal center produces strong updraft")
	_expect(float(thermal_after.get("battery", 0.0)) > float(outside_after.get("battery", 0.0)), "thermal lift recharges the assist battery")

	var checkpoint_state: Dictionary = rules.new_run(0)
	var first_beacon: Vector2 = rules.get_course(0)["beacons"][0]
	checkpoint_state["position"] = first_beacon - Vector2(10.0, 0.0)
	var checkpoint_after: Dictionary = rules.step(checkpoint_state, {}, 0.05)
	_expect(int(checkpoint_after.get("checkpoint", 0)) == 1, "passing the next beacon advances survey progress")
	var out_of_order: Dictionary = rules.new_run(0)
	out_of_order["position"] = rules.get_course(0)["beacons"][1]
	var out_of_order_after: Dictionary = rules.step(out_of_order, {}, 0.05)
	_expect(int(out_of_order_after.get("checkpoint", 0)) == 0, "later beacons cannot be collected out of order")

	var landing_course: Dictionary = rules.get_course(0)
	var landing_state: Dictionary = rules.new_run(0)
	landing_state["position"] = Vector2(float(landing_course["runway_x"]) - 38.0, float(landing_course["runway_y"]))
	landing_state["velocity"] = Vector2(100.0, 0.0)
	landing_state["pitch"] = 0.0
	landing_state["checkpoint"] = 3
	var landed: Dictionary = rules.step(landing_state, {}, 0.05)
	_expect(str(landed.get("status", "")) == "landed", "valid approach after all beacons completes a safe landing")

	var unsafe_state: Dictionary = landing_state.duplicate(true)
	unsafe_state["position"] = Vector2(float(landing_course["runway_x"]) - 38.0, float(landing_course["runway_y"]) + 90.0)
	var unsafe: Dictionary = rules.step(unsafe_state, {}, 0.05)
	_expect(str(unsafe.get("status", "")) == "crashed", "runway approach outside the altitude window is rejected")
	var incomplete_state: Dictionary = landing_state.duplicate(true)
	incomplete_state["checkpoint"] = 0
	var incomplete: Dictionary = rules.step(incomplete_state, {}, 0.05)
	_expect(str(incomplete.get("status", "")) == "flying", "runway cannot finish the course before all beacons are collected")

	if failures.is_empty():
		print("KROLL Thermal Glider rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)


func _run_reference_flight(rules: RefCounted, course_index: int) -> String:
	var state: Dictionary = rules.call("new_run", course_index)
	var course: Dictionary = rules.call("get_course", course_index)
	for _step_index in range(1200):
		var position: Vector2 = state.get("position", Vector2.ZERO)
		var velocity: Vector2 = state.get("velocity", Vector2.ZERO)
		var checkpoint: int = int(state.get("checkpoint", 0))
		var beacons: Array = course.get("beacons", [])
		var target: Vector2
		if checkpoint < beacons.size():
			target = beacons[checkpoint]
		else:
			target = Vector2(float(course.get("runway_x", 1700.0)) - 20.0, float(course.get("runway_y", 300.0)))
		var desired_vertical_acceleration: float = clampf(0.3 * (target.y - position.y) - 0.7 * velocity.y, -28.0, 28.0)
		var thermal_lift: float = 0.0
		for thermal_value in course.get("thermals", []):
			var thermal: Dictionary = thermal_value
			var center: Vector2 = thermal.get("position", Vector2.ZERO)
			var radius: float = maxf(1.0, float(thermal.get("radius", 1.0)))
			var strength: float = clampf(1.0 - position.distance_to(center) / radius, 0.0, 1.0)
			thermal_lift += float(thermal.get("lift", 0.0)) * strength
		var gust: float = 0.0
		for gust_value in course.get("gusts", []):
			var gust_data: Dictionary = gust_value
			if absf(position.x - float(gust_data.get("x", -10000.0))) < 90.0:
				gust += float(gust_data.get("strength", 0.0))
		var needed_lift: float = 32.0 + gust - desired_vertical_acceleration
		var pitch_ratio: float = (needed_lift - velocity.x * 0.14 - thermal_lift) / (maxf(velocity.x, 1.0) * 0.85)
		var desired_pitch: float = clampf(rad_to_deg(asin(clampf(pitch_ratio, -1.0, 1.0))), -28.0, 28.0)
		var current_pitch: float = float(state.get("pitch", 0.0))
		var pitch_input: int = 1 if desired_pitch > current_pitch + 1.2 else (-1 if desired_pitch < current_pitch - 1.2 else 0)
		var battery: float = float(state.get("battery", 0.0))
		state = rules.call("step", state, {
			"pitch": pitch_input,
			"boost": velocity.x < 140.0 and battery > 2.0,
			"brake": velocity.x > 160.0
		}, 0.05)
		if str(state.get("status", "")) != "flying":
			return str(state.get("status", ""))
	return str(state.get("status", "timeout"))

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

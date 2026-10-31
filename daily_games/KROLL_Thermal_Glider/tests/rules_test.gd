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

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

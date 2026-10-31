extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Dictionary = Rules.create_state(0)
	_expect(int(state.get("mission_index", -1)) == 0, "first mission initializes")
	_expect(state.get("cargo", []).size() == 3 and int(state.get("hull", 0)) == 3, "mission starts with three cargo pods and three hull points")
	var initial_position: Vector2 = state.get("drone_pos", Vector2.ZERO)
	Rules.step(state, 0.05, {"thrust": Vector2.RIGHT, "brake": false})
	_expect(float(state.get("drone_pos", Vector2.ZERO).x) > initial_position.x, "thrust accelerates the recovery drone")

	var brake_state: Dictionary = Rules.create_state(0)
	brake_state["drone_velocity"] = Vector2(120.0, 0.0)
	Rules.step(brake_state, 0.05, {"thrust": Vector2.ZERO, "brake": true})
	_expect(float(brake_state.get("drone_velocity", Vector2.ZERO).length()) < 120.0, "brake reduces inertial drift")

	var attach_state: Dictionary = Rules.create_state(0)
	var attach_cargo: Array = attach_state.get("cargo", [])
	attach_state["drone_pos"] = attach_cargo[0].get("position", Vector2.ZERO) + Vector2(-40.0, 0.0)
	_expect(Rules.toggle_tether(attach_state), "nearby cargo can be attached")
	_expect(int(attach_state.get("tethered_index", -1)) == 0, "nearest undelivered cargo is selected")
	_expect(Rules.toggle_tether(attach_state) and int(attach_state.get("tethered_index", -1)) == -1, "second tether action releases cargo")

	var out_of_range: Dictionary = Rules.create_state(0)
	out_of_range["drone_pos"] = Vector2(40.0, 40.0)
	_expect(not Rules.toggle_tether(out_of_range), "cargo outside tether range cannot be attached")

	var tow_state: Dictionary = Rules.create_state(0)
	var tow_cargo: Array = tow_state.get("cargo", [])
	tow_cargo[0]["position"] = Vector2(150.0, 300.0)
	tow_state["drone_pos"] = Vector2(100.0, 300.0)
	_expect(Rules.toggle_tether(tow_state), "nearby cargo attaches for tow simulation")
	tow_state["drone_pos"] = Vector2(300.0, 300.0)
	Rules.step(tow_state, 0.05, {"thrust": Vector2.ZERO, "brake": false})
	_expect(float(tow_cargo[0].get("position", Vector2.ZERO).x) > 150.0, "tether tension pulls cargo toward the drone")

	var delivery_state: Dictionary = Rules.create_state(0)
	var delivery_cargo: Array = delivery_state.get("cargo", [])
	var dock: Vector2 = delivery_state.get("dock_pos", Vector2.ZERO)
	delivery_cargo[0]["position"] = dock + Vector2(-10.0, 0.0)
	delivery_state["drone_pos"] = dock + Vector2(-30.0, 0.0)
	delivery_state["tethered_index"] = 0
	Rules.step(delivery_state, 0.016, {"thrust": Vector2.ZERO, "brake": false})
	_expect(bool(delivery_cargo[0].get("delivered", false)), "cargo inside dock radius is delivered")
	_expect(int(delivery_state.get("score", 0)) == 100, "successful delivery awards score")

	var hazard_state: Dictionary = Rules.create_state(0)
	var first_hazard: Dictionary = hazard_state.get("hazards", [])[0]
	hazard_state["drone_pos"] = first_hazard.get("position", Vector2.ZERO)
	Rules.step(hazard_state, 0.016, {"thrust": Vector2.ZERO, "brake": false})
	_expect(int(hazard_state.get("hull", 0)) == 2, "hazard collision consumes one hull point")

	var reset_state: Dictionary = Rules.reset(delivery_state)
	_expect(int(reset_state.get("mission_index", -1)) == 0 and int(reset_state.get("score", -1)) == 0, "reset restores the current mission")
	var next_state: Dictionary = Rules.next_mission(state)
	_expect(int(next_state.get("mission_index", -1)) == 1, "next mission advances the authored route")
	_expect(not Rules.toggle_tether(next_state) or int(next_state.get("tethered_index", -1)) >= 0, "tether operation never selects an invalid cargo index")

	if failures.is_empty():
		print("KROLL Tether Recovery rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules: RefCounted = RulesScript.new()
	_expect(int(rules.call("layout_count")) == 3, "three deterministic survey layouts exist")
	var layout: Dictionary = rules.call("get_layout", 0)
	var state: Dictionary = rules.call("create_state", layout)
	_expect(is_equal_approx(float(state.get("oxygen", 0.0)), 100.0), "new survey starts with full oxygen")
	for layout_index in range(int(rules.call("layout_count"))):
		var candidate_layout: Dictionary = rules.call("get_layout", layout_index)
		var candidate_beacons: Array = candidate_layout.get("beacons", [])
		_expect(candidate_beacons.size() == 3, "each authored layout requires three ordered beacons")
		_expect(_inside_arena(candidate_layout.get("start", Vector2.ZERO)), "each layout start is inside the arena")
		_expect(_inside_arena(candidate_layout.get("dock", Vector2.ZERO)), "each layout dock is inside the arena")
		for beacon in candidate_beacons:
			_expect(_inside_arena(beacon), "each beacon is inside the arena")
		var route_result: Dictionary = _simulate_autopilot(rules, candidate_layout)
		_expect(bool(route_result.get("finished", false)) and bool(route_result.get("won", false)), "each authored layout is completable by the deterministic route-follower acceptance simulation")
	var thrust_state: Dictionary = rules.call("step", state, Vector2.RIGHT, 0.1, _empty_layout())
	var thrust_velocity: Vector2 = thrust_state.get("velocity", Vector2.ZERO)
	_expect(thrust_velocity.x > 0.0, "thrust accelerates the drone")
	var capped_state: Dictionary = state.duplicate(true)
	capped_state["velocity"] = Vector2(500.0, 0.0)
	capped_state = rules.call("step", capped_state, Vector2.ZERO, 0.01, _empty_layout())
	var capped_velocity: Vector2 = capped_state["velocity"]
	_expect(capped_velocity.length() <= 230.0 + 0.01, "drone speed is capped")
	var drag_state: Dictionary = state.duplicate(true)
	drag_state["velocity"] = Vector2(100.0, 0.0)
	drag_state = rules.call("step", drag_state, Vector2.ZERO, 0.1, _empty_layout())
	var dragged_velocity: Vector2 = drag_state["velocity"]
	_expect(dragged_velocity.length() < 100.0, "water drag reduces momentum without thrust")
	var current_layout: Dictionary = _empty_layout()
	current_layout["currents"] = [{"center": Vector2(100.0, 100.0), "radius": 100.0, "force": Vector2(80.0, 0.0)}]
	var current_state: Dictionary = rules.call("create_state", current_layout)
	current_state["position"] = Vector2(100.0, 100.0)
	current_state = rules.call("step", current_state, Vector2.ZERO, 0.1, current_layout)
	var current_velocity: Vector2 = current_state["velocity"]
	_expect(current_velocity.x > 0.0, "current field applies deterministic drift")
	var route_layout: Dictionary = {
		"name": "Test Route",
		"start": Vector2(100.0, 100.0),
		"dock": Vector2(500.0, 350.0),
		"beacons": [Vector2(100.0, 100.0)],
		"hazards": [],
		"currents": []
	}
	var route_state: Dictionary = rules.call("create_state", route_layout)
	route_state = rules.call("step", route_state, Vector2.ZERO, 0.01, route_layout)
	_expect(int(route_state.get("collected", 0)) == 1, "drone collects the next beacon in route order")
	_expect(not bool(route_state.get("finished", false)), "collecting the final beacon does not win before returning to dock")
	route_state["position"] = Vector2(500.0, 350.0)
	route_state = rules.call("step", route_state, Vector2.ZERO, 0.01, route_layout)
	_expect(bool(route_state.get("finished", false)) and bool(route_state.get("won", false)), "returning to dock after all beacons wins")
	var premature_layout: Dictionary = route_layout.duplicate(true)
	var premature_state: Dictionary = rules.call("create_state", premature_layout)
	premature_state["position"] = premature_layout["dock"]
	premature_state = rules.call("step", premature_state, Vector2.ZERO, 0.01, premature_layout)
	_expect(not bool(premature_state.get("finished", false)), "dock cannot be used to skip required beacons")
	var hazard_layout: Dictionary = _empty_layout()
	hazard_layout["hazards"] = [Vector2(100.0, 100.0)]
	var hazard_state: Dictionary = rules.call("create_state", hazard_layout)
	hazard_state["position"] = Vector2(100.0, 100.0)
	hazard_state = rules.call("step", hazard_state, Vector2.ZERO, 0.01, hazard_layout)
	_expect(int(hazard_state.get("hits", 0)) == 1, "hazard contact is registered")
	_expect(float(hazard_state.get("oxygen", 100.0)) < 88.0, "hazard contact removes oxygen")
	var cooldown_state: Dictionary = hazard_state.duplicate(true)
	cooldown_state["position"] = Vector2(100.0, 100.0)
	cooldown_state = rules.call("step", cooldown_state, Vector2.ZERO, 0.01, hazard_layout)
	_expect(int(cooldown_state.get("hits", 0)) == 1, "hazard cooldown prevents repeated contact damage")
	var exhausted_state: Dictionary = rules.call("create_state", _empty_layout())
	exhausted_state["oxygen"] = 0.01
	exhausted_state = rules.call("step", exhausted_state, Vector2.ZERO, 0.1, _empty_layout())
	_expect(bool(exhausted_state.get("finished", false)) and not bool(exhausted_state.get("won", false)), "oxygen depletion ends the survey")
	var finished_snapshot: Dictionary = exhausted_state.duplicate(true)
	var unchanged: Dictionary = rules.call("step", exhausted_state, Vector2.RIGHT, 0.1, _empty_layout())
	_expect(unchanged == finished_snapshot, "finished survey state is immutable")
	var invalid_delta: Dictionary = rules.call("step", state, Vector2.RIGHT, -1.0, _empty_layout())
	_expect(invalid_delta == state, "invalid delta does not mutate the survey")
	if failures.is_empty():
		print("KROLL Tidal Survey rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _simulate_autopilot(rules: RefCounted, layout: Dictionary) -> Dictionary:
	var state: Dictionary = rules.call("create_state", layout)
	var beacons: Array = layout.get("beacons", [])
	var delta: float = 1.0 / 60.0
	for _frame in range(7500):
		if bool(state.get("finished", false)):
			return state
		var collected: int = int(state.get("collected", 0))
		var target: Vector2 = beacons[collected] if collected < beacons.size() else layout.get("dock", Vector2.ZERO)
		var position: Vector2 = state.get("position", Vector2.ZERO)
		var velocity: Vector2 = state.get("velocity", Vector2.ZERO)
		var offset: Vector2 = target - position
		var desired_velocity: Vector2 = Vector2.ZERO
		if offset.length_squared() > 0.001:
			desired_velocity = offset.normalized() * minf(145.0, offset.length() * 1.3)
		var acceleration: Vector2 = (desired_velocity - velocity) * 2.0
		if acceleration.length() > 190.0:
			acceleration = acceleration.normalized() * 190.0
		state = rules.call("step", state, acceleration / 190.0, delta, layout)
	return state

func _inside_arena(position: Vector2) -> bool:
	return position.x >= 0.0 and position.x <= 640.0 and position.y >= 0.0 and position.y <= 420.0

func _empty_layout() -> Dictionary:
	return {
		"name": "Empty",
		"start": Vector2(100.0, 100.0),
		"dock": Vector2(500.0, 350.0),
		"beacons": [],
		"hazards": [],
		"currents": []
	}

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

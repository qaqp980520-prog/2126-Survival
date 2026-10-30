extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.get_scenario_count() == 3, "three authored routes exist")
	var scenario: Dictionary = Rules.get_scenario(0)
	var state: Dictionary = Rules.create_state(0)
	_expect(int(state.get("lane", -1)) == 1 and int(state.get("health", 0)) == 2, "runner starts in the center lane with two integrity points")
	state = Rules.step(state, {"left": true}, 0.01, scenario)
	_expect(int(state.get("lane", -1)) == 0, "left input moves one lane")
	state = Rules.step(state, {"left": true}, 0.01, scenario)
	_expect(int(state.get("lane", -1)) == 0, "lane movement clamps at the left edge")

	var barrier_state: Dictionary = Rules.create_state(0)
	barrier_state["obstacles"] = [{"at": 1.0, "lane": 1, "kind": "barrier", "resolved": false}]
	var safe_barrier: Dictionary = Rules.step(barrier_state, {"jump": true}, 0.1, {"end_distance": 50.0, "required_cells": 0})
	_expect(int(safe_barrier.get("health", 0)) == 2, "jump clears a barrier crossed during the jump window")
	_expect(bool(safe_barrier["obstacles"][0].get("resolved", false)), "crossed barrier resolves exactly once")
	var hit_barrier: Dictionary = Rules.step(barrier_state, {}, 0.1, {"end_distance": 50.0, "required_cells": 0})
	_expect(int(hit_barrier.get("health", 0)) == 1, "an unjumped barrier consumes one integrity point")

	var gate_state: Dictionary = Rules.create_state(0)
	gate_state["obstacles"] = [{"at": 1.0, "lane": 1, "kind": "gate", "resolved": false}]
	var safe_gate: Dictionary = Rules.step(gate_state, {"slide": true}, 0.1, {"end_distance": 50.0, "required_cells": 0})
	_expect(int(safe_gate.get("health", 0)) == 2, "sliding clears a low gate")

	var drone_state: Dictionary = Rules.create_state(0)
	drone_state["obstacles"] = [{"at": 1.0, "lane": 1, "kind": "drone", "resolved": false}]
	var safe_drone: Dictionary = Rules.step(drone_state, {"right": true}, 0.1, {"end_distance": 50.0, "required_cells": 0})
	_expect(int(safe_drone.get("health", 0)) == 2 and int(safe_drone.get("lane", -1)) == 2, "changing lanes avoids a drone")

	var pickup_state: Dictionary = Rules.create_state(0)
	pickup_state["pickups"] = [{"at": 1.0, "lane": 1, "resolved": false}]
	var pickup_result: Dictionary = Rules.step(pickup_state, {}, 0.1, {"end_distance": 50.0, "required_cells": 0})
	_expect(int(pickup_result.get("cells", 0)) == 1, "pickup is collected when the runner crosses it in the matching lane")
	var miss_state: Dictionary = Rules.create_state(0)
	miss_state["pickups"] = [{"at": 1.0, "lane": 0, "resolved": false}]
	var missed: Dictionary = Rules.step(miss_state, {}, 0.1, {"end_distance": 50.0, "required_cells": 0})
	_expect(int(missed.get("cells", 0)) == 0, "pickup in another lane is not collected")

	var finish_state: Dictionary = Rules.create_state(0)
	finish_state["pickups"] = []
	finish_state["obstacles"] = []
	var won: Dictionary = Rules.step(finish_state, {}, 4.0, {"end_distance": 50.0, "required_cells": 0})
	_expect(str(won.get("status", "")) == "won", "reaching the exit with the required cells wins")
	var failed: Dictionary = Rules.step(finish_state, {}, 4.0, {"end_distance": 50.0, "required_cells": 1})
	_expect(str(failed.get("status", "")) == "failed", "reaching the exit without enough cells fails")
	var invalid_delta: Dictionary = Rules.step(finish_state, {}, 0.0, {"end_distance": 50.0, "required_cells": 0})
	_expect(is_equal_approx(float(invalid_delta.get("distance", -1.0)), 0.0), "non-positive delta does not advance the simulation")
	if failures.is_empty():
		print("KROLL Void Runner rules tests passed.")
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

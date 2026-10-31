extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.get_level_count() == 3, "three authored traffic shifts are available")
	_expect(Rules.get_level_data(0).get("id", "") == "depot_rush", "first shift is Depot Rush")
	_expect(Rules.get_level_data(2).get("id", "") == "freight_window", "third shift is Freight Window")
	var intervals: Array[int] = [4, 5, 5]
	for level_index in range(Rules.get_level_count()):
		var state: Dictionary = Rules.create_state(level_index)
		var desired_axis: int = Rules.AXIS_NS
		var interval: int = intervals[level_index]
		for tick_index in range(int(state.get("max_ticks", 0))):
			if tick_index > 0 and tick_index % interval == 0 and str(state.get("phase", "")) != Rules.PHASE_CLEARANCE:
				desired_axis = Rules.AXIS_EW if desired_axis == Rules.AXIS_NS else Rules.AXIS_NS
				Rules.request_signal(state, desired_axis)
			state = Rules.advance_tick(state)
			if str(state.get("status", "")) != "running":
				break
		_expect(str(state.get("status", "")) == "won", "authored signal strategy completes %s" % str(state.get("level_id", "")))
		_expect(int(state.get("delivered", 0)) >= int(state.get("target_deliveries", 0)), "completed shift reaches its delivery quota")
	var transition := Rules.create_state(0)
	_expect(Rules.request_signal(transition, Rules.AXIS_EW), "controller accepts a valid axis change")
	_expect(str(transition.get("phase", "")) == Rules.PHASE_CLEARANCE, "signal change enters all-red clearance")
	_expect(not Rules.request_signal(transition, Rules.AXIS_NS), "a second signal request is rejected during clearance")
	transition = Rules.advance_tick(transition)
	_expect(str(transition.get("phase", "")) == Rules.PHASE_EW_GREEN, "clearance ends with only east-west green")
	_expect(not Rules.request_signal(transition, 7), "invalid signal axis is rejected")
	var fair := Rules.create_state(0)
	fair["arrivals"] = []
	fair["target_deliveries"] = 99
	fair["queues"]["north"] = [1, 2]
	fair["queues"]["south"] = [3, 4]
	fair = Rules.advance_tick(fair)
	_expect(int(fair.get("delivered", 0)) == 1 and fair.get("last_served", {}).get("ns", "") == "north", "north/south queue tie starts with north")
	fair = Rules.advance_tick(fair)
	_expect(int(fair.get("delivered", 0)) == 2 and fair.get("last_served", {}).get("ns", "") == "south", "north/south queue tie alternates fairly")
	var overflow := Rules.create_state(0)
	overflow["tick"] = 1
	overflow["queues"]["east"] = [1, 2, 3, 4, 5]
	overflow = Rules.advance_tick(overflow)
	_expect(str(overflow.get("status", "")) == "failed" and str(overflow.get("reason", "")) == "queue_overflow", "full approach queue fails safely before exceeding its limit")
	var timeout := Rules.create_state(0)
	timeout["arrivals"] = []
	timeout["target_deliveries"] = 999
	timeout["queue_limit"] = 99
	for tick_index in range(int(timeout.get("max_ticks", 0))):
		timeout = Rules.advance_tick(timeout)
	_expect(str(timeout.get("status", "")) == "failed" and str(timeout.get("reason", "")) == "timeout", "shift timeout fails cleanly when quota is unreachable")
	if failures.is_empty():
		print("KROLL Crossflow Controller rules tests passed.")
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
		push_error("FAIL: " + description)

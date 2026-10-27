extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var state: Dictionary = Rules.new_state()
	assert(str(state["status"]) == "playing")
	assert(is_equal_approx(float(state["remaining_time"]), Rules.TIME_LIMIT))

	state = Rules.collect_data(state, "relay_data_01")
	var collected_ids: Array = state.get("data_ids", [])
	assert(collected_ids.size() == 1)
	state = Rules.collect_data(state, "relay_data_01")
	collected_ids = state.get("data_ids", [])
	assert(collected_ids.size() == 1, "Duplicate data must not increase progress")
	state = Rules.reach_exit(state)
	assert(str(state["status"]) == "playing", "Exit must remain locked before all data is collected")
	assert(str(state["last_action"]) == "gate_locked")

	for index: int in range(2, Rules.REQUIRED_DATA + 1):
		state = Rules.collect_data(state, "relay_data_%02d" % index)
	collected_ids = state.get("data_ids", [])
	assert(collected_ids.size() == Rules.REQUIRED_DATA)
	state = Rules.reach_exit(state)
	assert(str(state["status"]) == "won", "Exit should win after all required data is collected")
	var won_state: Dictionary = Rules.tick(state, 999.0)
	assert(str(won_state["status"]) == "won", "Terminal state must not time out")

	var timeout_state: Dictionary = Rules.tick(Rules.new_state(), Rules.TIME_LIMIT + 1.0)
	assert(str(timeout_state["status"]) == "failed")
	assert(str(timeout_state["last_action"]) == "timeout")
	var fallen_state: Dictionary = Rules.fail(Rules.new_state(), "fell")
	assert(str(fallen_state["status"]) == "failed")
	assert(str(fallen_state["last_action"]) == "fell")
	var invalid_delta_state: Dictionary = Rules.tick(Rules.new_state(), INF)
	assert(str(invalid_delta_state["status"]) == "playing", "Non-finite delta must not corrupt state")

	print("KROLL Vertical Relay rules tests passed.")
	quit(0)

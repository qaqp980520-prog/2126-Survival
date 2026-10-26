extends SceneTree

const Rules = preload("res://scripts/rules.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var state: Dictionary = Rules.apply_checkpoint(1, 0, 0)
	assert(not bool(state["accepted"]), "Out-of-order gate must be rejected.")
	assert(int(state["next_checkpoint"]) == 1 and int(state["lap_count"]) == 0)
	for gate in [1, 2, 3, 0]:
		state = Rules.apply_checkpoint(int(state["next_checkpoint"]), int(state["lap_count"]), gate)
		assert(bool(state["accepted"]), "The expected gate must advance the race.")
	assert(int(state["lap_count"]) == 1)
	assert(int(state["next_checkpoint"]) == 1)
	for _lap in range(2):
		for gate in [1, 2, 3, 0]:
			state = Rules.apply_checkpoint(int(state["next_checkpoint"]), int(state["lap_count"]), gate)
	assert(int(state["lap_count"]) == Rules.LAPS_TO_WIN)
	assert(bool(state["finished"]), "Three completed laps should win.")
	assert(Rules.is_off_track(0.0))
	assert(Rules.is_off_track(1.3))
	assert(not Rules.is_off_track(1.0))
	assert(Rules.can_activate_boost(45.0, 0.0))
	assert(not Rules.can_activate_boost(44.9, 0.0))
	assert(not Rules.can_activate_boost(100.0, 0.01))
	assert(is_equal_approx(Rules.clamp_speed(400.0, 300.0), 300.0))
	assert(is_equal_approx(Rules.clamp_speed(-5.0, 300.0), 0.0))
	print("KROLL Vector Rally rules tests passed.")
	quit(0)

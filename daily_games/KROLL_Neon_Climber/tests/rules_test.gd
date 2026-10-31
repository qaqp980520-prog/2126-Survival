extends SceneTree
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.level_count() == 3, "three platforming sectors are authored")
	for level_index in range(Rules.level_count()):
		_expect(Rules.is_valid_level(level_index), "sector %d has valid geometry and three unique cores" % level_index)
		_expect(Rules.required_core_count(level_index) == 3, "sector %d requires three data cores" % level_index)
	var state: Dictionary = Rules.new_run(0)
	_expect(str(state.get("level_id", "")) == "maintenance_shaft", "first sector starts at Maintenance Shaft")
	_expect(not Rules.can_exit(state), "exit remains locked before collecting the data cores")
	state = Rules.collect_core(state, "core_a")
	_expect((state["collected"] as Array).size() == 1, "first data core is recorded")
	state = Rules.collect_core(state, "core_a")
	_expect((state["collected"] as Array).size() == 1, "duplicate data core does not count twice")
	state = Rules.collect_core(state, "unknown_core")
	_expect((state["collected"] as Array).size() == 1, "unknown data core is rejected")
	state = Rules.activate_checkpoint(state, "wrong_checkpoint")
	_expect(str(state["checkpoint_id"]) == "start", "unknown checkpoint is rejected")
	state = Rules.activate_checkpoint(state, "midway")
	_expect(str(state["checkpoint_id"]) == "midway", "authored checkpoint is activated")
	state = Rules.record_hazard(state)
	_expect(int(state["deaths"]) == 1, "hazard contact increments the fall counter")
	_expect((state["collected"] as Array).size() == 1, "checkpoint respawn rules preserve collected cores")
	_expect(not Rules.can_exit(state), "partial collection cannot unlock the exit")
	state = Rules.collect_core(state, "core_b")
	state = Rules.collect_core(state, "core_c")
	_expect(Rules.can_exit(state), "all three unique data cores unlock the exit")
	state = Rules.complete_level(state)
	_expect(str(state["status"]) == "complete", "exit completion changes the sector state")
	var next: Dictionary = Rules.next_level(state)
	_expect(int(next["level_index"]) == 1 and str(next["level_id"]) == "reactor_scaffold", "completed sector unlocks Reactor Scaffold")
	var blocked: Dictionary = Rules.next_level(Rules.new_run(0))
	_expect(int(blocked["level_index"]) == 0, "unfinished sector cannot be skipped")
	var reset: Dictionary = Rules.new_run(2)
	reset = Rules.collect_core(reset, "core_a")
	reset = Rules.record_hazard(reset)
	reset = Rules.new_run(int(reset["level_index"]))
	_expect((reset["collected"] as Array).is_empty() and int(reset["deaths"]) == 0, "new run resets cores and falls")
	if failures.is_empty():
		print("KROLL Neon Climber rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

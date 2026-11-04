extends SceneTree

const Rules = preload("res://rules.gd")

const SOLUTIONS = [
	[
		{"anchor":Vector2i(0,0),"rotation":0},
		{"anchor":Vector2i(2,0),"rotation":0},
		{"anchor":Vector2i(2,1),"rotation":0},
		{"anchor":Vector2i(4,1),"rotation":0},
		{"anchor":Vector2i(0,4),"rotation":0}
	],
	[
		{"anchor":Vector2i(0,0),"rotation":0},
		{"anchor":Vector2i(3,0),"rotation":0},
		{"anchor":Vector2i(0,1),"rotation":0},
		{"anchor":Vector2i(2,1),"rotation":0},
		{"anchor":Vector2i(0,3),"rotation":0}
	],
	[
		{"anchor":Vector2i(0,0),"rotation":0},
		{"anchor":Vector2i(2,0),"rotation":0},
		{"anchor":Vector2i(2,1),"rotation":0},
		{"anchor":Vector2i(3,1),"rotation":0},
		{"anchor":Vector2i(0,2),"rotation":0},
		{"anchor":Vector2i(2,3),"rotation":0}
	]
]

const UNSTABLE_LAYOUT = [
	{"anchor":Vector2i(0,0),"rotation":0},
	{"anchor":Vector2i(0,2),"rotation":0},
	{"anchor":Vector2i(0,3),"rotation":0},
	{"anchor":Vector2i(2,0),"rotation":0},
	{"anchor":Vector2i(1,3),"rotation":0}
]

var failures: Array[String] = []

func _initialize() -> void:
	_test_rotation_normalization()
	_test_overlap_and_bounds_rejection()
	_test_unstable_load_can_be_undone()
	_test_all_authored_manifests()
	_test_restart_and_score_integrity()
	if failures.is_empty():
		print("KROLL Zero-G Cargo Bay rules tests passed.")
		quit(0)
	else:
		push_error("KROLL Zero-G Cargo Bay rules test failures: " + str(failures))
		quit(1)

func _test_rotation_normalization() -> void:
	var vertical: Array[Vector2i] = Rules.rotated_cells("bar", 1)
	_expect(vertical.size() == 2, "rotated bar keeps both cells")
	_expect(vertical[0].x == 0 and vertical[1].x == 0, "rotated bar normalizes to one column")
	_expect(vertical[0].y != vertical[1].y, "rotated bar spans two rows")
	_expect(Rules.rotated_cells("unknown", 0).is_empty(), "unknown cargo has no footprint")

func _test_overlap_and_bounds_rejection() -> void:
	var state: Dictionary = Rules.new_state()
	state["cursor"] = Vector2i(0,0)
	var first: Dictionary = Rules.perform_action(state, "place")
	_expect(bool(first.get("accepted", false)), "first crate placement is accepted")
	state = first.get("state", state)
	var before: Dictionary = state.duplicate(true)
	state["cursor"] = Vector2i(0,0)
	var overlap: Dictionary = Rules.perform_action(state, "place")
	_expect(not bool(overlap.get("accepted", false)), "overlapping second cargo is rejected")
	_expect(overlap.get("state", {}) == before, "rejected overlap leaves state unchanged")

	var edge_state: Dictionary = Rules.new_state()
	edge_state["cursor"] = Vector2i(4,4)
	var edge: Dictionary = Rules.perform_action(edge_state, "place")
	_expect(not bool(edge.get("accepted", false)), "a footprint extending beyond the deck is rejected")
	_expect(edge_state.get("placements", []).is_empty(), "out-of-bounds placement does not mutate the input state")

func _test_unstable_load_can_be_undone() -> void:
	var state: Dictionary = Rules.new_state()
	for item in UNSTABLE_LAYOUT:
		state["cursor"] = item["anchor"]
		state["rotation"] = int(item["rotation"])
		var result: Dictionary = Rules.perform_action(state, "place")
		_expect(bool(result.get("accepted", false)), "unstable test layout accepts a non-overlapping cargo placement")
		state = result.get("state", state)
	_expect(str(state.get("status", "")) == "unstable", "center of mass outside the support frame marks the load unstable")
	var undo: Dictionary = Rules.perform_action(state, "undo")
	_expect(bool(undo.get("accepted", false)), "unstable load permits undo")
	_expect(str(undo["state"].get("status", "")) == "active", "undo returns the load to active placement")
	_expect(undo["state"].get("placements", []).size() == 4, "undo removes exactly the last cargo piece")

func _test_all_authored_manifests() -> void:
	var state: Dictionary = Rules.new_state()
	for level_index in range(Rules.level_count()):
		var solution: Array = SOLUTIONS[level_index]
		for step_index in range(solution.size()):
			var step: Dictionary = solution[step_index]
			state["cursor"] = step["anchor"]
			state["rotation"] = int(step["rotation"])
			var result: Dictionary = Rules.perform_action(state, "place")
			_expect(bool(result.get("accepted", false)), "manifest %d placement %d is accepted" % [level_index + 1, step_index + 1])
			state = result.get("state", state)
		var center: Vector2 = Rules.calculate_center_of_mass(state.get("placements", []))
		_expect(Rules.is_stable(center), "manifest %d center of mass is inside the support frame" % (level_index + 1))
		_expect(Rules.score_for_center(center) == 100, "manifest %d earns the perfect balance score" % (level_index + 1))
		_expect(str(state.get("status", "")) == "won", "manifest %d is marked stable" % (level_index + 1))
		_expect(int(state.get("score", 0)) == (level_index + 1) * 100, "manifest %d awards its score exactly once" % (level_index + 1))
		if level_index < Rules.level_count() - 1:
			var next: Dictionary = Rules.perform_action(state, "next")
			_expect(bool(next.get("accepted", false)), "manifest %d advances after stabilization" % (level_index + 1))
			state = next.get("state", state)
	var finish: Dictionary = Rules.perform_action(state, "next")
	_expect(bool(finish.get("accepted", false)), "final manifest can close the campaign")
	_expect(str(finish["state"].get("status", "")) == "campaign_won", "campaign completion is explicit")
	_expect(int(finish["state"].get("score", 0)) == 300, "campaign score is capped at 300")

func _test_restart_and_score_integrity() -> void:
	var state: Dictionary = Rules.new_state()
	var placed: Dictionary = Rules.perform_action(state, "place")
	state = placed.get("state", state)
	var restarted: Dictionary = Rules.perform_action(state, "restart")
	_expect(bool(restarted.get("accepted", false)), "restart always creates a fresh campaign")
	_expect(int(restarted["state"].get("score", -1)) == 0, "restart resets score")
	_expect(restarted["state"].get("placements", []).is_empty(), "restart clears the deck")
	_expect(str(restarted["state"].get("status", "")) == "active", "restart restores the active state")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

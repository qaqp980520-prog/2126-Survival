extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.mission_count() == 3, "three fossil sites are available")
	for mission_index in range(Rules.mission_count()):
		_test_perfect_excavation(mission_index)
	_test_chisel_damage_and_safe_rock()
	_test_invalid_actions_do_not_consume_resources()
	_test_rewards_cannot_be_farmed_by_restarting()
	_test_action_budget_can_fail_a_site()
	if failures.is_empty():
		print("KROLL Fossil Extraction Lab rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_perfect_excavation(mission_index: int) -> void:
	var mission: Dictionary = Rules.mission_at(mission_index)
	var state: Dictionary = Rules.new_state(mission_index)
	var center: Vector2i = mission["center"]
	_expect(not str(mission.get("hint", "")).is_empty(), "each specimen includes a readable survey clue")
	var scan := Rules.apply_tool(state, "scan", center)
	_expect(bool(scan["accepted"]), "scanner works at the authored survey center")
	state = scan["state"]
	_expect(int(state["last_scan"]["fossil_count"]) == mission["fossils"].size(), "one scan identifies the full local fossil cluster")
	var air := Rules.apply_tool(state, "air", center)
	_expect(bool(air["accepted"]), "air scribe clears the specimen sector")
	state = air["state"]
	for fossil_cell in state["fossil_cells"]:
		_expect(int(Rules.cell_at(state, fossil_cell)["depth"]) == 1, "air scribe removes one layer over every fossil fragment")
	for fossil_cell in state["fossil_cells"]:
		var brush := Rules.apply_tool(state, "brush", fossil_cell)
		_expect(bool(brush["accepted"]), "brush safely exposes one fossil fragment")
		state = brush["state"]
	_expect(str(state["status"]) == "complete", "all fragments complete the specimen")
	_expect(int(state["integrity"]) == 100, "gentle excavation preserves full specimen integrity")
	_expect(int(state["actions_used"]) == 2 + state["fossil_cells"].size(), "scan, air and brush actions are counted exactly")
	_expect(int(state["mission_score"]) == 100, "efficient undamaged excavation earns the perfect score")
	_expect(bool(state["awarded"][mission_index]), "completed site is marked as already rewarded")

func _test_chisel_damage_and_safe_rock() -> void:
	var state: Dictionary = Rules.new_state(0)
	var fossil_cell: Vector2i = state["fossil_cells"][0]
	var damaged := Rules.apply_tool(state, "chisel", fossil_cell)
	_expect(bool(damaged["accepted"]), "micro chisel can remove a buried fossil cell")
	_expect(int(damaged["state"]["integrity"]) == 80, "chisel contact reduces specimen integrity by twenty")
	_expect(bool(Rules.cell_at(damaged["state"], fossil_cell)["exposed"]), "chisel exposes the fossil while recording damage")
	var rock_state: Dictionary = Rules.new_state(0)
	var safe := Rules.apply_tool(rock_state, "chisel", Vector2i(0, 0))
	_expect(bool(safe["accepted"]), "micro chisel can clear ordinary sediment")
	_expect(int(safe["state"]["integrity"]) == 100, "chisel does not damage non-fossil rock")

func _test_invalid_actions_do_not_consume_resources() -> void:
	var state: Dictionary = Rules.new_state()
	var invalid := Rules.apply_tool(state, "brush", Vector2i(-1, 0))
	_expect(not bool(invalid["accepted"]), "out-of-grid target is rejected")
	_expect(int(state["actions_left"]) == Rules.STARTING_ACTIONS, "invalid target consumes no action")
	var no_air: Dictionary = state.duplicate(true)
	no_air["air_charges"] = 0
	var rejected_air := Rules.apply_tool(no_air, "air", Vector2i(3, 3))
	_expect(not bool(rejected_air["accepted"]), "depleted air scribe is rejected")
	_expect(int(no_air["actions_left"]) == Rules.STARTING_ACTIONS, "depleted tool consumes no action")

func _test_rewards_cannot_be_farmed_by_restarting() -> void:
	var first: Dictionary = _solve_site(0)
	_expect(int(first["campaign_score"]) == 100, "first completion awards one hundred campaign points")
	var restarted: Dictionary = Rules.restart_mission(first)
	var second: Dictionary = _solve_site_from_state(restarted)
	_expect(int(second["campaign_score"]) == 100, "replaying a rewarded site cannot duplicate campaign points")

func _test_action_budget_can_fail_a_site() -> void:
	var state: Dictionary = Rules.new_state()
	state["actions_left"] = 1
	var result := Rules.apply_tool(state, "scan", Vector2i(3, 3))
	_expect(bool(result["accepted"]), "last available action can still be used")
	_expect(str(result["state"]["status"]) == "failed", "an unfinished site fails when its action budget reaches zero")

func _solve_site(mission_index: int) -> Dictionary:
	return _solve_site_from_state(Rules.new_state(mission_index))

func _solve_site_from_state(state: Dictionary) -> Dictionary:
	var center: Vector2i = state["center"]
	state = Rules.apply_tool(state, "scan", center)["state"]
	state = Rules.apply_tool(state, "air", center)["state"]
	for fossil_cell in state["fossil_cells"]:
		state = Rules.apply_tool(state, "brush", fossil_cell)["state"]
	return state

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

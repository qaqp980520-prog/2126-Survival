extends SceneTree

const Rules = preload("res://rules.gd")
const EXPECTED_PAR: Array = [[1, 1, 2, 2], [0, 1, 0, 1], [1, 0, 0, 1]]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for level_index in range(Rules.LEVELS.size()):
		var mission: Dictionary = Rules.mission_at(level_index)
		var solutions: Array = []
		for a in range(Rules.BOARD_SIZE):
			for b in range(Rules.BOARD_SIZE):
				for c in range(Rules.BOARD_SIZE):
					for d in range(Rules.BOARD_SIZE):
						var sequence: Array = [a, b, c, d]
						var state: Dictionary = Rules.start_level(level_index)
						for row in sequence:
							state = Rules.advance_cycle(state, int(row)).get("state", state)
						if Rules.is_stable(state.get("grid", [])):
							solutions.append(sequence)
		_expect(solutions.size() == 1, "%s has exactly one four-cycle vent sequence" % str(mission.get("name", "")))
		if not solutions.is_empty():
			_expect(solutions[0] == EXPECTED_PAR[level_index], "%s matches its authored vent sequence" % str(mission.get("name", "")))

	var state: Dictionary = Rules.new_state()
	var original_grid: Array = state["grid"].duplicate(true)
	var invalid: Dictionary = Rules.advance_cycle(state, -1)
	_expect(not bool(invalid.get("accepted", false)), "negative vent row is rejected")
	_expect(state["grid"] == original_grid and int(state["cycles"]) == 0, "rejected action leaves the source state unchanged")

	state = Rules.advance_cycle(state, 1)["state"]
	_expect(int(state["cycles"]) == 1, "valid vent cycle advances the chamber")
	var undone: Dictionary = Rules.undo_cycle(state)
	_expect(bool(undone.get("accepted", false)), "last thermal cycle can be undone")
	state = undone["state"]
	_expect(int(state["cycles"]) == 0 and state["grid"] == original_grid, "undo restores the exact prior temperature field")

	var failed_state: Dictionary = Rules.start_level(0)
	for row in [0, 0, 0, 0]:
		failed_state = Rules.advance_cycle(failed_state, row)["state"]
	_expect(bool(failed_state["failed"]), "an incorrect four-cycle schedule fails containment")
	_expect(not bool(failed_state["completed"]), "failed containment is never marked complete")

	var campaign: Dictionary = Rules.new_state()
	for row in EXPECTED_PAR[0]:
		campaign = Rules.advance_cycle(campaign, row)["state"]
	_expect(bool(campaign["completed"]) and int(campaign["campaign_score"]) == 100, "first chamber awards 100 points once")
	campaign = Rules.restart_level(campaign)
	for row in EXPECTED_PAR[0]:
		campaign = Rules.advance_cycle(campaign, row)["state"]
	_expect(int(campaign["campaign_score"]) == 100, "replaying a certified chamber cannot duplicate its reward")
	campaign = Rules.advance(campaign)["state"]
	for row in EXPECTED_PAR[1]:
		campaign = Rules.advance_cycle(campaign, row)["state"]
	campaign = Rules.advance(campaign)["state"]
	for row in EXPECTED_PAR[2]:
		campaign = Rules.advance_cycle(campaign, row)["state"]
	_expect(bool(campaign["completed"]) and int(campaign["campaign_score"]) == 300, "three-chamber campaign reaches the 300-point cap")
	var final_advance: Dictionary = Rules.advance(campaign)
	_expect(not bool(final_advance.get("accepted", false)), "campaign cannot advance beyond the final chamber")
	campaign = Rules.restart_campaign()
	_expect(int(campaign["campaign_score"]) == 0 and campaign["awarded"] == [false, false, false], "new campaign resets the reward ledger")

	if failures.is_empty():
		print("KROLL Thermal Containment rules tests passed.")
		quit(0)
	else:
		push_error("KROLL Thermal Containment rules test failures: " + str(failures))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

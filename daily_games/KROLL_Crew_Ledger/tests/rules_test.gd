extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules = RulesScript.new()
	_expect(rules.case_count() == 3, "rules expose three authored crew cases")
	_expect(rules.get_case_definition(-1).is_empty(), "invalid case index returns no definition")
	_expect(rules.get_reference_solution(-1).is_empty(), "invalid reference solution is rejected")

	for case_index in range(rules.case_count()):
		_expect(rules.count_solutions(case_index) == 1, "case %d has exactly one solution" % case_index)
		var definition: Dictionary = rules.get_case_definition(case_index)
		_expect(definition.get("crew", []).size() == 4 and definition.get("stations", []).size() == 4, "case %d has four crew and four stations" % case_index)
		_expect(definition.get("clues", []).size() == 4, "case %d exposes four readable clues" % case_index)
		var solution: Array = rules.get_reference_solution(case_index)
		var state: Dictionary = rules.create_state(case_index, case_index * 100)
		for crew_index in range(4):
			var update: Dictionary = rules.set_assignment(state, crew_index, int(solution[crew_index]))
			_expect(bool(update.get("ok", false)), "case %d accepts crew %d station assignment" % [case_index, crew_index])
			state = update.get("state", {})
		var submitted: Dictionary = rules.submit_case(state)
		_expect(bool(submitted.get("completed", false)), "case %d accepts its unique clue-consistent manifest" % case_index)
		_expect(int(submitted.get("state", {}).get("score", 0)) == (case_index + 1) * 100, "case %d awards exactly 100 points" % case_index)
		var advanced: Dictionary = rules.advance_case(submitted.get("state", {}))
		_expect(bool(advanced.get("ok", false)), "case %d advances only after a correct manifest" % case_index)
		if case_index < rules.case_count() - 1:
			_expect(int(advanced.get("state", {}).get("case_index", -1)) == case_index + 1, "case %d advances to the next file" % case_index)

	var initial: Dictionary = rules.create_state(0, 70)
	var incomplete: Dictionary = rules.submit_case(initial)
	_expect(str(incomplete.get("reason", "")) == "incomplete_assignment", "submission rejects unassigned crew")
	var invalid: Dictionary = rules.set_assignment(initial, 4, 0)
	_expect(str(invalid.get("reason", "")) == "invalid_crew", "invalid crew index is rejected")
	invalid = rules.set_assignment(initial, 0, 4)
	_expect(str(invalid.get("reason", "")) == "invalid_station", "invalid station index is rejected")
	invalid = rules.set_assignment(initial, 0, 0)
	var duplicate_state: Dictionary = invalid.get("state", {})
	invalid = rules.set_assignment(duplicate_state, 1, 0)
	var duplicate_result: Dictionary = rules.submit_case(invalid.get("state", {}))
	_expect(str(duplicate_result.get("reason", "")) == "duplicate_station", "duplicate station assignment is rejected before clue evaluation")

	var wrong_state: Dictionary = rules.create_state(0, 40)
	for crew_index in range(4):
		wrong_state = rules.set_assignment(wrong_state, crew_index, [0, 1, 2, 3][crew_index]).get("state", {})
	var wrong_result: Dictionary = rules.submit_case(wrong_state)
	_expect(str(wrong_result.get("state", {}).get("status", "")) == "failed", "complete but clue-inconsistent manifest fails the case")
	var reset_result: Dictionary = rules.reset_case(wrong_result.get("state", {}))
	_expect(bool(reset_result.get("ok", false)), "failed case can be reset")
	_expect(int(reset_result.get("state", {}).get("score", -1)) == 40, "reset preserves score from previous cases")
	_expect(reset_result.get("state", {}).get("assignments", []) == [-1, -1, -1, -1], "reset clears all four assignments")

	var final_state: Dictionary = {}
	for case_index in range(rules.case_count()):
		var state: Dictionary = rules.create_state(case_index, case_index * 100)
		var solution: Array = rules.get_reference_solution(case_index)
		for crew_index in range(4):
			state = rules.set_assignment(state, crew_index, int(solution[crew_index])).get("state", {})
		state = rules.submit_case(state).get("state", {})
		final_state = rules.advance_case(state).get("state", {})
	_expect(str(final_state.get("status", "")) == "campaign_complete", "third case completes the campaign")
	_expect(int(final_state.get("score", 0)) == 300, "campaign totals three hundred points")
	var denied_reset: Dictionary = rules.reset_case(final_state)
	_expect(not bool(denied_reset.get("ok", true)) and str(denied_reset.get("reason", "")) == "already_complete", "completed campaign cannot be reset for repeat score")

	if failures.is_empty():
		print("KROLL Crew Ledger rules tests passed.")
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

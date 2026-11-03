extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules := Rules.new()
	_expect(rules.get_case_count() == 3, "campaign contains three authored case files")
	_expect(rules.get_max_score() == 300, "campaign score is capped at 300")
	_expect(rules.get_case_definition(-1).is_empty(), "invalid case index returns an empty definition")

	for case_index in range(rules.get_case_count()):
		var definition: Dictionary = rules.get_case_definition(case_index)
		var suspects: Array = definition.get("suspects", [])
		var evidence: Array = definition.get("evidence", [])
		var solution_count: int = 0
		for suspect in suspects:
			for first_index in range(evidence.size()):
				for second_index in range(first_index + 1, evidence.size()):
					var pair: Array = [str(evidence[first_index].get("id", "")), str(evidence[second_index].get("id", ""))]
					if rules.is_correct_deduction(case_index, str(suspect.get("id", "")), pair):
						solution_count += 1
		_expect(solution_count == 1, "case %d has exactly one suspect/evidence-pair solution" % (case_index + 1))

	var wrong_state: Dictionary = rules.create_state(103)
	_expect(bool(rules.select_suspect(wrong_state, "taro")), "valid suspect selection is accepted")
	_expect(bool(rules.toggle_evidence(wrong_state, "console")), "first evidence selection is accepted")
	_expect(bool(rules.toggle_evidence(wrong_state, "biometric")), "second evidence selection is accepted")
	_expect(not bool(rules.toggle_evidence(wrong_state, "coolant")), "third simultaneous evidence selection is rejected")
	var selected_wrong: Array = wrong_state.get("selected_evidence", [])
	_expect(selected_wrong.size() == 2, "evidence selection never exceeds two records")
	for attempt in range(3):
		var wrong_result: Dictionary = rules.submit_deduction(wrong_state)
		_expect(not bool(wrong_result.get("ok", true)), "incorrect deduction is rejected on attempt %d" % (attempt + 1))
	_expect(str(wrong_state.get("status", "")) == "failed", "third incorrect deduction fails the current case")
	_expect(int(wrong_state.get("score", 0)) == 0, "incorrect deductions award no score")
	_expect(bool(rules.restart_case(wrong_state)), "failed case can be retried")
	_expect(int(wrong_state.get("strikes", -1)) == 0, "retry resets strikes")
	_expect(str(wrong_state.get("selected_suspect", "")) == "", "retry clears suspect selection")

	var campaign: Dictionary = rules.create_state(103)
	for case_index in range(rules.get_case_count()):
		var definition: Dictionary = rules.get_case_definition(case_index)
		var proof: Array = definition.get("proof", [])
		_expect(bool(rules.select_suspect(campaign, str(definition.get("culprit", "")))), "correct suspect is selectable")
		_expect(bool(rules.toggle_evidence(campaign, str(proof[0]))), "first proof record is selectable")
		_expect(bool(rules.toggle_evidence(campaign, str(proof[1]))), "second proof record is selectable")
		var result: Dictionary = rules.submit_deduction(campaign)
		_expect(bool(result.get("ok", false)), "authored proof solves case %d" % (case_index + 1))
		_expect(int(campaign.get("score", 0)) == (case_index + 1) * 100, "case reward is awarded once")
		if case_index < rules.get_case_count() - 1:
			_expect(bool(rules.advance_case(campaign)), "campaign advances after a solved case")
		else:
			_expect(str(campaign.get("status", "")) == "victory", "final case completes the campaign")
	_expect(int(campaign.get("score", 0)) == 300, "perfect campaign reaches exactly 300 points")
	_expect(not bool(rules.advance_case(campaign)), "completed campaign cannot advance beyond the final case")
	_expect(not bool(rules.submit_deduction(campaign).get("ok", false)), "completed campaign cannot score the final case again")

	var copied_case: Dictionary = rules.get_case_definition(0)
	copied_case["title"] = "MUTATED"
	_expect(str(rules.get_case_definition(0).get("title", "")) == "AIRLOCK 03", "case definitions are returned as defensive copies")

	if failures.is_empty():
		print("KROLL Casefile Station Zero rules tests passed.")
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

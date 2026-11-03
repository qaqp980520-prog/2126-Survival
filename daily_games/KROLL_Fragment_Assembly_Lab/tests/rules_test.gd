extends SceneTree

const Rules = preload("res://rules.gd")
var rules: Variant
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	rules = Rules.new()
	_test_level_contracts()
	_test_wrong_fragment_is_transactional()
	_test_three_mismatches_fail_and_restart()
	_test_score_is_awarded_once()
	_test_campaign_progression()
	if failures.is_empty():
		print("KROLL Fragment Assembly Lab rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_level_contracts() -> void:
	_expect(rules.get_level_count() == 3, "three authored labs are available")
	for level_index in range(rules.get_level_count()):
		var state: Dictionary = rules.create_state(level_index)
		var guard: int = 0
		while str(state.get("status", "")) == "playing" and guard < 6:
			var valid_ids: Array[String] = []
			for fragment in rules.get_available_fragments(state):
				var trial: Dictionary = rules.attempt_fragment(state, str(fragment.get("id", "")))
				if str(trial.get("sequence", "")) != str(state.get("sequence", "")):
					valid_ids.append(str(fragment.get("id", "")))
			_expect(valid_ids.size() == 1, "lab %d has exactly one valid next fragment at step %d" % [level_index + 1, guard + 1])
			if valid_ids.is_empty():
				break
			state = rules.attempt_fragment(state, valid_ids[0])
			guard += 1
		var expected_status: String = "campaign_passed" if level_index == rules.get_level_count() - 1 else "level_passed"
		_expect(str(state.get("status", "")) == expected_status, "lab %d can be solved with its unique fragment order" % (level_index + 1))
		_expect(str(state.get("sequence", "")) == str(state.get("target", "")), "lab %d reconstructs its exact target" % (level_index + 1))

func _test_wrong_fragment_is_transactional() -> void:
	var state: Dictionary = rules.create_state(0)
	var rejected: Dictionary = rules.attempt_fragment(state, "D1")
	_expect(str(rejected.get("sequence", "")) == str(state.get("sequence", "")), "wrong fragment does not mutate the assembled sequence")
	var rejected_used_ids: Array = rejected.get("used_ids", [])
	_expect(rejected_used_ids.is_empty(), "wrong fragment remains available after rejection")
	_expect(int(rejected.get("errors", 0)) == 1, "wrong fragment consumes one mismatch allowance")
	_expect(str(state.get("sequence", "")) == "ACGTAG", "original state remains immutable")

func _test_three_mismatches_fail_and_restart() -> void:
	var state: Dictionary = rules.create_state(0, 40)
	state = rules.attempt_fragment(state, "D1")
	state = rules.attempt_fragment(state, "D1")
	state = rules.attempt_fragment(state, "D1")
	_expect(str(state.get("status", "")) == "failed", "third mismatch fails the current lab")
	var restarted: Dictionary = rules.restart_level(state)
	_expect(str(restarted.get("status", "")) == "playing", "restart returns the lab to playing")
	_expect(int(restarted.get("errors", -1)) == 0, "restart clears mismatch count")
	_expect(str(restarted.get("sequence", "")) == "ACGTAG", "restart restores the seed fragment")
	_expect(int(restarted.get("total_score", -1)) == 40, "restart preserves previously earned campaign score")

func _test_score_is_awarded_once() -> void:
	var state: Dictionary = rules.create_state(0)
	state = rules.attempt_fragment(state, "A")
	state = rules.attempt_fragment(state, "B")
	_expect(str(state.get("status", "")) == "level_passed", "first lab passes after the exact sequence is assembled")
	_expect(int(state.get("total_score", 0)) == 100, "perfect first lab awards 100 points")
	var after_pass: Dictionary = rules.attempt_fragment(state, "D1")
	_expect(int(after_pass.get("total_score", 0)) == 100, "post-pass input cannot award duplicate score")
	var restart_after_pass: Dictionary = rules.restart_level(state)
	_expect(int(restart_after_pass.get("total_score", 0)) == 100, "restart cannot replay a passed lab for duplicate score")

func _test_campaign_progression() -> void:
	var state: Dictionary = rules.create_state(0)
	state = rules.next_level(state)
	_expect(int(state.get("level_index", -1)) == 0, "cannot skip a lab before passing it")
	state = rules.attempt_fragment(state, "A")
	state = rules.attempt_fragment(state, "B")
	state = rules.next_level(state)
	_expect(int(state.get("level_index", -1)) == 1, "passing lab one advances to lab two")
	_expect(int(state.get("total_score", 0)) == 100, "campaign score carries into lab two")
	state = rules.attempt_fragment(state, "A")
	state = rules.attempt_fragment(state, "B")
	state = rules.attempt_fragment(state, "C")
	state = rules.next_level(state)
	_expect(int(state.get("level_index", -1)) == 2, "passing lab two advances to lab three")
	state = rules.attempt_fragment(state, "A")
	state = rules.attempt_fragment(state, "B")
	state = rules.attempt_fragment(state, "C")
	_expect(str(state.get("status", "")) == "campaign_passed", "last lab completes the campaign")
	_expect(int(state.get("total_score", 0)) == 300, "three perfect labs award 300 total points")
	var locked: Dictionary = rules.next_level(state)
	_expect(int(locked.get("level_index", -1)) == 2, "campaign completion cannot advance beyond the final lab")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

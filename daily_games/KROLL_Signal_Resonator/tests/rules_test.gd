extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_invalid_state_and_lane()
	_test_early_hit_does_not_consume_note()
	_test_perfect_good_and_wrong_lane_scoring()
	_test_timeout_advances_notes()
	_test_campaign_completion_and_restart_lock()
	if failures.is_empty():
		print("KROLL Signal Resonator rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_invalid_state_and_lane() -> void:
	var rules := RulesScript.new()
	_expect(rules.create_state(-1).is_empty(), "invalid stage cannot create a state")
	var state: Dictionary = rules.create_state(0)
	var invalid: Dictionary = rules.submit_hit(state, 3, 900)
	_expect(not bool(invalid.get("ok", true)) and str(invalid.get("reason", "")) == "invalid_lane", "lane indexes outside 0..2 are rejected")
	var invalid_time: Dictionary = rules.submit_hit(state, 0, -1)
	_expect(not bool(invalid_time.get("ok", true)) and str(invalid_time.get("reason", "")) == "invalid_elapsed_time", "negative elapsed time is rejected")

func _test_early_hit_does_not_consume_note() -> void:
	var rules := RulesScript.new()
	var state: Dictionary = rules.create_state(0)
	var early: Dictionary = rules.submit_hit(state, 0, 500)
	_expect(not bool(early.get("ok", true)) and str(early.get("reason", "")) == "too_early", "input outside the early window is ignored")
	_expect(int(state.get("note_index", -1)) == 0, "early input leaves the note cursor unchanged")
	var in_window: Dictionary = rules.submit_hit(state, 0, 900 - rules.PERFECT_WINDOW_MS)
	_expect(bool(in_window.get("ok", false)) and str(in_window.get("grade", "")) == "perfect", "edge of the perfect window is accepted")

func _test_perfect_good_and_wrong_lane_scoring() -> void:
	var rules := RulesScript.new()
	var state: Dictionary = rules.create_state(0)
	var perfect: Dictionary = rules.submit_hit(state, 0, 900)
	_expect(bool(perfect.get("ok", false)) and str(perfect.get("grade", "")) == "perfect", "on-beat input receives a perfect grade")
	state = perfect["state"]
	var good: Dictionary = rules.submit_hit(state, 1, 900 + rules.get_beat_interval_ms(state) + 70)
	_expect(bool(good.get("ok", false)) and str(good.get("grade", "")) == "good", "input inside the good window receives a good grade")
	state = good["state"]
	var wrong: Dictionary = rules.submit_hit(state, 0, 900 + rules.get_beat_interval_ms(state) * 2)
	_expect(bool(wrong.get("ok", false)) and str(wrong.get("grade", "")) == "wrong_lane", "correct timing on the wrong lane counts as a miss")
	state = wrong["state"]
	_expect(int(state.get("hits", 0)) == 2 and int(state.get("misses", 0)) == 1, "hit and miss counters remain consistent")
	_expect(int(state.get("combo", -1)) == 0, "a wrong lane resets the combo")

func _test_timeout_advances_notes() -> void:
	var rules := RulesScript.new()
	var state: Dictionary = rules.create_state(0)
	var advanced: Dictionary = rules.advance_time(state, 900 + rules.get_beat_interval_ms(state) * 2 + rules.MISS_WINDOW_MS + 1)
	_expect(bool(advanced.get("ok", false)), "elapsed time can resolve overdue pulses")
	state = advanced["state"]
	_expect(int(state.get("note_index", -1)) == 3 and int(state.get("misses", 0)) == 3, "overdue pulses are marked missed in chronological order")

func _test_campaign_completion_and_restart_lock() -> void:
	var rules := RulesScript.new()
	var state: Dictionary = rules.create_state(0)
	for level_index in range(rules.get_level_count()):
		if level_index > 0:
			var next_level: Dictionary = rules.advance_level(state)
			_expect(bool(next_level.get("ok", false)), "campaign advances to stage %d" % (level_index + 1))
			state = next_level["state"]
		var level: Dictionary = rules.get_level_definition(level_index)
		var sequence: Array = level["sequence"]
		for note_index in range(sequence.size()):
			var expected: int = rules.get_expected_time_ms(state)
			var hit: Dictionary = rules.submit_hit(state, int(sequence[note_index]), expected)
			_expect(bool(hit.get("ok", false)) and str(hit.get("grade", "")) == "perfect", "stage %d note %d is scored" % [level_index + 1, note_index + 1])
			state = hit["state"]
		_expect(str(state.get("status", "")) == "passed", "stage %d reaches the required accuracy" % (level_index + 1))
		_expect(int(state.get("hits", 0)) == sequence.size(), "stage %d records every successful pulse" % (level_index + 1))
	_expect(str(state.get("status", "")) == "passed", "final stage remains ready for campaign completion")
	var completed: Dictionary = rules.advance_level(state)
	_expect(bool(completed.get("ok", false)) and str(completed["state"].get("status", "")) == "campaign_complete", "final stage completes the campaign")
	_expect(int(completed["state"].get("total_score", 0)) > 0, "campaign score includes all three stages")
	var locked: Dictionary = rules.submit_hit(completed["state"], 0, 900)
	_expect(not bool(locked.get("ok", true)), "completed campaign rejects additional score submissions")
	var restarted: Dictionary = rules.restart_campaign()
	_expect(bool(restarted.get("ok", false)) and int(restarted["state"].get("campaign_score", -1)) == 0, "campaign restart resets the score")
	_expect(str(restarted["state"].get("status", "")) == "playing", "campaign restart returns to the first stage")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

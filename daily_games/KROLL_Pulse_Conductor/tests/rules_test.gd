extends SceneTree
const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var rules = RulesScript.new()
	_expect(rules.get_chart_count() == 3, "three original pulse charts are available")
	for chart_index in range(rules.get_chart_count()):
		var definition: Dictionary = rules.get_chart_definition(chart_index)
		_expect(int(definition.get("bpm",0)) > 0, "chart %d has a positive tempo" % chart_index)
		var pattern: Array = definition.get("pattern",[])
		_expect(pattern.size() == 16, "chart %d contains sixteen beats" % chart_index)
		for lane_value in pattern:
			_expect(int(lane_value) >= 0 and int(lane_value) < RulesScript.LANE_COUNT, "chart %d uses only four valid lanes" % chart_index)
	_expect(str(rules.judge_timing(0.0).get("judgement","")) == "perfect", "zero timing error is perfect")
	_expect(str(rules.judge_timing(0.045).get("judgement","")) == "perfect", "perfect window boundary is inclusive")
	_expect(str(rules.judge_timing(-0.09).get("judgement","")) == "great", "early input uses the same symmetric great window")
	_expect(str(rules.judge_timing(0.14).get("judgement","")) == "good", "good window boundary is inclusive")
	_expect(str(rules.judge_timing(0.141).get("judgement","")) == "miss", "input outside the good window is a miss")
	var state: Dictionary = rules.create_state(0)
	var notes: Array = state.get("notes",[])
	_expect(notes.size() == 16, "new shift creates sixteen timed notes")
	var first_note: Dictionary = notes[0]
	var first_time: float = float(first_note["time"])
	var first_lane: int = int(first_note["lane"])
	_expect(rules.find_note_index(state,first_lane,first_time + RulesScript.GOOD_WINDOW) == 0, "late edge of the good window still finds the first note")
	_expect(rules.find_note_index(state,(first_lane + 1) % RulesScript.LANE_COUNT,first_time) == -1, "wrong lane cannot steal a note")
	var out_of_window: Dictionary = rules.hit_note(state,0,RulesScript.GOOD_WINDOW + 0.01)
	_expect(not bool(out_of_window.get("ok",true)) and str(out_of_window.get("reason","")) == "outside_window", "direct hit rejects timing outside the window")
	var hit: Dictionary = rules.hit_note(state,0,0.045)
	_expect(bool(hit.get("ok",false)) and str(hit.get("judgement","")) == "perfect", "first note accepts a perfect-boundary hit")
	state = hit["state"]
	_expect(int(state.get("score",0)) == 100 and int(state.get("combo",0)) == 1, "successful hit awards points and increments combo")
	var duplicate: Dictionary = rules.hit_note(state,0,0.0)
	_expect(not bool(duplicate.get("ok",true)) and str(duplicate.get("reason","")) == "already_judged", "a note can only be scored once")
	var missed_state: Dictionary = rules.resolve_misses(rules.create_state(0),first_time + RulesScript.GOOD_WINDOW + 0.01)
	_expect(int(missed_state.get("miss_count",0)) == 1, "expired note becomes one miss")
	_expect(int(missed_state.get("combo",-1)) == 0, "a miss resets combo")
	_expect(bool(missed_state.get("notes",[])[0].get("judged",false)), "missed note is locked against later scoring")
	var perfect_state: Dictionary = rules.create_state(0)
	var perfect_notes: Array = perfect_state.get("notes",[])
	for note_index in range(perfect_notes.size()):
		var perfect_hit: Dictionary = rules.hit_note(perfect_state,note_index,0.0)
		_expect(bool(perfect_hit.get("ok",false)), "perfect chart accepts note %d" % note_index)
		if bool(perfect_hit.get("ok",false)):
			perfect_state = perfect_hit["state"]
	_expect(str(perfect_state.get("status","")) == "passed", "sixteen perfect hits pass the first shift")
	_expect(int(perfect_state.get("score",0)) == 1600, "perfect shift scores sixteen hundred points")
	_expect(absf(rules.get_accuracy(perfect_state) - 100.0) < 0.001, "perfect shift reports one hundred percent accuracy")
	_expect(not bool(rules.restart_chart(perfect_state).get("ok",true)), "passed shift cannot be restarted for score farming")
	var failed_state: Dictionary = rules.resolve_misses(rules.create_state(0),1000.0)
	_expect(str(failed_state.get("status","")) == "failed" and int(failed_state.get("miss_count",0)) == 16, "unplayed shift fails after every note expires")
	var retried: Dictionary = rules.restart_chart(failed_state)
	_expect(bool(retried.get("ok",false)) and int(retried["state"].get("score",-1)) == 0, "failed shift can restart without carrying its failed score")
	var campaign_state: Dictionary = perfect_state
	for next_chart in range(1,rules.get_chart_count()):
		var advanced: Dictionary = rules.advance_chart(campaign_state)
		_expect(bool(advanced.get("ok",false)), "passed shift advances to chart %d" % next_chart)
		if not bool(advanced.get("ok",false)):
			break
		campaign_state = advanced["state"]
		var chart_notes: Array = campaign_state.get("notes",[])
		for note_index in range(chart_notes.size()):
			var perfect_hit: Dictionary = rules.hit_note(campaign_state,note_index,0.0)
			if bool(perfect_hit.get("ok",false)):
				campaign_state = perfect_hit["state"]
	_expect(str(campaign_state.get("status","")) == "passed", "third shift is passed before campaign finalization")
	var finished: Dictionary = rules.advance_chart(campaign_state)
	_expect(bool(finished.get("ok",false)), "last passed shift finalizes the campaign")
	_expect(str(finished.get("state",{}).get("status","")) == "campaign_complete", "campaign enters a locked terminal state")
	_expect(int(finished.get("state",{}).get("total_score",0)) == 4800, "three perfect shifts total forty-eight hundred points")
	_expect(not bool(rules.advance_chart(finished.get("state",{})).get("ok",true)), "completed campaign cannot advance again")
	_expect(int(rules.restart_campaign().get("campaign_score",-1)) == 0, "new campaign starts with zero carried score")
	if failures.is_empty():
		print("KROLL Pulse Conductor rules tests passed.")
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

extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_all_charts_clear()
	_test_offbeat_and_invalid_lane()
	_test_expired_note_counts_once()
	_test_terminal_lock()
	if failures.is_empty():
		print("KROLL Beat Lab rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_all_charts_clear() -> void:
	for chart_index in range(Rules.LANE_PATTERNS.size()):
		var rules = Rules.new()
		rules.start_chart(chart_index)
		_expect(rules.get_note_count() == 24, "each chart has 24 notes")
		var previous_time: float = -1.0
		for i in range(rules.get_note_count()):
			var note_time: float = rules.get_note_time(i)
			_expect(note_time > previous_time, "chart notes are ordered by time")
			_expect(rules.get_note_lane(i) >= 0 and rules.get_note_lane(i) < 4, "every note has a valid lane")
			var result: Dictionary = rules.judge_lane(rules.get_note_lane(i), note_time)
			_expect(bool(result.get("ok", false)), "exact timing hits note %d on chart %d" % [i, chart_index])
			previous_time = note_time
		rules.advance(previous_time + 1.0)
		var status: Dictionary = rules.get_status()
		_expect(bool(status["finished"]) and bool(status["won"]), "perfect chart clears")
		_expect(int(status["score"]) == 2400 and int(status["hits"]) == 24, "perfect chart scores 2400")
		_expect(int(status["misses"]) == 0, "perfect chart has no misses")

func _test_offbeat_and_invalid_lane() -> void:
	var rules = Rules.new()
	rules.start_chart(0)
	var before: Dictionary = rules.get_status()
	var invalid: Dictionary = rules.judge_lane(4, 0.0)
	_expect(str(invalid.get("reason", "")) == "invalid_lane", "invalid lane is rejected")
	_expect(rules.get_status() == before, "invalid lane does not mutate score or misses")
	var offbeat: Dictionary = rules.judge_lane(rules.get_note_lane(0), 0.0)
	_expect(not bool(offbeat.get("ok", false)) and int(rules.get_status()["misses"]) == 1, "early input counts one miss")

func _test_expired_note_counts_once() -> void:
	var rules = Rules.new()
	rules.start_chart(0)
	var result: Dictionary = rules.judge_lane(rules.get_note_lane(0), rules.get_note_time(0) + Rules.HIT_WINDOW_SECONDS + 0.02)
	_expect(not bool(result.get("ok", false)), "late input is rejected")
	_expect(int(rules.get_status()["misses"]) == 1, "expired note and late press do not double-count")

func _test_terminal_lock() -> void:
	var rules = Rules.new()
	rules.start_chart(1)
	var last_time: float = rules.get_note_time(rules.get_note_count() - 1)
	rules.advance(last_time + 2.0)
	var status: Dictionary = rules.get_status()
	_expect(bool(status["finished"]) and not bool(status["won"]), "letting the whole chart pass is a loss")
	var after: Dictionary = rules.judge_lane(0, last_time + 3.0)
	_expect(str(after.get("reason", "")) == "finished", "finished chart rejects further input")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

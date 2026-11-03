extends SceneTree

const Rules = preload("res://rules.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.relay_count() == 3, "campaign contains three relays")
	for relay_index in range(Rules.relay_count()):
		var relay: Dictionary = Rules.get_relay(relay_index)
		var lanes: Array = relay.get("lanes", [])
		_expect(lanes.size() == Rules.BEATS_PER_RELAY, "each relay has exactly twelve beats")
		for lane in lanes:
			_expect(int(lane) >= 0 and int(lane) < Rules.LANE_COUNT, "every authored beat targets a valid lane")
		_expect(int(relay.get("bpm", 0)) >= 60 and int(relay.get("bpm", 0)) <= 120, "relay tempo stays in the supported range")
	_expect(Rules.get_relay(-1).is_empty(), "negative relay index is rejected")
	_expect(Rules.get_relay(3).is_empty(), "out-of-range relay index is rejected")
	_expect(is_equal_approx(Rules.beat_interval(60), 1.0), "60 BPM maps to a one-second beat")
	_expect(is_equal_approx(Rules.beat_interval(120), 0.5), "120 BPM maps to a half-second beat")
	_expect(Rules.judge_hit(1, 1, 0.0).get("grade") == "perfect", "on-beat hit is perfect")
	_expect(not Rules.judge_hit(1, 1, 0.0).has("points"), "hit grades do not imply campaign score before relay completion")
	_expect(Rules.judge_hit(1, 1, Rules.PERFECT_WINDOW).get("grade") == "perfect", "perfect-window boundary is inclusive")
	_expect(Rules.judge_hit(1, 1, 0.15).get("grade") == "good", "inside the good window is accepted")
	_expect(Rules.judge_hit(1, 1, Rules.GOOD_WINDOW).get("grade") == "good", "good-window boundary is inclusive")
	_expect(Rules.judge_hit(1, 1, 0.23).get("grade") == "miss", "outside the good window is a miss")
	_expect(Rules.judge_hit(1, 2, 0.0).get("reason") == "wrong_lane", "wrong lane is rejected as a miss")
	_expect(Rules.judge_hit(-1, 0, 0.0).get("accepted") == false, "invalid expected lane is rejected")
	_expect(Rules.judge_hit(0, 0, INF).get("reason") == "invalid_timing", "non-finite timing is rejected")
	_expect(Rules.can_clear(10, 2), "ten hits with two misses clears a relay")
	_expect(not Rules.can_clear(9, 3), "nine hits with three misses fails a relay")
	_expect(Rules.relay_score(12, 0) == 100, "perfect relay earns one hundred points")
	_expect(Rules.relay_score(9, 3) == 0, "failed relay earns no points")
	if _failures.is_empty():
		print("KROLL Pulse Reactor rules tests passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)

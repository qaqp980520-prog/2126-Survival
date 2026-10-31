extends SceneTree
const Rules = preload("res://rules.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	_expect(Rules.TRACKS.size() == 3, "three authored time-trial tracks are available")
	for index in range(Rules.TRACKS.size()):
		var track: Dictionary = Rules.get_track(index)
		var race: Dictionary = Rules.new_race(index)
		_expect(str(race.get("track_id", "")) == str(track.get("id", "")), "track %d initializes with its stable ID" % index)
		_expect(Rules.is_on_track(race["position"], track), "track %d start position lies on the road ring" % index)
		_expect(track.get("checkpoints", []).size() == 4, "track %d defines four ordered checkpoints" % index)
	var state: Dictionary = Rules.new_race(0)
	var initial_position: Vector2 = state["position"]
	var accelerated: Dictionary = Rules.step(state, {"throttle": true}, 0.05)
	_expect(Vector2(accelerated["velocity"]).length() > 0.0, "throttle accelerates the car")
	_expect(Vector2(accelerated["position"]).distance_to(initial_position) > 0.0, "accelerated car advances along its heading")
	_expect(float(accelerated["elapsed"]) > 0.0, "race timer advances while racing")
	var braked: Dictionary = Rules.step(accelerated, {"brake": true}, 0.05)
	_expect(Vector2(braked["velocity"]).length() < Vector2(accelerated["velocity"]).length(), "brake reduces car speed")
	var steered: Dictionary = Rules.step(accelerated, {"steer": 1.0}, 0.05)
	_expect(not is_equal_approx(float(steered["heading"]), float(accelerated["heading"])), "steering changes heading while moving")
	var drifted: Dictionary = Rules.step(accelerated, {"handbrake": true}, 0.05)
	_expect(Vector2(drifted["velocity"]).length() > 0.0, "handbrake preserves a controllable drift instead of stopping the car")
	var offroad: Dictionary = Rules.new_race(0)
	offroad["position"] = Vector2(480.0, 350.0)
	offroad["velocity"] = Vector2(220.0, 0.0)
	var penalized: Dictionary = Rules.step(offroad, {}, 0.05)
	_expect(float(penalized["offroad_time"]) > 0.0, "off-road driving accumulates a penalty timer")
	_expect(Vector2(penalized["velocity"]).length() < 220.0, "off-road surface applies strong speed loss")
	var capped: Dictionary = Rules.new_race(0)
	capped["velocity"] = Vector2(1000.0, 0.0)
	var capped_result: Dictionary = Rules.step(capped, {}, 0.05)
	_expect(Vector2(capped_result["velocity"]).length() <= Rules.MAX_SPEED + 0.001, "speed remains under the maximum limit")
	var ordered: Dictionary = Rules.new_race(0)
	var track: Dictionary = Rules.get_track(0)
	var checkpoints: Array = track["checkpoints"]
	ordered["position"] = checkpoints[1]
	ordered = Rules.advance_checkpoint(ordered)
	_expect(int(ordered["next_checkpoint"]) == 0, "out-of-order checkpoint contact is ignored")
	for index in range(checkpoints.size()):
		ordered["position"] = checkpoints[index]
		ordered = Rules.advance_checkpoint(ordered)
		_expect(int(ordered["next_checkpoint"]) == ((index + 1) % checkpoints.size()), "checkpoint %d advances in the required order" % index)
	_expect(str(ordered["status"]) == "finished" and int(ordered["laps"]) == 1, "ordered checkpoint route completes exactly one lap")
	var next_track: Dictionary = Rules.next_track(ordered)
	_expect(int(next_track["track_index"]) == 1 and str(next_track["status"]) == "racing", "finished race advances to the next track")
	var blocked_advance: Dictionary = Rules.next_track(Rules.new_race(0))
	_expect(int(blocked_advance["track_index"]) == 0, "unfinished race cannot skip to the next track")
	var invalid_index: Dictionary = Rules.new_race(99)
	_expect(int(invalid_index["track_index"]) == 2, "invalid track index clamps to the final authored track")
	var frozen: Dictionary = Rules.step(ordered, {"throttle": true}, 0.05)
	_expect(Vector2(frozen["velocity"]).length() == 0.0, "finished race cannot continue accelerating")
	if failures.is_empty():
		print("KROLL Vector Rally rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)
func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

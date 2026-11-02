extends RefCounted
class_name KROLLSignalResonatorRules

const LANE_COUNT: int = 3
const START_DELAY_MS: int = 900
const PERFECT_WINDOW_MS: int = 45
const GOOD_WINDOW_MS: int = 100
const MISS_WINDOW_MS: int = 160
const LEVELS: Array[Dictionary] = [
	{
		"id": "carrier_lock",
		"title": "CARRIER LOCK",
		"bpm": 100,
		"sequence": [0, 1, 2, 0, 2, 1, 0, 1, 2, 2, 1, 0]
	},
	{
		"id": "phase_crossing",
		"title": "PHASE CROSSING",
		"bpm": 112,
		"sequence": [2, 0, 1, 2, 1, 0, 2, 2, 0, 1, 0, 1]
	},
	{
		"id": "deep_resonance",
		"title": "DEEP RESONANCE",
		"bpm": 124,
		"sequence": [1, 2, 0, 1, 0, 2, 1, 0, 2, 1, 2, 0]
	}
]

func get_level_count() -> int:
	return LEVELS.size()

func get_lane_count() -> int:
	return LANE_COUNT

func get_level_definition(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return LEVELS[index].duplicate(true)

func get_note_count(index: int) -> int:
	var level: Dictionary = get_level_definition(index)
	var sequence: Array = level.get("sequence", [])
	return sequence.size()

func create_state(index: int, campaign_score: int = 0, completed: Array = []) -> Dictionary:
	var level: Dictionary = get_level_definition(index)
	if level.is_empty() or campaign_score < 0:
		return {}
	var completed_levels: Array[int] = []
	for value in completed:
		if value is int and int(value) >= 0 and int(value) < LEVELS.size() and not completed_levels.has(int(value)):
			completed_levels.append(int(value))
	completed_levels.sort()
	return {
		"level_index": index,
		"level_id": str(level["id"]),
		"status": "playing",
		"campaign_score": campaign_score,
		"score": 0,
		"hits": 0,
		"misses": 0,
		"combo": 0,
		"best_combo": 0,
		"note_index": 0,
		"results": [],
		"completed_levels": completed_levels
	}

func get_beat_interval_ms(state: Dictionary) -> int:
	var level: Dictionary = get_level_definition(int(state.get("level_index", -1)))
	var bpm: int = int(level.get("bpm", 0))
	return int(round(60000.0 / float(bpm))) if bpm > 0 else -1

func get_expected_time_ms(state: Dictionary) -> int:
	var level: Dictionary = get_level_definition(int(state.get("level_index", -1)))
	var sequence: Array = level.get("sequence", [])
	var note_index: int = int(state.get("note_index", -1))
	if level.is_empty() or note_index < 0 or note_index >= sequence.size():
		return -1
	return START_DELAY_MS + note_index * get_beat_interval_ms(state)

func get_next_lane(state: Dictionary) -> int:
	var level: Dictionary = get_level_definition(int(state.get("level_index", -1)))
	var sequence: Array = level.get("sequence", [])
	var note_index: int = int(state.get("note_index", -1))
	if note_index < 0 or note_index >= sequence.size():
		return -1
	return int(sequence[note_index])

func advance_time(state: Dictionary, elapsed_ms: int) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "round_not_playing"}
	if elapsed_ms < 0:
		return {"ok": false, "reason": "invalid_elapsed_time"}
	var next: Dictionary = state.duplicate(true)
	while str(next.get("status", "")) == "playing":
		var expected_time: int = get_expected_time_ms(next)
		if expected_time < 0 or elapsed_ms <= expected_time + MISS_WINDOW_MS:
			break
		_register_miss(next)
		_finish_round(next)
	return {"ok": true, "state": next}

func submit_hit(state: Dictionary, lane: int, elapsed_ms: int) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "round_not_playing"}
	if lane < 0 or lane >= LANE_COUNT:
		return {"ok": false, "reason": "invalid_lane"}
	if elapsed_ms < 0:
		return {"ok": false, "reason": "invalid_elapsed_time"}
	var advanced: Dictionary = advance_time(state, elapsed_ms)
	if not bool(advanced.get("ok", false)):
		return advanced
	var next: Dictionary = advanced["state"]
	if str(next.get("status", "")) != "playing":
		return {"ok": false, "reason": "round_complete", "state": next}
	var expected_time: int = get_expected_time_ms(next)
	var delta: int = elapsed_ms - expected_time
	if delta < -MISS_WINDOW_MS:
		return {"ok": false, "reason": "too_early", "state": next}
	var required_lane: int = get_next_lane(next)
	if lane != required_lane:
		_register_miss(next)
		_finish_round(next)
		return {"ok": true, "grade": "wrong_lane", "delta_ms": delta, "state": next}
	var absolute_delta: int = absi(delta)
	if absolute_delta <= PERFECT_WINDOW_MS:
		_register_hit(next, "perfect", 100, delta)
		return {"ok": true, "grade": "perfect", "delta_ms": delta, "state": next}
	if absolute_delta <= GOOD_WINDOW_MS:
		_register_hit(next, "good", 60, delta)
		return {"ok": true, "grade": "good", "delta_ms": delta, "state": next}
	_register_miss(next)
	_finish_round(next)
	return {"ok": true, "grade": "miss", "delta_ms": delta, "state": next}

func advance_level(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "passed":
		return {"ok": false, "reason": "round_not_passed"}
	var level_index: int = int(state.get("level_index", -1))
	if level_index < 0 or level_index >= LEVELS.size():
		return {"ok": false, "reason": "invalid_level"}
	var completed: Array = state.get("completed_levels", []).duplicate(true)
	if not completed.has(level_index):
		completed.append(level_index)
	var total_score: int = int(state.get("campaign_score", 0)) + int(state.get("score", 0))
	if level_index + 1 >= LEVELS.size():
		return {
			"ok": true,
			"state": {
				"level_index": level_index,
				"level_id": "campaign",
				"status": "campaign_complete",
				"campaign_score": total_score,
				"total_score": total_score,
				"score": int(state.get("score", 0)),
				"hits": int(state.get("hits", 0)),
				"misses": int(state.get("misses", 0)),
				"completed_levels": completed
			}
		}
	return {"ok": true, "state": create_state(level_index + 1, total_score, completed)}

func restart_level(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) == "passed" or str(state.get("status", "")) == "campaign_complete":
		return {"ok": false, "reason": "completed_round_locked"}
	var level_index: int = int(state.get("level_index", -1))
	var next: Dictionary = create_state(level_index, int(state.get("campaign_score", 0)), state.get("completed_levels", []))
	if next.is_empty():
		return {"ok": false, "reason": "invalid_level"}
	return {"ok": true, "state": next}

func restart_campaign() -> Dictionary:
	return {"ok": true, "state": create_state(0)}

func get_accuracy_percent(state: Dictionary) -> int:
	var total: int = int(state.get("hits", 0)) + int(state.get("misses", 0))
	return int(round(100.0 * float(state.get("hits", 0)) / float(total))) if total > 0 else 100

func _register_hit(state: Dictionary, grade: String, base_score: int, delta_ms: int) -> void:
	state["hits"] = int(state.get("hits", 0)) + 1
	state["combo"] = int(state.get("combo", 0)) + 1
	state["best_combo"] = maxi(int(state.get("best_combo", 0)), int(state["combo"]))
	state["score"] = int(state.get("score", 0)) + base_score + mini(int(state["combo"]) - 1, 5) * 10
	state["results"].append({"grade": grade, "delta_ms": delta_ms, "lane": get_next_lane(state)} )
	state["note_index"] = int(state.get("note_index", 0)) + 1
	_finish_round(state)

func _register_miss(state: Dictionary) -> void:
	state["misses"] = int(state.get("misses", 0)) + 1
	state["combo"] = 0
	state["results"].append({"grade": "miss", "delta_ms": 0, "lane": get_next_lane(state)})
	state["note_index"] = int(state.get("note_index", 0)) + 1

func _finish_round(state: Dictionary) -> void:
	var level: Dictionary = get_level_definition(int(state.get("level_index", -1)))
	var sequence: Array = level.get("sequence", [])
	if sequence.is_empty() or int(state.get("note_index", 0)) < sequence.size():
		return
	var minimum_hits: int = int(ceil(float(sequence.size()) * 0.75))
	state["status"] = "passed" if int(state.get("hits", 0)) >= minimum_hits else "failed"

func _record_miss(state: Dictionary) -> void:
	_register_miss(state)

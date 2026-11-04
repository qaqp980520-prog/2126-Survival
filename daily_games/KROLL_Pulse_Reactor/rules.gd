extends RefCounted
class_name KrollPulseReactorRules

const LANE_COUNT: int = 3
const BEATS_PER_RELAY: int = 12
const LEAD_IN_SECONDS: float = 1.0
const PERFECT_WINDOW: float = 0.10
const GOOD_WINDOW: float = 0.22
const RELAY_REWARD: int = 100

const RELAYS := [
	{
		"name": "COOLANT LOOP",
		"bpm": 72,
		"lanes": [0, 1, 2, 1, 0, 2, 2, 1, 0, 1, 2, 0]
	},
	{
		"name": "TURBINE ARRAY",
		"bpm": 90,
		"lanes": [2, 0, 1, 2, 1, 0, 2, 1, 1, 0, 2, 0]
	},
	{
		"name": "CORE SYNCHRONIZER",
		"bpm": 108,
		"lanes": [1, 2, 0, 2, 0, 1, 2, 0, 1, 1, 2, 0]
	}
]

static func relay_count() -> int:
	return RELAYS.size()

static func get_relay(index: int) -> Dictionary:
	if index < 0 or index >= RELAYS.size():
		return {}
	return RELAYS[index].duplicate(true)

static func beat_interval(bpm: int) -> float:
	return 60.0 / float(maxi(1, bpm))

static func lane_name(lane: int) -> String:
	match lane:
		0:
			return "LEFT / A"
		1:
			return "CENTER / S"
		2:
			return "RIGHT / D"
		_:
			return "UNKNOWN"

static func judge_hit(expected_lane: int, actual_lane: int, timing_error: float) -> Dictionary:
	if expected_lane < 0 or expected_lane >= LANE_COUNT or actual_lane < 0 or actual_lane >= LANE_COUNT:
		return {"grade": "miss", "accepted": false, "reason": "invalid_lane"}
	if not is_finite(timing_error):
		return {"grade": "miss", "accepted": false, "reason": "invalid_timing"}
	if expected_lane != actual_lane:
		return {"grade": "miss", "accepted": true, "reason": "wrong_lane"}
	var error: float = absf(timing_error)
	if error <= PERFECT_WINDOW:
		return {"grade": "perfect", "accepted": true, "reason": ""}
	if error <= GOOD_WINDOW:
		return {"grade": "good", "accepted": true, "reason": ""}
	return {"grade": "miss", "accepted": true, "reason": "outside_window"}

static func can_clear(hit_count: int, miss_count: int) -> bool:
	return hit_count >= 10 and miss_count <= 2

static func relay_score(hit_count: int, miss_count: int) -> int:
	return RELAY_REWARD if can_clear(hit_count, miss_count) else 0

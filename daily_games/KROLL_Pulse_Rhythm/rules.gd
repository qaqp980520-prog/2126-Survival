extends RefCounted
class_name KrollPulseRhythmRules

const PERFECT_WINDOW: float = 0.075
const GOOD_WINDOW: float = 0.16

static func judge_timing(error_seconds: float) -> String:
	var error_value: float = absf(error_seconds)
	if error_value <= PERFECT_WINDOW:
		return "PERFECT"
	if error_value <= GOOD_WINDOW:
		return "GOOD"
	return "MISS"

static func score_for(judgment: String) -> int:
	match judgment:
		"PERFECT":
			return 300
		"GOOD":
			return 100
		_:
			return 0

static func lane_from_x(x_position: float, viewport_width: float = 960.0, lane_count: int = 4) -> int:
	if lane_count <= 1 or viewport_width <= 0.0:
		return 0
	return clampi(int(floor(x_position / (viewport_width / float(lane_count)))), 0, lane_count - 1)

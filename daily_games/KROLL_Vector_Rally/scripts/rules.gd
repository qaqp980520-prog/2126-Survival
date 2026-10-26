extends RefCounted

const CHECKPOINT_COUNT: int = 4
const LAPS_TO_WIN: int = 3
const TIME_LIMIT_SECONDS: float = 90.0
const OFF_TRACK_INNER_RADIUS: float = 0.76
const OFF_TRACK_OUTER_RADIUS: float = 1.24
const MIN_BOOST_SPEED: float = 45.0

static func apply_checkpoint(next_checkpoint: int, lap_count: int, gate_index: int) -> Dictionary:
	var result := {
		"accepted": false,
		"next_checkpoint": next_checkpoint,
		"lap_count": lap_count,
		"finished": lap_count >= LAPS_TO_WIN
	}
	if next_checkpoint < 0 or next_checkpoint >= CHECKPOINT_COUNT:
		return result
	if gate_index < 0 or gate_index >= CHECKPOINT_COUNT or gate_index != next_checkpoint:
		return result
	var next_gate: int = (next_checkpoint + 1) % CHECKPOINT_COUNT
	var next_lap: int = lap_count + (1 if gate_index == 0 else 0)
	result["accepted"] = true
	result["next_checkpoint"] = next_gate
	result["lap_count"] = next_lap
	result["finished"] = next_lap >= LAPS_TO_WIN
	return result

static func is_off_track(normalized_radius: float) -> bool:
	return normalized_radius < OFF_TRACK_INNER_RADIUS or normalized_radius > OFF_TRACK_OUTER_RADIUS

static func can_activate_boost(speed: float, cooldown_seconds: float) -> bool:
	return speed >= MIN_BOOST_SPEED and cooldown_seconds <= 0.0

static func clamp_speed(speed: float, maximum_speed: float) -> float:
	return clampf(speed, 0.0, maxf(0.0, maximum_speed))

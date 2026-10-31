extends RefCounted

const MISSION_COUNT: int = 3
const TARGETS_PER_MISSION: int = 4
const MIN_ZOOM: int = 0
const MAX_ZOOM: int = 4

static func get_mission(index: int) -> Dictionary:
	match posmod(index, MISSION_COUNT):
		0:
			return {
				"id": "dockside",
				"name": "DOCKSIDE CONSTELLATION",
				"region": "ORBITAL DOCK 04",
				"targets": [
					Vector2(0.18, 0.30),
					Vector2(0.34, 0.19),
					Vector2(0.48, 0.37),
					Vector2(0.62, 0.24)
				],
				"time_limit": 75.0
			}
		1:
			return {
				"id": "ion_crown",
				"name": "ION CROWN",
				"region": "ION STORM PERIMETER",
				"targets": [
					Vector2(0.72, 0.18),
					Vector2(0.82, 0.34),
					Vector2(0.66, 0.47),
					Vector2(0.84, 0.60)
				],
				"time_limit": 70.0
			}
		_:
			return {
				"id": "deep_signal",
				"name": "DEEP SIGNAL",
				"region": "OUTER DARK SECTOR",
				"targets": [
					Vector2(0.24, 0.67),
					Vector2(0.40, 0.78),
					Vector2(0.57, 0.64),
					Vector2(0.74, 0.79)
				],
				"time_limit": 65.0
			}

static func clamp_aim(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, 0.0, 1.0), clampf(value.y, 0.0, 1.0))

static func get_lock_tolerance(zoom_level: int) -> float:
	var tolerances: Array[float] = [0.075, 0.060, 0.047, 0.035, 0.025]
	return tolerances[clampi(zoom_level, MIN_ZOOM, MAX_ZOOM)]

static func can_lock(aim: Vector2, target: Vector2, zoom_level: int) -> bool:
	return aim.distance_to(target) <= get_lock_tolerance(zoom_level)

static func advance_target(current_index: int, target_count: int = TARGETS_PER_MISSION) -> int:
	return clampi(current_index + 1, 0, maxi(0, target_count))

static func is_mission_complete(target_index: int, target_count: int = TARGETS_PER_MISSION) -> bool:
	return target_count > 0 and target_index >= target_count

static func is_valid_target(target: Variant) -> bool:
	return target is Vector2 and target.x >= 0.0 and target.x <= 1.0 and target.y >= 0.0 and target.y <= 1.0

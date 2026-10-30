extends RefCounted

const MAP_SIZE: Vector2 = Vector2(640.0, 360.0)
const BASE_FRAME_HALF: Vector2 = Vector2(230.0, 150.0)
const MIN_ZOOM: int = 0
const MAX_ZOOM: int = 3

const SCENARIOS: Array[Dictionary] = [
	{"id": "lunar", "name": "LUNAR BEACON ARRAY", "targets": [Vector2(250.0, 165.0), Vector2(330.0, 125.0), Vector2(385.0, 215.0)], "hazards": [Vector2(475.0, 175.0)]},
	{"id": "crater", "name": "CRATER RELAY", "targets": [Vector2(150.0, 95.0), Vector2(210.0, 160.0), Vector2(255.0, 220.0)], "hazards": [Vector2(360.0, 150.0)]},
	{"id": "debris", "name": "ORBITAL DEBRIS FIELD", "targets": [Vector2(420.0, 100.0), Vector2(480.0, 155.0), Vector2(525.0, 220.0)], "hazards": [Vector2(315.0, 155.0)]}
]

static func get_scenario_count() -> int:
	return SCENARIOS.size()

static func get_scenario(index: int) -> Dictionary:
	return SCENARIOS[posmod(index, SCENARIOS.size())].duplicate(true)

static func create_state(_scenario_index: int = 0) -> Dictionary:
	return {"center": MAP_SIZE * 0.5, "zoom": MIN_ZOOM, "shots_left": 3, "status": "aiming", "feedback": "Frame every target. Keep all red interference outside the shot."}

static func frame_half_extents(zoom_level: int) -> Vector2:
	if zoom_level < MIN_ZOOM or zoom_level > MAX_ZOOM:
		return Vector2.ZERO
	return BASE_FRAME_HALF / pow(1.55, float(zoom_level))

static func point_inside_frame(point: Vector2, center: Vector2, zoom_level: int) -> bool:
	if zoom_level < MIN_ZOOM or zoom_level > MAX_ZOOM or not _valid_vector(point) or not _valid_vector(center):
		return false
	var half_extents: Vector2 = frame_half_extents(zoom_level)
	var offset: Vector2 = point - center
	return absf(offset.x) <= half_extents.x and absf(offset.y) <= half_extents.y

static func evaluate_capture(scenario_index: int, center: Vector2, zoom_level: int) -> Dictionary:
	if scenario_index < 0 or scenario_index >= SCENARIOS.size() or not _valid_vector(center) or zoom_level < MIN_ZOOM or zoom_level > MAX_ZOOM:
		return {"ok": false, "reason": "invalid_camera", "targets_inside": 0, "total_targets": 0, "hazards_inside": 0}
	var scenario: Dictionary = get_scenario(scenario_index)
	var targets: Array = scenario.get("targets", [])
	var hazards: Array = scenario.get("hazards", [])
	if targets.is_empty():
		return {"ok": false, "reason": "invalid_scenario", "targets_inside": 0, "total_targets": 0, "hazards_inside": 0}
	var targets_inside: int = 0
	for point_value in targets:
		if not (point_value is Vector2) or not _valid_vector(point_value):
			return {"ok": false, "reason": "invalid_scenario", "targets_inside": targets_inside, "total_targets": targets.size(), "hazards_inside": 0}
		if point_inside_frame(point_value, center, zoom_level):
			targets_inside += 1
	var hazards_inside: int = 0
	for point_value in hazards:
		if not (point_value is Vector2) or not _valid_vector(point_value):
			return {"ok": false, "reason": "invalid_scenario", "targets_inside": targets_inside, "total_targets": targets.size(), "hazards_inside": hazards_inside}
		if point_inside_frame(point_value, center, zoom_level):
			hazards_inside += 1
	var success: bool = targets_inside == targets.size() and hazards_inside == 0
	var reason: String = "clear"
	if hazards_inside > 0:
		reason = "hazard_in_frame"
	elif targets_inside < targets.size():
		reason = "targets_missing"
	return {"ok": success, "reason": reason, "targets_inside": targets_inside, "total_targets": targets.size(), "hazards_inside": hazards_inside, "half_extents": frame_half_extents(zoom_level)}

static func _valid_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)

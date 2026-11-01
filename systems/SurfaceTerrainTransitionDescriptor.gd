extends RefCounted
class_name SurfaceTerrainTransitionDescriptor

## Pure, deterministic topology descriptor for a pair of cardinally adjacent terrain patches.
## This module creates no Nodes and never mutates either input snapshot.
const POSITION_TOLERANCE: float = 0.01
const BASE_TOP_HEIGHT: float = 0.05
const HEIGHT_STEP: float = 0.25

static func build(first: Dictionary, second: Dictionary) -> Dictionary:
	var first_error: String = _validate_snapshot(first)
	if not first_error.is_empty():
		return {"ok":false,"error":"first_%s" % first_error}
	var second_error: String = _validate_snapshot(second)
	if not second_error.is_empty():
		return {"ok":false,"error":"second_%s" % second_error}
	var first_id: String = str(first["stable_id"])
	var second_id: String = str(second["stable_id"])
	if first_id == second_id:
		return {"ok":false,"error":"duplicate_stable_id"}
	var first_size: float = float(first["patch_size"])
	var second_size: float = float(second["patch_size"])
	if absf(first_size - second_size) > POSITION_TOLERANCE:
		return {"ok":false,"error":"mixed_patch_sizes"}

	var canonical_first: Dictionary = first.duplicate(true)
	var canonical_second: Dictionary = second.duplicate(true)
	if first_id > second_id:
		canonical_first = second.duplicate(true)
		canonical_second = first.duplicate(true)
	var patch_size: float = float(canonical_first["patch_size"])
	var first_position: Vector3 = canonical_first["position"]
	var second_position: Vector3 = canonical_second["position"]
	var side: String = _side_between(first_position, second_position, patch_size)
	if side.is_empty():
		return {"ok":false,"error":"not_cardinal_neighbors"}

	var first_top: float = BASE_TOP_HEIGHT + float(canonical_first["height_level"]) * HEIGHT_STEP
	var second_top: float = BASE_TOP_HEIGHT + float(canonical_second["height_level"]) * HEIGHT_STEP
	var height_delta: float = absf(first_top - second_top)
	var equal_height: bool = height_delta <= POSITION_TOLERANCE
	var higher_id: String = ""
	var lower_id: String = ""
	if not equal_height:
		if first_top > second_top:
			higher_id = str(canonical_first["stable_id"])
			lower_id = str(canonical_second["stable_id"])
		else:
			higher_id = str(canonical_second["stable_id"])
			lower_id = str(canonical_first["stable_id"])
	var edge_key: String = _make_edge_key(first_id if first_id < second_id else second_id, second_id if first_id < second_id else first_id)
	var descriptor: Dictionary = {
		"edge_key":edge_key,
		"owner_stable_id":str(canonical_first["stable_id"]),
		"first_stable_id":str(canonical_first["stable_id"]),
		"second_stable_id":str(canonical_second["stable_id"]),
		"first_side":side,
		"second_side":_opposite_side(side),
		"mode":"flush_join" if equal_height else "unequal_height",
		"transition_required":not equal_height,
		"higher_stable_id":higher_id,
		"lower_stable_id":lower_id,
		"first_top_height":first_top,
		"second_top_height":second_top,
		"height_delta":height_delta,
		"patch_size":patch_size
	}
	return {"ok":true,"descriptor":descriptor}

static func validate_descriptor(first: Dictionary, second: Dictionary, descriptor: Dictionary) -> bool:
	if not descriptor.has("edge_key"):
		return false
	var rebuilt: Dictionary = build(first, second)
	return bool(rebuilt.get("ok", false)) and rebuilt.get("descriptor", {}) == descriptor

static func _validate_snapshot(snapshot: Dictionary) -> String:
	for key in ["stable_id","position","patch_size","height_level","revision"]:
		if not snapshot.has(key):
			return "missing_%s" % key
	if not (snapshot["stable_id"] is String) or str(snapshot["stable_id"]).strip_edges().is_empty():
		return "invalid_stable_id"
	if not (snapshot["position"] is Vector3):
		return "invalid_position"
	var position: Vector3 = snapshot["position"]
	if is_nan(position.x) or is_inf(position.x) or is_nan(position.y) or is_inf(position.y) or is_nan(position.z) or is_inf(position.z):
		return "non_finite_position"
	var size_value: Variant = snapshot["patch_size"]
	if not (size_value is int or size_value is float):
		return "invalid_patch_size"
	var patch_size: float = float(size_value)
	if is_nan(patch_size) or is_inf(patch_size) or patch_size <= 0.0:
		return "invalid_patch_size"
	if not (snapshot["height_level"] is int) or int(snapshot["height_level"]) < 0 or int(snapshot["height_level"]) > 2:
		return "invalid_height_level"
	if not (snapshot["revision"] is int) or int(snapshot["revision"]) < 0:
		return "invalid_revision"
	return ""

static func _side_between(first: Vector3, second: Vector3, patch_size: float) -> String:
	var delta: Vector3 = second - first
	if absf(delta.y) > POSITION_TOLERANCE:
		return ""
	if absf(delta.x - patch_size) <= POSITION_TOLERANCE and absf(delta.z) <= POSITION_TOLERANCE:
		return "east"
	if absf(delta.x + patch_size) <= POSITION_TOLERANCE and absf(delta.z) <= POSITION_TOLERANCE:
		return "west"
	if absf(delta.z + patch_size) <= POSITION_TOLERANCE and absf(delta.x) <= POSITION_TOLERANCE:
		return "north"
	if absf(delta.z - patch_size) <= POSITION_TOLERANCE and absf(delta.x) <= POSITION_TOLERANCE:
		return "south"
	return ""

static func _opposite_side(side: String) -> String:
	match side:
		"east": return "west"
		"west": return "east"
		"north": return "south"
		"south": return "north"
		_: return ""

static func _make_edge_key(first_id: String, second_id: String) -> String:
	return "terrain-edge|%d:%s|%d:%s" % [first_id.length(), first_id, second_id.length(), second_id]

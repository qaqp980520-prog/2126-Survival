extends RefCounted
class_name SurfaceTerrainEdgePolicy

## Conservative policy for two independently persisted terrain patches that share an edge.
## Until a shared transition collider exists, only isolated patches keep a ramp to base ground.
static func classify_edge(local_state: Dictionary, neighbor_state: Dictionary = {}) -> Dictionary:
	if not _valid_state(local_state):
		return _invalid_result("invalid_local_state")
	if neighbor_state.is_empty():
		return {"valid": true, "mode": "ground_ramp", "ramp_enabled": true, "height_delta": 0.0, "higher_patch": "none", "material_seam": false}
	if not _valid_state(neighbor_state):
		return _invalid_result("invalid_neighbor_state")
	var local_height: int = int(local_state["height_level"])
	var neighbor_height: int = int(neighbor_state["height_level"])
	var delta: int = neighbor_height - local_height
	if delta == 0:
		return {"valid": true, "mode": "flush_join", "ramp_enabled": false, "height_delta": 0.0, "higher_patch": "none", "material_seam": str(local_state["surface_type"]) != str(neighbor_state["surface_type"])}
	return {
		"valid": true,
		"mode": "neighbor_higher" if delta > 0 else "local_higher",
		"ramp_enabled": false,
		"height_delta": absf(float(delta)) * 0.25,
		"higher_patch": "neighbor" if delta > 0 else "local",
		"material_seam": str(local_state["surface_type"]) != str(neighbor_state["surface_type"])
	}

static func _valid_state(state: Dictionary) -> bool:
	if state.size() != 3 or not state.has("height_level") or not state.has("surface_type") or not state.has("revision"):
		return false
	if not (state["height_level"] is int) or not (state["surface_type"] is String) or not (state["revision"] is int):
		return false
	if int(state["height_level"]) < 0 or int(state["height_level"]) > 2:
		return false
	if not ["soil", "rock", "metal"].has(str(state["surface_type"])):
		return false
	return int(state["revision"]) >= 0 and int(state["revision"]) <= 1000000

static func _invalid_result(reason: String) -> Dictionary:
	return {"valid": false, "mode": "invalid", "reason": reason, "ramp_enabled": false, "height_delta": 0.0, "higher_patch": "none", "material_seam": false}

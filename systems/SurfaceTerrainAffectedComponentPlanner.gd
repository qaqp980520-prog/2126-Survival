extends RefCounted
class_name SurfaceTerrainAffectedComponentPlanner

## Builds the deterministic edge/junction closure affected by a terrain delta.
## Both old and candidate resolver reports are included so removed and newly
## connected topology cannot be missed. Reports are included regardless of policy.
static func build_closure(
	seed_edge_keys: Array,
	old_reports: Array,
	old_patches_by_stable_id: Dictionary,
	candidate_reports: Array,
	candidate_patches_by_stable_id: Dictionary,
	patch_size: float
) -> Dictionary:
	if is_nan(patch_size) or is_inf(patch_size) or patch_size <= 0.0:
		return {"ok": false, "error": "invalid_patch_size"}

	var seeds: Array[String] = []
	for seed_value in seed_edge_keys:
		if not (seed_value is String):
			return {"ok": false, "error": "invalid_seed_edge_key"}
		var seed_key: String = seed_value
		if seed_key.strip_edges().is_empty():
			return {"ok": false, "error": "invalid_seed_edge_key"}
		if not seeds.has(seed_key):
			seeds.append(seed_key)
	seeds.sort()
	if seeds.is_empty():
		return {
			"ok": true,
			"edge_keys": [],
			"junction_keys": [],
			"edge_count": 0,
			"junction_count": 0,
			"old_report_count": old_reports.size(),
			"candidate_report_count": candidate_reports.size()
		}

	var edge_to_junctions: Dictionary = {}
	var junction_to_edges: Dictionary = {}
	var old_result: Dictionary = _append_reports(
		old_reports,
		old_patches_by_stable_id,
		patch_size,
		edge_to_junctions,
		junction_to_edges
	)
	if not bool(old_result.get("ok", false)):
		return old_result
	var candidate_result: Dictionary = _append_reports(
		candidate_reports,
		candidate_patches_by_stable_id,
		patch_size,
		edge_to_junctions,
		junction_to_edges
	)
	if not bool(candidate_result.get("ok", false)):
		return candidate_result

	var visited_edges: Dictionary = {}
	var visited_junctions: Dictionary = {}
	var queue: Array[String] = []
	for seed_key in seeds:
		queue.append(seed_key)
	var queue_index: int = 0
	while queue_index < queue.size():
		var edge_key: String = queue[queue_index]
		queue_index += 1
		if visited_edges.has(edge_key):
			continue
		visited_edges[edge_key] = true
		var linked_junctions: Array = edge_to_junctions.get(edge_key, [])
		linked_junctions.sort()
		for junction_value in linked_junctions:
			var junction_key: String = str(junction_value)
			if visited_junctions.has(junction_key):
				continue
			visited_junctions[junction_key] = true
			var linked_edges: Array = junction_to_edges.get(junction_key, [])
			linked_edges.sort()
			for linked_edge_value in linked_edges:
				var linked_edge: String = str(linked_edge_value)
				if not visited_edges.has(linked_edge):
					queue.append(linked_edge)

	var edge_keys: Array[String] = _sorted_keys(visited_edges)
	var junction_keys: Array[String] = _sorted_keys(visited_junctions)
	return {
		"ok": true,
		"edge_keys": edge_keys,
		"junction_keys": junction_keys,
		"edge_count": edge_keys.size(),
		"junction_count": junction_keys.size(),
		"old_report_count": old_reports.size(),
		"candidate_report_count": candidate_reports.size()
	}


## Matches the manager's PATCH_SIZE/half-corner coordinate convention and
## its three-decimal junction key format.
static func junction_key_for_corner(patch_position: Vector3, corner: String, patch_size: float) -> String:
	if is_nan(patch_size) or is_inf(patch_size) or patch_size <= 0.0 or not _is_finite_vector3(patch_position):
		return ""
	var half: float = patch_size * 0.5
	var offset: Vector3 = Vector3.ZERO
	match corner:
		"north_east":
			offset = Vector3(half, 0.0, -half)
		"south_east":
			offset = Vector3(half, 0.0, half)
		"south_west":
			offset = Vector3(-half, 0.0, half)
		"north_west":
			offset = Vector3(-half, 0.0, -half)
		_:
			return ""
	var position: Vector3 = patch_position + offset
	if not _is_finite_vector3(position):
		return ""
	return "%.3f|%.3f|%.3f" % [position.x, position.y, position.z]


static func _append_reports(
	reports: Array,
	patches_by_stable_id: Dictionary,
	patch_size: float,
	edge_to_junctions: Dictionary,
	junction_to_edges: Dictionary
) -> Dictionary:
	for report_value in reports:
		if not (report_value is Dictionary):
			return {"ok": false, "error": "invalid_corner_report"}
		var report: Dictionary = report_value
		var stable_id_value: Variant = report.get("stable_id", null)
		var corner_value: Variant = report.get("corner", null)
		var edge_keys_value: Variant = report.get("edge_keys", null)
		if not (stable_id_value is String) or str(stable_id_value).strip_edges().is_empty():
			return {"ok": false, "error": "invalid_report_stable_id"}
		if not (corner_value is String):
			return {"ok": false, "error": "invalid_report_corner"}
		if not (edge_keys_value is Array) or edge_keys_value.size() != 2:
			return {"ok": false, "error": "invalid_report_edge_keys"}
		var stable_id: String = stable_id_value
		var corner: String = corner_value
		var patch: Node3D = patches_by_stable_id.get(stable_id) as Node3D
		if not is_instance_valid(patch) or patch.is_queued_for_deletion():
			return {"ok": false, "error": "missing_report_patch"}
		var junction_key: String = junction_key_for_corner(patch.global_position, corner, patch_size)
		if junction_key.is_empty():
			return {"ok": false, "error": "invalid_corner_or_position"}
		var report_edge_set: Dictionary = {}
		for edge_key_value in edge_keys_value:
			if not (edge_key_value is String) or str(edge_key_value).strip_edges().is_empty():
				return {"ok": false, "error": "invalid_report_edge_key"}
			var edge_key: String = edge_key_value
			if report_edge_set.has(edge_key):
				return {"ok": false, "error": "duplicate_report_edge_key"}
			report_edge_set[edge_key] = true
			var junctions: Array = edge_to_junctions.get(edge_key, [])
			if not junctions.has(junction_key):
				junctions.append(junction_key)
			edge_to_junctions[edge_key] = junctions
			var edges: Array = junction_to_edges.get(junction_key, [])
			if not edges.has(edge_key):
				edges.append(edge_key)
			junction_to_edges[junction_key] = edges
	return {"ok": true}


static func _sorted_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in source.keys():
		result.append(str(key))
	result.sort()
	return result


static func _is_finite_vector3(value: Vector3) -> bool:
	return not (
		is_nan(value.x) or is_inf(value.x)
		or is_nan(value.y) or is_inf(value.y)
		or is_nan(value.z) or is_inf(value.z)
	)

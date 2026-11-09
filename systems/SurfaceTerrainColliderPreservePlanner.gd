extends RefCounted
class_name SurfaceTerrainColliderPreservePlanner

## Detached planner: never mutates Nodes, collision layers, patch flags or manager maps.
## Old maps are complete committed resource maps; candidate maps contain only resources
## inside the supplied Edge↔Junction affected closure.
static func build_plan(affected_edge_keys: Array, affected_junction_keys: Array, old_edges: Dictionary, candidate_edges: Dictionary, old_corner_caps: Dictionary, candidate_corner_caps: Dictionary) -> Dictionary:
	var edge_scope: Dictionary = _normalize_keys(affected_edge_keys, "invalid_affected_edge_key")
	if not bool(edge_scope.get("ok", false)):
		return edge_scope
	var junction_scope: Dictionary = _normalize_keys(affected_junction_keys, "invalid_affected_junction_key")
	if not bool(junction_scope.get("ok", false)):
		return junction_scope
	var affected_edges: Dictionary = edge_scope["set"]
	var affected_junctions: Dictionary = junction_scope["set"]
	var edge_list: Array[String] = edge_scope["keys"]
	var junction_list: Array[String] = junction_scope["keys"]

	var checks: Array[Dictionary] = [
		_validate_edge_resources(old_edges, true),
		_validate_edge_resources(candidate_edges, false),
		_validate_corner_cap_resources(old_corner_caps, true),
		_validate_corner_cap_resources(candidate_corner_caps, false)
	]
	for check in checks:
		if not bool(check.get("ok", false)):
			return check

	var preserve_edges: Array[String] = []
	var reactivate_edges: Array[String] = []
	var stage_edges: Array[String] = []
	var retire_edges: Array[String] = []

	for key_value in candidate_edges.keys():
		var key: String = str(key_value)
		if not affected_edges.has(key):
			return {"ok": false, "error": "candidate_edge_outside_affected_closure", "key": key}

	for key_value in old_edges.keys():
		var key: String = str(key_value)
		if affected_edges.has(key):
			continue
		var old_record: Dictionary = old_edges[key]
		if not bool(old_record["body_reusable"]):
			return {"ok": false, "error": "stale_edge_outside_affected_closure", "key": key}
		preserve_edges.append(key)
		if not bool(old_record["patch_states_active"]):
			reactivate_edges.append(key)

	for key in edge_list:
		var has_old: bool = old_edges.has(key)
		var has_candidate: bool = candidate_edges.has(key)
		if not has_candidate:
			if has_old:
				retire_edges.append(key)
			continue
		var candidate_record: Dictionary = candidate_edges[key]
		if not has_old:
			stage_edges.append(key)
			continue
		var old_record: Dictionary = old_edges[key]
		if bool(old_record["body_reusable"]) and _signatures_match(old_record["reuse_signature"], candidate_record["reuse_signature"]):
			preserve_edges.append(key)
			if not bool(old_record["patch_states_active"]):
				reactivate_edges.append(key)
		else:
			stage_edges.append(key)
			retire_edges.append(key)

	var preserve_caps: Array[String] = []
	var stage_caps: Array[String] = []
	var retire_caps: Array[String] = []
	var scoped_cap_keys: Dictionary = {}

	for key_value in candidate_corner_caps.keys():
		var key: String = str(key_value)
		var candidate_record: Dictionary = candidate_corner_caps[key]
		var candidate_junction: String = str(candidate_record["junction_key"])
		if not affected_junctions.has(candidate_junction):
			return {"ok": false, "error": "candidate_corner_cap_outside_affected_closure", "key": key}
		scoped_cap_keys[key] = true

	for key_value in old_corner_caps.keys():
		var key: String = str(key_value)
		var old_record: Dictionary = old_corner_caps[key]
		var old_junction: String = str(old_record["junction_key"])
		if affected_junctions.has(old_junction):
			scoped_cap_keys[key] = true
			continue
		if candidate_corner_caps.has(key):
			return {"ok": false, "error": "old_corner_cap_junction_outside_affected_closure", "key": key}
		if not bool(old_record["body_reusable"]):
			return {"ok": false, "error": "stale_corner_cap_outside_affected_closure", "key": key}
		preserve_caps.append(key)

	var scoped_cap_list: Array[String] = _sorted_keys(scoped_cap_keys)
	for key in scoped_cap_list:
		var has_old: bool = old_corner_caps.has(key)
		var has_candidate: bool = candidate_corner_caps.has(key)
		if not has_candidate:
			if has_old:
				retire_caps.append(key)
			continue
		var candidate_record: Dictionary = candidate_corner_caps[key]
		if not has_old:
			stage_caps.append(key)
			continue
		var old_record: Dictionary = old_corner_caps[key]
		if str(old_record["junction_key"]) == str(candidate_record["junction_key"]) and bool(old_record["body_reusable"]) and _signatures_match(old_record["reuse_signature"], candidate_record["reuse_signature"]):
			preserve_caps.append(key)
		else:
			stage_caps.append(key)
			retire_caps.append(key)

	preserve_edges.sort()
	reactivate_edges.sort()
	stage_edges.sort()
	retire_edges.sort()
	preserve_caps.sort()
	stage_caps.sort()
	retire_caps.sort()
	return {
		"ok": true,
		"affected_edge_keys": edge_list,
		"affected_junction_keys": junction_list,
		"preserve_edge_keys": preserve_edges,
		"reactivate_edge_keys": reactivate_edges,
		"stage_edge_keys": stage_edges,
		"retire_edge_keys": retire_edges,
		"preserve_corner_cap_keys": preserve_caps,
		"stage_corner_cap_keys": stage_caps,
		"retire_corner_cap_keys": retire_caps,
		"preserve_edge_count": preserve_edges.size(),
		"reactivate_edge_count": reactivate_edges.size(),
		"stage_edge_count": stage_edges.size(),
		"retire_edge_count": retire_edges.size(),
		"preserve_corner_cap_count": preserve_caps.size(),
		"stage_corner_cap_count": stage_caps.size(),
		"retire_corner_cap_count": retire_caps.size()
	}


static func _normalize_keys(values: Array, error_code: String) -> Dictionary:
	var keys: Array[String] = []
	var key_set: Dictionary = {}
	for value in values:
		if not (value is String):
			return {"ok": false, "error": error_code}
		var key: String = value
		if key.strip_edges().is_empty():
			return {"ok": false, "error": error_code}
		if not key_set.has(key):
			key_set[key] = true
			keys.append(key)
	keys.sort()
	return {"ok": true, "keys": keys, "set": key_set}


static func _validate_edge_resources(resources: Dictionary, require_old_state: bool) -> Dictionary:
	for key_value in resources.keys():
		if not (key_value is String) or str(key_value).strip_edges().is_empty():
			return {"ok": false, "error": "invalid_edge_resource_key"}
		var record_value: Variant = resources[key_value]
		if not (record_value is Dictionary):
			return {"ok": false, "error": "invalid_edge_resource_record"}
		var record: Dictionary = record_value
		var signature_value: Variant = record.get("reuse_signature", null)
		if not (signature_value is Array):
			return {"ok": false, "error": "invalid_edge_reuse_signature"}
		var signature: Array = signature_value
		if signature.is_empty():
			return {"ok": false, "error": "empty_edge_reuse_signature"}
		if require_old_state:
			if typeof(record.get("body_reusable", null)) != TYPE_BOOL:
				return {"ok": false, "error": "invalid_old_edge_body_state"}
			if typeof(record.get("patch_states_active", null)) != TYPE_BOOL:
				return {"ok": false, "error": "invalid_old_edge_patch_state"}
	return {"ok": true}


static func _validate_corner_cap_resources(resources: Dictionary, require_old_state: bool) -> Dictionary:
	for key_value in resources.keys():
		if not (key_value is String) or str(key_value).strip_edges().is_empty():
			return {"ok": false, "error": "invalid_corner_cap_resource_key"}
		var record_value: Variant = resources[key_value]
		if not (record_value is Dictionary):
			return {"ok": false, "error": "invalid_corner_cap_resource_record"}
		var record: Dictionary = record_value
		var junction_value: Variant = record.get("junction_key", null)
		if not (junction_value is String) or str(junction_value).strip_edges().is_empty():
			return {"ok": false, "error": "invalid_corner_cap_junction_key"}
		var signature_value: Variant = record.get("reuse_signature", null)
		if not (signature_value is Array):
			return {"ok": false, "error": "invalid_corner_cap_reuse_signature"}
		var signature: Array = signature_value
		if signature.is_empty():
			return {"ok": false, "error": "empty_corner_cap_reuse_signature"}
		if require_old_state and typeof(record.get("body_reusable", null)) != TYPE_BOOL:
			return {"ok": false, "error": "invalid_old_corner_cap_body_state"}
	return {"ok": true}


static func _signatures_match(previous: Array, candidate: Array) -> bool:
	if previous.size() != candidate.size():
		return false
	for index in range(candidate.size()):
		if previous[index] != candidate[index]:
			return false
	return true


static func _sorted_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_value in source.keys():
		result.append(str(key_value))
	result.sort()
	return result

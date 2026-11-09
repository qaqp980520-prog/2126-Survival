extends RefCounted
class_name SurfaceTerrainAdjacencyIndex

## Persistent spatial index and detached load/unload delta planner.
## This primitive does not mutate live patch edges or collider-manager ownership.
const SIDES: Array[String] = ["east", "west", "north", "south"]
const POSITION_TOLERANCE: float = 0.01
const TransitionDescriptorScript = preload("res://systems/SurfaceTerrainTransitionDescriptor.gd")

var _entries_by_stable_id: Dictionary = {}
var _bucket_to_stable_ids: Dictionary = {}
var _patch_size: float = -1.0
var _generation: int = 0
var _plan_serial: int = 0
var _pending_plans: Dictionary = {}


## Atomically replaces the index from a complete live patch set.
## stable_ids_by_instance maps Node instance IDs to persistent world-object Stable IDs.
func rebuild(patches: Array[Node3D], stable_ids_by_instance: Dictionary) -> Dictionary:
	var candidate_entries: Dictionary = {}
	var candidate_buckets: Dictionary = {}
	var copied_buckets: Dictionary = {}
	var seen_instances: Dictionary = {}
	var candidate_patch_size: float = -1.0

	for patch in patches:
		if not is_instance_valid(patch):
			return {"ok": false, "error": "invalid_patch"}
		var instance_id: int = patch.get_instance_id()
		if seen_instances.has(instance_id):
			return {"ok": false, "error": "duplicate_instance"}
		seen_instances[instance_id] = true
		var stable_id: String = str(stable_ids_by_instance.get(instance_id, ""))
		var record_result: Dictionary = _make_record(patch, stable_id)
		if not bool(record_result.get("ok", false)):
			return record_result
		if candidate_entries.has(stable_id):
			return {"ok": false, "error": "duplicate_stable_id"}
		var record: Dictionary = record_result["record"]
		var size: float = float(record["snapshot"]["patch_size"])
		if candidate_patch_size < 0.0:
			candidate_patch_size = size
		elif absf(size - candidate_patch_size) > POSITION_TOLERANCE:
			return {"ok": false, "error": "mixed_patch_sizes"}
		if _has_duplicate_position(record, candidate_buckets, candidate_entries):
			return {"ok": false, "error": "duplicate_position"}
		candidate_entries[stable_id] = record
		_add_bucket_id(candidate_buckets, record["bucket"], stable_id, copied_buckets)

	var descriptor_result: Dictionary = _build_descriptors_for_all(
		candidate_entries,
		candidate_buckets,
		candidate_patch_size
	)
	if not bool(descriptor_result.get("ok", false)):
		return descriptor_result

	_entries_by_stable_id = candidate_entries
	_bucket_to_stable_ids = candidate_buckets
	_patch_size = candidate_patch_size
	_generation += 1
	_pending_plans.clear()
	var descriptors: Dictionary = descriptor_result.get("descriptors", {})
	return {
		"ok": true,
		"generation": _generation,
		"patch_count": _entries_by_stable_id.size(),
		"bucket_count": _bucket_to_stable_ids.size(),
		"edge_count": descriptors.size()
	}


## Prepares a load/unload delta without changing the committed index or live patches.
## A Stable ID may appear in both arrays to represent unload/reload with a new Node instance.
## Returned summaries are detached copies; the internal candidate snapshot is addressed by plan_id.
func plan_delta(remove_stable_ids: Array, additions: Array) -> Dictionary:
	var candidate_entries: Dictionary = _entries_by_stable_id.duplicate()
	# Dictionary.duplicate() copies the bucket map; arrays are copied only when a bucket is touched.
	var candidate_buckets: Dictionary = _bucket_to_stable_ids.duplicate()
	var copied_buckets: Dictionary = {}
	var removed_ids: Array[String] = []
	var added_ids: Array[String] = []
	var changed_ids: Dictionary = {}
	var removed_seen: Dictionary = {}

	for stable_id_value in remove_stable_ids:
		var stable_id: String = str(stable_id_value)
		if stable_id.strip_edges().is_empty():
			return {"ok": false, "error": "invalid_remove_stable_id"}
		if removed_seen.has(stable_id):
			return {"ok": false, "error": "duplicate_remove_stable_id"}
		if not candidate_entries.has(stable_id):
			return {"ok": false, "error": "unknown_remove_stable_id"}
		removed_seen[stable_id] = true
		var old_record: Dictionary = candidate_entries[stable_id]
		_remove_bucket_id(candidate_buckets, old_record["bucket"], stable_id, copied_buckets)
		candidate_entries.erase(stable_id)
		removed_ids.append(stable_id)
		changed_ids[stable_id] = true

	var candidate_patch_size: float = _first_patch_size(candidate_entries)
	var added_seen: Dictionary = {}
	var added_instances: Dictionary = {}

	for addition_value in additions:
		if not (addition_value is Dictionary):
			return {"ok": false, "error": "invalid_addition"}
		var addition: Dictionary = addition_value
		var stable_id: String = str(addition.get("stable_id", ""))
		var patch: Node3D = addition.get("patch") as Node3D
		if stable_id.strip_edges().is_empty():
			return {"ok": false, "error": "invalid_stable_id"}
		if added_seen.has(stable_id) or candidate_entries.has(stable_id):
			return {"ok": false, "error": "duplicate_stable_id"}
		added_seen[stable_id] = true
		if not is_instance_valid(patch):
			return {"ok": false, "error": "invalid_patch"}
		var instance_id: int = patch.get_instance_id()
		if added_instances.has(instance_id) or _contains_instance(candidate_entries, instance_id):
			return {"ok": false, "error": "duplicate_instance"}
		added_instances[instance_id] = true

		var record_result: Dictionary = _make_record(patch, stable_id)
		if not bool(record_result.get("ok", false)):
			return record_result
		var record: Dictionary = record_result["record"]
		var size: float = float(record["snapshot"]["patch_size"])
		if candidate_patch_size < 0.0:
			candidate_patch_size = size
		elif absf(size - candidate_patch_size) > POSITION_TOLERANCE:
			return {"ok": false, "error": "mixed_patch_sizes"}
		if _has_duplicate_position(record, candidate_buckets, candidate_entries):
			return {"ok": false, "error": "duplicate_position"}
		candidate_entries[stable_id] = record
		_add_bucket_id(candidate_buckets, record["bucket"], stable_id, copied_buckets)
		added_ids.append(stable_id)
		changed_ids[stable_id] = true

	if removed_ids.is_empty() and added_ids.is_empty():
		return {"ok": true, "noop": true, "generation": _generation}

	var touched_ids: Dictionary = changed_ids.duplicate()
	for stable_id in removed_ids:
		var old_record: Dictionary = _entries_by_stable_id[stable_id]
		for neighbor_id in _collect_cardinal_neighbors(
			old_record["position"],
			_patch_size,
			_bucket_to_stable_ids,
			_entries_by_stable_id,
			stable_id
		):
			touched_ids[neighbor_id] = true
	for stable_id in added_ids:
		var new_record: Dictionary = candidate_entries[stable_id]
		for neighbor_id in _collect_cardinal_neighbors(
			new_record["position"],
			candidate_patch_size,
			candidate_buckets,
			candidate_entries,
			stable_id
		):
			touched_ids[neighbor_id] = true

	var old_descriptor_result: Dictionary = _build_descriptors_for_ids(
		_entries_by_stable_id,
		_bucket_to_stable_ids,
		changed_ids,
		_patch_size
	)
	if not bool(old_descriptor_result.get("ok", false)):
		return old_descriptor_result
	var new_descriptor_result: Dictionary = _build_descriptors_for_ids(
		candidate_entries,
		candidate_buckets,
		changed_ids,
		candidate_patch_size
	)
	if not bool(new_descriptor_result.get("ok", false)):
		return new_descriptor_result

	var old_descriptors: Dictionary = old_descriptor_result.get("descriptors", {})
	var new_descriptors: Dictionary = new_descriptor_result.get("descriptors", {})
	var affected_edge_keys: Dictionary = {}
	var added_edge_keys: Array[String] = []
	var removed_edge_keys: Array[String] = []
	var changed_edge_keys: Array[String] = []
	for edge_key_value in old_descriptors.keys():
		var edge_key: String = str(edge_key_value)
		affected_edge_keys[edge_key] = true
		if not new_descriptors.has(edge_key):
			removed_edge_keys.append(edge_key)
		elif old_descriptors[edge_key] != new_descriptors[edge_key]:
			changed_edge_keys.append(edge_key)
	for edge_key_value in new_descriptors.keys():
		var edge_key: String = str(edge_key_value)
		affected_edge_keys[edge_key] = true
		if not old_descriptors.has(edge_key):
			added_edge_keys.append(edge_key)

	var plan_id: String = "%d:%d" % [_generation, _plan_serial]
	_plan_serial += 1
	var summary: Dictionary = {
		"plan_id": plan_id,
		"base_generation": _generation,
		"next_generation": _generation + 1,
		"removed_stable_ids": _sorted_strings(removed_ids),
		"added_stable_ids": _sorted_strings(added_ids),
		"touched_stable_ids": _sorted_strings(touched_ids.keys()),
		"affected_edge_keys": _sorted_strings(affected_edge_keys.keys()),
		"added_edge_keys": _sorted_strings(added_edge_keys),
		"removed_edge_keys": _sorted_strings(removed_edge_keys),
		"changed_edge_keys": _sorted_strings(changed_edge_keys),
		"old_descriptors": old_descriptors.duplicate(true),
		"new_descriptors": new_descriptors.duplicate(true),
		"patch_count_after": candidate_entries.size()
	}
	_pending_plans[plan_id] = {
		"base_generation": _generation,
		"candidate_entries": candidate_entries,
		"candidate_buckets": candidate_buckets,
		"candidate_patch_size": candidate_patch_size,
		"summary": summary.duplicate(true)
	}
	return {"ok": true, "noop": false, "summary": summary.duplicate(true)}


## Commits only the index snapshot. Production edge/cap mutation is intentionally not wired here.
## A stale generation or changed Node snapshot is rejected without changing committed state.
func commit_delta(plan_id: String) -> Dictionary:
	if not _pending_plans.has(plan_id):
		return {"ok": false, "error": "unknown_plan"}
	var plan: Dictionary = _pending_plans[plan_id]
	if int(plan.get("base_generation", -1)) != _generation:
		_pending_plans.erase(plan_id)
		return {"ok": false, "error": "stale_generation"}

	var candidate_entries: Dictionary = plan["candidate_entries"]
	# Validate only the changed patches and their immediate neighbors. Unchanged buckets
	# and records remain persistent; a full scan here would erase the benefit of the index.
	var touched_ids: Array = plan["summary"].get("touched_stable_ids", [])
	for stable_id_value in touched_ids:
		var stable_id: String = str(stable_id_value)
		if not candidate_entries.has(stable_id):
			continue
		var record: Dictionary = candidate_entries[stable_id]
		var current_result: Dictionary = _record_matches_current(stable_id, record)
		if not bool(current_result.get("ok", false)):
			_pending_plans.erase(plan_id)
			return current_result

	_entries_by_stable_id = candidate_entries.duplicate()
	_bucket_to_stable_ids = plan["candidate_buckets"]
	_patch_size = float(plan["candidate_patch_size"])
	_generation += 1
	_pending_plans.erase(plan_id)
	return {
		"ok": true,
		"generation": _generation,
		"patch_count": _entries_by_stable_id.size(),
		"summary": plan["summary"].duplicate(true)
	}


func abort_delta(plan_id: String) -> bool:
	return _pending_plans.erase(plan_id)


func get_patch(stable_id: String) -> Node3D:
	if not _entries_by_stable_id.has(stable_id):
		return null
	var record: Dictionary = _entries_by_stable_id[stable_id]
	var patch_ref: Variant = record.get("patch_ref")
	if not (patch_ref is WeakRef):
		return null
	return patch_ref.get_ref() as Node3D


func get_snapshot(stable_id: String) -> Dictionary:
	if not _entries_by_stable_id.has(stable_id):
		return {}
	return _entries_by_stable_id[stable_id]["snapshot"].duplicate(true)


func get_neighbors(stable_id: String) -> Array[String]:
	if not _entries_by_stable_id.has(stable_id) or _patch_size <= 0.0:
		return []
	var record: Dictionary = _entries_by_stable_id[stable_id]
	return _collect_cardinal_neighbors(
		record["position"],
		_patch_size,
		_bucket_to_stable_ids,
		_entries_by_stable_id,
		stable_id
	)


func get_edge_descriptors() -> Dictionary:
	var selected_ids: Dictionary = {}
	for stable_id in _entries_by_stable_id.keys():
		selected_ids[str(stable_id)] = true
	var result: Dictionary = _build_descriptors_for_ids(
		_entries_by_stable_id,
		_bucket_to_stable_ids,
		selected_ids,
		_patch_size
	)
	if not bool(result.get("ok", false)):
		return {}
	return result.get("descriptors", {}).duplicate(true)


func get_patch_count() -> int:
	return _entries_by_stable_id.size()


func get_generation() -> int:
	return _generation


func get_patch_size() -> float:
	return _patch_size


func _make_record(patch: Node3D, stable_id: String) -> Dictionary:
	if not is_instance_valid(patch) or not patch.is_inside_tree() or patch.is_queued_for_deletion():
		return {"ok": false, "error": "invalid_patch"}
	if stable_id.strip_edges().is_empty():
		return {"ok": false, "error": "invalid_stable_id"}
	if not patch.has_method("get_edge_ramp_profile") or not patch.has_method("get_world_object_state") or not patch.has_method("validate_world_object_state"):
		return {"ok": false, "error": "unsupported_patch"}
	var profile_value: Variant = patch.call("get_edge_ramp_profile")
	if not (profile_value is Dictionary):
		return {"ok": false, "error": "invalid_patch_profile"}
	var profile: Dictionary = profile_value
	var size_value: Variant = profile.get("patch_size", 0.0)
	if not (size_value is int or size_value is float):
		return {"ok": false, "error": "invalid_patch_size"}
	var patch_size: float = float(size_value)
	if is_nan(patch_size) or is_inf(patch_size) or patch_size <= 0.0:
		return {"ok": false, "error": "invalid_patch_size"}

	var position: Vector3 = patch.global_position
	if not _is_finite_vector3(position):
		return {"ok": false, "error": "invalid_patch_position"}
	var state_value: Variant = patch.call("get_world_object_state")
	if not (state_value is Dictionary):
		return {"ok": false, "error": "invalid_patch_state"}
	var state: Dictionary = state_value
	if not bool(patch.call("validate_world_object_state", state)):
		return {"ok": false, "error": "invalid_patch_state"}
	if not state.has("height_level") or not state.has("revision"):
		return {"ok": false, "error": "invalid_patch_state"}

	var snapshot: Dictionary = {
		"stable_id": stable_id,
		"position": position,
		"patch_size": patch_size,
		"height_level": state["height_level"],
		"revision": state["revision"],
		"state": state.duplicate(true)
	}
	return {
		"ok": true,
		"record": {
			"patch_ref": weakref(patch),
			"instance_id": patch.get_instance_id(),
			"position": position,
			"bucket": _position_bucket(position),
			"snapshot": snapshot
		}
	}


func _record_matches_current(stable_id: String, stored_record: Dictionary) -> Dictionary:
	var patch_ref: Variant = stored_record.get("patch_ref")
	if not (patch_ref is WeakRef):
		return {"ok": false, "error": "stale_patch_reference"}
	var patch: Node3D = patch_ref.get_ref() as Node3D
	if not is_instance_valid(patch):
		return {"ok": false, "error": "stale_patch_reference"}
	var current_result: Dictionary = _make_record(patch, stable_id)
	if not bool(current_result.get("ok", false)):
		return {"ok": false, "error": "stale_patch_snapshot"}
	var current_record: Dictionary = current_result["record"]
	if int(current_record["instance_id"]) != int(stored_record["instance_id"]):
		return {"ok": false, "error": "stale_patch_reference"}
	if current_record["position"] != stored_record["position"] or current_record["snapshot"] != stored_record["snapshot"]:
		return {"ok": false, "error": "stale_patch_snapshot"}
	return {"ok": true}


func _has_duplicate_position(record: Dictionary, buckets: Dictionary, entries: Dictionary) -> bool:
	var position: Vector3 = record["position"]
	var bucket: Vector3i = record["bucket"]
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			for z_offset in range(-1, 2):
				var neighbor_bucket: Vector3i = bucket + Vector3i(x_offset, y_offset, z_offset)
				var candidate_ids: Array = buckets.get(neighbor_bucket, [])
				for candidate_id_value in candidate_ids:
					var candidate_id: String = str(candidate_id_value)
					if not entries.has(candidate_id):
						continue
					var candidate_position: Vector3 = entries[candidate_id]["position"]
					if candidate_position.distance_to(position) <= POSITION_TOLERANCE:
						return true
	return false


func _contains_instance(entries: Dictionary, instance_id: int) -> bool:
	for record_value in entries.values():
		var record: Dictionary = record_value
		if int(record.get("instance_id", -1)) == instance_id:
			return true
	return false


func _first_patch_size(entries: Dictionary) -> float:
	if entries.is_empty():
		return -1.0
	var first_record: Dictionary = entries.values()[0]
	return float(first_record["snapshot"]["patch_size"])


func _ensure_bucket_array_for_write(buckets: Dictionary, bucket: Vector3i, copied_buckets: Dictionary) -> Array:
	if not copied_buckets.has(bucket) or not buckets.has(bucket):
		var existing_ids: Array = buckets.get(bucket, [])
		buckets[bucket] = existing_ids.duplicate()
		copied_buckets[bucket] = true
	return buckets[bucket]


func _add_bucket_id(buckets: Dictionary, bucket: Vector3i, stable_id: String, copied_buckets: Dictionary) -> void:
	var ids: Array = _ensure_bucket_array_for_write(buckets, bucket, copied_buckets)
	ids.append(stable_id)
	buckets[bucket] = ids


func _remove_bucket_id(buckets: Dictionary, bucket: Vector3i, stable_id: String, copied_buckets: Dictionary) -> void:
	if not buckets.has(bucket):
		return
	var ids: Array = _ensure_bucket_array_for_write(buckets, bucket, copied_buckets)
	ids.erase(stable_id)
	if ids.is_empty():
		buckets.erase(bucket)
	else:
		buckets[bucket] = ids


func _collect_cardinal_neighbors(
	position: Vector3,
	patch_size: float,
	buckets: Dictionary,
	entries: Dictionary,
	excluded_stable_id: String = ""
) -> Array[String]:
	var neighbor_map: Dictionary = {}
	if patch_size <= 0.0:
		return []
	for side in SIDES:
		var target_bucket: Vector3i = _position_bucket(position + _side_offset(side, patch_size))
		for x_offset in range(-1, 2):
			for y_offset in range(-1, 2):
				for z_offset in range(-1, 2):
					var bucket: Vector3i = target_bucket + Vector3i(x_offset, y_offset, z_offset)
					var candidate_ids: Array = buckets.get(bucket, [])
					for candidate_id_value in candidate_ids:
						var candidate_id: String = str(candidate_id_value)
						if candidate_id == excluded_stable_id or not entries.has(candidate_id):
							continue
						var candidate_position: Vector3 = entries[candidate_id]["position"]
						if _side_between(position, candidate_position, patch_size) == side:
							neighbor_map[candidate_id] = true
	var neighbors: Array[String] = []
	for neighbor_id_value in neighbor_map.keys():
		neighbors.append(str(neighbor_id_value))
	neighbors.sort()
	return neighbors


func _build_descriptors_for_all(entries: Dictionary, buckets: Dictionary, patch_size: float) -> Dictionary:
	var selected_ids: Dictionary = {}
	for stable_id_value in entries.keys():
		selected_ids[str(stable_id_value)] = true
	return _build_descriptors_for_ids(entries, buckets, selected_ids, patch_size)


func _build_descriptors_for_ids(
	entries: Dictionary,
	buckets: Dictionary,
	selected_ids: Dictionary,
	patch_size: float
) -> Dictionary:
	var descriptors: Dictionary = {}
	if patch_size <= 0.0:
		return {"ok": true, "descriptors": descriptors}
	var stable_ids: Array[String] = []
	for stable_id_value in selected_ids.keys():
		stable_ids.append(str(stable_id_value))
	stable_ids.sort()
	for stable_id in stable_ids:
		if not entries.has(stable_id):
			continue
		var record: Dictionary = entries[stable_id]
		var neighbors: Array[String] = _collect_cardinal_neighbors(
			record["position"],
			patch_size,
			buckets,
			entries,
			stable_id
		)
		for neighbor_id in neighbors:
			var built: Dictionary = TransitionDescriptorScript.build(
				record["snapshot"],
				entries[neighbor_id]["snapshot"]
			)
			if not bool(built.get("ok", false)):
				return {"ok": false, "error": "descriptor_invalid:" + str(built.get("error", "unknown"))}
			var descriptor: Dictionary = built.get("descriptor", {})
			var edge_key: String = str(descriptor.get("edge_key", ""))
			if not descriptors.has(edge_key):
				descriptors[edge_key] = descriptor.duplicate(true)
	return {"ok": true, "descriptors": descriptors}


func _sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	result.sort()
	return result


func _position_bucket(position: Vector3) -> Vector3i:
	return Vector3i(
		floori(position.x / POSITION_TOLERANCE),
		floori(position.y / POSITION_TOLERANCE),
		floori(position.z / POSITION_TOLERANCE)
	)


func _side_offset(side: String, patch_size: float) -> Vector3:
	match side:
		"east": return Vector3(patch_size, 0.0, 0.0)
		"west": return Vector3(-patch_size, 0.0, 0.0)
		"north": return Vector3(0.0, 0.0, -patch_size)
		"south": return Vector3(0.0, 0.0, patch_size)
		_: return Vector3.ZERO


func _side_between(first: Vector3, second: Vector3, patch_size: float) -> String:
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


func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)

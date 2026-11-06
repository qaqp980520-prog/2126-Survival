extends RefCounted

## Rebuilds derived terrain adjacency and stable transition descriptors after chunk load/unload.
## Spatial buckets keep duplicate validation and cardinal-neighbor discovery bounded per patch.
const SIDES: Array[String] = ["east", "west", "north", "south"]
const POSITION_TOLERANCE: float = 0.01
const TransitionDescriptorScript = preload("res://systems/SurfaceTerrainTransitionDescriptor.gd")

## stable_ids_by_instance maps live Node instance IDs to persistent world-object Stable IDs.
## When omitted, node paths are accepted for isolated fixtures only; production callers pass registry IDs.
static func bind_patches(patches: Array[Node3D], stable_ids_by_instance: Dictionary = {}) -> Dictionary:
	var seen_instances: Dictionary = {}
	var seen_stable_ids: Dictionary = {}
	var positions: Array[Vector3] = []
	var positions_by_bucket: Dictionary = {}
	var snapshots_by_stable_id: Dictionary = {}
	var stable_id_by_instance: Dictionary = {}
	var patch_size: float = -1.0
	var duplicate_position_candidate_checks: int = 0
	var position_bucket_lookups: int = 0
	var adjacency_candidate_checks: int = 0
	var adjacency_bucket_lookups: int = 0

	# Complete validation and descriptor construction before changing any live edge state.
	for patch_index in range(patches.size()):
		var patch: Node3D = patches[patch_index]
		if not is_instance_valid(patch) or not patch.is_inside_tree() or patch.is_queued_for_deletion():
			return {"ok": false, "error": "invalid_patch"}
		if not patch.has_method("bind_neighbor_patch") or not patch.has_method("clear_neighbor_edge_state") or not patch.has_method("get_edge_ramp_profile") or not patch.has_method("get_world_object_state") or not patch.has_method("validate_world_object_state"):
			return {"ok": false, "error": "unsupported_patch"}
		var instance_id: int = patch.get_instance_id()
		if seen_instances.has(instance_id):
			return {"ok": false, "error": "duplicate_instance"}
		seen_instances[instance_id] = true

		var stable_id: String = str(stable_ids_by_instance.get(instance_id, str(patch.get_path())))
		if stable_id.strip_edges().is_empty():
			return {"ok": false, "error": "invalid_stable_id"}
		if seen_stable_ids.has(stable_id):
			return {"ok": false, "error": "duplicate_stable_id"}
		seen_stable_ids[stable_id] = true
		stable_id_by_instance[instance_id] = stable_id

		var profile: Variant = patch.call("get_edge_ramp_profile")
		if not (profile is Dictionary):
			return {"ok": false, "error": "invalid_patch_profile"}
		var candidate_size: float = float(profile.get("patch_size", 0.0))
		if is_nan(candidate_size) or is_inf(candidate_size) or candidate_size <= 0.0:
			return {"ok": false, "error": "invalid_patch_size"}
		if patch_size < 0.0:
			patch_size = candidate_size
		elif absf(candidate_size - patch_size) > POSITION_TOLERANCE:
			return {"ok": false, "error": "mixed_patch_sizes"}

		# A tolerance-sized spatial hash checks only the 27 neighboring buckets.
		# This preserves the previous Euclidean duplicate-position contract at negative
		# coordinates and across bucket boundaries without scanning every prior patch.
		var position: Vector3 = patch.global_position
		var position_bucket: Vector3i = _position_bucket(position)
		for x_offset in range(-1, 2):
			for y_offset in range(-1, 2):
				for z_offset in range(-1, 2):
					position_bucket_lookups += 1
					var neighbor_bucket: Vector3i = position_bucket + Vector3i(x_offset, y_offset, z_offset)
					var prior_indices: Array = positions_by_bucket.get(neighbor_bucket, [])
					for prior_index_value in prior_indices:
						duplicate_position_candidate_checks += 1
						var prior_index: int = int(prior_index_value)
						if positions[prior_index].distance_to(position) <= POSITION_TOLERANCE:
							return {"ok": false, "error": "duplicate_position"}
		positions.append(position)
		var bucket_indices: Array = positions_by_bucket.get(position_bucket, [])
		bucket_indices.append(patch_index)
		positions_by_bucket[position_bucket] = bucket_indices

		var state: Variant = patch.call("get_world_object_state")
		if not (state is Dictionary) or not bool(patch.call("validate_world_object_state", state)):
			return {"ok": false, "error": "invalid_patch_state"}
		if not state.has("height_level") or not state.has("revision"):
			return {"ok": false, "error": "invalid_patch_state"}
		var snapshot: Dictionary = {
			"stable_id": stable_id,
			"position": position,
			"patch_size": candidate_size,
			"height_level": state.get("height_level"),
			"revision": state.get("revision")
		}
		snapshots_by_stable_id[stable_id] = snapshot

	# Discover only the four cardinal neighbor positions for each patch. Candidate
	# indices are sorted to retain deterministic pair order from the former all-pairs scan.
	var pair_descriptors: Array[Dictionary] = []
	for first_index in range(patches.size()):
		var first: Node3D = patches[first_index]
		var neighbor_indices: Array[int] = []
		for side in SIDES:
			var target_position: Vector3 = first.global_position + _side_offset(side, patch_size)
			var target_bucket: Vector3i = _position_bucket(target_position)
			for x_offset in range(-1, 2):
				for y_offset in range(-1, 2):
					for z_offset in range(-1, 2):
						adjacency_bucket_lookups += 1
						var neighbor_bucket: Vector3i = target_bucket + Vector3i(x_offset, y_offset, z_offset)
						var candidate_indices: Array = positions_by_bucket.get(neighbor_bucket, [])
						for candidate_index_value in candidate_indices:
							var second_index: int = int(candidate_index_value)
							if second_index <= first_index:
								continue
							adjacency_candidate_checks += 1
							var second_candidate: Node3D = patches[second_index]
							if _side_between(first.global_position, second_candidate.global_position, patch_size) == side:
								neighbor_indices.append(second_index)
		neighbor_indices.sort()
		for second_index in neighbor_indices:
			var second: Node3D = patches[second_index]
			var first_id: String = str(stable_id_by_instance[first.get_instance_id()])
			var second_id: String = str(stable_id_by_instance[second.get_instance_id()])
			var built: Dictionary = TransitionDescriptorScript.build(snapshots_by_stable_id[first_id], snapshots_by_stable_id[second_id])
			if not bool(built.get("ok", false)):
				return {"ok": false, "error": "descriptor_invalid:" + str(built.get("error", "unknown"))}
			var descriptor: Dictionary = built.get("descriptor", {})
			var first_side: String = str(descriptor.get("first_side", "")) if first_id == str(descriptor.get("first_stable_id", "")) else str(descriptor.get("second_side", ""))
			var second_side: String = str(descriptor.get("second_side", "")) if first_id == str(descriptor.get("first_stable_id", "")) else str(descriptor.get("first_side", ""))
			if not SIDES.has(first_side) or not SIDES.has(second_side):
				return {"ok": false, "error": "descriptor_side_invalid"}
			pair_descriptors.append({
				"first": first,
				"second": second,
				"first_side": first_side,
				"second_side": second_side,
				"descriptor": descriptor
			})

	for patch in patches:
		for side in SIDES:
			if not bool(patch.call("clear_neighbor_edge_state", side)):
				_clear_all(patches)
				return {"ok": false, "error": "clear_neighbor_failed"}

	var descriptors: Dictionary = {}
	for pair in pair_descriptors:
		var first: Node3D = pair["first"]
		var second: Node3D = pair["second"]
		var descriptor: Dictionary = pair["descriptor"]
		var first_side: String = str(pair["first_side"])
		var second_side: String = str(pair["second_side"])
		if not bool(first.call("bind_neighbor_patch", first_side, second)) or not bool(second.call("bind_neighbor_patch", second_side, first)):
			_clear_all(patches)
			return {"ok": false, "error": "neighbor_bind_failed"}
		descriptors[str(descriptor["edge_key"])] = descriptor.duplicate(true)

	return {
		"ok": true,
		"patch_count": patches.size(),
		"pair_count": pair_descriptors.size(),
		"descriptor_count": descriptors.size(),
		"duplicate_position_candidate_checks": duplicate_position_candidate_checks,
		"position_bucket_lookups": position_bucket_lookups,
		"adjacency_candidate_checks": adjacency_candidate_checks,
		"adjacency_bucket_lookups": adjacency_bucket_lookups,
		"descriptors": descriptors
	}

static func _position_bucket(position: Vector3) -> Vector3i:
	return Vector3i(
		floori(position.x / POSITION_TOLERANCE),
		floori(position.y / POSITION_TOLERANCE),
		floori(position.z / POSITION_TOLERANCE)
	)

static func _side_offset(side: String, patch_size: float) -> Vector3:
	match side:
		"east": return Vector3(patch_size, 0.0, 0.0)
		"west": return Vector3(-patch_size, 0.0, 0.0)
		"north": return Vector3(0.0, 0.0, -patch_size)
		"south": return Vector3(0.0, 0.0, patch_size)
		_: return Vector3.ZERO

static func _side_between(first: Vector3, second: Vector3, patch_size: float) -> String:
	var delta: Vector3 = second - first
	if absf(delta.y) > POSITION_TOLERANCE:
		return ""
	if absf(delta.x - patch_size) <= POSITION_TOLERANCE and absf(delta.z) <= POSITION_TOLERANCE:
		return "east"
	if absf(delta.x + patch_size) <= POSITION_TOLERANCE and absf(delta.z) <= POSITION_TOLERANCE:
		return "west"
	if absf(delta.z - patch_size) <= POSITION_TOLERANCE and absf(delta.x) <= POSITION_TOLERANCE:
		return "south"
	if absf(delta.z + patch_size) <= POSITION_TOLERANCE and absf(delta.x) <= POSITION_TOLERANCE:
		return "north"
	return ""

static func _clear_all(patches: Array[Node3D]) -> void:
	for patch in patches:
		if not is_instance_valid(patch):
			continue
		for side in SIDES:
			patch.call("clear_neighbor_edge_state", side)

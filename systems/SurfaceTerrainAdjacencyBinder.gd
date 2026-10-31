extends RefCounted

## Rebuilds derived terrain adjacency from live world positions after chunk load/unload.
const SIDES: Array[String] = ["east", "west", "north", "south"]
const POSITION_TOLERANCE: float = 0.01

static func bind_patches(patches: Array[Node3D]) -> Dictionary:
	var seen_instances: Dictionary = {}
	var positions: Array[Vector3] = []
	var patch_size: float = -1.0
	for patch in patches:
		if not is_instance_valid(patch) or not patch.is_inside_tree() or patch.is_queued_for_deletion():
			return {"ok": false, "error": "invalid_patch"}
		if not patch.has_method("bind_neighbor_patch") or not patch.has_method("clear_neighbor_edge_state") or not patch.has_method("get_edge_ramp_profile"):
			return {"ok": false, "error": "unsupported_patch"}
		var instance_id: int = patch.get_instance_id()
		if seen_instances.has(instance_id):
			return {"ok": false, "error": "duplicate_instance"}
		seen_instances[instance_id] = true
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
		for prior_position in positions:
			if prior_position.distance_to(patch.global_position) <= POSITION_TOLERANCE:
				return {"ok": false, "error": "duplicate_position"}
		positions.append(patch.global_position)

	for patch in patches:
		for side in SIDES:
			if not bool(patch.call("clear_neighbor_edge_state", side)):
				return {"ok": false, "error": "clear_neighbor_failed"}

	var pair_count: int = 0
	for first_index in range(patches.size()):
		for second_index in range(first_index + 1, patches.size()):
			var first: Node3D = patches[first_index]
			var second: Node3D = patches[second_index]
			var side: String = _side_between(first.global_position, second.global_position, patch_size)
			if side.is_empty():
				continue
			var opposite: String = _opposite_side(side)
			if not bool(first.call("bind_neighbor_patch", side, second)) or not bool(second.call("bind_neighbor_patch", opposite, first)):
				_clear_all(patches)
				return {"ok": false, "error": "neighbor_bind_failed"}
			pair_count += 1
	return {"ok": true, "patch_count": patches.size(), "pair_count": pair_count}

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

static func _opposite_side(side: String) -> String:
	match side:
		"east": return "west"
		"west": return "east"
		"north": return "south"
		"south": return "north"
		_: return ""

static func _clear_all(patches: Array[Node3D]) -> void:
	for patch in patches:
		if not is_instance_valid(patch):
			continue
		for side in SIDES:
			patch.call("clear_neighbor_edge_state", side)

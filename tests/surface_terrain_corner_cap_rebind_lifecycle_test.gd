extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")
const PATCH_SIZE: float = 2.0
const STABLE_IDS: Array[String] = ["rebind/nw", "rebind/ne", "rebind/sw", "rebind/se"]
const CORNERS: Array[String] = ["south_east", "south_west", "north_east", "north_west"]
const SIDES: Array[String] = ["east", "west", "north", "south"]
const POSITIONS: Array[Vector3] = [
	Vector3.ZERO,
	Vector3(PATCH_SIZE, 0.0, 0.0),
	Vector3(0.0, 0.0, PATCH_SIZE),
	Vector3(PATCH_SIZE, 0.0, PATCH_SIZE)
]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var holder := Node3D.new()
	holder.name = "Run99CornerCapRebindRoot"
	root.add_child(holder)
	var manager: Node3D = ManagerScript.new()
	holder.add_child(manager)

	var first_generation: Dictionary = _create_generation(holder, "Original")
	await process_frame
	await physics_frame
	_apply_checkerboard(first_generation)
	var first_binding: Dictionary = BinderScript.bind_patches(first_generation["patches"], first_generation["stable_ids"])
	_expect(bool(first_binding.get("ok", false)), "original patch generation binds successfully")
	if not bool(first_binding.get("ok", false)):
		holder.queue_free()
		await process_frame
		quit(1)
		return

	var first_descriptors: Dictionary = first_binding.get("descriptors", {})
	var first_report: Dictionary = manager.call("sync_transitions", first_descriptors, first_generation["patches_by_id"])
	await process_frame
	await physics_frame
	_expect(bool(first_report.get("ok", false)), "manager commits the original four-way cap generation")
	_expect(int(manager.call("get_corner_cap_count")) == 4, "original generation owns four caps")
	_expect(int(manager.call("get_transition_count")) == 4, "original generation owns four shared ramps")

	var old_cap_refs: Array[WeakRef] = []
	var old_edge_refs: Array[WeakRef] = []
	var old_patch_refs: Array[WeakRef] = []
	var old_cap_ids: Dictionary = {}
	var old_edge_ids: Dictionary = {}
	for stable_id in STABLE_IDS:
		for corner in CORNERS:
			var old_cap: StaticBody3D = manager.call("get_corner_cap_body", stable_id, corner)
			if is_instance_valid(old_cap):
				old_cap_refs.append(weakref(old_cap))
				old_cap_ids[old_cap.get_instance_id()] = true
	for edge_key_value in first_descriptors.keys():
		var edge_body: StaticBody3D = manager.call("get_transition_body", str(edge_key_value))
		if is_instance_valid(edge_body):
			old_edge_refs.append(weakref(edge_body))
			old_edge_ids[edge_body.get_instance_id()] = true
	for old_patch in first_generation["patches"]:
		old_patch_refs.append(weakref(old_patch))

	manager.call("clear_all")
	await process_frame
	await physics_frame
	await process_frame
	_expect(int(manager.call("get_corner_cap_count")) == 0, "clear_all removes every original cap before chunk replacement")
	_expect(int(manager.call("get_transition_count")) == 0, "clear_all removes every original ramp before chunk replacement")
	for weak_cap in old_cap_refs:
		_expect(weak_cap.get_ref() == null, "retired cap body is released before stable-ID reuse")
	for weak_edge in old_edge_refs:
		_expect(weak_edge.get_ref() == null, "retired edge body is released before stable-ID reuse")

	for old_patch in first_generation["patches"]:
		old_patch.queue_free()
	await process_frame
	await process_frame
	for weak_patch in old_patch_refs:
		_expect(weak_patch.get_ref() == null, "unloaded patch instance is released before replacement")

	var reloaded_generation: Dictionary = _create_generation(holder, "Reloaded")
	await process_frame
	await physics_frame
	_apply_checkerboard(reloaded_generation)
	var reloaded_binding: Dictionary = BinderScript.bind_patches(reloaded_generation["patches"], reloaded_generation["stable_ids"])
	_expect(bool(reloaded_binding.get("ok", false)), "reloaded patches with the same stable IDs bind successfully")
	if not bool(reloaded_binding.get("ok", false)):
		holder.queue_free()
		await process_frame
		quit(1)
		return

	var descriptors: Dictionary = reloaded_binding.get("descriptors", {})
	var invalid_descriptors: Dictionary = descriptors.duplicate(true)
	var sorted_keys: Array = invalid_descriptors.keys()
	sorted_keys.sort()
	if not sorted_keys.is_empty():
		var invalid_key: String = str(sorted_keys[0])
		var invalid_descriptor: Dictionary = invalid_descriptors[invalid_key]
		invalid_descriptor["first_side"] = 17
		invalid_descriptors[invalid_key] = invalid_descriptor
		var rejected: Dictionary = manager.call("sync_transitions", invalid_descriptors, reloaded_generation["patches_by_id"])
		_expect(not bool(rejected.get("ok", false)) and str(rejected.get("error", "")) == "invalid_edge_sides", "invalid rebind descriptor is rejected before staging")
		_expect(int(manager.call("get_corner_cap_count")) == 0, "rejected rebind leaves no partial corner caps")
		_expect(int(manager.call("get_transition_count")) == 0, "rejected rebind leaves no partial edge ramps")

	for patch in reloaded_generation["patches"]:
		var base_collision := patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
		_expect(base_collision != null and not base_collision.disabled, "rejected rebind preserves full base collision on " + patch.name)
		for side in SIDES:
			_expect(not bool(patch.call("is_shared_transition_active", side)), "rejected rebind leaves " + patch.name + " " + side + " inactive")

	var reloaded_report: Dictionary = manager.call("sync_transitions", descriptors, reloaded_generation["patches_by_id"])
	await process_frame
	await physics_frame
	_expect(bool(reloaded_report.get("ok", false)), "same manager commits the reloaded patch generation")
	_expect(int(reloaded_report.get("corner_cap_count", -1)) == 4, "reloaded generation restores four shared corner caps")
	_expect(int(reloaded_report.get("active_count", -1)) == 4, "reloaded generation restores four shared ramps")
	_expect(int(manager.call("get_corner_cap_count")) == 4, "manager owns exactly four new cap bodies")
	_expect(int(manager.call("get_transition_count")) == 4, "manager owns exactly four new ramp bodies")

	for index in range(STABLE_IDS.size()):
		var stable_id: String = STABLE_IDS[index]
		var corner: String = CORNERS[index]
		var new_cap: StaticBody3D = manager.call("get_corner_cap_body", stable_id, corner)
		_expect(is_instance_valid(new_cap), "reloaded stable ID resolves to a live cap: " + stable_id + " " + corner)
		if is_instance_valid(new_cap):
			_expect(not old_cap_ids.has(new_cap.get_instance_id()), "reloaded cap uses a new instance rather than a stale body")
			_expect(new_cap.collision_layer == 1, "reloaded cap collision is enabled after commit")
	for edge_key_value in descriptors.keys():
		var new_edge: StaticBody3D = manager.call("get_transition_body", str(edge_key_value))
		_expect(is_instance_valid(new_edge), "reloaded edge resolves to a live shared ramp")
		if is_instance_valid(new_edge):
			_expect(not old_edge_ids.has(new_edge.get_instance_id()), "reloaded ramp uses a new instance rather than a stale body")

	for stable_id in STABLE_IDS:
		var patch: Node3D = reloaded_generation["patches_by_id"][stable_id]
		var base_collision := patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
		_expect(base_collision != null and base_collision.disabled, "committed reloaded cap geometry segments base collision on " + stable_id)
		var active_sides: int = 0
		for side in SIDES:
			if bool(patch.call("is_shared_transition_active", side)):
				active_sides += 1
		_expect(active_sides == 2, "reloaded patch owns exactly two incident shared edges: " + stable_id)

	manager.call("clear_all")
	await process_frame
	await physics_frame
	_expect(int(manager.call("get_corner_cap_count")) == 0, "final clear_all removes every reloaded cap")
	_expect(int(manager.call("get_transition_count")) == 0, "final clear_all removes every reloaded ramp")
	for patch in reloaded_generation["patches"]:
		var restored_collision := patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
		_expect(restored_collision != null and not restored_collision.disabled, "final clear_all restores base collision on " + patch.name)
		for side in SIDES:
			_expect(not bool(patch.call("is_shared_transition_active", side)), "final clear_all clears " + patch.name + " " + side + " ownership")

	holder.queue_free()
	await process_frame
	if failures.is_empty():
		print("Run 99 terrain corner-cap patch rebind lifecycle regression passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _create_generation(holder: Node3D, generation_name: String) -> Dictionary:
	var patches: Array[Node3D] = []
	var stable_ids: Dictionary = {}
	var patches_by_id: Dictionary = {}
	var names: Array[String] = ["NW", "NE", "SW", "SE"]
	for index in range(STABLE_IDS.size()):
		var patch: Node3D = PatchScript.new()
		patch.name = generation_name + "_" + names[index]
		patch.position = POSITIONS[index]
		holder.add_child(patch)
		patches.append(patch)
		stable_ids[patch.get_instance_id()] = STABLE_IDS[index]
		patches_by_id[STABLE_IDS[index]] = patch
	return {
		"patches": patches,
		"stable_ids": stable_ids,
		"patches_by_id": patches_by_id
	}

func _apply_checkerboard(generation: Dictionary) -> void:
	var high_state := {"height_level": 2, "surface_type": "metal", "revision": 1}
	var low_state := {"height_level": 0, "surface_type": "soil", "revision": 1}
	for stable_id in STABLE_IDS:
		var patch: Node3D = generation["patches_by_id"][stable_id]
		if stable_id == "rebind/nw" or stable_id == "rebind/se":
			_expect(bool(patch.call("apply_world_object_state", high_state)), "patch accepts high state: " + stable_id)
		else:
			_expect(bool(patch.call("apply_world_object_state", low_state)), "patch accepts low state: " + stable_id)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

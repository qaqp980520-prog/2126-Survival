extends SceneTree

const MineralRegistryScript = preload("res://systems/MineralVeinRegistry.gd")
const ControllerScript = preload("res://systems/MineralChunkController.gd")
const ObjectRegistryScript = preload("res://systems/WorldObjectStateRegistry.gd")
const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const PATCH_SIZE: float = 2.0
const CHUNK_IDS: Array[String] = ["terrain/nw", "terrain/ne", "terrain/sw", "terrain/se"]
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
	var mineral_registry: Node = MineralRegistryScript.new()
	var object_registry: Node = ObjectRegistryScript.new()
	var controller: Node3D = ControllerScript.new()
	root.add_child(mineral_registry)
	root.add_child(object_registry)
	root.add_child(controller)
	await process_frame
	_expect(bool(controller.call("bind_registry", mineral_registry)), "controller binds the production mineral registry")
	_expect(bool(controller.call("bind_object_state_registry", object_registry)), "controller binds the world-object state registry")

	var generations: Array[Dictionary] = []
	for index in range(CHUNK_IDS.size()):
		var entry: Dictionary = _new_patch_chunk("Initial_%d" % index, POSITIONS[index])
		var loaded: bool = bool(controller.call("load_chunk", CHUNK_IDS[index], entry["chunk"], 1700000000 + index))
		_expect(loaded, "controller loads terrain chunk " + CHUNK_IDS[index])
		if not loaded:
			await _cleanup(controller, mineral_registry, object_registry)
			quit(1)
			return
		await process_frame
		var state: Dictionary = _high_state() if index == 0 or index == 3 else _low_state()
		_expect(bool(entry["patch"].call("apply_world_object_state", state)), "loaded patch accepts its persisted checkerboard state")
		await process_frame
		generations.append(entry)

	var manager: Node3D = controller.get_node_or_null("SurfaceTerrainTransitionColliderManager") as Node3D
	_expect(manager != null, "production controller creates its shared transition manager")
	if manager == null:
		await _cleanup(controller, mineral_registry, object_registry)
		quit(1)
		return
	_expect(int(manager.call("get_corner_cap_count")) == 4, "four loaded chunks produce four shared corner caps")
	_expect(int(manager.call("get_transition_count")) == 4, "four loaded chunks produce four shared edge ramps")

	var old_patch: Node3D = generations[3]["patch"] as Node3D
	var old_patch_id: int = old_patch.get_instance_id()
	var old_patch_ref: WeakRef = weakref(old_patch)
	var replacement_stable_id: String = CHUNK_IDS[3] + "/object/ChunkRoot/TerrainPatch"
	_expect(bool(controller.call("unload_chunk", CHUNK_IDS[3], 1700000010)), "controller unloads the south-east chunk")
	await process_frame
	await process_frame
	_expect(old_patch_ref.get_ref() == null, "unloaded production patch instance is released")
	_expect(int(manager.call("get_corner_cap_count")) == 0, "three remaining chunks remove the obsolete four-way cap")
	_expect(int(manager.call("get_transition_count")) == 2, "three remaining chunks retain only their two live shared ramps")

	var replacement: Dictionary = _new_patch_chunk("Replacement_SE", POSITIONS[3])
	var new_patch: Node3D = replacement["patch"] as Node3D
	_expect(bool(controller.call("load_chunk", CHUNK_IDS[3], replacement["chunk"], 1700000020)), "controller reloads the same chunk ID with a replacement patch")
	await process_frame
	_expect(new_patch.get_instance_id() != old_patch_id, "reloaded terrain uses a new patch instance")
	var restored_state: Dictionary = new_patch.call("get_world_object_state")
	_expect(int(restored_state.get("height_level", -1)) == 2 and str(restored_state.get("surface_type", "")) == "metal", "same stable ID restores the saved terrain height and material")
	_expect(int(manager.call("get_corner_cap_count")) == 4, "controller rebind rebuilds all four corner caps after reload")
	_expect(int(manager.call("get_transition_count")) == 4, "controller rebind rebuilds all four shared ramps after reload")
	_expect(bool(new_patch.call("is_shared_transition_active", "west")) and bool(new_patch.call("is_shared_transition_active", "north")), "replacement patch owns its two correct incident shared edges")
	var base_collision: CollisionShape3D = new_patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
	_expect(base_collision != null and base_collision.disabled, "reloaded corner-cap patch segments its base collision after commit")

	for chunk_id in CHUNK_IDS:
		_expect(bool(controller.call("unload_chunk", chunk_id, 1700000030)), "controller unloads final terrain chunk " + chunk_id)
		await process_frame
		await process_frame
	_expect(int(manager.call("get_corner_cap_count")) == 0, "final production unload clears every shared corner cap")
	_expect(int(manager.call("get_transition_count")) == 0, "final production unload clears every shared ramp")
	var payload: Dictionary = object_registry.call("to_save_dict")
	var saved_objects: Dictionary = payload.get("objects", {})
	_expect(saved_objects.has(replacement_stable_id), "reloaded patch state remains in the world-object registry after final unload")
	if saved_objects.has(replacement_stable_id):
		var saved_record: Dictionary = saved_objects[replacement_stable_id]
		var saved_state: Dictionary = saved_record.get("state", {})
		_expect(int(saved_state.get("height_level", -1)) == 2, "final unload persists the replacement patch's restored height")

	await _cleanup(controller, mineral_registry, object_registry)
	if failures.is_empty():
		print("MineralChunkController terrain rebind integration test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _new_patch_chunk(generation_name: String, patch_position: Vector3) -> Dictionary:
	var chunk := Node3D.new()
	chunk.name = "ChunkRoot"
	chunk.set_meta("generation_name", generation_name)
	var patch: Node3D = PatchScript.new()
	patch.name = "TerrainPatch"
	patch.position = patch_position
	chunk.add_child(patch)
	return {"chunk": chunk, "patch": patch}

func _high_state() -> Dictionary:
	return {"height_level": 2, "surface_type": "metal", "revision": 1}

func _low_state() -> Dictionary:
	return {"height_level": 0, "surface_type": "soil", "revision": 1}

func _cleanup(controller: Node3D, mineral_registry: Node, object_registry: Node) -> void:
	controller.queue_free()
	mineral_registry.queue_free()
	object_registry.queue_free()
	await process_frame

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const ControllerScript = preload("res://systems/MineralChunkController.gd")


class FakeTransitionManager:
	extends Node3D

	var fail_next_sync: bool = true
	var sync_calls: int = 0

	func sync_transitions(_descriptors: Dictionary, _patches_by_stable_id: Dictionary, _profile_enabled: bool = false) -> Dictionary:
		sync_calls += 1
		if fail_next_sync:
			fail_next_sync = false
			return {"ok": false, "error": "injected_staging_failure"}
		return {
			"ok": true,
			"active_count": 1,
			"blocked_count": 0,
			"corner_cap_count": 0,
			"reused_edge_count": 0,
			"reactivated_edge_count": 0,
			"staged_edge_count": 1,
			"retired_edge_count": 0,
			"reused_corner_cap_count": 0,
			"staged_corner_cap_count": 0,
			"retired_corner_cap_count": 0
		}


class FakeObjectStateRegistry:
	extends Node

	var records: Dictionary = {}

	func to_save_dict() -> Dictionary:
		return {"schema_version": 1, "objects": records.duplicate(true)}

	func restore_save_dict(payload: Dictionary) -> bool:
		if not payload.has("schema_version") or not (payload.get("objects", {}) is Dictionary):
			return false
		records = payload["objects"].duplicate(true)
		return true

	func set_object_state(stable_id: String, chunk_id: String, state: Dictionary) -> bool:
		if stable_id.is_empty() or chunk_id.is_empty():
			return false
		records[stable_id] = {"chunk_id": chunk_id, "state": state.duplicate(true)}
		return true


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var holder := Node3D.new()
	holder.name = "TerrainControllerTransactionTestRoot"
	root.add_child(holder)

	var controller: Node3D = ControllerScript.new()
	controller.name = "MineralChunkController"
	holder.add_child(controller)

	var chunk_a := Node3D.new()
	chunk_a.name = "ChunkA"
	var chunk_b := Node3D.new()
	chunk_b.name = "ChunkB"
	var chunk_c := Node3D.new()
	chunk_c.name = "ChunkC"
	controller.add_child(chunk_a)
	controller.add_child(chunk_b)
	controller.add_child(chunk_c)

	var patch_a: Node3D = _new_patch(chunk_a, "TerrainA", Vector3(0.0, 0.0, 0.0))
	var patch_b: Node3D = _new_patch(chunk_b, "TerrainB", Vector3(2.0, 0.0, 0.0))
	var patch_c: Node3D = _new_patch(chunk_c, "TerrainC", Vector3(4.0, 0.0, 0.0))
	await process_frame

	_expect(bool(patch_b.call("apply_world_object_state", {"height_level": 1, "surface_type": "soil", "revision": 1})), "middle patch receives a valid elevated terrain state")
	_expect(bool(patch_a.call("bind_neighbor_patch", "east", patch_b)), "initial A-east/B-west edge binds from A")
	_expect(bool(patch_b.call("bind_neighbor_patch", "west", patch_a)), "initial A-east/B-west edge binds reciprocally")
	_expect(bool(patch_b.call("bind_neighbor_patch", "east", patch_c)), "initial B-east/C-west edge binds from B")
	_expect(bool(patch_c.call("bind_neighbor_patch", "west", patch_b)), "initial B-east/C-west edge binds reciprocally")

	_expect(bool(patch_a.call("set_shared_transition_active", "east", true)), "A-east shared transition starts active")
	_expect(bool(patch_b.call("set_shared_transition_active", "west", true)), "B-west shared transition starts active")
	_expect(bool(patch_b.call("set_shared_transition_active", "east", true)), "B-east shared transition starts active")
	_expect(bool(patch_c.call("set_shared_transition_active", "west", true)), "C-west shared transition starts active")

	var fake_registry := Node.new()
	fake_registry.name = "FakeMineralRegistry"
	controller.add_child(fake_registry)
	controller.registry = fake_registry

	var object_registry := FakeObjectStateRegistry.new()
	object_registry.name = "FakeWorldObjectStateRegistry"
	object_registry.records = {
		"persistent/keep": {"chunk_id": "persistent", "state": {"value": 7}}
	}
	controller.add_child(object_registry)
	controller.object_state_registry = object_registry

	var transition_manager := FakeTransitionManager.new()
	transition_manager.name = "InjectedTransitionManager"
	controller.add_child(transition_manager)
	controller._terrain_transition_collider_manager = transition_manager
	controller._terrain_transition_descriptors = {"preserved": {"edge_key": "before-failed-sync"}}

	controller._chunk_roots = {"chunk_a": chunk_a, "chunk_b": chunk_b, "chunk_c": chunk_c}
	controller._chunk_veins = {"chunk_a": {}, "chunk_b": {}, "chunk_c": {}}
	controller._chunk_crops = {"chunk_a": {}, "chunk_b": {}, "chunk_c": {}}
	controller._chunk_objects = {
		"chunk_a": {"chunk_a/object/terrain": patch_a},
		"chunk_b": {"chunk_b/object/terrain": patch_b},
		"chunk_c": {"chunk_c/object/terrain": patch_c}
	}

	var registry_before: Dictionary = object_registry.call("to_save_dict")
	var failed_unload: bool = bool(controller.call("unload_chunk", "chunk_c", 100))
	_expect(not failed_unload, "injected collider staging failure rejects chunk unload")
	_expect(transition_manager.sync_calls == 1, "failed unload reaches the transition manager exactly once")
	_expect(controller._chunk_roots.has("chunk_c"), "failed unload retains the Controller chunk-root entry")
	_expect(chunk_c.get_parent() == controller and not chunk_c.is_queued_for_deletion(), "failed unload keeps the old chunk root attached and alive")
	_expect(patch_a.call("get_bound_neighbor_patch", "east") == patch_b, "failed unload restores A-east/B-west adjacency")
	_expect(patch_b.call("get_bound_neighbor_patch", "west") == patch_a, "failed unload restores the reciprocal B-west/A-east adjacency")
	_expect(patch_b.call("get_bound_neighbor_patch", "east") == patch_c, "failed unload restores the removed chunk's B-east/C-west edge")
	_expect(patch_c.call("get_bound_neighbor_patch", "west") == patch_b, "failed unload restores the external reciprocal C-west/B-east edge")
	_expect(bool(patch_a.call("is_shared_transition_active", "east")), "failed unload restores A-east transition activation")
	_expect(bool(patch_b.call("is_shared_transition_active", "west")), "failed unload restores B-west transition activation")
	_expect(bool(patch_b.call("is_shared_transition_active", "east")), "failed unload restores B-east transition activation")
	_expect(bool(patch_c.call("is_shared_transition_active", "west")), "failed unload restores C-west transition activation")
	_expect(controller.call("get_terrain_transition_descriptors") == {"preserved": {"edge_key": "before-failed-sync"}}, "failed collider sync preserves the committed descriptor snapshot")
	_expect(object_registry.call("to_save_dict") == registry_before, "failed unload restores the world-object registry snapshot")

	var successful_unload: bool = bool(controller.call("unload_chunk", "chunk_c", 101))
	_expect(successful_unload, "chunk unload succeeds after the injected failure is removed")
	_expect(transition_manager.sync_calls == 2, "successful retry commits one new adjacency synchronization")
	_expect(not controller._chunk_roots.has("chunk_c"), "successful unload removes the Controller chunk-root entry")
	_expect(chunk_c.get_parent() == null and chunk_c.is_queued_for_deletion(), "successful unload detaches and queues the old root only after adjacency commit")
	_expect(patch_a.call("get_bound_neighbor_patch", "east") == patch_b, "successful unload retains the unaffected A-east/B-west edge")
	_expect(patch_b.call("get_bound_neighbor_patch", "east") == null, "successful unload clears the departing B-east edge")
	_expect(patch_c.call("get_bound_neighbor_patch", "west") == null, "successful unload clears the departing reciprocal C-west edge")
	_expect(controller.call("get_terrain_transition_descriptors").size() == 1, "successful unload publishes the new descriptor snapshot")

	await process_frame
	_expect(not is_instance_valid(patch_c), "successful unload releases the departing patch after the commit")

	holder.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("Surface terrain controller transaction tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)


func _new_patch(parent: Node3D, patch_name: String, patch_position: Vector3) -> Node3D:
	var patch: Node3D = PatchScript.new()
	patch.name = patch_name
	patch.position = patch_position
	parent.add_child(patch)
	return patch


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

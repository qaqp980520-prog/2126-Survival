extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const ControllerScript = preload("res://systems/MineralChunkController.gd")
const MiningNodeScript = preload("res://systems/MineralMiningNode.gd")
const LifecycleAdapterScript = preload("res://systems/MineralChunkLifecycleAdapter.gd")
const DirectorScript = preload("res://systems/MineralGridStreamingDirector.gd")
const StatefulPropScript = preload("res://systems/WorldObjectStatefulProp.gd")


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

	func get_object_state(stable_id: String) -> Dictionary:
		return records.get(stable_id, {}).duplicate(true)

	func set_object_state(stable_id: String, chunk_id: String, state: Dictionary) -> bool:
		if stable_id.is_empty() or chunk_id.is_empty():
			return false
		records[stable_id] = {"chunk_id": chunk_id, "state": state.duplicate(true)}
		return true

	func get_chunk_states(chunk_id: String) -> Dictionary:
		var result: Dictionary = {}
		for stable_id in records.keys():
			if str(records[stable_id].get("chunk_id", "")) == chunk_id:
				result[stable_id] = records[stable_id].duplicate(true)
		return result

	func restore_chunk_states(chunk_id: String, snapshot: Dictionary) -> bool:
		if not (snapshot is Dictionary):
			return false
		for stable_id in records.keys():
			if str(records[stable_id].get("chunk_id", "")) == chunk_id:
				records.erase(stable_id)
		for stable_id in snapshot.keys():
			if not (snapshot[stable_id] is Dictionary) or str(snapshot[stable_id].get("chunk_id", "")) != chunk_id:
				return false
			records[stable_id] = snapshot[stable_id].duplicate(true)
		return true


class FakeMineralRegistry:
	extends Node

	var registered_veins: Dictionary = {}

	func get_registered_ids() -> PackedStringArray:
		var ids := PackedStringArray()
		for stable_id in registered_veins.keys():
			ids.append(str(stable_id))
		ids.sort()
		return ids

	func register_vein(stable_id: String, vein: Node, _now_unix: int = -1) -> bool:
		if stable_id.is_empty() or registered_veins.has(stable_id) or not is_instance_valid(vein):
			return false
		registered_veins[stable_id] = vein
		return true

	func unregister_vein(stable_id: String, vein: Node, _now_unix: int = -1) -> bool:
		if not registered_veins.has(stable_id) or registered_veins[stable_id] != vein:
			return false
		registered_veins.erase(stable_id)
		return true


class FailingMineralAdapter:
	extends Node

	var load_calls: int = 0
	var unload_calls: int = 0

	func load_chunk(_chunk_id: String, _veins: Dictionary, _now_unix: int = -1) -> bool:
		load_calls += 1
		return false

	func unload_chunk(_chunk_id: String, _now_unix: int = -1) -> bool:
		unload_calls += 1
		return true


class FakeReconcileController:
	extends Node

	var loaded_ids: PackedStringArray = PackedStringArray(["surface/chunk_2_3"])

	func load_chunk(_id: String, _root: Node3D, _now_unix: int = -1) -> bool:
		return true

	func unload_chunk(_id: String, _now_unix: int = -1) -> bool:
		return true

	func is_chunk_loaded(_id: String) -> bool:
		return true

	func get_loaded_chunk_ids() -> PackedStringArray:
		return loaded_ids.duplicate()

	func end_terrain_adjacency_batch() -> Dictionary:
		return {"ok": false, "error": "injected_end_failure"}


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
	var vein_c: Node3D = MiningNodeScript.new()
	vein_c.name = "IronVein"
	chunk_c.add_child(vein_c)
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

	var fake_mineral_registry := FakeMineralRegistry.new()
	fake_mineral_registry.name = "FakeMineralRegistry"
	controller.add_child(fake_mineral_registry)
	controller.set("registry", fake_mineral_registry)
	var lifecycle_adapter = LifecycleAdapterScript.new()
	lifecycle_adapter.name = "RealMineralChunkLifecycleAdapter"
	controller.add_child(lifecycle_adapter)
	_expect(bool(lifecycle_adapter.call("bind_registry", fake_mineral_registry)), "real mineral lifecycle adapter binds the fake registry")
	controller.set("adapter", lifecycle_adapter)
	_expect(bool(lifecycle_adapter.call("load_chunk", "chunk_c", {"ChunkC/IronVein": vein_c}, 99)), "initial chunk C mineral registration succeeds")
	_expect(fake_mineral_registry.registered_veins.has("chunk_c/vein/ChunkC/IronVein"), "initial chunk C vein is present in the registry")

	var object_registry := FakeObjectStateRegistry.new()
	object_registry.name = "FakeWorldObjectStateRegistry"
	object_registry.records = {
		"persistent/keep": {"chunk_id": "persistent", "state": {"value": 7}}
	}
	controller.add_child(object_registry)
	controller.set("object_state_registry", object_registry)

	var transition_manager := FakeTransitionManager.new()
	transition_manager.name = "InjectedTransitionManager"
	controller.add_child(transition_manager)
	controller.set("_terrain_transition_collider_manager", transition_manager)
	controller.set("_terrain_transition_descriptors", {"preserved": {"edge_key": "before-failed-sync"}})

	controller.set("_chunk_roots", {"chunk_a": chunk_a, "chunk_b": chunk_b, "chunk_c": chunk_c})
	controller.set("_chunk_veins", {"chunk_a": {}, "chunk_b": {}, "chunk_c": {"ChunkC/IronVein": vein_c}})
	controller.set("_chunk_crops", {"chunk_a": {}, "chunk_b": {}, "chunk_c": {}})
	controller.set("_chunk_objects", {
		"chunk_a": {"chunk_a/object/terrain": patch_a},
		"chunk_b": {"chunk_b/object/terrain": patch_b},
		"chunk_c": {"chunk_c/object/terrain": patch_c}
	})

	var registry_before: Dictionary = object_registry.call("to_save_dict")
	var failed_unload: bool = bool(controller.call("unload_chunk", "chunk_c", 100))
	_expect(not failed_unload, "injected collider staging failure rejects chunk unload")
	_expect(transition_manager.sync_calls == 1, "failed unload reaches the transition manager exactly once")
	_expect(controller.get("_chunk_roots").has("chunk_c"), "failed unload retains the Controller chunk-root entry")
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
	_expect(bool(lifecycle_adapter.call("is_chunk_loaded", "chunk_c")), "failed unload re-registers the chunk through the real lifecycle adapter")
	_expect(fake_mineral_registry.registered_veins.has("chunk_c/vein/ChunkC/IronVein"), "failed unload restores the registered vein identity")

	var chunk_f_root := Node3D.new()
	chunk_f_root.name = "ChunkF"
	var patch_f: Node3D = _new_patch(chunk_f_root, "TerrainF", Vector3(6.0, 0.0, 0.0))
	var prop_f: Node3D = StatefulPropScript.new()
	prop_f.name = "SalvageCrate"
	chunk_f_root.add_child(prop_f)
	_expect(bool(controller.call("load_chunk", "chunk_f", chunk_f_root, 100)), "second stateful chunk loads before the multi-retirement batch")
	_expect(transition_manager.sync_calls == 2, "second stateful chunk performs one pre-batch adjacency synchronization")
	var registry_before_batch: Dictionary = object_registry.call("to_save_dict")

	# A failed batch commit must restore every pending retirement and its adapter/registry state.
	transition_manager.fail_next_sync = true
	_expect(bool(controller.call("begin_terrain_adjacency_batch")), "rollback terrain adjacency batch begins")
	var staged_failed_unload: bool = bool(controller.call("unload_chunk", "chunk_c", 101))
	var staged_failed_unload_f: bool = bool(controller.call("unload_chunk", "chunk_f", 101))
	_expect(staged_failed_unload and staged_failed_unload_f, "two chunk unloads stage without freeing either root")
	_expect(transition_manager.sync_calls == 2, "multiple batch unloads defer collider synchronization until one batch commit")
	_expect(controller.get("_pending_chunk_unloads").size() == 2, "batch records both pending retirements")
	_expect(chunk_c.get_parent() == controller and not chunk_c.is_queued_for_deletion() and chunk_f_root.get_parent() == controller and not chunk_f_root.is_queued_for_deletion(), "both pending roots remain attached and alive")
	_expect(not bool(lifecycle_adapter.call("is_chunk_loaded", "chunk_c")), "pending retirement unregisters chunk C minerals before adjacency commit")
	var failed_batch_end: Dictionary = controller.call("end_terrain_adjacency_batch")
	_expect(not bool(failed_batch_end.get("ok", false)), "injected batch collider failure rejects the pending retirements")
	_expect(transition_manager.sync_calls == 3, "failed multi-retirement batch performs one collider synchronization attempt")
	_expect(controller.get("_pending_chunk_unloads").is_empty(), "failed batch clears every cancelled retirement record")
	_expect(controller.get("_chunk_roots").has("chunk_c") and chunk_c.get_parent() == controller and not chunk_c.is_queued_for_deletion(), "failed batch retains the original C root")
	_expect(controller.get("_chunk_roots").has("chunk_f") and chunk_f_root.get_parent() == controller and not chunk_f_root.is_queued_for_deletion(), "failed batch retains the original F root")
	_expect(bool(lifecycle_adapter.call("is_chunk_loaded", "chunk_c")), "failed batch re-registers C minerals through the real adapter")
	_expect(object_registry.call("to_save_dict") == registry_before_batch, "multi-retirement rollback restores each chunk's object-state records without overwriting its neighbor")
	_expect(patch_b.call("get_bound_neighbor_patch", "east") == patch_c and patch_c.call("get_bound_neighbor_patch", "west") == patch_b, "failed batch restores the B/C reciprocal terrain edge")
	_expect(patch_c.call("get_bound_neighbor_patch", "east") == patch_f and patch_f.call("get_bound_neighbor_patch", "west") == patch_c, "failed batch preserves the C/F reciprocal terrain edge")

	# All stale roots stay alive until one shared adjacency commit excludes the complete pending-retirement set.
	var batch_rebuilds_before: int = int(controller.call("get_terrain_adjacency_rebuild_count"))
	_expect(bool(controller.call("begin_terrain_adjacency_batch")), "successful terrain adjacency batch begins")
	var batch_root := Node3D.new()
	batch_root.name = "ChunkD"
	var batch_patch: Node3D = _new_patch(batch_root, "TerrainD", Vector3(4.0, 0.0, 0.0))
	var batch_load: bool = bool(controller.call("load_chunk", "chunk_d", batch_root, 102))
	_expect(batch_load, "candidate chunk load is accepted into the active adjacency batch")
	_expect(transition_manager.sync_calls == 3, "batched candidate load defers transition synchronization")
	_expect(controller.get("_terrain_adjacency_batch_dirty"), "batched candidate load marks adjacency dirty")

	var successful_unload: bool = bool(controller.call("unload_chunk", "chunk_c", 103))
	var successful_unload_f: bool = bool(controller.call("unload_chunk", "chunk_f", 103))
	_expect(successful_unload and successful_unload_f, "two stale chunks are staged while their old roots remain alive")
	_expect(transition_manager.sync_calls == 3, "staged unloads do not trigger extra per-chunk synchronization")
	_expect(controller.get("_pending_chunk_unloads").size() == 2, "successful batch records both departing chunks")
	_expect(chunk_c.get_parent() == controller and not chunk_c.is_queued_for_deletion() and chunk_f_root.get_parent() == controller and not chunk_f_root.is_queued_for_deletion(), "both departing roots remain attached until the shared commit")
	var batch_end: Dictionary = controller.call("end_terrain_adjacency_batch")
	_expect(bool(batch_end.get("ok", false)), "shared terrain adjacency batch commits successfully")
	_expect(transition_manager.sync_calls == 4, "one shared commit synchronizes the loaded window exactly once")
	_expect(int(controller.call("get_terrain_adjacency_rebuild_count")) - batch_rebuilds_before == 1, "load plus two unloads perform exactly one full adjacency rebuild")
	_expect(controller.get("_pending_chunk_unloads").is_empty(), "successful commit clears all pending retirements")
	_expect(not controller.get("_chunk_roots").has("chunk_c") and not controller.get("_chunk_roots").has("chunk_f"), "successful commit removes both Controller chunk-root entries")
	_expect(chunk_c.get_parent() == null and chunk_c.is_queued_for_deletion() and chunk_f_root.get_parent() == null and chunk_f_root.is_queued_for_deletion(), "successful commit detaches and queues both old roots only after adjacency commit")
	_expect(patch_a.call("get_bound_neighbor_patch", "east") == patch_b, "successful unload retains the unaffected A-east/B-west edge")
	_expect(patch_b.call("get_bound_neighbor_patch", "east") == batch_patch, "successful unload binds the replacement D patch at the departing boundary")
	_expect(batch_patch.call("get_bound_neighbor_patch", "west") == patch_b, "successful unload binds the replacement patch reciprocally")
	_expect(patch_c.call("get_bound_neighbor_patch", "west") == null, "successful unload clears the departing reciprocal C-west edge")
	_expect(controller.call("get_terrain_transition_descriptors").size() == 2, "successful unload publishes descriptors for both remaining transition edges")
	_expect(not bool(lifecycle_adapter.call("is_chunk_loaded", "chunk_c")), "successful unload unregisters the chunk through the real lifecycle adapter")
	_expect(not fake_mineral_registry.registered_veins.has("chunk_c/vein/ChunkC/IronVein"), "successful unload removes the registered vein identity")
	_expect(int(batch_end.get("retired_chunk_count", -1)) == 2, "batch commit reports both retired chunks")

	# A Director rollback can cancel a staged retirement and keep the exact old root.
	var cancel_rebuilds_before: int = int(controller.call("get_terrain_adjacency_rebuild_count"))
	var registry_before_cancel: Dictionary = object_registry.call("to_save_dict")
	var rollback_director := DirectorScript.new()
	rollback_director.name = "RollbackDirector"
	rollback_director.set("chunk_controller", controller)
	rollback_director.set("chunk_factory", Callable())
	holder.add_child(rollback_director)
	_expect(bool(controller.call("begin_terrain_adjacency_batch")), "pending-retirement cancellation batch begins")
	_expect(bool(controller.call("unload_chunk", "chunk_d", 104)), "replacement chunk can be staged for retirement")
	_expect(controller.get("_pending_chunk_unloads").has("chunk_d"), "replacement chunk retirement is pending")
	var director_restore_ok: bool = bool(rollback_director.call("_restore_unloaded_chunks", [{"id": "chunk_d", "coord": Vector2i(2, 0)}], 104))
	_expect(director_restore_ok, "Director rollback restores a held pending root without requiring a factory")
	_expect(not controller.get("_pending_chunk_unloads").has("chunk_d"), "Director cancellation removes the pending retirement")
	_expect(controller.is_chunk_loaded("chunk_d") and batch_root.get_parent() == controller, "Director cancellation preserves the exact replacement root")
	_expect(rollback_director.call("get_managed_chunk_ids").has("chunk_d"), "Director restores its managed-ID map for the held root")
	_expect(object_registry.call("to_save_dict") == registry_before_cancel, "cancellation restores the pre-unload world-object registry snapshot")
	var cancel_batch_end: Dictionary = controller.call("end_terrain_adjacency_batch")
	_expect(bool(cancel_batch_end.get("ok", false)), "cancellation batch commits successfully")
	_expect(int(controller.call("get_terrain_adjacency_rebuild_count")) - cancel_rebuilds_before == 1, "cancellation batch performs one reconciliation rebuild")
	_expect(transition_manager.sync_calls == 5, "cancellation batch synchronizes once after restoring the pending root")

	await process_frame
	_expect(not is_instance_valid(patch_c), "successful unload releases the departing patch after the commit")

	# Mineral registration failure must not invoke the terrain transaction at all.
	var failing_adapter := FailingMineralAdapter.new()
	failing_adapter.name = "FailingMineralAdapter"
	controller.add_child(failing_adapter)
	controller.set("adapter", failing_adapter)
	var registry_before_load: Dictionary = object_registry.call("to_save_dict")
	var candidate_root := Node3D.new()
	candidate_root.name = "ChunkE"
	var candidate_patch: Node3D = _new_patch(candidate_root, "TerrainE", Vector3(6.0, 0.0, 0.0))
	var candidate_ore: Node3D = MiningNodeScript.new()
	candidate_ore.name = "IronVein"
	candidate_root.add_child(candidate_ore)
	var manager_calls_before_load: int = transition_manager.sync_calls
	var failed_load: bool = bool(controller.call("load_chunk", "chunk_e", candidate_root, 200))
	_expect(not failed_load, "injected mineral registration failure rejects candidate chunk load")
	_expect(failing_adapter.load_calls == 1 and failing_adapter.unload_calls == 0, "failed candidate registration is not followed by an adapter inverse call")
	_expect(transition_manager.sync_calls == manager_calls_before_load, "failed mineral registration does not publish or synchronize candidate terrain adjacency")
	_expect(candidate_root.get_parent() == null and not candidate_root.is_queued_for_deletion(), "failed candidate load leaves root detached and caller-owned")
	_expect(not controller.get("_chunk_roots").has("chunk_e"), "failed candidate load does not publish Controller chunk maps")
	_expect(batch_patch.call("get_bound_neighbor_patch", "east") == null, "failed candidate load leaves the existing boundary unchanged")
	_expect(candidate_patch.call("get_bound_neighbor_patch", "west") == null, "failed candidate load leaves the candidate patch unbound")
	_expect(object_registry.call("to_save_dict") == registry_before_load, "failed candidate load restores the world-object registry snapshot")
	candidate_root.free()

	var fake_reconcile_controller := FakeReconcileController.new()
	fake_reconcile_controller.name = "FakeReconcileController"
	holder.add_child(fake_reconcile_controller)
	var reconcile_director := DirectorScript.new()
	reconcile_director.name = "ReconcileDirector"
	reconcile_director.set("chunk_controller", fake_reconcile_controller)
	reconcile_director.set("_managed_chunk_ids", {"surface/chunk_0_0": Vector2i.ZERO})
	holder.add_child(reconcile_director)
	var failed_finalize: Dictionary = reconcile_director.call("_end_controller_terrain_adjacency_batch")
	_expect(not bool(failed_finalize.get("ok", true)), "Director receives the injected failed batch result")
	_expect(bool(failed_finalize.get("managed_map_reconciled", false)), "Director reconciles managed IDs after failed batch rollback")
	_expect(reconcile_director.call("get_managed_chunk_ids").has("surface/chunk_2_3"), "reconciliation restores the Controller's actual loaded surface ID")
	var map_before_invalid_reconcile: PackedStringArray = reconcile_director.call("get_managed_chunk_ids")
	fake_reconcile_controller.loaded_ids = PackedStringArray(["unknown/chunk"])
	_expect(not bool(reconcile_director.call("_reconcile_managed_chunk_ids_from_controller")), "reconciliation rejects an unknown Controller chunk ID")
	_expect(reconcile_director.call("get_managed_chunk_ids") == map_before_invalid_reconcile, "failed reconciliation leaves the previous managed map untouched")

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

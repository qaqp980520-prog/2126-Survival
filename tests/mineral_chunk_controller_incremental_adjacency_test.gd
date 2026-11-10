extends SceneTree

const ControllerScript = preload("res://systems/MineralChunkController.gd")
const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")
const IndexScript = preload("res://systems/SurfaceTerrainAdjacencyIndex.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const VeinRegistryScript = preload("res://systems/MineralVeinRegistry.gd")
const WorldObjectRegistryScript = preload("res://systems/WorldObjectStateRegistry.gd")


class FaultInjectingColliderManager extends SurfaceTerrainTransitionColliderManager:
	var fail_commit_once: bool = false
	var abort_failures_remaining: int = 0

	func commit_sync_transitions(transaction_id: int) -> Dictionary:
		if fail_commit_once:
			fail_commit_once = false
			return {"ok": false, "error": "injected_commit_failure"}
		return super.commit_sync_transitions(transaction_id)

	func abort_sync_transitions(transaction_id: int) -> Dictionary:
		if abort_failures_remaining > 0:
			abort_failures_remaining -= 1
			return {"ok": false, "error": "injected_abort_failure"}
		return super.abort_sync_transitions(transaction_id)


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_incremental_chunk_window_preserves_unaffected_resources()
	await _test_patch_state_edit_uses_safe_full_rebind()
	await _test_retained_coordinator_abort_recovery_keeps_chunk_roots()
	if failures.is_empty():
		print("Mineral chunk controller incremental adjacency tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(1)


func _test_incremental_chunk_window_preserves_unaffected_resources() -> void:
	var fixture: Dictionary = _make_fixture("IncrementalWindowFixture")
	if fixture.is_empty():
		return
	var controller: Node3D = fixture["controller"]
	var holder: Node3D = fixture["holder"]
	var a: Dictionary = await _make_chunk(holder, "ChunkA", Vector3(0.0, 0.0, 0.0), 0)
	var b: Dictionary = await _make_chunk(holder, "ChunkB", Vector3(2.0, 0.0, 0.0), 1)
	var d: Dictionary = await _make_chunk(holder, "ChunkD", Vector3(20.0, 0.0, 0.0), 0)
	var e: Dictionary = await _make_chunk(holder, "ChunkE", Vector3(22.0, 0.0, 0.0), 1)
	_expect(bool(controller.call("load_chunk", "chunk_a", a["root"], 100)), "initial chunk A loads through the production Controller")
	_expect(bool(controller.call("load_chunk", "chunk_b", b["root"], 100)), "initial chunk B loads through the production Controller")
	_expect(bool(controller.call("load_chunk", "chunk_d", d["root"], 100)), "disconnected chunk D loads through the production Controller")
	_expect(bool(controller.call("load_chunk", "chunk_e", e["root"], 100)), "disconnected chunk E loads through the production Controller")

	var stable_d: String = _stable_id_for_chunk(controller, "chunk_d")
	var stable_e: String = _stable_id_for_chunk(controller, "chunk_e")
	var descriptors_before: Dictionary = controller.call("get_terrain_transition_descriptors")
	var unrelated_edge: String = _edge_key_for_pair(descriptors_before, stable_d, stable_e)
	var unrelated_body: StaticBody3D = controller.call("get_terrain_transition_collider", unrelated_edge) as StaticBody3D
	_expect(not unrelated_edge.is_empty() and is_instance_valid(unrelated_body), "disconnected D/E transition has a committed collider body")
	var generation_before: int = int(controller.call("get_terrain_adjacency_index_generation"))
	var rebuilds_before: int = int(controller.call("get_terrain_adjacency_rebuild_count"))
	var c: Dictionary = await _make_chunk(holder, "ChunkC", Vector3(4.0, 0.0, 0.0), 0)

	_expect(bool(controller.call("begin_terrain_adjacency_batch")), "synchronous window delta opens one Controller adjacency batch")
	_expect(bool(controller.call("unload_chunk", "chunk_a", 101)), "departing chunk A is staged for retirement")
	_expect(bool(controller.call("load_chunk", "chunk_c", c["root"], 101)), "arriving chunk C is staged in the same batch")
	var committed: Dictionary = controller.call("end_terrain_adjacency_batch")
	_expect(bool(committed.get("ok", false)) and bool(committed.get("incremental", false)), "batch commits through the persistent Index/Coordinator delta path")
	_expect(int(controller.call("get_terrain_adjacency_rebuild_count")) - rebuilds_before == 1, "one window shift performs exactly one adjacency transaction")
	_expect(int(controller.call("get_terrain_adjacency_index_generation")) == generation_before + 1, "successful chunk delta advances the existing Index generation once")
	_expect(int(controller.call("get_terrain_adjacency_index_patch_count")) == 4, "Index contains B, C, D, and E after the window delta")
	_expect(controller.call("get_terrain_transition_descriptors").size() == 2, "only B/C and disconnected D/E descriptors remain")
	_expect(int(controller.call("get_terrain_transition_collider_count")) == 2, "only the two live transition collider bodies remain")
	_expect(b["patch"].call("get_bound_neighbor_patch", "east") == c["patch"], "B binds to arriving C after the scoped transaction")
	_expect(c["patch"].call("get_bound_neighbor_patch", "west") == b["patch"], "C holds the reciprocal B neighbor")
	_expect(controller.call("get_terrain_transition_collider", unrelated_edge) == unrelated_body, "unaffected D/E collider retains the exact same Node instance")
	_expect(controller.get("_pending_chunk_unloads").is_empty(), "successful delta retires the old chunk only after all participants finalize")
	await process_frame
	_expect(not is_instance_valid(a["root"]), "departing chunk A is freed after the coordinated commit")
	_assert_full_descriptor_parity(controller, "incremental window shift")
	await _release_fixture(fixture)


func _test_patch_state_edit_uses_safe_full_rebind() -> void:
	var fixture: Dictionary = _make_fixture("PatchEditFallbackFixture")
	if fixture.is_empty():
		return
	var controller: Node3D = fixture["controller"]
	var holder: Node3D = fixture["holder"]
	var a: Dictionary = await _make_chunk(holder, "EditA", Vector3(0.0, 0.0, 0.0), 0)
	var b: Dictionary = await _make_chunk(holder, "EditB", Vector3(2.0, 0.0, 0.0), 1)
	var d: Dictionary = await _make_chunk(holder, "EditD", Vector3(20.0, 0.0, 0.0), 0)
	var e: Dictionary = await _make_chunk(holder, "EditE", Vector3(22.0, 0.0, 0.0), 1)
	_expect(bool(controller.call("load_chunk", "edit_a", a["root"], 200)), "edit fixture loads A")
	_expect(bool(controller.call("load_chunk", "edit_b", b["root"], 200)), "edit fixture loads B")
	_expect(bool(controller.call("load_chunk", "edit_d", d["root"], 200)), "edit fixture loads disconnected D")
	_expect(bool(controller.call("load_chunk", "edit_e", e["root"], 200)), "edit fixture loads disconnected E")
	var generation_before: int = int(controller.call("get_terrain_adjacency_index_generation"))
	var rebuilds_before: int = int(controller.call("get_terrain_adjacency_rebuild_count"))
	_expect(bool(controller.call("begin_terrain_adjacency_batch")), "terrain edit batch begins")
	_expect(bool(b["patch"].call("apply_world_object_state", {"height_level": 2, "surface_type": "soil", "revision": 2})), "Patch accepts a newer terrain state inside the batch")
	var result: Dictionary = controller.call("end_terrain_adjacency_batch")
	_expect(bool(result.get("ok", false)), "in-place terrain edit completes safely")
	_expect(not bool(result.get("incremental", false)), "in-place edit deliberately uses the full Binder until Index snapshot-edit reservation exists")
	_expect(int(controller.call("get_terrain_adjacency_rebuild_count")) - rebuilds_before == 1, "in-place edit performs one authoritative rebind")
	_expect(int(controller.call("get_terrain_adjacency_index_generation")) == generation_before + 1, "full rebind advances rather than resets the persistent Index generation")
	_assert_full_descriptor_parity(controller, "in-place patch edit")
	await _release_fixture(fixture)


func _test_retained_coordinator_abort_recovery_keeps_chunk_roots() -> void:
	var fixture: Dictionary = _make_fixture("CoordinatorAbortRecoveryFixture")
	if fixture.is_empty():
		return
	var controller: Node3D = fixture["controller"]
	var holder: Node3D = fixture["holder"]
	var manager: FaultInjectingColliderManager = fixture["manager"] as FaultInjectingColliderManager
	var a: Dictionary = await _make_chunk(holder, "RecoveryA", Vector3(0.0, 0.0, 0.0), 0)
	var b: Dictionary = await _make_chunk(holder, "RecoveryB", Vector3(2.0, 0.0, 0.0), 1)
	var d: Dictionary = await _make_chunk(holder, "RecoveryD", Vector3(20.0, 0.0, 0.0), 0)
	var e: Dictionary = await _make_chunk(holder, "RecoveryE", Vector3(22.0, 0.0, 0.0), 1)
	_expect(bool(controller.call("load_chunk", "recovery_a", a["root"], 300)), "recovery fixture loads A")
	_expect(bool(controller.call("load_chunk", "recovery_b", b["root"], 300)), "recovery fixture loads B")
	_expect(bool(controller.call("load_chunk", "recovery_d", d["root"], 300)), "recovery fixture loads D")
	_expect(bool(controller.call("load_chunk", "recovery_e", e["root"], 300)), "recovery fixture loads E")
	var f: Dictionary = await _make_chunk(holder, "RecoveryF", Vector3(24.0, 0.0, 0.0), 0)
	manager.fail_commit_once = true
	manager.abort_failures_remaining = 1
	_expect(bool(controller.call("begin_terrain_adjacency_batch")), "fault-injected window delta begins")
	_expect(bool(controller.call("unload_chunk", "recovery_d", 301)), "old D root is held pending the transaction")
	_expect(bool(controller.call("load_chunk", "recovery_f", f["root"], 301)), "replacement F root is staged")
	var failed_commit: Dictionary = controller.call("end_terrain_adjacency_batch")
	_expect(not bool(failed_commit.get("ok", true)), "injected Collider commit and Abort failures reject the batch")
	_expect(bool(controller.call("has_pending_terrain_adjacency_recovery")), "Controller exposes retained Coordinator recovery")
	_expect(controller.get("_pending_chunk_unloads").has("recovery_d"), "old D retirement remains pending while Collider Abort is incomplete")
	_expect(d["root"].get_parent() == controller and not d["root"].is_queued_for_deletion(), "old D root remains attached and alive during recovery")
	_expect(controller.call("get_terrain_transition_descriptors").size() == 2, "published candidate Index does not overwrite the last finalized descriptor snapshot")

	var recovered: Dictionary = controller.call("retry_terrain_adjacency_recovery")
	_expect(bool(recovered.get("ok", false)) and bool(recovered.get("rolled_back", false)), "retry aborts the staged Collider, rolls back Patch/Index, and reconciles the live root set")
	_expect(not bool(controller.call("has_pending_terrain_adjacency_recovery")), "successful retry clears Controller recovery state")
	_expect(controller.get("_pending_chunk_unloads").is_empty(), "rollback recovery restores the pending D retirement")
	_expect(controller.is_chunk_loaded("recovery_d") and d["root"].get_parent() == controller, "old D root remains live after the failed window delta is rolled back")
	_expect(controller.is_chunk_loaded("recovery_f") and f["root"].get_parent() == controller, "new F root remains live for the Director's next reconciliation")
	_expect(int(controller.call("get_terrain_adjacency_index_patch_count")) == 5, "full recovery reconcile indexes all five currently live Patches")
	_expect(controller.call("get_terrain_transition_descriptors").size() == 3, "full recovery reconcile restores D/E and includes the still-live E/F edge")
	_expect(int(controller.call("get_terrain_transition_collider_count")) == 3, "recovery rebind leaves all three live transition collider bodies")
	_assert_full_descriptor_parity(controller, "Coordinator Abort recovery")
	await _release_fixture(fixture)


func _make_fixture(holder_name: String) -> Dictionary:
	var holder := Node3D.new()
	holder.name = holder_name
	root.add_child(holder)
	var controller: Node3D = ControllerScript.new()
	controller.name = "MineralChunkController"
	holder.add_child(controller)
	var registry: Node = VeinRegistryScript.new()
	registry.name = "MineralVeinRegistry"
	controller.add_child(registry)
	var object_registry: Node = WorldObjectRegistryScript.new()
	object_registry.name = "WorldObjectStateRegistry"
	controller.add_child(object_registry)
	var manager: FaultInjectingColliderManager = FaultInjectingColliderManager.new()
	manager.name = "FaultInjectingTransitionManager"
	controller.add_child(manager)
	controller.set("_terrain_transition_collider_manager", manager)
	_expect(bool(controller.call("bind_registry", registry)), holder_name + " binds the real MineralVeinRegistry")
	_expect(bool(controller.call("bind_object_state_registry", object_registry)), holder_name + " binds the real WorldObjectStateRegistry")
	return {"holder": holder, "controller": controller, "manager": manager}


func _make_chunk(holder: Node3D, chunk_name: String, patch_position: Vector3, height_level: int) -> Dictionary:
	var chunk_root := Node3D.new()
	chunk_root.name = chunk_name
	var patch: Node3D = PatchScript.new()
	patch.name = "Terrain"
	patch.position = patch_position
	chunk_root.add_child(patch)
	holder.add_child(chunk_root)
	await process_frame
	if height_level > 0:
		_expect(bool(patch.call("apply_world_object_state", {
			"height_level": height_level,
			"surface_type": "soil",
			"revision": height_level
		})), chunk_name + " receives its initial terrain height")
	holder.remove_child(chunk_root)
	return {"root": chunk_root, "patch": patch}


func _stable_id_for_chunk(controller: Node3D, chunk_id: String) -> String:
	var objects_by_chunk: Dictionary = controller.get("_chunk_objects")
	var objects: Dictionary = objects_by_chunk.get(chunk_id, {})
	for stable_id_value in objects.keys():
		var node: Node = objects[stable_id_value] as Node
		if is_instance_valid(node) and node.has_method("bind_neighbor_patch"):
			return str(stable_id_value)
	return ""


func _edge_key_for_pair(descriptors: Dictionary, first_id: String, second_id: String) -> String:
	for edge_key_value in descriptors.keys():
		var descriptor: Dictionary = descriptors[edge_key_value]
		var descriptor_first: String = str(descriptor.get("first_stable_id", ""))
		var descriptor_second: String = str(descriptor.get("second_stable_id", ""))
		if (descriptor_first == first_id and descriptor_second == second_id) or (descriptor_first == second_id and descriptor_second == first_id):
			return str(edge_key_value)
	return ""


func _assert_full_descriptor_parity(controller: Node3D, label: String) -> void:
	var objects_by_chunk: Dictionary = controller.get("_chunk_objects")
	var patches: Array[Node3D] = []
	var stable_ids_by_instance: Dictionary = {}
	for chunk_objects_value in objects_by_chunk.values():
		var objects: Dictionary = chunk_objects_value
		for stable_id_value in objects.keys():
			var patch: Node3D = objects[stable_id_value] as Node3D
			if is_instance_valid(patch) and patch.is_inside_tree() and patch.has_method("bind_neighbor_patch"):
				patches.append(patch)
				stable_ids_by_instance[patch.get_instance_id()] = str(stable_id_value)
	var oracle = IndexScript.new()
	var rebuilt: Dictionary = oracle.call("rebuild", patches, stable_ids_by_instance)
	_expect(bool(rebuilt.get("ok", false)), label + " full Index rebuild oracle succeeds")
	if bool(rebuilt.get("ok", false)):
		_expect(oracle.call("get_edge_descriptors") == controller.call("get_terrain_transition_descriptors"), label + " incremental descriptors equal the full rebuild oracle")
	var pure: Dictionary = BinderScript.build_candidate_descriptors(patches, stable_ids_by_instance)
	_expect(bool(pure.get("ok", false)), label + " non-mutating Binder candidate builder succeeds")
	if bool(pure.get("ok", false)):
		_expect(pure.get("descriptors", {}) == controller.call("get_terrain_transition_descriptors"), label + " descriptors equal the pure Binder candidate result")


func _release_fixture(fixture: Dictionary) -> void:
	var holder: Node3D = fixture.get("holder") as Node3D
	if is_instance_valid(holder):
		holder.queue_free()
	await process_frame
	await process_frame


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

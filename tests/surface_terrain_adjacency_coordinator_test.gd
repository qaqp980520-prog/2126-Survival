extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const IndexScript = preload("res://systems/SurfaceTerrainAdjacencyIndex.gd")
const ScopedTransactionScript = preload("res://systems/SurfaceTerrainAdjacencyScopedTransaction.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")
const CoordinatorScript = preload("res://systems/SurfaceTerrainAdjacencyCoordinator.gd")

class FaultInjectingPatch extends SurfaceTerrainPatch:
	var end_batch_failures_remaining: int = 0

	func end_collision_segmentation_batch() -> bool:
		if end_batch_failures_remaining > 0:
			end_batch_failures_remaining -= 1
			return false
		return super.end_collision_segmentation_batch()


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

	func has_test_pending_transaction() -> bool:
		return not _pending_sync_transaction.is_empty()


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_successful_three_participant_publish()
	await _test_profiled_execution_reports_non_overlapping_phases()
	await _test_stale_batch_snapshot_generation_is_rejected()
	await _test_collider_commit_failure_rolls_back_all_participants()
	await _test_collider_abort_failure_retains_all_participants_for_retry()
	await _test_finalize_retry_keeps_published_generation_reserved()
	await _test_index_only_delta_skips_patch_and_collider_participants()
	if failures.is_empty():
		print("Surface terrain adjacency coordinator transaction tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(1)


func _test_successful_three_participant_publish() -> void:
	var fixture: Dictionary = await _make_fixture(false, false)
	if fixture.is_empty():
		return
	var holder: Node3D = fixture["holder"]
	var replacement: Node3D = _new_patch(holder, "ReplacementB", Vector3(2.0, 0.0, 0.0), 1)
	await process_frame
	var result: Dictionary = fixture["coordinator"].execute_delta(
		["patch/b"],
		[{"stable_id": "patch/b", "patch": replacement}]
	)
	_expect(bool(result.get("ok", false)) and bool(result.get("finalized", false)), "coordinator publishes and finalizes Index, scoped Patch state, and Collider resources")
	_expect(not result.has("coordinator_profile_usec"), "Coordinator phase profiling remains opt-in by default")
	_expect(fixture["index"].call("get_patch", "patch/b") == replacement, "Index commits the replacement Patch instance")
	_expect(fixture["a"].call("get_bound_neighbor_patch", "east") == replacement, "scoped Patch state points the original neighbor at the replacement")
	_expect(replacement.call("get_bound_neighbor_patch", "west") == fixture["a"], "replacement Patch holds the reciprocal neighbor")
	_expect(fixture["b"].call("get_bound_neighbor_patch", "west") == null, "retired Patch has no remaining reciprocal neighbor")
	_expect(int(fixture["manager"].call("get_transition_count")) == 0, "partial Collider commit retires the now-unneeded transition edge")
	_expect(not bool(fixture["index"].call("get_corner_graph_stats").get("generation_reserved", true)), "successful coordinator finalization releases the Index generation")
	_expect(not bool(fixture["coordinator"].call("has_pending_transaction")), "successful coordinator transaction leaves no pending recovery")
	await process_frame
	await process_frame
	_expect(not is_instance_valid(fixture["old_body"]), "old Collider body is released only after the transaction succeeds")
	await _release_fixture(fixture)


func _test_profiled_execution_reports_non_overlapping_phases() -> void:
	var fixture: Dictionary = await _make_fixture(false, false)
	if fixture.is_empty():
		return
	var holder: Node3D = fixture["holder"]
	var replacement: Node3D = _new_patch(holder, "ReplacementBProfiled", Vector3(2.0, 0.0, 0.0), 1)
	await process_frame
	var snapshot_result: Dictionary = fixture["index"].call("get_patches_by_stable_id")
	var snapshot_generation: int = int(fixture["index"].call("get_generation"))
	var result: Dictionary = fixture["coordinator"].execute_delta(
		["patch/b"],
		[{"stable_id": "patch/b", "patch": replacement}],
		true,
		snapshot_result.get("patches_by_stable_id", {}),
		snapshot_generation
	)
	_expect(bool(result.get("ok", false)) and bool(result.get("finalized", false)), "profiled Coordinator transaction still finalizes all three participants")
	var profile: Dictionary = result.get("coordinator_profile_usec", {})
	var phase_keys: Array[String] = [
		"plan_delta_usec",
		"index_reservation_usec",
		"candidate_patch_map_usec",
		"candidate_descriptor_snapshot_usec",
		"collider_prepare_usec",
		"scoped_prepare_usec",
		"scoped_apply_usec",
		"collider_accept_usec",
		"index_publish_usec",
		"collider_commit_usec",
		"scoped_finalize_usec",
		"index_finalize_usec"
	]
	var measured_usec: int = 0
	var all_phases_valid: bool = true
	for key in phase_keys:
		if not profile.has(key) or int(profile.get(key, -1)) < 0:
			all_phases_valid = false
			continue
		measured_usec += int(profile.get(key, 0))
	_expect(all_phases_valid, "profiled Coordinator reports every non-negative transaction phase")
	var total_usec: int = int(profile.get("total_usec", -1))
	var unattributed_usec: int = int(profile.get("unattributed_usec", -1))
	_expect(total_usec > 0, "profiled Coordinator reports a positive total duration")
	_expect(measured_usec <= total_usec, "Coordinator phase timings do not overlap the measured total")
	_expect(unattributed_usec == total_usec - measured_usec, "Coordinator reports the exact unattributed timing remainder")
	_expect(int(profile.get("candidate_patch_map_usec", -1)) >= 0 and int(profile.get("candidate_descriptor_snapshot_usec", -1)) >= 0, "candidate snapshot materialization is measured separately")
	await _release_fixture(fixture)


func _test_stale_batch_snapshot_generation_is_rejected() -> void:
	var fixture: Dictionary = await _make_fixture(false, false)
	if fixture.is_empty():
		return
	var holder: Node3D = fixture["holder"]
	var replacement: Node3D = _new_patch(holder, "ReplacementBStaleSnapshot", Vector3(2.0, 0.0, 0.0), 1)
	await process_frame
	var snapshot_result: Dictionary = fixture["index"].call("get_patches_by_stable_id")
	_expect(bool(snapshot_result.get("ok", false)), "test captures a valid detached pre-delta Index snapshot")
	var snapshot_generation: int = int(fixture["index"].call("get_generation"))
	var result: Dictionary = fixture["coordinator"].execute_delta(
		["patch/b"],
		[{"stable_id": "patch/b", "patch": replacement}],
		false,
		snapshot_result.get("patches_by_stable_id", {}),
		snapshot_generation - 1
	)
	_expect(not bool(result.get("ok", true)), "Coordinator rejects a stale batch snapshot before reserving or publishing")
	_expect(str(result.get("error", "")) == "batch_index_snapshot_generation_mismatch", "stale snapshot rejection reports the generation mismatch")
	_expect(fixture["index"].call("get_patch", "patch/b") == fixture["b"], "stale snapshot rejection preserves the original Index mapping")
	_expect(fixture["a"].call("get_bound_neighbor_patch", "east") == fixture["b"], "stale snapshot rejection leaves live Patch adjacency unchanged")
	_expect(fixture["manager"].call("get_transition_body", fixture["edge_key"]) == fixture["old_body"], "stale snapshot rejection preserves the existing Collider body")
	_expect(not bool(fixture["index"].call("get_corner_graph_stats").get("generation_reserved", true)), "stale snapshot rejection leaves no Index generation reservation")
	_expect(not bool(fixture["coordinator"].call("has_pending_transaction")), "stale snapshot rejection leaves no pending Coordinator recovery")
	await _release_fixture(fixture)


func _test_collider_commit_failure_rolls_back_all_participants() -> void:
	var fixture: Dictionary = await _make_fixture(true, false)
	if fixture.is_empty():
		return
	var holder: Node3D = fixture["holder"]
	var replacement: Node3D = _new_patch(holder, "ReplacementBFailure", Vector3(2.0, 0.0, 0.0), 2)
	await process_frame
	fixture["manager"].fail_commit_once = true
	var generation_before: int = int(fixture["index"].call("get_generation"))
	var result: Dictionary = fixture["coordinator"].execute_delta(
		["patch/b"],
		[{"stable_id": "patch/b", "patch": replacement}]
	)
	_expect(not bool(result.get("ok", true)), "injected Collider commit failure rejects the coordinated transaction")
	_expect(str(result.get("error", "")).begins_with("collider_commit_failed:"), "coordinator reports the failing participant")
	_expect(fixture["index"].call("get_patch", "patch/b") == fixture["b"], "Index rollback restores the exact old Patch mapping")
	_expect(fixture["a"].call("get_bound_neighbor_patch", "east") == fixture["b"], "scoped rollback restores the exact old first neighbor")
	_expect(fixture["b"].call("get_bound_neighbor_patch", "west") == fixture["a"], "scoped rollback restores the exact old reciprocal neighbor")
	_expect(replacement.call("get_bound_neighbor_patch", "west") == null, "failed replacement is left unbound")
	_expect(fixture["manager"].call("get_transition_body", fixture["edge_key"]) == fixture["old_body"], "failed Collider commit retains the exact previously committed body")
	_expect(is_instance_valid(fixture["old_body"]) and fixture["old_body"].collision_layer == 1, "old Collider body remains active after rollback")
	_expect(int(fixture["index"].call("get_generation")) == generation_before + 2, "publish plus rollback advances the Index generation monotonically")
	_expect(not bool(fixture["index"].call("get_corner_graph_stats").get("generation_reserved", true)), "successful rollback releases the Index generation reservation")
	_expect(not bool(fixture["coordinator"].call("has_pending_transaction")), "successful three-participant rollback clears coordinator pending state")
	await _release_fixture(fixture)


func _test_collider_abort_failure_retains_all_participants_for_retry() -> void:
	var fixture: Dictionary = await _make_fixture(true, false)
	if fixture.is_empty():
		return
	var holder: Node3D = fixture["holder"]
	var manager: FaultInjectingColliderManager = fixture["manager"] as FaultInjectingColliderManager
	var replacement: Node3D = _new_patch(holder, "ReplacementBAbortFailure", Vector3(2.0, 0.0, 0.0), 2)
	await process_frame
	manager.fail_commit_once = true
	manager.abort_failures_remaining = 2
	var generation_before: int = int(fixture["index"].call("get_generation"))
	var result: Dictionary = fixture["coordinator"].execute_delta(
		["patch/b"],
		[{"stable_id": "patch/b", "patch": replacement}]
	)
	_expect(not bool(result.get("ok", true)), "injected Collider commit failure is rejected when cleanup is also failing")
	_expect(str(result.get("error", "")) == "collider_abort_pending", "coordinator reports the retained Collider abort phase")
	_expect(bool(result.get("pending_retained", false)) and bool(fixture["coordinator"].call("has_pending_transaction")), "coordinator retains all participant snapshots while Collider abort is incomplete")
	_expect(manager.has_test_pending_transaction(), "staged Collider resources remain owned by the pending manager transaction")
	_expect(fixture["index"].call("get_patch", "patch/b") == replacement, "published Index remains on the candidate while Collider cleanup is pending")
	_expect(fixture["a"].call("get_bound_neighbor_patch", "east") == replacement, "scoped Patch state remains on the candidate while Collider cleanup is pending")
	_expect(is_instance_valid(fixture["old_body"]) and fixture["manager"].call("get_transition_body", fixture["edge_key"]) == fixture["old_body"], "previously committed Collider body remains active during abort retry")

	var first_retry: Dictionary = fixture["coordinator"].call("retry_pending")
	_expect(not bool(first_retry.get("ok", true)) and str(first_retry.get("error", "")) == "collider_abort_still_pending", "failed abort retry does not advance to Patch or Index rollback")
	_expect(bool(fixture["coordinator"].call("has_pending_transaction")) and manager.has_test_pending_transaction(), "coordinator and Collider manager both retain pending ownership after the first retry")
	_expect(fixture["index"].call("get_patch", "patch/b") == replacement, "Index remains published until staged Collider resources are actually aborted")
	_expect(fixture["a"].call("get_bound_neighbor_patch", "east") == replacement, "Patch neighbor state is not rolled back ahead of Collider cleanup")

	var second_retry: Dictionary = fixture["coordinator"].call("retry_pending")
	_expect(bool(second_retry.get("ok", false)) and bool(second_retry.get("rolled_back", false)), "second abort retry completes Collider cleanup before rolling back other participants")
	_expect(not manager.has_test_pending_transaction(), "successful retry clears the staged Collider transaction")
	_expect(fixture["index"].call("get_patch", "patch/b") == fixture["b"], "Index rollback restores the exact original Patch instance")
	_expect(fixture["a"].call("get_bound_neighbor_patch", "east") == fixture["b"], "Patch rollback restores the exact original neighbor instance")
	_expect(replacement.call("get_bound_neighbor_patch", "west") == null, "candidate replacement is left unbound after recovery")
	_expect(fixture["manager"].call("get_transition_body", fixture["edge_key"]) == fixture["old_body"], "Collider rollback preserves the exact old body")
	_expect(is_instance_valid(fixture["old_body"]) and fixture["old_body"].collision_layer == 1, "old Collider body remains active after complete recovery")
	_expect(int(fixture["index"].call("get_generation")) == generation_before + 2, "Index generation remains monotonic across publish and rollback")
	_expect(not bool(fixture["index"].call("get_corner_graph_stats").get("generation_reserved", true)), "successful recovery releases the Index reservation")
	_expect(not bool(fixture["coordinator"].call("has_pending_transaction")), "successful recovery clears coordinator pending state")
	await _release_fixture(fixture)


func _test_finalize_retry_keeps_published_generation_reserved() -> void:
	var fixture: Dictionary = await _make_fixture(false, true)
	if fixture.is_empty():
		return
	var holder: Node3D = fixture["holder"]
	var fault_patch: FaultInjectingPatch = fixture["a"] as FaultInjectingPatch
	fault_patch.end_batch_failures_remaining = 1
	var replacement: Node3D = _new_patch(holder, "ReplacementBFinalize", Vector3(2.0, 0.0, 0.0), 1)
	await process_frame
	var result: Dictionary = fixture["coordinator"].execute_delta(
		["patch/b"],
		[{"stable_id": "patch/b", "patch": replacement}]
	)
	_expect(not bool(result.get("ok", true)) and str(result.get("error", "")) == "scoped_finalize_pending", "transient Patch batch-close failure retains the coordinated transaction")
	_expect(bool(fixture["coordinator"].call("has_pending_transaction")), "coordinator retains the Finalize retry state")
	_expect(fixture["index"].call("get_patch", "patch/b") == replacement, "Index remains published while Patch Finalize is pending")
	_expect(bool(fixture["index"].call("get_corner_graph_stats").get("generation_reserved", false)), "Index generation remains reserved until Patch Finalize succeeds")
	_expect(int(fixture["manager"].call("get_transition_count")) == 0, "Collider participant is not recommitted during Finalize recovery")
	var retried: Dictionary = fixture["coordinator"].call("retry_pending")
	_expect(bool(retried.get("ok", false)) and bool(retried.get("finalized", false)), "Finalize retry completes without repeating Collider commit")
	_expect(not bool(fixture["coordinator"].call("has_pending_transaction")), "successful Finalize retry clears coordinator state")
	_expect(not bool(fixture["index"].call("get_corner_graph_stats").get("generation_reserved", true)), "successful Finalize retry releases Index reservation")
	_expect(fixture["a"].call("get_bound_neighbor_patch", "east") == replacement, "Finalize retry keeps the committed replacement neighbor")
	await _release_fixture(fixture)


func _test_index_only_delta_skips_patch_and_collider_participants() -> void:
	var fixture: Dictionary = await _make_fixture(false, false)
	if fixture.is_empty():
		return
	var isolated: Node3D = _new_patch(fixture["holder"], "IsolatedPatch", Vector3(100.0, 0.0, 0.0), 0)
	await process_frame
	var original_transition_count: int = int(fixture["manager"].call("get_transition_count"))
	var result: Dictionary = fixture["coordinator"].execute_delta(
		[],
		[{"stable_id": "patch/isolated", "patch": isolated}]
	)
	_expect(bool(result.get("ok", false)) and bool(result.get("finalized", false)) and bool(result.get("index_only", false)), "isolated Patch addition commits through the Index-only path")
	_expect(fixture["index"].call("get_patch", "patch/isolated") == isolated, "Index-only path publishes the isolated Patch")
	_expect(int(fixture["manager"].call("get_transition_count")) == original_transition_count, "Index-only path leaves existing Collider resources untouched")
	_expect(fixture["a"].call("get_bound_neighbor_patch", "east") == fixture["b"], "Index-only path leaves existing Patch neighbor state untouched")
	await _release_fixture(fixture)


func _make_fixture(use_fault_manager: bool, use_fault_patch: bool) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "TerrainAdjacencyCoordinatorFixture"
	root.add_child(holder)
	var a: Node3D
	if use_fault_patch:
		a = FaultInjectingPatch.new()
	else:
		a = PatchScript.new()
	a.name = "PatchA"
	a.position = Vector3.ZERO
	holder.add_child(a)
	var b: Node3D = _new_patch(holder, "PatchB", Vector3(2.0, 0.0, 0.0), 0)
	if not _set_height(a, 1):
		holder.queue_free()
		return {}
	await process_frame
	await physics_frame

	var patches: Array[Node3D] = [a, b]
	var instance_ids: Dictionary = {
		a.get_instance_id(): "patch/a",
		b.get_instance_id(): "patch/b"
	}
	var binding: Dictionary = BinderScript.bind_patches(patches, instance_ids)
	_expect(bool(binding.get("ok", false)), "coordinator fixture Binder creates the initial reciprocal edge")
	if not bool(binding.get("ok", false)):
		holder.queue_free()
		return {}
	var patches_by_stable_id: Dictionary = {"patch/a": a, "patch/b": b}
	var manager: Node
	if use_fault_manager:
		manager = FaultInjectingColliderManager.new()
	else:
		manager = ManagerScript.new()
	holder.add_child(manager)
	var initial_sync: Dictionary = manager.call("sync_transitions", binding.get("descriptors", {}), patches_by_stable_id)
	_expect(bool(initial_sync.get("ok", false)), "coordinator fixture creates the initial committed Collider resource")
	if not bool(initial_sync.get("ok", false)):
		holder.queue_free()
		return {}
	var edge_key: String = str(binding.get("descriptors", {}).keys()[0])
	var old_body: StaticBody3D = manager.call("get_transition_body", edge_key) as StaticBody3D
	var index = IndexScript.new()
	var index_rebuild: Dictionary = index.rebuild(patches, instance_ids)
	_expect(bool(index_rebuild.get("ok", false)), "coordinator fixture builds the committed adjacency Index")
	if not bool(index_rebuild.get("ok", false)):
		holder.queue_free()
		return {}
	var scoped = ScopedTransactionScript.new()
	var coordinator = CoordinatorScript.new()
	_expect(bool(coordinator.bind_participants(index, scoped, manager)), "coordinator binds all three transaction participants")
	return {
		"holder": holder,
		"a": a,
		"b": b,
		"manager": manager,
		"index": index,
		"scoped": scoped,
		"coordinator": coordinator,
		"edge_key": edge_key,
		"old_body": old_body
	}


func _new_patch(holder: Node3D, patch_name: String, patch_position: Vector3, height_level: int) -> Node3D:
	var patch: Node3D = PatchScript.new()
	patch.name = patch_name
	patch.position = patch_position
	holder.add_child(patch)
	_set_height(patch, height_level)
	return patch


func _set_height(patch: Node3D, height_level: int) -> bool:
	var state_value: Variant = patch.call("get_world_object_state")
	if not (state_value is Dictionary):
		return false
	var state: Dictionary = state_value
	state["height_level"] = height_level
	state["revision"] = int(state.get("revision", 0)) + 1
	return bool(patch.call("apply_world_object_state", state))


func _release_fixture(fixture: Dictionary) -> void:
	var holder: Node3D = fixture.get("holder") as Node3D
	if is_instance_valid(holder):
		holder.queue_free()
	await process_frame
	await process_frame


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

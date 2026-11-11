extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const IndexScript = preload("res://systems/SurfaceTerrainAdjacencyIndex.gd")
const CornerResolverScript = preload("res://systems/SurfaceTerrainCornerConflictResolver.gd")
const AffectedComponentPlannerScript = preload("res://systems/SurfaceTerrainAffectedComponentPlanner.gd")

class AlternateSizePatch:
	extends Node3D

	var configured_patch_size: float = 3.0

	func get_edge_ramp_profile() -> Dictionary:
		return {"patch_size": configured_patch_size}

	func get_world_object_state() -> Dictionary:
		return {"height_level": 0, "surface_type": "soil", "revision": 0}

	func validate_world_object_state(state: Dictionary) -> bool:
		return (
			state.size() == 3
			and state.get("height_level") is int
			and state.get("surface_type") is String
			and state.get("revision") is int
		)


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var holder := Node3D.new()
	holder.name = "TerrainAdjacencyIndexTestRoot"
	root.add_child(holder)

	# The west/east pair crosses a negative-coordinate spatial-bucket boundary.
	var west: Node3D = _new_patch(holder, "West", Vector3(-4.0, 0.0, -2.0))
	var center: Node3D = _new_patch(holder, "Center", Vector3(-1.995, 0.0, -2.0))
	var south: Node3D = _new_patch(holder, "South", Vector3(-1.995, 0.0, 0.0))
	var far: Node3D = _new_patch(holder, "Far", Vector3(20.0, 0.0, 0.0))
	await process_frame

	var stable_ids: Dictionary = {
		west.get_instance_id(): "terrain/west",
		center.get_instance_id(): "terrain/center",
		south.get_instance_id(): "terrain/south",
		far.get_instance_id(): "terrain/far"
	}
	var index = IndexScript.new()
	var initial: Dictionary = index.rebuild([west, center, south, far], stable_ids)
	_expect(bool(initial.get("ok", false)), "rebuild accepts a valid live patch set")
	_expect(int(initial.get("patch_count", -1)) == 4, "rebuild records all four Stable IDs")
	_expect(int(initial.get("edge_count", -1)) == 2, "rebuild derives the two cardinal edge descriptors")
	_expect(index.get_patch("terrain/center") == center, "Stable ID lookup returns the original patch instance")
	_expect(index.get_neighbors("terrain/center") == ["terrain/south", "terrain/west"], "negative-coordinate bucket lookup finds both cardinal neighbors")
	_expect(index.get_edge_descriptors().size() == 2, "full descriptor query matches the rebuilt edge count")
	_assert_matches_full_rebuild_oracle(index, [west, center, south, far], stable_ids, "initial rebuild")

	var initial_generation: int = index.get_generation()
	var duplicate: Node3D = _new_patch(holder, "Duplicate", center.position)
	await process_frame
	var duplicate_plan: Dictionary = index.plan_delta([], [
		{"stable_id": "terrain/duplicate", "patch": duplicate}
	])
	_expect(not bool(duplicate_plan.get("ok", true)) and str(duplicate_plan.get("error", "")) == "duplicate_position", "delta preflight rejects a duplicate position across adjacent negative buckets")
	_expect(index.get_generation() == initial_generation, "rejected duplicate-position plan leaves the committed generation unchanged")
	_expect(index.get_patch("terrain/center") == center, "rejected plan preserves the committed patch instance")
	duplicate.queue_free()
	await process_frame

	var existing_instance_plan: Dictionary = index.plan_delta([], [
		{"stable_id": "terrain/duplicate_existing_instance", "patch": west}
	])
	_expect(not bool(existing_instance_plan.get("ok", true)) and str(existing_instance_plan.get("error", "")) == "duplicate_instance", "delta preflight rejects an existing Patch Node reused under a second Stable ID")
	var duplicate_addition: Node3D = _new_patch(holder, "DuplicateAdditionInstance", Vector3(100.0, 0.0, 100.0))
	await process_frame
	var duplicate_addition_plan: Dictionary = index.plan_delta([], [
		{"stable_id": "terrain/duplicate_addition_a", "patch": duplicate_addition},
		{"stable_id": "terrain/duplicate_addition_b", "patch": duplicate_addition}
	])
	_expect(not bool(duplicate_addition_plan.get("ok", true)) and str(duplicate_addition_plan.get("error", "")) == "duplicate_instance", "delta preflight rejects one Node repeated within the same additions batch")
	duplicate_addition.queue_free()
	await process_frame

	var same_instance_plan: Dictionary = index.plan_delta(
		["terrain/far"],
		[{"stable_id": "terrain/far", "patch": far}]
	)
	_expect(bool(same_instance_plan.get("ok", false)), "remove-and-readd of the same Node remains valid after post-removal instance-set construction")
	if bool(same_instance_plan.get("ok", false)):
		var same_instance_summary: Dictionary = same_instance_plan.get("summary", {})
		_expect(bool(index.commit_delta(str(same_instance_summary.get("plan_id", ""))).get("ok", false)), "same-Node replacement commits without changing its Stable ID")

	var replacement: Node3D = _new_patch(holder, "ReplacementCenter", center.position)
	await process_frame
	var replacement_plan: Dictionary = index.plan_delta(
		["terrain/center"],
		[{"stable_id": "terrain/center", "patch": replacement}]
	)
	_expect(bool(replacement_plan.get("ok", false)), "remove-and-readd of the same Stable ID is accepted")
	if bool(replacement_plan.get("ok", false)):
		var summary: Dictionary = replacement_plan.get("summary", {})
		_expect(summary.get("removed_stable_ids", []) == ["terrain/center"], "replacement plan records the removed Stable ID")
		_expect(summary.get("added_stable_ids", []) == ["terrain/center"], "replacement plan records the re-added Stable ID")
		var replacement_edges: Array = summary.get("affected_edge_keys", [])
		var old_descriptors: Dictionary = summary.get("old_descriptors", {})
		var new_descriptors: Dictionary = summary.get("new_descriptors", {})
		_expect(replacement_edges.size() == 2, "replacement plan scopes both incident edge keys")
		_expect(old_descriptors.size() == 2, "replacement plan snapshots both old incident descriptors")
		_expect(new_descriptors.size() == 2, "replacement plan derives both new incident descriptors")
		var replacement_commit: Dictionary = index.commit_delta(str(summary.get("plan_id", "")))
		_expect(bool(replacement_commit.get("ok", false)), "replacement delta commits after its Node snapshot remains unchanged")
	_expect(index.get_patch("terrain/center") == replacement, "committed replacement points to the new patch instance")
	_expect(index.get_neighbors("terrain/center") == ["terrain/south", "terrain/west"], "replacement preserves the same cardinal neighborhood")
	var old_center_ref: WeakRef = weakref(center)
	center.queue_free()
	await process_frame
	_expect(old_center_ref.get_ref() == null, "WeakRef resolves null after the replaced Node is freed")
	var current_patches: Array[Node3D] = [west, replacement, south, far]
	var current_ids: Dictionary = {
		west.get_instance_id(): "terrain/west",
		replacement.get_instance_id(): "terrain/center",
		south.get_instance_id(): "terrain/south",
		far.get_instance_id(): "terrain/far"
	}
	_assert_matches_full_rebuild_oracle(index, current_patches, current_ids, "same-Stable-ID replacement")

	var east: Node3D = _new_patch(holder, "East", Vector3(0.005, 0.0, -2.0))
	await process_frame
	var east_plan: Dictionary = index.plan_delta([], [
		{"stable_id": "terrain/east", "patch": east}
	])
	_expect(bool(east_plan.get("ok", false)), "adding one adjacent patch creates a valid delta")
	if bool(east_plan.get("ok", false)):
		var east_summary: Dictionary = east_plan.get("summary", {})
		var east_added_edges: Array = east_summary.get("added_edge_keys", [])
		var east_affected_edges: Array = east_summary.get("affected_edge_keys", [])
		_expect(east_added_edges.size() == 1, "one-patch addition stages exactly one new cardinal edge")
		_expect(east_affected_edges.size() == 1, "one-patch addition does not mark unrelated edges as affected")
		var east_commit: Dictionary = index.commit_delta(str(east_summary.get("plan_id", "")))
		_expect(bool(east_commit.get("ok", false)), "one-patch addition commits")
	_expect(index.get_neighbors("terrain/center") == ["terrain/east", "terrain/south", "terrain/west"], "committed index returns all three center neighbors")
	current_patches.append(east)
	current_ids[east.get_instance_id()] = "terrain/east"
	_assert_matches_full_rebuild_oracle(index, current_patches, current_ids, "one-patch addition")

	var remove_south_plan: Dictionary = index.plan_delta(["terrain/south"], [])
	_expect(bool(remove_south_plan.get("ok", false)), "pure patch removal creates a valid delta")
	if bool(remove_south_plan.get("ok", false)):
		var remove_south_summary: Dictionary = remove_south_plan.get("summary", {})
		var removed_edge_keys: Array = remove_south_summary.get("removed_edge_keys", [])
		var removed_affected_keys: Array = remove_south_summary.get("affected_edge_keys", [])
		_expect(removed_edge_keys.size() == 1 and removed_affected_keys.size() == 1, "pure removal stages only its one incident edge retirement")
		var remove_south_commit: Dictionary = index.commit_delta(str(remove_south_summary.get("plan_id", "")))
		_expect(bool(remove_south_commit.get("ok", false)), "pure patch removal commits")
	current_patches.erase(south)
	current_ids.erase(south.get_instance_id())
	_expect(index.get_neighbors("terrain/center") == ["terrain/east", "terrain/west"], "removed patch is absent from the center neighborhood")
	_assert_matches_full_rebuild_oracle(index, current_patches, current_ids, "pure patch removal")

	var stale_a: Node3D = _new_patch(holder, "StaleA", Vector3(2.005, 0.0, -2.0))
	var stale_b: Node3D = _new_patch(holder, "StaleB", Vector3(-6.0, 0.0, -2.0))
	await process_frame
	var plan_a: Dictionary = index.plan_delta([], [{"stable_id": "terrain/stale_a", "patch": stale_a}])
	var plan_b: Dictionary = index.plan_delta([], [{"stable_id": "terrain/stale_b", "patch": stale_b}])
	_expect(bool(plan_a.get("ok", false)) and bool(plan_b.get("ok", false)), "two plans can be prepared from one committed generation")
	if bool(plan_a.get("ok", false)) and bool(plan_b.get("ok", false)):
		var summary_a: Dictionary = plan_a.get("summary", {})
		var summary_b: Dictionary = plan_b.get("summary", {})
		var commit_a: Dictionary = index.commit_delta(str(summary_a.get("plan_id", "")))
		_expect(bool(commit_a.get("ok", false)), "first same-generation plan commits")
		current_patches.append(stale_a)
		current_ids[stale_a.get_instance_id()] = "terrain/stale_a"
		_assert_matches_full_rebuild_oracle(index, current_patches, current_ids, "first same-generation commit")
		var commit_b: Dictionary = index.commit_delta(str(summary_b.get("plan_id", "")))
		_expect(not bool(commit_b.get("ok", true)) and str(commit_b.get("error", "")) == "stale_generation", "second same-generation plan is rejected as stale")
	_expect(index.get_patch("terrain/stale_b") == null, "stale plan does not leak its candidate patch into the index")
	stale_b.queue_free()
	await process_frame

	var changed_snapshot: Node3D = _new_patch(holder, "ChangedSnapshot", Vector3(4.005, 0.0, -2.0))
	await process_frame
	var snapshot_plan: Dictionary = index.plan_delta([], [
		{"stable_id": "terrain/changed_snapshot", "patch": changed_snapshot}
	])
	_expect(bool(snapshot_plan.get("ok", false)), "unchanged Node can be captured in a prepared plan")
	if bool(snapshot_plan.get("ok", false)):
		var snapshot_summary: Dictionary = snapshot_plan.get("summary", {})
		var state: Dictionary = changed_snapshot.call("get_world_object_state")
		state["height_level"] = 1
		state["revision"] = int(state.get("revision", 0)) + 1
		_expect(bool(changed_snapshot.call("apply_world_object_state", state)), "fixture state can change after planning")
		var stale_snapshot_commit: Dictionary = index.commit_delta(str(snapshot_summary.get("plan_id", "")))
		_expect(not bool(stale_snapshot_commit.get("ok", true)) and str(stale_snapshot_commit.get("error", "")) == "stale_patch_snapshot", "commit rejects a patch whose state changed after planning")
	_expect(index.get_patch("terrain/changed_snapshot") == null, "stale snapshot is not committed")
	_assert_matches_full_rebuild_oracle(index, current_patches, current_ids, "rejected stale snapshot")
	changed_snapshot.queue_free()
	await process_frame

	var freed_patch: Node3D = _new_patch(holder, "FreedBeforeCommit", Vector3(6.005, 0.0, -2.0))
	await process_frame
	var freed_plan: Dictionary = index.plan_delta([], [
		{"stable_id": "terrain/freed_before_commit", "patch": freed_patch}
	])
	_expect(bool(freed_plan.get("ok", false)), "live patch can be staged before its queued release")
	if bool(freed_plan.get("ok", false)):
		var freed_summary: Dictionary = freed_plan.get("summary", {})
		freed_patch.queue_free()
		await process_frame
		var freed_commit: Dictionary = index.commit_delta(str(freed_summary.get("plan_id", "")))
		_expect(not bool(freed_commit.get("ok", true)) and str(freed_commit.get("error", "")) == "stale_patch_reference", "commit rejects a patch released after planning")
	_expect(index.get_patch("terrain/freed_before_commit") == null, "released candidate patch is never committed")

	var abort_patch: Node3D = _new_patch(holder, "Abort", Vector3(6.005, 0.0, -2.0))
	await process_frame
	var abort_plan: Dictionary = index.plan_delta([], [
		{"stable_id": "terrain/abort", "patch": abort_patch}
	])
	_expect(bool(abort_plan.get("ok", false)), "abort fixture plan is prepared")
	if bool(abort_plan.get("ok", false)):
		var abort_summary: Dictionary = abort_plan.get("summary", {})
		var abort_id: String = str(abort_summary.get("plan_id", ""))
		_expect(index.abort_delta(abort_id), "prepared delta can be aborted")
		var after_abort: Dictionary = index.commit_delta(abort_id)
		_expect(not bool(after_abort.get("ok", true)) and str(after_abort.get("error", "")) == "unknown_plan", "aborted plan cannot later be committed")
	abort_patch.queue_free()
	await process_frame

	var unknown_remove: Dictionary = index.plan_delta(["terrain/missing"], [])
	_expect(not bool(unknown_remove.get("ok", true)) and str(unknown_remove.get("error", "")) == "unknown_remove_stable_id", "unknown removals are rejected before mutation")

	var alternate := AlternateSizePatch.new()
	alternate.name = "AlternateSize"
	alternate.position = Vector3(40.0, 0.0, 0.0)
	holder.add_child(alternate)
	await process_frame
	var mixed_size_plan: Dictionary = index.plan_delta([], [
		{"stable_id": "terrain/alternate_size", "patch": alternate}
	])
	_expect(not bool(mixed_size_plan.get("ok", true)) and str(mixed_size_plan.get("error", "")) == "mixed_patch_sizes", "delta preflight rejects a mixed patch-size candidate")
	alternate.queue_free()
	await process_frame

	var duplicate_rebuild: Node3D = _new_patch(holder, "DuplicateRebuild", west.position)
	await process_frame
	var duplicate_rebuild_ids: Dictionary = {
		west.get_instance_id(): "terrain/west",
		replacement.get_instance_id(): "terrain/center",
		south.get_instance_id(): "terrain/south",
		far.get_instance_id(): "terrain/far",
		duplicate_rebuild.get_instance_id(): "terrain/duplicate_rebuild"
	}
	var generation_before_failed_rebuild: int = index.get_generation()
	var failed_rebuild: Dictionary = index.rebuild(
		[west, replacement, south, far, duplicate_rebuild],
		duplicate_rebuild_ids
	)
	_expect(not bool(failed_rebuild.get("ok", true)) and str(failed_rebuild.get("error", "")) == "duplicate_position", "failed full rebuild rejects duplicate positions")
	_expect(index.get_generation() == generation_before_failed_rebuild, "failed full rebuild preserves the prior committed generation")
	_expect(index.get_patch("terrain/center") == replacement, "failed full rebuild preserves the prior committed index")
	_assert_matches_full_rebuild_oracle(index, current_patches, current_ids, "failed rebuild rollback")
	duplicate_rebuild.queue_free()
	await process_frame

	# A removal plan must reject a patch whose world-object snapshot changes before commit.
	var removed_snapshot_patch: Node3D = _new_patch(holder, "RemovedSnapshot", Vector3(4.005, 0.0, -2.0))
	await process_frame
	var add_removed_snapshot: Dictionary = index.plan_delta([], [
		{"stable_id": "terrain/removed_snapshot", "patch": removed_snapshot_patch}
	])
	_expect(bool(add_removed_snapshot.get("ok", false)), "removal-snapshot fixture can be staged")
	if bool(add_removed_snapshot.get("ok", false)):
		var add_removed_summary: Dictionary = add_removed_snapshot.get("summary", {})
		var add_removed_commit: Dictionary = index.commit_delta(str(add_removed_summary.get("plan_id", "")))
		_expect(bool(add_removed_commit.get("ok", false)), "removal-snapshot fixture is committed")
		current_patches.append(removed_snapshot_patch)
		current_ids[removed_snapshot_patch.get_instance_id()] = "terrain/removed_snapshot"
		_assert_matches_full_rebuild_oracle(index, current_patches, current_ids, "removal-snapshot fixture")

	var removed_snapshot_generation: int = index.get_generation()
	var stale_removed_snapshot_plan: Dictionary = index.plan_delta(["terrain/removed_snapshot"], [])
	_expect(bool(stale_removed_snapshot_plan.get("ok", false)), "pure removal plan captures the committed patch snapshot")
	if bool(stale_removed_snapshot_plan.get("ok", false)):
		var stale_removed_summary: Dictionary = stale_removed_snapshot_plan.get("summary", {})
		var original_removed_state: Dictionary = removed_snapshot_patch.call("get_world_object_state")
		var changed_removed_state: Dictionary = original_removed_state.duplicate(true)
		changed_removed_state["height_level"] = 1
		changed_removed_state["revision"] = int(changed_removed_state.get("revision", 0)) + 1
		_expect(bool(removed_snapshot_patch.call("apply_world_object_state", changed_removed_state)), "removed patch state can change after planning")
		var stale_removed_snapshot_commit: Dictionary = index.commit_delta(str(stale_removed_summary.get("plan_id", "")))
		_expect(
			not bool(stale_removed_snapshot_commit.get("ok", true))
			and str(stale_removed_snapshot_commit.get("error", "")) == "stale_patch_snapshot",
			"commit rejects a removed patch whose state changed after planning"
		)
		_expect(index.get_generation() == removed_snapshot_generation, "rejected removed-patch snapshot leaves the committed generation unchanged")
		_expect(index.get_patch("terrain/removed_snapshot") == removed_snapshot_patch, "rejected removal preserves the committed patch instance")
		_expect(bool(removed_snapshot_patch.call("apply_world_object_state", original_removed_state)), "removed patch can restore its original snapshot for oracle comparison")
		_assert_matches_full_rebuild_oracle(index, current_patches, current_ids, "rejected removed-patch snapshot")

	# An expired WeakRef on the removal side must also reject the transaction.
	var removed_freed_patch: Node3D = _new_patch(holder, "RemovedFreed", Vector3(6.005, 0.0, -2.0))
	await process_frame
	var add_removed_freed: Dictionary = index.plan_delta([], [
		{"stable_id": "terrain/removed_freed", "patch": removed_freed_patch}
	])
	_expect(bool(add_removed_freed.get("ok", false)), "removal-WeakRef fixture can be staged")
	if bool(add_removed_freed.get("ok", false)):
		var add_freed_summary: Dictionary = add_removed_freed.get("summary", {})
		var add_freed_commit: Dictionary = index.commit_delta(str(add_freed_summary.get("plan_id", "")))
		_expect(bool(add_freed_commit.get("ok", false)), "removal-WeakRef fixture is committed")
		current_patches.append(removed_freed_patch)
		current_ids[removed_freed_patch.get_instance_id()] = "terrain/removed_freed"
		_assert_matches_full_rebuild_oracle(index, current_patches, current_ids, "removal-WeakRef fixture")

	var removed_freed_instance_id: int = removed_freed_patch.get_instance_id()
	var removed_freed_generation: int = index.get_generation()
	var removed_freed_count: int = index.get_patch_count()
	var stale_removed_ref_plan: Dictionary = index.plan_delta(["terrain/removed_freed"], [])
	_expect(bool(stale_removed_ref_plan.get("ok", false)), "removal plan can be prepared before the old Node is released")
	if bool(stale_removed_ref_plan.get("ok", false)):
		var stale_removed_ref_summary: Dictionary = stale_removed_ref_plan.get("summary", {})
		current_patches.erase(removed_freed_patch)
		current_ids.erase(removed_freed_instance_id)
		removed_freed_patch.queue_free()
		await process_frame
		var stale_removed_ref_commit: Dictionary = index.commit_delta(str(stale_removed_ref_summary.get("plan_id", "")))
		_expect(
			not bool(stale_removed_ref_commit.get("ok", true))
			and str(stale_removed_ref_commit.get("error", "")) == "stale_patch_reference",
			"commit rejects a removed patch whose WeakRef expired after planning"
		)
		_expect(index.get_generation() == removed_freed_generation, "rejected removed-WeakRef plan leaves the generation unchanged")
		_expect(index.get_patch_count() == removed_freed_count, "rejected removed-WeakRef plan preserves the committed index snapshot")
		_expect(index.get_patch("terrain/removed_freed") == null, "released removed patch is observable as an expired WeakRef")
		var cleanup_rebuild: Dictionary = index.rebuild(current_patches, current_ids)
		_expect(bool(cleanup_rebuild.get("ok", false)), "full rebuild can reconcile the index after an externally released removed patch")
		_assert_matches_full_rebuild_oracle(index, current_patches, current_ids, "removed WeakRef cleanup rebuild")

	await _run_persistent_corner_graph_tests()
	await _test_patch_size_cache_after_emptying_index()

	holder.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("Surface terrain adjacency index tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)


func _test_patch_size_cache_after_emptying_index() -> void:
	var size_holder := Node3D.new()
	size_holder.name = "PatchSizeCacheAfterEmptyingTestRoot"
	root.add_child(size_holder)
	var first: AlternateSizePatch = AlternateSizePatch.new()
	first.name = "InitialSizeThree"
	first.configured_patch_size = 3.0
	size_holder.add_child(first)
	await process_frame
	var size_index = IndexScript.new()
	var rebuild: Dictionary = size_index.rebuild(
		[first],
		{first.get_instance_id(): "size/first"}
	)
	_expect(bool(rebuild.get("ok", false)), "patch-size cache fixture builds an initial single-patch Index")
	if not bool(rebuild.get("ok", false)):
		size_holder.queue_free()
		await process_frame
		return
	var remove_plan: Dictionary = size_index.plan_delta(["size/first"], [])
	_expect(bool(remove_plan.get("ok", false)), "removing the last Patch creates an empty candidate Index")
	if bool(remove_plan.get("ok", false)):
		var remove_summary: Dictionary = remove_plan.get("summary", {})
		var remove_commit: Dictionary = size_index.commit_delta(str(remove_summary.get("plan_id", "")))
		_expect(bool(remove_commit.get("ok", false)) and size_index.get_patch_count() == 0, "empty candidate Index commits and clears its patch-size invariant")
	var replacement: AlternateSizePatch = AlternateSizePatch.new()
	replacement.name = "ReplacementSizeFour"
	replacement.configured_patch_size = 4.0
	size_holder.add_child(replacement)
	await process_frame
	var replacement_plan: Dictionary = size_index.plan_delta([], [
		{"stable_id": "size/replacement", "patch": replacement}
	])
	_expect(bool(replacement_plan.get("ok", false)), "empty Index accepts a new Patch size after the previous set was removed")
	if bool(replacement_plan.get("ok", false)):
		var replacement_summary: Dictionary = replacement_plan.get("summary", {})
		_expect(bool(size_index.commit_delta(str(replacement_summary.get("plan_id", ""))).get("ok", false)), "new Patch size is committed after emptying the Index")
	_expect(size_index.get_patch("size/replacement") == replacement, "new-size Patch is the committed instance")
	var matching: AlternateSizePatch = AlternateSizePatch.new()
	matching.name = "MatchingSizeFour"
	matching.configured_patch_size = 4.0
	size_holder.add_child(matching)
	await process_frame
	var matching_plan: Dictionary = size_index.plan_delta([], [
		{"stable_id": "size/matching", "patch": matching}
	])
	_expect(bool(matching_plan.get("ok", false)), "subsequent additions use the newly committed Patch-size invariant")
	if bool(matching_plan.get("ok", false)):
		var matching_summary: Dictionary = matching_plan.get("summary", {})
		_expect(bool(size_index.commit_delta(str(matching_summary.get("plan_id", ""))).get("ok", false)), "matching Patch-size addition commits")
	var mismatched: AlternateSizePatch = AlternateSizePatch.new()
	mismatched.name = "MismatchedSizeThree"
	mismatched.configured_patch_size = 3.0
	size_holder.add_child(mismatched)
	await process_frame
	var mixed_plan: Dictionary = size_index.plan_delta([], [
		{"stable_id": "size/mismatched", "patch": mismatched}
	])
	_expect(not bool(mixed_plan.get("ok", true)) and str(mixed_plan.get("error", "")) == "mixed_patch_sizes", "cached Patch-size invariant still rejects mixed-size candidates")
	size_holder.queue_free()
	await process_frame
	await process_frame


func _run_persistent_corner_graph_tests() -> void:
	var graph_holder := Node3D.new()
	graph_holder.name = "PersistentCornerGraphTestRoot"
	root.add_child(graph_holder)

	var top_left: Node3D = _new_patch(graph_holder, "TopLeft", Vector3(0.0, 0.0, 0.0))
	var top_center: Node3D = _new_patch(graph_holder, "TopCenter", Vector3(2.0, 0.0, 0.0))
	var top_right: Node3D = _new_patch(graph_holder, "TopRight", Vector3(4.0, 0.0, 0.0))
	var bottom_left: Node3D = _new_patch(graph_holder, "BottomLeft", Vector3(0.0, 0.0, 2.0))
	var bottom_center: Node3D = _new_patch(graph_holder, "BottomCenter", Vector3(2.0, 0.0, 2.0))
	var bottom_right: Node3D = _new_patch(graph_holder, "BottomRight", Vector3(4.0, 0.0, 2.0))
	var isolated_a: Node3D = _new_patch(graph_holder, "IsolatedA", Vector3(100.0, 0.0, 0.0))
	var isolated_b: Node3D = _new_patch(graph_holder, "IsolatedB", Vector3(102.0, 0.0, 0.0))
	_expect(_set_height_level(top_left, 0), "corner graph fixture sets top-left height")
	_expect(_set_height_level(top_center, 1), "corner graph fixture sets top-center height")
	_expect(_set_height_level(top_right, 0), "corner graph fixture sets top-right height")
	_expect(_set_height_level(bottom_left, 1), "corner graph fixture sets bottom-left height")
	_expect(_set_height_level(bottom_center, 0), "corner graph fixture sets bottom-center height")
	_expect(_set_height_level(bottom_right, 1), "corner graph fixture sets bottom-right height")
	_expect(_set_height_level(isolated_a, 0), "isolated edge fixture sets first height")
	_expect(_set_height_level(isolated_b, 1), "isolated edge fixture sets second height")
	await process_frame

	var grid_patches: Array[Node3D] = [
		top_left, top_center, top_right,
		bottom_left, bottom_center, bottom_right,
		isolated_a, isolated_b
	]
	var grid_ids: Dictionary = {
		top_left.get_instance_id(): "grid/top_left",
		top_center.get_instance_id(): "grid/top_center",
		top_right.get_instance_id(): "grid/top_right",
		bottom_left.get_instance_id(): "grid/bottom_left",
		bottom_center.get_instance_id(): "grid/bottom_center",
		bottom_right.get_instance_id(): "grid/bottom_right",
		isolated_a.get_instance_id(): "grid/isolated_a",
		isolated_b.get_instance_id(): "grid/isolated_b"
	}
	var graph_index = IndexScript.new()
	var graph_rebuild: Dictionary = graph_index.rebuild(grid_patches, grid_ids)
	_expect(bool(graph_rebuild.get("ok", false)), "persistent corner graph rebuild succeeds for a checkerboard grid")
	if not bool(graph_rebuild.get("ok", false)):
		graph_holder.queue_free()
		await process_frame
		return
	_expect(int(graph_rebuild.get("edge_count", -1)) == 8, "persistent graph caches all seven grid edges plus one isolated edge")
	var graph_stats: Dictionary = graph_index.get_corner_graph_stats()
	_expect(int(graph_stats.get("report_count", -1)) == 8, "checkerboard rebuild stores eight corner reports")
	_expect(int(graph_stats.get("junction_count", -1)) == 2, "checkerboard rebuild stores two connected Junctions")

	var descriptors: Dictionary = graph_index.get_edge_descriptors()
	var initial_report_oracle: Dictionary = _build_corner_report_oracle(grid_patches, grid_ids, descriptors, graph_index.get_patch_size())
	_expect(bool(initial_report_oracle.get("ok", false)), "full resolver report oracle succeeds after initial rebuild")
	_expect(
		graph_index.get_corner_reports_by_stable_id() == initial_report_oracle.get("reports_by_stable_id", {}),
		"persistent corner report cache matches the full resolver oracle after rebuild"
	)
	var isolated_edge_key: String = ""
	var grid_seed_edge_key: String = ""
	for edge_key_value in descriptors.keys():
		var edge_key: String = str(edge_key_value)
		var descriptor: Dictionary = descriptors[edge_key]
		var first_id: String = str(descriptor.get("first_stable_id", ""))
		var second_id: String = str(descriptor.get("second_stable_id", ""))
		if first_id == "grid/isolated_a" or second_id == "grid/isolated_a":
			isolated_edge_key = edge_key
		elif grid_seed_edge_key.is_empty() and first_id.begins_with("grid/") and second_id.begins_with("grid/"):
			grid_seed_edge_key = edge_key
	var initial_closure: Dictionary = graph_index.get_corner_graph_closure([grid_seed_edge_key])
	_expect(bool(initial_closure.get("ok", false)), "persistent graph can query a committed connected closure")
	_expect(initial_closure.get("edge_keys", []).size() == 7, "two connected Junctions close over exactly seven grid edges")
	_expect(initial_closure.get("junction_keys", []).size() == 2, "two connected Junctions are both reachable from one seed")
	_expect(not initial_closure.get("edge_keys", []).has(isolated_edge_key), "unrelated isolated transition edge stays outside the closure")

	var replacement: Node3D = _new_patch(graph_holder, "ReplacementTopCenter", Vector3(2.0, 0.0, 0.0))
	_expect(_set_height_level(replacement, 0), "replacement patch changes height to remove its three transition edges")
	await process_frame
	var delta_result: Dictionary = graph_index.plan_delta(
		["grid/top_center"],
		[{"stable_id": "grid/top_center", "patch": replacement}]
	)
	_expect(bool(delta_result.get("ok", false)), "height-changing same-Stable-ID replacement plans a corner graph delta")
	if bool(delta_result.get("ok", false)):
		var summary: Dictionary = delta_result.get("summary", {})
		var closure_edges: Array = summary.get("closure_edge_keys", [])
		var closure_junctions: Array = summary.get("closure_junction_keys", [])
		var old_reports: Array = summary.get("old_closure_reports", [])
		var new_reports: Array = summary.get("new_closure_reports", [])
		_expect(closure_edges.size() == 7, "old/new union closure retains all seven edges across the two connected Junctions")
		_expect(closure_junctions.size() == 2, "old/new union closure retains both Junctions while topology changes")
		_expect(summary.get("old_closure_descriptors", {}).size() == 7, "old closure carries every old descriptor needed for retirement")
		_expect(summary.get("new_closure_descriptors", {}).size() == 7, "candidate closure carries every candidate descriptor needed for staging")
		_expect(old_reports.size() == 8, "old closure exposes all eight prior corner reports")
		_expect(new_reports.size() == 2, "candidate closure exposes only the two surviving corner reports")
		_expect(not closure_edges.has(isolated_edge_key), "delta closure does not include the unrelated isolated edge")

		var plan_id: String = str(summary.get("plan_id", ""))
		var reservation: Dictionary = graph_index.reserve_delta(plan_id)
		_expect(bool(reservation.get("ok", false)), "prepared delta reserves the committed index generation")
		var competing_patch: Node3D = _new_patch(graph_holder, "CompetingPatch", Vector3(200.0, 0.0, 0.0))
		await process_frame
		var competing_plan: Dictionary = graph_index.plan_delta([], [
			{"stable_id": "grid/competing", "patch": competing_patch}
		])
		_expect(bool(competing_plan.get("ok", false)), "a second plan may be prepared while the first generation is reserved")
		if bool(competing_plan.get("ok", false)):
			var competing_id: String = str(competing_plan.get("summary", {}).get("plan_id", ""))
			var blocked_commit: Dictionary = graph_index.commit_delta(competing_id)
			_expect(
				not bool(blocked_commit.get("ok", true))
				and str(blocked_commit.get("error", "")) == "generation_reserved",
				"generation reservation blocks another plan from publishing"
			)
			var blocked_rebuild: Dictionary = graph_index.rebuild(grid_patches, grid_ids)
			_expect(
				not bool(blocked_rebuild.get("ok", true))
				and str(blocked_rebuild.get("error", "")) == "generation_reserved",
				"full rebuild cannot invalidate a reserved cross-participant transaction"
			)
		var committed: Dictionary = graph_index.commit_delta(plan_id)
		_expect(bool(committed.get("ok", false)), "reserved delta publishes the candidate corner graph atomically with the index")
		if bool(competing_plan.get("ok", false)):
			var stale_competing: Dictionary = graph_index.commit_delta(str(competing_plan.get("summary", {}).get("plan_id", "")))
			_expect(
				not bool(stale_competing.get("ok", true))
				and str(stale_competing.get("error", "")) == "stale_generation",
				"competing plan becomes stale after the reserved generation commits"
			)
		_expect(graph_index.get_patch("grid/top_center") == replacement, "committed delta points at the replacement Patch instance")
		var committed_stats: Dictionary = graph_index.get_corner_graph_stats()
		_expect(int(committed_stats.get("report_count", -1)) == 2, "committed graph retains only the two surviving reports")
		_expect(int(committed_stats.get("junction_count", -1)) == 2, "committed graph retains the two now-disconnected Junctions")
		_expect(graph_index.get_edge_descriptors().has(isolated_edge_key), "committed local delta preserves the isolated descriptor")
		if not new_reports.is_empty():
			var first_new_report: Dictionary = new_reports[0]
			var candidate_seed: String = str(first_new_report.get("edge_keys", [""])[0])
			var candidate_closure: Dictionary = graph_index.get_corner_graph_closure([candidate_seed])
			_expect(candidate_closure.get("edge_keys", []).size() == 2, "committed graph closure is reduced to the surviving local two-edge component")
			_expect(candidate_closure.get("junction_keys", []).size() == 1, "committed graph no longer traverses the removed middle connection")

		grid_patches.erase(top_center)
		grid_ids.erase(top_center.get_instance_id())
		grid_patches.append(replacement)
		grid_ids[replacement.get_instance_id()] = "grid/top_center"
		var oracle: Dictionary = BinderScript.bind_patches(grid_patches, grid_ids)
		_expect(bool(oracle.get("ok", false)), "full Binder oracle succeeds after the persistent graph delta")
		_expect(
			oracle.get("descriptors", {}) == graph_index.get_edge_descriptors(),
			"persistent descriptor cache matches the full Binder oracle after the delta"
		)
		var committed_report_oracle: Dictionary = _build_corner_report_oracle(
			grid_patches,
			grid_ids,
			graph_index.get_edge_descriptors(),
			graph_index.get_patch_size()
		)
		_expect(bool(committed_report_oracle.get("ok", false)), "full resolver report oracle succeeds after the graph delta")
		_expect(
			graph_index.get_corner_reports_by_stable_id() == committed_report_oracle.get("reports_by_stable_id", {}),
			"persistent corner report cache matches the full resolver oracle after the delta"
		)
		top_center.queue_free()
		if is_instance_valid(competing_patch):
			competing_patch.queue_free()
	else:
		replacement.queue_free()
	await process_frame

	var reservation_holder := Node3D.new()
	reservation_holder.name = "AdjacencyGenerationReservationTestRoot"
	root.add_child(reservation_holder)
	var base_a: Node3D = _new_patch(reservation_holder, "BaseA", Vector3(0.0, 0.0, 0.0))
	var base_b: Node3D = _new_patch(reservation_holder, "BaseB", Vector3(20.0, 0.0, 0.0))
	var candidate_a: Node3D = _new_patch(reservation_holder, "CandidateA", Vector3(40.0, 0.0, 0.0))
	var candidate_b: Node3D = _new_patch(reservation_holder, "CandidateB", Vector3(60.0, 0.0, 0.0))
	var candidate_c: Node3D = _new_patch(reservation_holder, "CandidateC", Vector3(80.0, 0.0, 0.0))
	var candidate_d: Node3D = _new_patch(reservation_holder, "CandidateD", Vector3(100.0, 0.0, 0.0))
	var candidate_e: Node3D = _new_patch(reservation_holder, "CandidateE", Vector3(120.0, 0.0, 0.0))
	await process_frame
	var reservation_index = IndexScript.new()
	var reservation_ids: Dictionary = {
		base_a.get_instance_id(): "reservation/base_a",
		base_b.get_instance_id(): "reservation/base_b"
	}
	var reservation_rebuild: Dictionary = reservation_index.rebuild([base_a, base_b], reservation_ids)
	_expect(bool(reservation_rebuild.get("ok", false)), "generation reservation fixture rebuild succeeds")
	var plan_a: Dictionary = reservation_index.plan_delta([], [
		{"stable_id": "reservation/candidate_a", "patch": candidate_a}
	])
	var plan_b: Dictionary = reservation_index.plan_delta([], [
		{"stable_id": "reservation/candidate_b", "patch": candidate_b}
	])
	_expect(bool(plan_a.get("ok", false)) and bool(plan_b.get("ok", false)), "two independent candidate plans share the same base generation")
	if bool(plan_a.get("ok", false)) and bool(plan_b.get("ok", false)):
		var plan_a_id: String = str(plan_a.get("summary", {}).get("plan_id", ""))
		var plan_b_id: String = str(plan_b.get("summary", {}).get("plan_id", ""))
		_expect(bool(reservation_index.reserve_delta(plan_a_id).get("ok", false)), "first candidate acquires the generation reservation")
		var competing: Dictionary = reservation_index.commit_delta(plan_b_id)
		_expect(str(competing.get("error", "")) == "generation_reserved", "unreserved candidate cannot commit through another transaction's reservation")
		_expect(bool(reservation_index.commit_delta(plan_a_id).get("ok", false)), "reserved candidate commits successfully")
		var stale: Dictionary = reservation_index.commit_delta(plan_b_id)
		_expect(str(stale.get("error", "")) == "stale_generation", "unreserved candidate is rejected after the generation advances")

	var plan_c: Dictionary = reservation_index.plan_delta([], [
		{"stable_id": "reservation/candidate_c", "patch": candidate_c}
	])
	_expect(bool(plan_c.get("ok", false)), "a later plan can be prepared after the prior reservation is released by commit")
	if bool(plan_c.get("ok", false)):
		var plan_c_id: String = str(plan_c.get("summary", {}).get("plan_id", ""))
		_expect(bool(reservation_index.reserve_delta(plan_c_id).get("ok", false)), "later plan acquires a fresh generation reservation")
		_expect(reservation_index.release_delta_reservation(plan_c_id), "coordinator can explicitly release a reservation before publication")
		_expect(bool(reservation_index.commit_delta(plan_c_id).get("ok", false)), "released plan remains valid and can commit normally")

	var plan_d: Dictionary = reservation_index.plan_delta([], [
		{"stable_id": "reservation/candidate_d", "patch": candidate_d}
	])
	var plan_e: Dictionary = reservation_index.plan_delta([], [
		{"stable_id": "reservation/candidate_e", "patch": candidate_e}
	])
	_expect(bool(plan_d.get("ok", false)) and bool(plan_e.get("ok", false)), "reversible publication fixture prepares two competing plans")
	if bool(plan_d.get("ok", false)) and bool(plan_e.get("ok", false)):
		var plan_d_id: String = str(plan_d.get("summary", {}).get("plan_id", ""))
		var plan_e_id: String = str(plan_e.get("summary", {}).get("plan_id", ""))
		var plan_patches: Dictionary = reservation_index.get_plan_patches_by_stable_id(plan_d_id)
		_expect(bool(plan_patches.get("ok", false)), "prepared plan exposes a validated candidate Patch map")
		_expect(plan_patches.get("patches_by_stable_id", {}).get("reservation/candidate_d") == candidate_d, "prepared Patch map resolves the exact candidate Node")
		var plan_descriptors: Dictionary = reservation_index.get_plan_edge_descriptors(plan_d_id)
		_expect(bool(plan_descriptors.get("ok", false)), "prepared plan exposes its full candidate descriptor cache")
		var generation_before_publish: int = reservation_index.get_generation()
		_expect(bool(reservation_index.reserve_delta(plan_d_id).get("ok", false)), "reversible publication plan reserves its generation")
		var published: Dictionary = reservation_index.publish_delta(plan_d_id)
		_expect(bool(published.get("ok", false)) and bool(published.get("published", false)), "Index can publish a candidate while retaining its rollback snapshot")
		_expect(reservation_index.get_patch("reservation/candidate_d") == candidate_d, "published Index exposes the candidate Patch before finalization")
		_expect(bool(reservation_index.get_corner_graph_stats().get("generation_reserved", false)), "published Index keeps its generation reservation until coordinator finalization")
		var blocked_competitor: Dictionary = reservation_index.commit_delta(plan_e_id)
		_expect(str(blocked_competitor.get("error", "")) == "generation_reserved", "competing plan cannot publish while a candidate is reversibly published")
		var rolled_back: Dictionary = reservation_index.rollback_published_delta(plan_d_id)
		_expect(bool(rolled_back.get("ok", false)), "published Index can restore its previous snapshot after a downstream failure")
		_expect(reservation_index.get_patch("reservation/candidate_d") == null, "Index rollback removes the candidate Patch from the committed map")
		_expect(reservation_index.get_patch_count() == 4, "Index rollback restores the prior committed Patch count")
		_expect(reservation_index.get_generation() == generation_before_publish + 2, "Index rollback keeps the generation monotonic")
		_expect(not bool(reservation_index.get_corner_graph_stats().get("generation_reserved", true)), "Index rollback releases the coordinator reservation")
		var stale_after_rollback: Dictionary = reservation_index.commit_delta(plan_e_id)
		_expect(str(stale_after_rollback.get("error", "")) == "stale_generation", "plans based on the pre-publish generation become stale after rollback")

	var final_plan: Dictionary = reservation_index.plan_delta([], [
		{"stable_id": "reservation/candidate_d", "patch": candidate_d}
	])
	_expect(bool(final_plan.get("ok", false)), "candidate can be prepared again after a reversible rollback")
	if bool(final_plan.get("ok", false)):
		var final_plan_id: String = str(final_plan.get("summary", {}).get("plan_id", ""))
		_expect(bool(reservation_index.reserve_delta(final_plan_id).get("ok", false)), "final candidate reserves the current generation")
		_expect(bool(reservation_index.publish_delta(final_plan_id).get("ok", false)), "final candidate publishes for coordinator finalization")
		_expect(bool(reservation_index.finalize_delta(final_plan_id).get("ok", false)), "Index finalization discards the retained rollback snapshot")
		_expect(reservation_index.get_patch("reservation/candidate_d") == candidate_d, "finalized Index keeps the candidate Patch committed")
		_expect(not bool(reservation_index.get_corner_graph_stats().get("generation_reserved", true)), "finalization releases the generation reservation")

	graph_holder.queue_free()
	reservation_holder.queue_free()
	await process_frame


func _build_corner_report_oracle(
	patches: Array[Node3D],
	stable_ids_by_instance: Dictionary,
	descriptors: Dictionary,
	patch_size: float
) -> Dictionary:
	var resolver_candidates: Dictionary = {}
	for edge_key_value in descriptors.keys():
		var edge_key: String = str(edge_key_value)
		var descriptor: Dictionary = descriptors[edge_key]
		if not bool(descriptor.get("transition_required", false)):
			continue
		resolver_candidates[edge_key] = {
			"first_id": str(descriptor.get("first_stable_id", "")),
			"second_id": str(descriptor.get("second_stable_id", "")),
			"first_side": str(descriptor.get("first_side", "")),
			"second_side": str(descriptor.get("second_side", ""))
		}
	var resolved: Dictionary = CornerResolverScript.resolve(resolver_candidates)
	if not bool(resolved.get("ok", false)):
		return {"ok": false, "error": str(resolved.get("error", "resolver_failed"))}
	var patches_by_stable_id: Dictionary = {}
	for patch in patches:
		if not is_instance_valid(patch):
			return {"ok": false, "error": "invalid_patch"}
		var stable_id: String = str(stable_ids_by_instance.get(patch.get_instance_id(), ""))
		if stable_id.is_empty():
			return {"ok": false, "error": "missing_stable_id"}
		patches_by_stable_id[stable_id] = patch
	var reports_by_stable_id: Dictionary = {}
	for report_value in resolved.get("reports", []):
		var report: Dictionary = report_value
		var stable_id: String = str(report.get("stable_id", ""))
		var patch: Node3D = patches_by_stable_id.get(stable_id) as Node3D
		if not is_instance_valid(patch):
			return {"ok": false, "error": "missing_report_patch"}
		var junction_key: String = AffectedComponentPlannerScript.junction_key_for_corner(
			patch.global_position,
			str(report.get("corner", "")),
			patch_size
		)
		if junction_key.is_empty():
			return {"ok": false, "error": "invalid_report_junction"}
		var stored_report: Dictionary = report.duplicate(true)
		stored_report["junction_key"] = junction_key
		if not reports_by_stable_id.has(stable_id):
			reports_by_stable_id[stable_id] = []
		var stable_reports: Array = reports_by_stable_id[stable_id]
		stable_reports.append(stored_report)
		reports_by_stable_id[stable_id] = stable_reports
	return {"ok": true, "reports_by_stable_id": reports_by_stable_id}


func _set_height_level(patch: Node3D, height_level: int) -> bool:
	if not is_instance_valid(patch) or not patch.has_method("get_world_object_state") or not patch.has_method("apply_world_object_state"):
		return false
	var state_value: Variant = patch.call("get_world_object_state")
	if not (state_value is Dictionary):
		return false
	var state: Dictionary = state_value
	state["height_level"] = height_level
	state["revision"] = int(state.get("revision", 0)) + 1
	return bool(patch.call("apply_world_object_state", state))


func _assert_matches_full_rebuild_oracle(index, patches: Array[Node3D], stable_ids: Dictionary, label: String) -> void:
	var oracle_report: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	_expect(bool(oracle_report.get("ok", false)), label + ": full-rebuild binder oracle succeeds")
	var oracle_descriptors: Dictionary = oracle_report.get("descriptors", {})
	var indexed_descriptors: Dictionary = index.get_edge_descriptors()
	_expect(oracle_descriptors == indexed_descriptors, label + ": delta index descriptor map matches the full-rebuild oracle")


func _new_patch(holder: Node3D, patch_name: String, patch_position: Vector3) -> Node3D:
	var patch: Node3D = PatchScript.new()
	patch.name = patch_name
	patch.position = patch_position
	holder.add_child(patch)
	return patch


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

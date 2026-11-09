extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const IndexScript = preload("res://systems/SurfaceTerrainAdjacencyIndex.gd")

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

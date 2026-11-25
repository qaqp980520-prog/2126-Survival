extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const IndexScript = preload("res://systems/SurfaceTerrainAdjacencyIndex.gd")
const RADII: Array[int] = [1, 2, 3, 4, 8]
const SAMPLE_COUNT: int = 5

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var holder := Node3D.new()
	holder.name = "TerrainAdjacencyDeltaBenchmarkRoot"
	root.add_child(holder)
	await process_frame

	for radius in RADII:
		await _benchmark_radius(holder, radius)

	holder.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("Surface terrain adjacency delta benchmark completed.")
		quit(0)
	else:
		for failure in failures:
			push_error("BENCHMARK FAILURE: " + failure)
		quit(1)


func _benchmark_radius(holder: Node3D, radius: int) -> void:
	var base_patches: Array[Node3D] = []
	var base_ids: Dictionary = {}
		for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			var stable_id: String = _stable_id(x, z)
			var patch: Node3D = _new_patch(holder, "R%d_X%d_Z%d" % [radius, x, z], x, z)
			base_patches.append(patch)
			base_ids[patch.get_instance_id()] = stable_id
	await process_frame

	var index = IndexScript.new()
	var rebuild: Dictionary = index.rebuild(base_patches, base_ids)
	_expect(bool(rebuild.get("ok", false)), "radius %d baseline index rebuild succeeds" % radius)
	if not bool(rebuild.get("ok", false)):
		return

	var remove_ids: Array[String] = []
	for z in range(-radius, radius + 1):
		remove_ids.append(_stable_id(-radius, z))

	var delta_samples: Array[float] = []
	var full_samples: Array[float] = []
	var last_profile_usec: Dictionary = {}
	var last_profile_counts: Dictionary = {}
	var parity_passes: int = 0

	for sample_index in range(SAMPLE_COUNT):
		var removed_set: Dictionary = {}
		for stable_id in remove_ids:
			removed_set[stable_id] = true

		var candidate_patches: Array[Node3D] = []
		var candidate_ids: Dictionary = {}
		for patch in base_patches:
			var stable_id: String = str(base_ids.get(patch.get_instance_id(), ""))
			if removed_set.has(stable_id):
				continue
			candidate_patches.append(patch)
			candidate_ids[patch.get_instance_id()] = stable_id

		var additions: Array[Dictionary] = []
		var added_patches: Array[Node3D] = []
		for z in range(-radius, radius + 1):
			var stable_id: String = _stable_id(radius + 1, z)
			var patch: Node3D = _new_patch(
				holder,
				"R%d_S%d_AddedZ%d" % [radius, sample_index, z],
				radius + 1,
				z
			)
			added_patches.append(patch)
			candidate_patches.append(patch)
			candidate_ids[patch.get_instance_id()] = stable_id
			additions.append({"stable_id": stable_id, "patch": patch})
		await process_frame

		var delta_started_usec: int = Time.get_ticks_usec()
		var delta_result: Dictionary = index.plan_delta(remove_ids, additions, true)
		var delta_usec: int = Time.get_ticks_usec() - delta_started_usec
		_expect(
			bool(delta_result.get("ok", false)) and not bool(delta_result.get("noop", true)),
			"radius %d sample %d builds a non-noop incremental candidate" % [radius, sample_index + 1]
		)
		if not bool(delta_result.get("ok", false)):
			for added_patch in added_patches:
				added_patch.queue_free()
			await process_frame
			continue

		var summary: Dictionary = delta_result.get("summary", {})
		var plan_id: String = str(summary.get("plan_id", ""))
		var pending_value: Variant = index._pending_plans.get(plan_id, {})
		var pending: Dictionary = pending_value if pending_value is Dictionary else {}
		var candidate_descriptors: Dictionary = pending.get("candidate_descriptors", {})
		var candidate_entries: Dictionary = pending.get("candidate_entries", {})
		var candidate_reports: Dictionary = pending.get("candidate_corner_reports_by_stable_id", {})

		var full_started_usec: int = Time.get_ticks_usec()
		var full_binder: Dictionary = BinderScript.bind_patches(candidate_patches, candidate_ids)
		var full_reports: Dictionary = {}
		var full_graph: Dictionary = {}
		if bool(full_binder.get("ok", false)):
			var report_result: Dictionary = index._build_corner_reports_by_stable_id(
				full_binder.get("descriptors", {}),
				candidate_entries,
				index.get_patch_size()
			)
			if bool(report_result.get("ok", false)):
				full_reports = report_result.get("reports_by_stable_id", {})
				full_graph = index._build_corner_graph(full_reports)
		var full_usec: int = Time.get_ticks_usec() - full_started_usec

		var descriptor_parity: bool = (
			bool(full_binder.get("ok", false))
			and candidate_descriptors == full_binder.get("descriptors", {})
		)
		var report_parity: bool = (
			bool(full_graph.get("ok", false))
			and candidate_reports == full_graph.get("reports_by_stable_id", {})
		)
		var edge_graph_parity: bool = (
			candidate_entries.size() == candidate_patches.size()
			and int(pending.get("candidate_corner_report_count", -1)) == int(full_graph.get("report_count", -2))
			and pending.get("candidate_edge_to_junctions", {}) == full_graph.get("edge_to_junctions", {})
			and pending.get("candidate_junction_to_edges", {}) == full_graph.get("junction_to_edges", {})
			and pending.get("candidate_edge_junction_refcounts", {}) == full_graph.get("edge_junction_refcounts", {})
		)
		_expect(descriptor_parity, "radius %d sample %d incremental descriptors match full Binder rebuild" % [radius, sample_index + 1])
		_expect(report_parity, "radius %d sample %d corner reports match full resolver rebuild" % [radius, sample_index + 1])
		_expect(edge_graph_parity, "radius %d sample %d corner graph maps match full rebuild" % [radius, sample_index + 1])

		var profile_usec: Dictionary = delta_result.get("plan_delta_profile_usec", {})
		var profile_counts: Dictionary = delta_result.get("plan_delta_profile_counts", {})
		_expect(profile_usec.has("total_usec") and int(profile_usec.get("total_usec", -1)) >= 0, "radius %d sample %d includes Index phase timings" % [radius, sample_index + 1])
		_expect(profile_counts.has("candidate_entries_shallow_copied") and profile_counts.has("closure_edges_visited"), "radius %d sample %d includes structural work counters" % [radius, sample_index + 1])

		if descriptor_parity and report_parity and edge_graph_parity and full_usec > 0:
			parity_passes += 1
			delta_samples.append(float(delta_usec))
			full_samples.append(float(full_usec))
			last_profile_usec = profile_usec
			last_profile_counts = profile_counts

		_expect(index.abort_delta(plan_id), "radius %d sample %d aborts the detached candidate" % [radius, sample_index + 1])
		for added_patch in added_patches:
			added_patch.queue_free()
		await process_frame

	_expect(parity_passes == SAMPLE_COUNT, "radius %d completes all %d matched delta/full-rebuild samples" % [radius, SAMPLE_COUNT])
	if parity_passes == SAMPLE_COUNT:
		var record: Dictionary = {
			"radius": radius,
			"sample_count": SAMPLE_COUNT,
			"patch_count_before": base_patches.size(),
			"patch_count_after": base_patches.size(),
			"removed_count": remove_ids.size(),
			"added_count": remove_ids.size(),
			"delta_total_usec_p50": _percentile(delta_samples, 0.50),
			"delta_total_usec_p95": _percentile(delta_samples, 0.95),
			"delta_total_usec_max": _maximum(delta_samples),
			"full_rebuild_total_usec_p50": _percentile(full_samples, 0.50),
			"full_rebuild_total_usec_p95": _percentile(full_samples, 0.95),
			"full_rebuild_total_usec_max": _maximum(full_samples),
			"delta_profile_usec": last_profile_usec,
			"delta_profile_counts": last_profile_counts,
			"descriptor_report_graph_parity_samples": parity_passes,
			"os": OS.get_name(),
			"processor": OS.get_processor_name(),
			"processor_count": OS.get_processor_count(),
			"display_server": DisplayServer.get_name()
		}
		print("SURFACE_TERRAIN_ADJACENCY_DELTA_BENCHMARK_JSON:" + JSON.stringify(record))

	for patch in base_patches:
		if is_instance_valid(patch):
			patch.queue_free()
	await process_frame


func _new_patch(holder: Node3D, patch_name: String, x: int, z: int) -> Node3D:
	var patch: Node3D = PatchScript.new()
	patch.name = patch_name
	patch.position = Vector3(float(x) * 2.0, 0.0, float(z) * 2.0)
	holder.add_child(patch)
	var state: Dictionary = patch.call("get_world_object_state")
	state["height_level"] = posmod(x + z, 2)
	state["revision"] = int(state.get("revision", 0)) + 1
	_expect(bool(patch.call("apply_world_object_state", state)), patch_name + " applies deterministic checkerboard height")
	return patch


func _stable_id(x: int, z: int) -> String:
	return "terrain/%d_%d" % [x, z]


func _percentile(values: Array[float], percentile: float) -> int:
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	var index: int = clampi(int(ceil(percentile * float(sorted_values.size()))) - 1, 0, sorted_values.size() - 1)
	return int(sorted_values[index])


func _maximum(values: Array[float]) -> int:
	var result: float = 0.0
	for value in values:
		result = maxf(result, value)
	return int(result)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

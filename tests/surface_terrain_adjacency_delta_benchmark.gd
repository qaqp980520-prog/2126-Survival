extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const IndexScript = preload("res://systems/SurfaceTerrainAdjacencyIndex.gd")
const OverlayMapScript = preload("res://systems/SurfaceTerrainOverlayMap.gd")
const OVERLAY_FIXTURE_SIZES: Array[int] = [225, 576, 2048, 8192]
const OVERLAY_SAMPLE_COUNT: int = 7
const OVERLAY_UPDATE_COUNT: int = 8
const OVERLAY_REMOVE_COUNT: int = 4
const OVERLAY_ADD_COUNT: int = 4
const OVERLAY_LOOKUP_COUNT: int = 32
const OVERLAY_MISSING_SENTINEL: String = "__overlay_missing_sentinel__"
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
	await _benchmark_sparse_localized(holder)
	_benchmark_overlay_map()
	_benchmark_overlay_compaction()

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
		var candidate_entry_count_match: bool = candidate_entries.size() == candidate_patches.size()
		var candidate_report_count_match: bool = int(pending.get("candidate_corner_report_count", -1)) == int(full_graph.get("report_count", -2))
		var edge_to_junctions_match: bool = _normalize_string_array_map(pending.get("candidate_edge_to_junctions", {})) == _normalize_string_array_map(full_graph.get("edge_to_junctions", {}))
		var junction_to_edges_match: bool = _normalize_string_array_map(pending.get("candidate_junction_to_edges", {})) == _normalize_string_array_map(full_graph.get("junction_to_edges", {}))
		var refcounts_match: bool = pending.get("candidate_edge_junction_refcounts", {}) == full_graph.get("edge_junction_refcounts", {})
		var reverse_report_index_match: bool = (
			pending.get("candidate_junction_to_report_stable_ids", {})
			== full_graph.get("junction_to_report_stable_ids", {})
		)
		var reverse_report_index_count_match: bool = (
			int(pending.get("candidate_corner_report_index_membership_count", -1))
			== int(full_graph.get("report_index_membership_count", -2))
		)
		var edge_graph_parity: bool = (
			candidate_entry_count_match
			and candidate_report_count_match
			and edge_to_junctions_match
			and junction_to_edges_match
			and refcounts_match
			and reverse_report_index_match
			and reverse_report_index_count_match
		)
		_expect(descriptor_parity, "radius %d sample %d incremental descriptors match full Binder rebuild" % [radius, sample_index + 1])
		_expect(report_parity, "radius %d sample %d corner reports match full resolver rebuild" % [radius, sample_index + 1])
		_expect(candidate_entry_count_match, "radius %d sample %d candidate entry count matches the full patch set" % [radius, sample_index + 1])
		_expect(candidate_report_count_match, "radius %d sample %d cached report count matches the full graph rebuild" % [radius, sample_index + 1])
		_expect(edge_to_junctions_match, "radius %d sample %d edge-to-junction links match as unordered sets" % [radius, sample_index + 1])
		_expect(junction_to_edges_match, "radius %d sample %d junction-to-edge links match as unordered sets" % [radius, sample_index + 1])
		_expect(refcounts_match, "radius %d sample %d edge/junction reference counts match exactly" % [radius, sample_index + 1])
		_expect(reverse_report_index_match, "radius %d sample %d Junction-to-report reverse index matches the full rebuild" % [radius, sample_index + 1])
		_expect(reverse_report_index_count_match, "radius %d sample %d reverse-index membership count matches the full rebuild" % [radius, sample_index + 1])

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
			"fixture": "contiguous_checkerboard_boundary",
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


func _benchmark_sparse_localized(holder: Node3D) -> void:
	const ISLANDS_PER_AXIS: int = 3
	const ISLAND_RADIUS: int = 2
	const ISLAND_STRIDE: int = 8
	var base_patches: Array[Node3D] = []
	var base_ids: Dictionary = {}
	var center_stable_id: String = ""
	for island_x in range(-1, ISLANDS_PER_AXIS - 1):
		for island_z in range(-1, ISLANDS_PER_AXIS - 1):
			for local_x in range(-ISLAND_RADIUS, ISLAND_RADIUS + 1):
				for local_z in range(-ISLAND_RADIUS, ISLAND_RADIUS + 1):
					var x: int = island_x * ISLAND_STRIDE + local_x
					var z: int = island_z * ISLAND_STRIDE + local_z
					var stable_id: String = _sparse_stable_id(island_x, island_z, local_x, local_z)
					var patch: Node3D = _new_patch(holder, "Sparse_%d_%d_%d_%d" % [island_x, island_z, local_x, local_z], x, z)
					base_patches.append(patch)
					base_ids[patch.get_instance_id()] = stable_id
					if island_x == 0 and island_z == 0 and local_x == 0 and local_z == 0:
						center_stable_id = stable_id
	await process_frame

	var index = IndexScript.new()
	var rebuild: Dictionary = index.rebuild(base_patches, base_ids)
	_expect(bool(rebuild.get("ok", false)), "sparse localized fixture rebuilds nine disconnected checkerboard islands")
	if not bool(rebuild.get("ok", false)):
		for patch in base_patches:
			patch.queue_free()
		await process_frame
		return
	_expect(base_patches.size() == 225, "sparse localized fixture contains nine islands with twenty-five patches each")
	_expect(not center_stable_id.is_empty(), "sparse localized fixture identifies its center patch Stable ID")

	var delta_samples: Array[float] = []
	var full_samples: Array[float] = []
	var last_profile_usec: Dictionary = {}
	var last_profile_counts: Dictionary = {}
	var last_total_full_scan_buckets: int = 0
	var last_total_full_scan_reports: int = 0
	var last_reverse_index_junction_count: int = 0
	var last_reverse_index_membership_count: int = 0
	var parity_passes: int = 0
	for sample_index in range(SAMPLE_COUNT):
		var replacement: Node3D = _new_patch(holder, "SparseCenterReplacement%d" % sample_index, 0, 0)
		var replacement_state: Dictionary = replacement.call("get_world_object_state")
		replacement_state["height_level"] = 1
		replacement_state["revision"] = int(replacement_state.get("revision", 0)) + 1
		_expect(bool(replacement.call("apply_world_object_state", replacement_state)), "sparse sample %d flips the center patch height" % (sample_index + 1))
		await process_frame

		var candidate_patches: Array[Node3D] = []
		var candidate_ids: Dictionary = {}
		for patch in base_patches:
			var stable_id: String = str(base_ids.get(patch.get_instance_id(), ""))
			if stable_id == center_stable_id:
				continue
			candidate_patches.append(patch)
			candidate_ids[patch.get_instance_id()] = stable_id
		candidate_patches.append(replacement)
		candidate_ids[replacement.get_instance_id()] = center_stable_id
		var additions: Array[Dictionary] = [{"stable_id": center_stable_id, "patch": replacement}]

		var delta_started_usec: int = Time.get_ticks_usec()
		var delta_result: Dictionary = index.plan_delta([center_stable_id], additions, true)
		var delta_usec: int = Time.get_ticks_usec() - delta_started_usec
		_expect(
			bool(delta_result.get("ok", false)) and not bool(delta_result.get("noop", true)),
			"sparse sample %d prepares a one-patch localized replacement" % (sample_index + 1)
		)
		if not bool(delta_result.get("ok", false)):
			replacement.queue_free()
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
		var reverse_index_parity: bool = (
			pending.get("candidate_junction_to_report_stable_ids", {})
			== full_graph.get("junction_to_report_stable_ids", {})
		)
		var reverse_index_count_parity: bool = (
			int(pending.get("candidate_corner_report_index_membership_count", -1))
			== int(full_graph.get("report_index_membership_count", -2))
		)
		var edge_to_junctions_match: bool = _normalize_string_array_map(pending.get("candidate_edge_to_junctions", {})) == _normalize_string_array_map(full_graph.get("edge_to_junctions", {}))
		var junction_to_edges_match: bool = _normalize_string_array_map(pending.get("candidate_junction_to_edges", {})) == _normalize_string_array_map(full_graph.get("junction_to_edges", {}))
		var refcounts_match: bool = pending.get("candidate_edge_junction_refcounts", {}) == full_graph.get("edge_junction_refcounts", {})
		var entry_count_match: bool = candidate_entries.size() == candidate_patches.size()
		var report_count_match: bool = int(pending.get("candidate_corner_report_count", -1)) == int(full_graph.get("report_count", -2))
		var graph_parity: bool = (
			entry_count_match and report_count_match and edge_to_junctions_match
			and junction_to_edges_match and refcounts_match
			and reverse_index_parity and reverse_index_count_parity
		)
		_expect(descriptor_parity, "sparse sample %d descriptors match the full Binder oracle" % (sample_index + 1))
		_expect(report_parity, "sparse sample %d corner reports match the full resolver oracle" % (sample_index + 1))
		_expect(graph_parity, "sparse sample %d corner graph and reverse index match the full rebuild" % (sample_index + 1))

		var profile_usec: Dictionary = delta_result.get("plan_delta_profile_usec", {})
		var profile_counts: Dictionary = delta_result.get("plan_delta_profile_counts", {})
		var total_full_scan_buckets: int = index._corner_reports_by_stable_id.size() + candidate_reports.size()
		var total_full_scan_reports: int = _count_report_entries(index._corner_reports_by_stable_id) + _count_report_entries(candidate_reports)
		last_total_full_scan_buckets = total_full_scan_buckets
		last_total_full_scan_reports = total_full_scan_reports
		last_reverse_index_junction_count = int(pending.get("candidate_junction_to_report_stable_ids", {}).size())
		last_reverse_index_membership_count = int(pending.get("candidate_corner_report_index_membership_count", 0))
		var visited_buckets: int = int(profile_counts.get("corner_report_buckets_visited", -1))
		var visited_reports: int = int(profile_counts.get("corner_reports_visited", -1))
		_expect(visited_buckets >= 0 and visited_buckets < total_full_scan_buckets, "sparse sample %d reverse index visits fewer report buckets than a full scan" % (sample_index + 1))
		_expect(visited_reports >= 0 and visited_reports < total_full_scan_reports, "sparse sample %d reverse index visits fewer report records than a full scan" % (sample_index + 1))
		_expect(int(profile_counts.get("closure_junctions_visited", -1)) < index.get_corner_graph_stats().get("junction_count", 0) * 2, "sparse sample %d closure remains smaller than the combined old/candidate graph" % (sample_index + 1))

		if descriptor_parity and report_parity and graph_parity and full_usec > 0:
			parity_passes += 1
			delta_samples.append(float(delta_usec))
			full_samples.append(float(full_usec))
			last_profile_usec = profile_usec
			last_profile_counts = profile_counts
		_expect(index.abort_delta(plan_id), "sparse sample %d aborts the detached candidate" % (sample_index + 1))
		replacement.queue_free()
		await process_frame

	_expect(parity_passes == SAMPLE_COUNT, "sparse localized fixture completes all five matched delta/full-rebuild samples")
	if parity_passes == SAMPLE_COUNT:
		var record: Dictionary = {
			"fixture": "sparse_localized_center_replacement",
			"islands": ISLANDS_PER_AXIS * ISLANDS_PER_AXIS,
			"patches_per_island": (ISLAND_RADIUS * 2 + 1) * (ISLAND_RADIUS * 2 + 1),
			"patch_count_before": base_patches.size(),
			"patch_count_after": base_patches.size(),
			"changed_patch_count": 1,
			"sample_count": SAMPLE_COUNT,
			"delta_total_usec_p50": _percentile(delta_samples, 0.50),
			"delta_total_usec_p95": _percentile(delta_samples, 0.95),
			"delta_total_usec_max": _maximum(delta_samples),
			"full_rebuild_total_usec_p50": _percentile(full_samples, 0.50),
			"full_rebuild_total_usec_p95": _percentile(full_samples, 0.95),
			"full_rebuild_total_usec_max": _maximum(full_samples),
			"delta_profile_usec": last_profile_usec,
			"delta_profile_counts": last_profile_counts,
			"corner_report_buckets_visited": int(last_profile_counts.get("corner_report_buckets_visited", 0)),
			"corner_report_buckets_full_scan_equivalent": last_total_full_scan_buckets,
			"corner_report_bucket_visit_reduction_ratio": 1.0 - float(last_profile_counts.get("corner_report_buckets_visited", 0)) / maxf(float(last_total_full_scan_buckets), 1.0),
			"corner_reports_visited": int(last_profile_counts.get("corner_reports_visited", 0)),
			"corner_reports_full_scan_equivalent": last_total_full_scan_reports,
			"corner_report_visit_reduction_ratio": 1.0 - float(last_profile_counts.get("corner_reports_visited", 0)) / maxf(float(last_total_full_scan_reports), 1.0),
			"candidate_reverse_index_junction_count": last_reverse_index_junction_count,
			"candidate_reverse_index_membership_count": last_reverse_index_membership_count,
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


func _normalize_string_array_map(source: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	var keys: Array[String] = []
	for key_value in source.keys():
		keys.append(str(key_value))
	keys.sort()
	for key in keys:
		var values: Array[String] = []
		for value in source.get(key, []):
			values.append(str(value))
		values.sort()
		normalized[key] = values
	return normalized


func _stable_id(x: int, z: int) -> String:
	return "terrain/%d_%d" % [x, z]


func _sparse_stable_id(island_x: int, island_z: int, local_x: int, local_z: int) -> String:
	return "terrain/sparse/%d_%d/%d_%d" % [island_x, island_z, local_x, local_z]


func _count_report_entries(reports_by_stable_id: Dictionary) -> int:
	var count: int = 0
	for reports_value in reports_by_stable_id.values():
		if reports_value is Array:
			count += reports_value.size()
	return count


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


func _benchmark_overlay_map() -> void:
	for fixture_size in OVERLAY_FIXTURE_SIZES:
		var base: Dictionary = {}
		for index in range(fixture_size):
			base["patch/%05d" % index] = {
				"revision": index,
				"payload": PackedInt32Array([index % 13, index % 17, index % 23])
			}
		var overlay_root: RefCounted = OverlayMapScript.new(base)
		var update_keys: Array[String] = []
		var remove_keys: Array[String] = []
		var addition_keys: Array[String] = []
		for index in range(OVERLAY_UPDATE_COUNT):
			update_keys.append("patch/%05d" % (index * max(1, int(fixture_size / OVERLAY_UPDATE_COUNT))))
		for index in range(OVERLAY_REMOVE_COUNT):
			remove_keys.append("patch/%05d" % (fixture_size - 1 - index))
		for index in range(OVERLAY_ADD_COUNT):
			addition_keys.append("new/%02d" % index)

		var full_samples: Array[float] = []
		var overlay_samples: Array[float] = []
		var materialize_samples: Array[float] = []
		var parity_passes: int = 0
		for sample_index in range(OVERLAY_SAMPLE_COUNT):
			var update_values: Dictionary = {}
			for update_index in range(OVERLAY_UPDATE_COUNT):
				update_values[update_keys[update_index]] = {
					"revision": 100000 + sample_index * 100 + update_index,
					"payload": PackedInt32Array([fixture_size, sample_index, update_index])
				}
			var addition_values: Dictionary = {}
			for addition_index in range(OVERLAY_ADD_COUNT):
				addition_values[addition_keys[addition_index]] = {
					"revision": 200000 + sample_index * 100 + addition_index,
					"payload": PackedInt32Array([fixture_size, sample_index, addition_index])
				}

			var full_started_usec: int = Time.get_ticks_usec()
			var full_candidate: Dictionary = base.duplicate(false)
			for key in update_values:
				full_candidate[key] = update_values[key]
			for key in remove_keys:
				full_candidate.erase(key)
			for key in addition_values:
				full_candidate[key] = addition_values[key]
			var full_checksum: int = _overlay_dictionary_checksum(full_candidate, fixture_size, sample_index, OVERLAY_LOOKUP_COUNT)
			full_samples.append(float(Time.get_ticks_usec() - full_started_usec))

			var overlay_started_usec: int = Time.get_ticks_usec()
			var candidate: RefCounted = overlay_root.call("fork")
			for key in update_values:
				candidate.call("set_value", key, update_values[key])
			for key in remove_keys:
				candidate.call("erase_key", key)
			for key in addition_values:
				candidate.call("set_value", key, addition_values[key])
			var overlay_checksum: int = _overlay_map_checksum(candidate, fixture_size, sample_index, OVERLAY_LOOKUP_COUNT)
			overlay_samples.append(float(Time.get_ticks_usec() - overlay_started_usec))

			var materialize_started_usec: int = Time.get_ticks_usec()
			var materialized: Dictionary = candidate.call("materialize")
			materialize_samples.append(float(Time.get_ticks_usec() - materialize_started_usec))
			_expect(materialized == full_candidate, "overlay fixture %d sample %d matches Dictionary oracle" % [fixture_size, sample_index + 1])
			_expect(overlay_checksum == full_checksum, "overlay fixture %d sample %d lookup checksum matches" % [fixture_size, sample_index + 1])
			_expect(int(candidate.call("size")) == full_candidate.size(), "overlay fixture %d sample %d cached size matches" % [fixture_size, sample_index + 1])
			if materialized == full_candidate and overlay_checksum == full_checksum:
				parity_passes += 1

		var record: Dictionary = {
			"fixture_entries": fixture_size,
			"sample_count": OVERLAY_SAMPLE_COUNT,
			"delta_operations": OVERLAY_UPDATE_COUNT + OVERLAY_REMOVE_COUNT + OVERLAY_ADD_COUNT,
			"lookup_count": OVERLAY_LOOKUP_COUNT,
			"dictionary_copy_edit_lookup_p50_usec": _percentile(full_samples, 0.5),
			"overlay_fork_edit_lookup_p50_usec": _percentile(overlay_samples, 0.5),
			"overlay_materialize_p50_usec": _percentile(materialize_samples, 0.5),
			"parity_passes": parity_passes,
			"expected_parity_passes": OVERLAY_SAMPLE_COUNT,
			"overlay_max_depth": 1
		}
		print("SURFACE_TERRAIN_OVERLAY_MAP_BENCHMARK_JSON:" + JSON.stringify(record))
		_expect(parity_passes == OVERLAY_SAMPLE_COUNT, "overlay fixture %d passes all matched samples" % fixture_size)


func _overlay_dictionary_checksum(source: Dictionary, fixture_size: int, sample_index: int, lookup_count: int) -> int:
	var checksum: int = 0
	for index in range(lookup_count):
		var key: String = "patch/%05d" % ((index * 7919 + sample_index * 13) % fixture_size)
		var value: Variant = source.get(key, OVERLAY_MISSING_SENTINEL)
		if value is Dictionary:
			checksum += int(value.get("revision", 0))
	return checksum


func _overlay_map_checksum(source: RefCounted, fixture_size: int, sample_index: int, lookup_count: int) -> int:
	var checksum: int = 0
	for index in range(lookup_count):
		var key: String = "patch/%05d" % ((index * 7919 + sample_index * 13) % fixture_size)
		var value: Variant = source.call("get_value", key, OVERLAY_MISSING_SENTINEL)
		if value is Dictionary:
			checksum += int(value.get("revision", 0))
	return checksum

func _benchmark_overlay_compaction() -> void:
	for fixture_size in OVERLAY_FIXTURE_SIZES:
		var base: Dictionary = {}
		for index in range(fixture_size):
			base["patch/%05d" % index] = {
				"revision": index,
				"payload": PackedInt32Array([index % 13, index % 17, index % 23])
			}
		var dictionary_total_samples: Array[float] = []
		var overlay_total_samples: Array[float] = []
		var compaction_fork_samples: Array[float] = []
		var parity_passes: int = 0
		for sample_index in range(OVERLAY_SAMPLE_COUNT):
			var dictionary_snapshot: Dictionary = base.duplicate(false)
			var overlay_snapshot: RefCounted = OverlayMapScript.new(base)
			var dictionary_total_usec: int = 0
			var overlay_total_usec: int = 0
			var compaction_fork_usec: int = -1
			var sample_parity_ok: bool = true
			for transaction_index in range(9):
				var update_values: Dictionary = {}
				var update_keys: Array[String] = []
				for update_index in range(OVERLAY_UPDATE_COUNT):
					var update_key: String = "patch/%05d" % (update_index * max(1, int(fixture_size / OVERLAY_UPDATE_COUNT)))
					update_keys.append(update_key)
					update_values[update_key] = {
						"revision": 300000 + sample_index * 1000 + transaction_index * 100 + update_index,
						"payload": PackedInt32Array([fixture_size, sample_index, transaction_index, update_index])
					}
				var remove_keys: Array[String] = []
				for remove_index in range(OVERLAY_REMOVE_COUNT):
					var removed_key_index: int = fixture_size - 1 - transaction_index * OVERLAY_REMOVE_COUNT - remove_index
					remove_keys.append("patch/%05d" % removed_key_index)
				var addition_values: Dictionary = {}
				var addition_keys: Array[String] = []
				for addition_index in range(OVERLAY_ADD_COUNT):
					var addition_key: String = "compaction/%02d/%02d" % [transaction_index, addition_index]
					addition_keys.append(addition_key)
					addition_values[addition_key] = {
						"revision": 400000 + sample_index * 1000 + transaction_index * 100 + addition_index,
						"payload": PackedInt32Array([fixture_size, sample_index, transaction_index, addition_index])
					}
				var lookup_keys: Array[String] = []
				for lookup_index in range(OVERLAY_LOOKUP_COUNT):
					var lookup_group: int = int(lookup_index / 4)
					match lookup_index % 4:
						0:
							lookup_keys.append(update_keys[lookup_group % update_keys.size()])
						1:
							lookup_keys.append(remove_keys[lookup_group % remove_keys.size()])
						2:
							lookup_keys.append(addition_keys[lookup_group % addition_keys.size()])
						_:
							lookup_keys.append("missing/%02d/%02d" % [transaction_index, lookup_group])
				var dictionary_started_usec: int = Time.get_ticks_usec()
				var dictionary_candidate: Dictionary = dictionary_snapshot.duplicate(false)
				for key in update_values:
					dictionary_candidate[key] = update_values[key]
				for key in remove_keys:
					dictionary_candidate.erase(key)
				for key in addition_values:
					dictionary_candidate[key] = addition_values[key]
				var dictionary_checksum: int = 0
				for key in lookup_keys:
					var dictionary_value: Variant = dictionary_candidate.get(key, OVERLAY_MISSING_SENTINEL)
					if dictionary_value is Dictionary:
						dictionary_checksum += int(dictionary_value.get("revision", 0))
				dictionary_total_usec += Time.get_ticks_usec() - dictionary_started_usec
				dictionary_snapshot = dictionary_candidate
				var overlay_started_usec: int = Time.get_ticks_usec()
				var fork_started_usec: int = Time.get_ticks_usec()
				var candidate: RefCounted = overlay_snapshot.call("fork")
				var fork_elapsed_usec: int = Time.get_ticks_usec() - fork_started_usec
				if transaction_index == 8:
					compaction_fork_usec = fork_elapsed_usec
				for key in update_values:
					candidate.call("set_value", key, update_values[key])
				for key in remove_keys:
					candidate.call("erase_key", key)
				for key in addition_values:
					candidate.call("set_value", key, addition_values[key])
				var overlay_checksum: int = 0
				for key in lookup_keys:
					var overlay_value: Variant = candidate.call("get_value", key, OVERLAY_MISSING_SENTINEL)
					if overlay_value is Dictionary:
						overlay_checksum += int(overlay_value.get("revision", 0))
				overlay_total_usec += Time.get_ticks_usec() - overlay_started_usec
				var previous_depth: int = int(overlay_snapshot.call("get_depth"))
				var candidate_depth: int = int(candidate.call("get_depth"))
				if transaction_index == 8:
					_expect(previous_depth == 8 and candidate_depth == 1, "overlay fixture %d sample %d performs one depth-eight compaction" % [fixture_size, sample_index + 1])
				else:
					_expect(candidate_depth == previous_depth + 1, "overlay fixture %d sample %d advances one layer before compaction" % [fixture_size, sample_index + 1])
				_expect(overlay_checksum == dictionary_checksum, "overlay compaction fixture %d sample %d transaction %d lookup parity" % [fixture_size, sample_index + 1, transaction_index + 1])
				if overlay_checksum != dictionary_checksum:
					sample_parity_ok = false
				overlay_snapshot = candidate
			if compaction_fork_usec < 0:
				_expect(false, "overlay compaction fixture %d sample %d records the depth-eight fork" % [fixture_size, sample_index + 1])
				sample_parity_ok = false
			var final_materialized: Dictionary = overlay_snapshot.call("materialize")
			_expect(final_materialized == dictionary_snapshot, "overlay compaction fixture %d sample %d final Dictionary parity" % [fixture_size, sample_index + 1])
			_expect(int(overlay_snapshot.call("size")) == dictionary_snapshot.size(), "overlay compaction fixture %d sample %d cached size parity" % [fixture_size, sample_index + 1])
			if final_materialized != dictionary_snapshot or int(overlay_snapshot.call("size")) != dictionary_snapshot.size():
				sample_parity_ok = false
			if sample_parity_ok:
				parity_passes += 1
			dictionary_total_samples.append(float(dictionary_total_usec))
			overlay_total_samples.append(float(overlay_total_usec))
			compaction_fork_samples.append(float(compaction_fork_usec))
		var dictionary_p50: int = _percentile(dictionary_total_samples, 0.5)
		var overlay_p50: int = _percentile(overlay_total_samples, 0.5)
		var record: Dictionary = {
			"fixture_entries": fixture_size,
			"sample_count": OVERLAY_SAMPLE_COUNT,
			"transactions_per_sample": 9,
			"updates_per_transaction": OVERLAY_UPDATE_COUNT,
			"removals_per_transaction": OVERLAY_REMOVE_COUNT,
			"insertions_per_transaction": OVERLAY_ADD_COUNT,
			"lookups_per_transaction": OVERLAY_LOOKUP_COUNT,
			"dictionary_nine_transaction_total_p50_usec": dictionary_p50,
			"overlay_nine_transaction_total_p50_usec": overlay_p50,
			"overlay_depth_eight_compaction_fork_p50_usec": _percentile(compaction_fork_samples, 0.5),
			"overlay_depth_eight_compaction_fork_p95_usec": _percentile(compaction_fork_samples, 0.95),
			"dictionary_to_overlay_total_ratio": float(dictionary_p50) / maxf(1.0, float(overlay_p50)),
			"compactions_per_sample": 1,
			"parity_passes": parity_passes,
			"expected_parity_passes": OVERLAY_SAMPLE_COUNT
		}
		print("SURFACE_TERRAIN_OVERLAY_COMPACTION_BENCHMARK_JSON:" + JSON.stringify(record))
		_expect(parity_passes == OVERLAY_SAMPLE_COUNT, "overlay compaction fixture %d passes all nine-transaction parity samples" % fixture_size)


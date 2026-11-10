extends RefCounted
class_name SurfaceTerrainAdjacencyIndex

## Persistent spatial index and detached load/unload delta planner.
## This primitive does not mutate live patch edges or collider-manager ownership.
const SIDES: Array[String] = ["east", "west", "north", "south"]
const POSITION_TOLERANCE: float = 0.01
const TransitionDescriptorScript = preload("res://systems/SurfaceTerrainTransitionDescriptor.gd")
const CornerResolverScript = preload("res://systems/SurfaceTerrainCornerConflictResolver.gd")
const AffectedComponentPlannerScript = preload("res://systems/SurfaceTerrainAffectedComponentPlanner.gd")

var _descriptors_by_edge_key: Dictionary = {}
var _corner_reports_by_stable_id: Dictionary = {}
var _edge_to_junctions: Dictionary = {}
var _junction_to_edges: Dictionary = {}
var _edge_junction_refcounts: Dictionary = {}
var _reserved_plan_id: String = ""

var _entries_by_stable_id: Dictionary = {}
var _bucket_to_stable_ids: Dictionary = {}
var _patch_size: float = -1.0
var _generation: int = 0
var _plan_serial: int = 0
var _pending_plans: Dictionary = {}


## Atomically replaces the index from a complete live patch set.
## stable_ids_by_instance maps Node instance IDs to persistent world-object Stable IDs.
func rebuild(patches: Array[Node3D], stable_ids_by_instance: Dictionary) -> Dictionary:
	if not _reserved_plan_id.is_empty():
		return {"ok": false, "error": "generation_reserved", "reserved_plan_id": _reserved_plan_id}
	var candidate_entries: Dictionary = {}
	var candidate_buckets: Dictionary = {}
	var copied_buckets: Dictionary = {}
	var seen_instances: Dictionary = {}
	var candidate_patch_size: float = -1.0

	for patch in patches:
		if not is_instance_valid(patch):
			return {"ok": false, "error": "invalid_patch"}
		var instance_id: int = patch.get_instance_id()
		if seen_instances.has(instance_id):
			return {"ok": false, "error": "duplicate_instance"}
		seen_instances[instance_id] = true
		var stable_id: String = str(stable_ids_by_instance.get(instance_id, ""))
		var record_result: Dictionary = _make_record(patch, stable_id)
		if not bool(record_result.get("ok", false)):
			return record_result
		if candidate_entries.has(stable_id):
			return {"ok": false, "error": "duplicate_stable_id"}
		var record: Dictionary = record_result["record"]
		var size: float = float(record["snapshot"]["patch_size"])
		if candidate_patch_size < 0.0:
			candidate_patch_size = size
		elif absf(size - candidate_patch_size) > POSITION_TOLERANCE:
			return {"ok": false, "error": "mixed_patch_sizes"}
		if _has_duplicate_position(record, candidate_buckets, candidate_entries):
			return {"ok": false, "error": "duplicate_position"}
		candidate_entries[stable_id] = record
		_add_bucket_id(candidate_buckets, record["bucket"], stable_id, copied_buckets)

	var descriptor_result: Dictionary = _build_descriptors_for_all(
		candidate_entries,
		candidate_buckets,
		candidate_patch_size
	)
	if not bool(descriptor_result.get("ok", false)):
		return descriptor_result
	var candidate_descriptors: Dictionary = descriptor_result.get("descriptors", {})
	var report_result: Dictionary = _build_corner_reports_by_stable_id(
		candidate_descriptors,
		candidate_entries,
		candidate_patch_size
	)
	if not bool(report_result.get("ok", false)):
		return report_result
	var graph_result: Dictionary = _build_corner_graph(report_result.get("reports_by_stable_id", {}))
	if not bool(graph_result.get("ok", false)):
		return graph_result

	_entries_by_stable_id = candidate_entries
	_bucket_to_stable_ids = candidate_buckets
	_patch_size = candidate_patch_size
	_descriptors_by_edge_key = candidate_descriptors.duplicate(true)
	_corner_reports_by_stable_id = graph_result.get("reports_by_stable_id", {}).duplicate(true)
	_edge_to_junctions = graph_result.get("edge_to_junctions", {}).duplicate(true)
	_junction_to_edges = graph_result.get("junction_to_edges", {}).duplicate(true)
	_edge_junction_refcounts = graph_result.get("edge_junction_refcounts", {}).duplicate(true)
	_generation += 1
	_pending_plans.clear()
	_reserved_plan_id = ""
	return {
		"ok": true,
		"generation": _generation,
		"patch_count": _entries_by_stable_id.size(),
		"bucket_count": _bucket_to_stable_ids.size(),
		"edge_count": _descriptors_by_edge_key.size(),
		"corner_report_count": int(graph_result.get("report_count", 0)),
		"junction_count": _junction_to_edges.size()
	}

## Prepares a load/unload delta without changing the committed index or live patches.
## A Stable ID may appear in both arrays to represent unload/reload with a new Node instance.
## Returned summaries are detached copies; the internal candidate snapshot is addressed by plan_id.
func plan_delta(remove_stable_ids: Array, additions: Array) -> Dictionary:
	var candidate_entries: Dictionary = _entries_by_stable_id.duplicate()
	# Dictionary.duplicate() copies the bucket map; arrays are copied only when a bucket is touched.
	var candidate_buckets: Dictionary = _bucket_to_stable_ids.duplicate()
	var copied_buckets: Dictionary = {}
	var removed_ids: Array[String] = []
	var added_ids: Array[String] = []
	var changed_ids: Dictionary = {}
	var removed_seen: Dictionary = {}

	for stable_id_value in remove_stable_ids:
		var stable_id: String = str(stable_id_value)
		if stable_id.strip_edges().is_empty():
			return {"ok": false, "error": "invalid_remove_stable_id"}
		if removed_seen.has(stable_id):
			return {"ok": false, "error": "duplicate_remove_stable_id"}
		if not candidate_entries.has(stable_id):
			return {"ok": false, "error": "unknown_remove_stable_id"}
		removed_seen[stable_id] = true
		var old_record: Dictionary = candidate_entries[stable_id]
		_remove_bucket_id(candidate_buckets, old_record["bucket"], stable_id, copied_buckets)
		candidate_entries.erase(stable_id)
		removed_ids.append(stable_id)
		changed_ids[stable_id] = true

	var candidate_patch_size: float = _first_patch_size(candidate_entries)
	var added_seen: Dictionary = {}
	var added_instances: Dictionary = {}

	for addition_value in additions:
		if not (addition_value is Dictionary):
			return {"ok": false, "error": "invalid_addition"}
		var addition: Dictionary = addition_value
		var stable_id: String = str(addition.get("stable_id", ""))
		var patch: Node3D = addition.get("patch") as Node3D
		if stable_id.strip_edges().is_empty():
			return {"ok": false, "error": "invalid_stable_id"}
		if added_seen.has(stable_id) or candidate_entries.has(stable_id):
			return {"ok": false, "error": "duplicate_stable_id"}
		added_seen[stable_id] = true
		if not is_instance_valid(patch):
			return {"ok": false, "error": "invalid_patch"}
		var instance_id: int = patch.get_instance_id()
		if added_instances.has(instance_id) or _contains_instance(candidate_entries, instance_id):
			return {"ok": false, "error": "duplicate_instance"}
		added_instances[instance_id] = true

		var record_result: Dictionary = _make_record(patch, stable_id)
		if not bool(record_result.get("ok", false)):
			return record_result
		var record: Dictionary = record_result["record"]
		var size: float = float(record["snapshot"]["patch_size"])
		if candidate_patch_size < 0.0:
			candidate_patch_size = size
		elif absf(size - candidate_patch_size) > POSITION_TOLERANCE:
			return {"ok": false, "error": "mixed_patch_sizes"}
		if _has_duplicate_position(record, candidate_buckets, candidate_entries):
			return {"ok": false, "error": "duplicate_position"}
		candidate_entries[stable_id] = record
		_add_bucket_id(candidate_buckets, record["bucket"], stable_id, copied_buckets)
		added_ids.append(stable_id)
		changed_ids[stable_id] = true

	if removed_ids.is_empty() and added_ids.is_empty():
		return {"ok": true, "noop": true, "generation": _generation}

	var touched_ids: Dictionary = changed_ids.duplicate()
	for stable_id in removed_ids:
		var old_record: Dictionary = _entries_by_stable_id[stable_id]
		for neighbor_id in _collect_cardinal_neighbors(
			old_record["position"],
			_patch_size,
			_bucket_to_stable_ids,
			_entries_by_stable_id,
			stable_id
		):
			touched_ids[neighbor_id] = true
	for stable_id in added_ids:
		var new_record: Dictionary = candidate_entries[stable_id]
		for neighbor_id in _collect_cardinal_neighbors(
			new_record["position"],
			candidate_patch_size,
			candidate_buckets,
			candidate_entries,
			stable_id
		):
			touched_ids[neighbor_id] = true

	var old_descriptor_result: Dictionary = _build_descriptors_for_ids(
		_entries_by_stable_id,
		_bucket_to_stable_ids,
		changed_ids,
		_patch_size
	)
	if not bool(old_descriptor_result.get("ok", false)):
		return old_descriptor_result
	var new_descriptor_result: Dictionary = _build_descriptors_for_ids(
		candidate_entries,
		candidate_buckets,
		changed_ids,
		candidate_patch_size
	)
	if not bool(new_descriptor_result.get("ok", false)):
		return new_descriptor_result

	var old_descriptors: Dictionary = old_descriptor_result.get("descriptors", {})
	var new_descriptors: Dictionary = new_descriptor_result.get("descriptors", {})
	var affected_edge_keys: Dictionary = {}
	var added_edge_keys: Array[String] = []
	var removed_edge_keys: Array[String] = []
	var changed_edge_keys: Array[String] = []
	for edge_key_value in old_descriptors.keys():
		var edge_key: String = str(edge_key_value)
		affected_edge_keys[edge_key] = true
		if not new_descriptors.has(edge_key):
			removed_edge_keys.append(edge_key)
		elif old_descriptors[edge_key] != new_descriptors[edge_key]:
			changed_edge_keys.append(edge_key)
	for edge_key_value in new_descriptors.keys():
		var edge_key: String = str(edge_key_value)
		affected_edge_keys[edge_key] = true
		if not old_descriptors.has(edge_key):
			added_edge_keys.append(edge_key)

	var old_local_result: Dictionary = _build_descriptors_for_ids(
		_entries_by_stable_id,
		_bucket_to_stable_ids,
		touched_ids,
		_patch_size
	)
	if not bool(old_local_result.get("ok", false)):
		return old_local_result
	var new_local_result: Dictionary = _build_descriptors_for_ids(
		candidate_entries,
		candidate_buckets,
		touched_ids,
		candidate_patch_size
	)
	if not bool(new_local_result.get("ok", false)):
		return new_local_result
	var old_local_descriptors: Dictionary = old_local_result.get("descriptors", {})
	var new_local_descriptors: Dictionary = new_local_result.get("descriptors", {})
	var new_report_result: Dictionary = _build_corner_reports_by_stable_id(
		new_local_descriptors,
		candidate_entries,
		candidate_patch_size,
		touched_ids,
		true
	)
	if not bool(new_report_result.get("ok", false)):
		return new_report_result
	var graph_delta: Dictionary = _apply_corner_report_delta(
		touched_ids,
		new_report_result.get("reports_by_stable_id", {})
	)
	if not bool(graph_delta.get("ok", false)):
		return graph_delta

	# Replace only descriptor keys incident to touched Stable IDs. Descriptor records
	# outside this local neighborhood remain shared and untouched.
	var candidate_descriptors: Dictionary = _descriptors_by_edge_key.duplicate(false)
	for edge_key_value in old_local_descriptors.keys():
		candidate_descriptors.erase(str(edge_key_value))
	for edge_key_value in new_local_descriptors.keys():
		candidate_descriptors[str(edge_key_value)] = new_local_descriptors[edge_key_value].duplicate(true)

	var closure_result: Dictionary = _build_union_corner_closure(
		_sorted_strings(affected_edge_keys.keys()),
		_edge_to_junctions,
		_junction_to_edges,
		graph_delta.get("edge_to_junctions", {}),
		graph_delta.get("junction_to_edges", {})
	)
	if not bool(closure_result.get("ok", false)):
		return closure_result
	var closure_edge_keys: Array = closure_result.get("edge_keys", [])
	var closure_junction_keys: Array = closure_result.get("junction_keys", [])
	var closure_junction_set: Dictionary = {}
	for junction_key in closure_junction_keys:
		closure_junction_set[junction_key] = true
	var old_closure_descriptors: Dictionary = _select_descriptors(_descriptors_by_edge_key, closure_edge_keys)
	var new_closure_descriptors: Dictionary = _select_descriptors(candidate_descriptors, closure_edge_keys)
	var old_closure_reports: Array[Dictionary] = _collect_corner_reports_for_junctions(
		_corner_reports_by_stable_id,
		closure_junction_set
	)
	var new_closure_reports: Array[Dictionary] = _collect_corner_reports_for_junctions(
		graph_delta.get("reports_by_stable_id", {}),
		closure_junction_set
	)

	var plan_id: String = "%d:%d" % [_generation, _plan_serial]
	_plan_serial += 1
	var summary: Dictionary = {
		"plan_id": plan_id,
		"base_generation": _generation,
		"next_generation": _generation + 1,
		"removed_stable_ids": _sorted_strings(removed_ids),
		"added_stable_ids": _sorted_strings(added_ids),
		"touched_stable_ids": _sorted_strings(touched_ids.keys()),
		"affected_edge_keys": _sorted_strings(affected_edge_keys.keys()),
		"added_edge_keys": _sorted_strings(added_edge_keys),
		"removed_edge_keys": _sorted_strings(removed_edge_keys),
		"changed_edge_keys": _sorted_strings(changed_edge_keys),
		"old_descriptors": old_descriptors.duplicate(true),
		"new_descriptors": new_descriptors.duplicate(true),
		"closure_edge_keys": closure_edge_keys.duplicate(),
		"closure_junction_keys": closure_junction_keys.duplicate(),
		"old_closure_descriptors": old_closure_descriptors.duplicate(true),
		"new_closure_descriptors": new_closure_descriptors.duplicate(true),
		"old_closure_reports": old_closure_reports.duplicate(true),
		"new_closure_reports": new_closure_reports.duplicate(true),
		"recomputed_corner_report_count": _old_report_count_for_ids(_corner_reports_by_stable_id, touched_ids) + _old_report_count_for_ids(graph_delta.get("reports_by_stable_id", {}), touched_ids),
		"candidate_corner_report_count": int(graph_delta.get("report_count", 0)),
		"candidate_junction_count": graph_delta.get("junction_to_edges", {}).size(),
		"patch_count_after": candidate_entries.size()
	}
	_pending_plans[plan_id] = {
		"base_generation": _generation,
		"candidate_entries": candidate_entries,
		"candidate_buckets": candidate_buckets,
		"candidate_patch_size": candidate_patch_size,
		"candidate_descriptors": candidate_descriptors,
		"candidate_corner_reports_by_stable_id": graph_delta.get("reports_by_stable_id", {}),
		"candidate_edge_to_junctions": graph_delta.get("edge_to_junctions", {}),
		"candidate_junction_to_edges": graph_delta.get("junction_to_edges", {}),
		"candidate_edge_junction_refcounts": graph_delta.get("edge_junction_refcounts", {}),
		"summary": summary.duplicate(true)
	}
	return {"ok": true, "noop": false, "summary": summary.duplicate(true)}


## Commits only the index snapshot. Production edge/cap mutation is intentionally not wired here.
## A stale generation or changed Node snapshot is rejected without changing committed state.
func commit_delta(plan_id: String) -> Dictionary:
	if not _reserved_plan_id.is_empty() and _reserved_plan_id != plan_id:
		return {"ok": false, "error": "generation_reserved", "reserved_plan_id": _reserved_plan_id}
	if not _pending_plans.has(plan_id):
		return {"ok": false, "error": "unknown_plan"}
	var plan: Dictionary = _pending_plans[plan_id]
	if int(plan.get("base_generation", -1)) != _generation:
		_pending_plans.erase(plan_id)
		if _reserved_plan_id == plan_id:
			_reserved_plan_id = ""
		return {"ok": false, "error": "stale_generation"}

	var candidate_entries: Dictionary = plan["candidate_entries"]
	var committed_entries: Dictionary = _entries_by_stable_id
	# Validate the committed side as well as the candidate side. Removed IDs are absent
	# from candidate_entries, but their old WeakRefs/snapshots still define this transaction.
	# Replacements must validate both the old and new Node instances before the index swaps.
	var touched_ids: Array = plan["summary"].get("touched_stable_ids", [])
	for stable_id_value in touched_ids:
		var stable_id: String = str(stable_id_value)
		var has_committed_record: bool = committed_entries.has(stable_id)
		if has_committed_record:
			var committed_record: Dictionary = committed_entries[stable_id]
			var committed_result: Dictionary = _record_matches_current(stable_id, committed_record)
			if not bool(committed_result.get("ok", false)):
				_pending_plans.erase(plan_id)
				if _reserved_plan_id == plan_id:
					_reserved_plan_id = ""
				return committed_result
		if candidate_entries.has(stable_id):
			var candidate_record: Dictionary = candidate_entries[stable_id]
			var validate_candidate: bool = not has_committed_record
			if has_committed_record:
				var prior_record: Dictionary = committed_entries[stable_id]
				validate_candidate = (
					int(candidate_record.get("instance_id", -1))
					!= int(prior_record.get("instance_id", -1))
				)
			if validate_candidate:
				var candidate_result: Dictionary = _record_matches_current(stable_id, candidate_record)
				if not bool(candidate_result.get("ok", false)):
					_pending_plans.erase(plan_id)
					if _reserved_plan_id == plan_id:
						_reserved_plan_id = ""
					return candidate_result

	_entries_by_stable_id = candidate_entries.duplicate()
	_bucket_to_stable_ids = plan["candidate_buckets"]
	_patch_size = float(plan["candidate_patch_size"])
	_descriptors_by_edge_key = plan.get("candidate_descriptors", {}).duplicate(false)
	_corner_reports_by_stable_id = plan.get("candidate_corner_reports_by_stable_id", {}).duplicate(false)
	_edge_to_junctions = plan.get("candidate_edge_to_junctions", {}).duplicate(false)
	_junction_to_edges = plan.get("candidate_junction_to_edges", {}).duplicate(false)
	_edge_junction_refcounts = plan.get("candidate_edge_junction_refcounts", {}).duplicate(false)
	_generation += 1
	_pending_plans.erase(plan_id)
	if _reserved_plan_id == plan_id:
		_reserved_plan_id = ""
	return {
		"ok": true,
		"generation": _generation,
		"patch_count": _entries_by_stable_id.size(),
		"summary": plan["summary"].duplicate(true)
	}


func abort_delta(plan_id: String) -> bool:
	if _reserved_plan_id == plan_id:
		_reserved_plan_id = ""
	return _pending_plans.erase(plan_id)


## Reserves the committed generation while a coordinator stages other participants.
## A different plan cannot publish until this reservation is committed or released.
func reserve_delta(plan_id: String) -> Dictionary:
	if not _pending_plans.has(plan_id):
		return {"ok": false, "error": "unknown_plan"}
	if int(_pending_plans[plan_id].get("base_generation", -1)) != _generation:
		return {"ok": false, "error": "stale_generation"}
	if not _reserved_plan_id.is_empty() and _reserved_plan_id != plan_id:
		return {"ok": false, "error": "generation_reserved", "reserved_plan_id": _reserved_plan_id}
	_reserved_plan_id = plan_id
	return {"ok": true, "plan_id": plan_id, "generation": _generation}


func release_delta_reservation(plan_id: String) -> bool:
	if _reserved_plan_id != plan_id:
		return false
	_reserved_plan_id = ""
	return true


func get_corner_reports_by_stable_id() -> Dictionary:
	return _corner_reports_by_stable_id.duplicate(true)


func get_corner_graph_stats() -> Dictionary:
	var report_count: int = 0
	for reports_value in _corner_reports_by_stable_id.values():
		if reports_value is Array:
			report_count += reports_value.size()
	var link_count: int = 0
	for count_value in _edge_junction_refcounts.values():
		link_count += int(count_value)
	return {
		"patch_count": _entries_by_stable_id.size(),
		"descriptor_count": _descriptors_by_edge_key.size(),
		"report_count": report_count,
		"junction_count": _junction_to_edges.size(),
		"edge_junction_link_count": link_count,
		"generation": _generation,
		"generation_reserved": not _reserved_plan_id.is_empty()
	}


func get_corner_graph_closure(seed_edge_keys: Array) -> Dictionary:
	return _build_union_corner_closure(
		seed_edge_keys,
		_edge_to_junctions,
		_junction_to_edges,
		_edge_to_junctions,
		_junction_to_edges
	)


func get_patch(stable_id: String) -> Node3D:
	if not _entries_by_stable_id.has(stable_id):
		return null
	var record: Dictionary = _entries_by_stable_id[stable_id]
	var patch_ref: Variant = record.get("patch_ref")
	if not (patch_ref is WeakRef):
		return null
	return patch_ref.get_ref() as Node3D


func get_snapshot(stable_id: String) -> Dictionary:
	if not _entries_by_stable_id.has(stable_id):
		return {}
	return _entries_by_stable_id[stable_id]["snapshot"].duplicate(true)


func get_neighbors(stable_id: String) -> Array[String]:
	if not _entries_by_stable_id.has(stable_id) or _patch_size <= 0.0:
		return []
	var record: Dictionary = _entries_by_stable_id[stable_id]
	return _collect_cardinal_neighbors(
		record["position"],
		_patch_size,
		_bucket_to_stable_ids,
		_entries_by_stable_id,
		stable_id
	)


func get_edge_descriptors() -> Dictionary:
	return _descriptors_by_edge_key.duplicate(true)


func get_patch_count() -> int:
	return _entries_by_stable_id.size()


func get_generation() -> int:
	return _generation


func get_patch_size() -> float:
	return _patch_size


func _build_corner_reports_by_stable_id(
	descriptors: Dictionary,
	entries: Dictionary,
	patch_size: float,
	selected_ids: Dictionary = {},
	filter_selected: bool = false
) -> Dictionary:
	var resolver_candidates: Dictionary = {}
	for edge_key_value in descriptors.keys():
		var edge_key: String = str(edge_key_value)
		var descriptor_value: Variant = descriptors[edge_key_value]
		if not (descriptor_value is Dictionary):
			return {"ok": false, "error": "invalid_corner_descriptor"}
		var descriptor: Dictionary = descriptor_value
		if not bool(descriptor.get("transition_required", false)):
			continue
		for required in ["first_stable_id", "second_stable_id", "first_side", "second_side"]:
			if not descriptor.has(required):
				return {"ok": false, "error": "corner_descriptor_missing_" + required}
		resolver_candidates[edge_key] = {
			"first_id": str(descriptor["first_stable_id"]),
			"second_id": str(descriptor["second_stable_id"]),
			"first_side": str(descriptor["first_side"]),
			"second_side": str(descriptor["second_side"])
		}
	var resolved: Dictionary = CornerResolverScript.resolve(resolver_candidates)
	if not bool(resolved.get("ok", false)):
		return {"ok": false, "error": "corner_resolve_failed:" + str(resolved.get("error", "unknown"))}
	var reports_by_stable_id: Dictionary = {}
	for report_value in resolved.get("reports", []):
		if not (report_value is Dictionary):
			return {"ok": false, "error": "invalid_corner_report"}
		var report: Dictionary = report_value
		var stable_id: String = str(report.get("stable_id", ""))
		if stable_id.is_empty():
			return {"ok": false, "error": "invalid_corner_report_stable_id"}
		if filter_selected and not selected_ids.has(stable_id):
			continue
		if not entries.has(stable_id):
			return {"ok": false, "error": "corner_report_patch_missing"}
		var record: Dictionary = entries[stable_id]
		var position_value: Variant = record.get("position", null)
		if not (position_value is Vector3):
			return {"ok": false, "error": "corner_report_position_missing"}
		var junction_key: String = AffectedComponentPlannerScript.junction_key_for_corner(
			position_value,
			str(report.get("corner", "")),
			patch_size
		)
		if junction_key.is_empty():
			return {"ok": false, "error": "corner_report_junction_invalid"}
		var stored_report: Dictionary = report.duplicate(true)
		stored_report["junction_key"] = junction_key
		if not reports_by_stable_id.has(stable_id):
			reports_by_stable_id[stable_id] = []
		var stable_reports: Array = reports_by_stable_id[stable_id]
		stable_reports.append(stored_report)
		reports_by_stable_id[stable_id] = stable_reports
	return {"ok": true, "reports_by_stable_id": reports_by_stable_id}


func _build_corner_graph(reports_by_stable_id: Dictionary) -> Dictionary:
	var edge_to_junctions: Dictionary = {}
	var junction_to_edges: Dictionary = {}
	var edge_junction_refcounts: Dictionary = {}
	var copied_edge_arrays: Dictionary = {}
	var copied_junction_arrays: Dictionary = {}
	var report_count: int = 0
	for reports_value in reports_by_stable_id.values():
		if not (reports_value is Array):
			return {"ok": false, "error": "invalid_corner_report_bucket"}
		for report_value in reports_value:
			if not (report_value is Dictionary):
				return {"ok": false, "error": "invalid_corner_report"}
			var report: Dictionary = report_value
			var junction_key: String = str(report.get("junction_key", ""))
			var edge_keys: Variant = report.get("edge_keys", null)
			if junction_key.is_empty() or not (edge_keys is Array) or edge_keys.size() != 2:
				return {"ok": false, "error": "invalid_corner_graph_report"}
			for edge_key_value in edge_keys:
				var edge_key: String = str(edge_key_value)
				if edge_key.is_empty() or not _add_corner_graph_link(
					edge_key,
					junction_key,
					edge_to_junctions,
					junction_to_edges,
					edge_junction_refcounts,
					copied_edge_arrays,
					copied_junction_arrays
				):
					return {"ok": false, "error": "corner_graph_link_invalid"}
			report_count += 1
	return {
		"ok": true,
		"reports_by_stable_id": reports_by_stable_id.duplicate(true),
		"edge_to_junctions": edge_to_junctions,
		"junction_to_edges": junction_to_edges,
		"edge_junction_refcounts": edge_junction_refcounts,
		"report_count": report_count
	}


func _apply_corner_report_delta(touched_ids: Dictionary, replacement_reports: Dictionary) -> Dictionary:
	var next_reports: Dictionary = _corner_reports_by_stable_id.duplicate(false)
	var next_edge_to_junctions: Dictionary = _edge_to_junctions.duplicate(false)
	var next_junction_to_edges: Dictionary = _junction_to_edges.duplicate(false)
	var next_refcounts: Dictionary = _edge_junction_refcounts.duplicate(false)
	var copied_edge_arrays: Dictionary = {}
	var copied_junction_arrays: Dictionary = {}
	for stable_id in _sorted_strings(touched_ids.keys()):
		var old_reports: Array = _corner_reports_by_stable_id.get(stable_id, [])
		for report_value in old_reports:
			if not (report_value is Dictionary):
				return {"ok": false, "error": "committed_corner_report_invalid"}
			var old_report: Dictionary = report_value
			for edge_key_value in old_report.get("edge_keys", []):
				if not _remove_corner_graph_link(
					str(edge_key_value),
					str(old_report.get("junction_key", "")),
					next_edge_to_junctions,
					next_junction_to_edges,
					next_refcounts,
					copied_edge_arrays,
					copied_junction_arrays
				):
					return {"ok": false, "error": "committed_corner_graph_inconsistent"}
		next_reports.erase(stable_id)
		var new_reports: Array = replacement_reports.get(stable_id, [])
		if not new_reports.is_empty():
			var stored_reports: Array = new_reports.duplicate(true)
			next_reports[stable_id] = stored_reports
			for new_report_value in stored_reports:
				var new_report: Dictionary = new_report_value
				for edge_key_value in new_report.get("edge_keys", []):
					if not _add_corner_graph_link(
						str(edge_key_value),
						str(new_report.get("junction_key", "")),
						next_edge_to_junctions,
						next_junction_to_edges,
						next_refcounts,
						copied_edge_arrays,
						copied_junction_arrays
					):
						return {"ok": false, "error": "candidate_corner_graph_invalid"}
	var report_count: int = 0
	for reports_value in next_reports.values():
		if reports_value is Array:
			report_count += reports_value.size()
	return {
		"ok": true,
		"reports_by_stable_id": next_reports,
		"edge_to_junctions": next_edge_to_junctions,
		"junction_to_edges": next_junction_to_edges,
		"edge_junction_refcounts": next_refcounts,
		"report_count": report_count
	}


func _add_corner_graph_link(
	edge_key: String,
	junction_key: String,
	edge_to_junctions: Dictionary,
	junction_to_edges: Dictionary,
	refcounts: Dictionary,
	copied_edge_arrays: Dictionary,
	copied_junction_arrays: Dictionary
) -> bool:
	if edge_key.is_empty() or junction_key.is_empty():
		return false
	var link_key: String = _corner_graph_link_key(edge_key, junction_key)
	var prior_count: int = int(refcounts.get(link_key, 0))
	if prior_count == 0:
		var junctions: Array = _mutable_graph_array(edge_to_junctions, edge_key, copied_edge_arrays)
		if not junctions.has(junction_key):
			junctions.append(junction_key)
		edge_to_junctions[edge_key] = junctions
		var edges: Array = _mutable_graph_array(junction_to_edges, junction_key, copied_junction_arrays)
		if not edges.has(edge_key):
			edges.append(edge_key)
		junction_to_edges[junction_key] = edges
	refcounts[link_key] = prior_count + 1
	return true


func _remove_corner_graph_link(
	edge_key: String,
	junction_key: String,
	edge_to_junctions: Dictionary,
	junction_to_edges: Dictionary,
	refcounts: Dictionary,
	copied_edge_arrays: Dictionary,
	copied_junction_arrays: Dictionary
) -> bool:
	var link_key: String = _corner_graph_link_key(edge_key, junction_key)
	var prior_count: int = int(refcounts.get(link_key, 0))
	if prior_count <= 0:
		return false
	if prior_count > 1:
		refcounts[link_key] = prior_count - 1
		return true
	refcounts.erase(link_key)
	var junctions: Array = _mutable_graph_array(edge_to_junctions, edge_key, copied_edge_arrays)
	junctions.erase(junction_key)
	if junctions.is_empty():
		edge_to_junctions.erase(edge_key)
	else:
		edge_to_junctions[edge_key] = junctions
	var edges: Array = _mutable_graph_array(junction_to_edges, junction_key, copied_junction_arrays)
	edges.erase(edge_key)
	if edges.is_empty():
		junction_to_edges.erase(junction_key)
	else:
		junction_to_edges[junction_key] = edges
	return true


func _mutable_graph_array(source: Dictionary, key: String, copied: Dictionary) -> Array:
	if not copied.has(key):
		var existing: Array = source.get(key, [])
		source[key] = existing.duplicate()
		copied[key] = true
	return source.get(key, [])


func _corner_graph_link_key(edge_key: String, junction_key: String) -> String:
	return "%d:%s%d:%s" % [edge_key.length(), edge_key, junction_key.length(), junction_key]


func _build_union_corner_closure(
	seed_edge_keys: Array,
	old_edge_to_junctions: Dictionary,
	old_junction_to_edges: Dictionary,
	candidate_edge_to_junctions: Dictionary,
	candidate_junction_to_edges: Dictionary
) -> Dictionary:
	var queue: Array[String] = []
	var seed_seen: Dictionary = {}
	for seed_value in seed_edge_keys:
		if not (seed_value is String) or str(seed_value).strip_edges().is_empty():
			return {"ok": false, "error": "invalid_corner_closure_seed"}
		var seed_key: String = seed_value
		if not seed_seen.has(seed_key):
			seed_seen[seed_key] = true
			queue.append(seed_key)
	queue.sort()
	var visited_edges: Dictionary = {}
	var visited_junctions: Dictionary = {}
	var queue_index: int = 0
	while queue_index < queue.size():
		var edge_key: String = queue[queue_index]
		queue_index += 1
		if visited_edges.has(edge_key):
			continue
		visited_edges[edge_key] = true
		var linked_junctions: Array[String] = _union_sorted_strings(
			old_edge_to_junctions.get(edge_key, []),
			candidate_edge_to_junctions.get(edge_key, [])
		)
		for junction_key in linked_junctions:
			if visited_junctions.has(junction_key):
				continue
			visited_junctions[junction_key] = true
			var linked_edges: Array[String] = _union_sorted_strings(
				old_junction_to_edges.get(junction_key, []),
				candidate_junction_to_edges.get(junction_key, [])
			)
			for linked_edge in linked_edges:
				if not visited_edges.has(linked_edge):
					queue.append(linked_edge)
	return {
		"ok": true,
		"edge_keys": _sorted_strings(visited_edges.keys()),
		"junction_keys": _sorted_strings(visited_junctions.keys())
	}


func _union_sorted_strings(first: Array, second: Array) -> Array[String]:
	var values: Dictionary = {}
	for value in first:
		values[str(value)] = true
	for value in second:
		values[str(value)] = true
	return _sorted_strings(values.keys())


func _select_descriptors(source: Dictionary, selected_keys: Array) -> Dictionary:
	var result: Dictionary = {}
	for key_value in selected_keys:
		var key: String = str(key_value)
		if source.has(key):
			result[key] = source[key].duplicate(true)
	return result


func _collect_corner_reports_for_junctions(
	reports_by_stable_id: Dictionary,
	selected_junctions: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stable_ids: Array[String] = _sorted_strings(reports_by_stable_id.keys())
	for stable_id in stable_ids:
		for report_value in reports_by_stable_id[stable_id]:
			if not (report_value is Dictionary):
				continue
			var report: Dictionary = report_value
			if selected_junctions.has(str(report.get("junction_key", ""))):
				result.append(report.duplicate(true))
	result.sort_custom(Callable(self, "_corner_report_less"))
	return result


func _corner_report_less(first: Dictionary, second: Dictionary) -> bool:
	if str(first.get("stable_id", "")) != str(second.get("stable_id", "")):
		return str(first.get("stable_id", "")) < str(second.get("stable_id", ""))
	if str(first.get("corner", "")) != str(second.get("corner", "")):
		return str(first.get("corner", "")) < str(second.get("corner", ""))
	return str(first.get("edge_keys", [])) < str(second.get("edge_keys", []))


func _old_report_count_for_ids(reports_by_stable_id: Dictionary, selected_ids: Dictionary) -> int:
	var count: int = 0
	for stable_id_value in selected_ids.keys():
		var reports: Variant = reports_by_stable_id.get(str(stable_id_value), [])
		if reports is Array:
			count += reports.size()
	return count


func _make_record(patch: Node3D, stable_id: String) -> Dictionary:
	if not is_instance_valid(patch) or not patch.is_inside_tree() or patch.is_queued_for_deletion():
		return {"ok": false, "error": "invalid_patch"}
	if stable_id.strip_edges().is_empty():
		return {"ok": false, "error": "invalid_stable_id"}
	if not patch.has_method("get_edge_ramp_profile") or not patch.has_method("get_world_object_state") or not patch.has_method("validate_world_object_state"):
		return {"ok": false, "error": "unsupported_patch"}
	var profile_value: Variant = patch.call("get_edge_ramp_profile")
	if not (profile_value is Dictionary):
		return {"ok": false, "error": "invalid_patch_profile"}
	var profile: Dictionary = profile_value
	var size_value: Variant = profile.get("patch_size", 0.0)
	if not (size_value is int or size_value is float):
		return {"ok": false, "error": "invalid_patch_size"}
	var patch_size: float = float(size_value)
	if is_nan(patch_size) or is_inf(patch_size) or patch_size <= 0.0:
		return {"ok": false, "error": "invalid_patch_size"}

	var position: Vector3 = patch.global_position
	if not _is_finite_vector3(position):
		return {"ok": false, "error": "invalid_patch_position"}
	var state_value: Variant = patch.call("get_world_object_state")
	if not (state_value is Dictionary):
		return {"ok": false, "error": "invalid_patch_state"}
	var state: Dictionary = state_value
	if not bool(patch.call("validate_world_object_state", state)):
		return {"ok": false, "error": "invalid_patch_state"}
	if not state.has("height_level") or not state.has("revision"):
		return {"ok": false, "error": "invalid_patch_state"}

	var snapshot: Dictionary = {
		"stable_id": stable_id,
		"position": position,
		"patch_size": patch_size,
		"height_level": state["height_level"],
		"revision": state["revision"],
		"state": state.duplicate(true)
	}
	return {
		"ok": true,
		"record": {
			"patch_ref": weakref(patch),
			"instance_id": patch.get_instance_id(),
			"position": position,
			"bucket": _position_bucket(position),
			"snapshot": snapshot
		}
	}


func _record_matches_current(stable_id: String, stored_record: Dictionary) -> Dictionary:
	var patch_ref: Variant = stored_record.get("patch_ref")
	if not (patch_ref is WeakRef):
		return {"ok": false, "error": "stale_patch_reference"}
	var patch: Node3D = patch_ref.get_ref() as Node3D
	if not is_instance_valid(patch):
		return {"ok": false, "error": "stale_patch_reference"}
	var current_result: Dictionary = _make_record(patch, stable_id)
	if not bool(current_result.get("ok", false)):
		return {"ok": false, "error": "stale_patch_snapshot"}
	var current_record: Dictionary = current_result["record"]
	if int(current_record["instance_id"]) != int(stored_record["instance_id"]):
		return {"ok": false, "error": "stale_patch_reference"}
	if current_record["position"] != stored_record["position"] or current_record["snapshot"] != stored_record["snapshot"]:
		return {"ok": false, "error": "stale_patch_snapshot"}
	return {"ok": true}


func _has_duplicate_position(record: Dictionary, buckets: Dictionary, entries: Dictionary) -> bool:
	var position: Vector3 = record["position"]
	var bucket: Vector3i = record["bucket"]
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			for z_offset in range(-1, 2):
				var neighbor_bucket: Vector3i = bucket + Vector3i(x_offset, y_offset, z_offset)
				var candidate_ids: Array = buckets.get(neighbor_bucket, [])
				for candidate_id_value in candidate_ids:
					var candidate_id: String = str(candidate_id_value)
					if not entries.has(candidate_id):
						continue
					var candidate_position: Vector3 = entries[candidate_id]["position"]
					if candidate_position.distance_to(position) <= POSITION_TOLERANCE:
						return true
	return false


func _contains_instance(entries: Dictionary, instance_id: int) -> bool:
	for record_value in entries.values():
		var record: Dictionary = record_value
		if int(record.get("instance_id", -1)) == instance_id:
			return true
	return false


func _first_patch_size(entries: Dictionary) -> float:
	if entries.is_empty():
		return -1.0
	var first_record: Dictionary = entries.values()[0]
	return float(first_record["snapshot"]["patch_size"])


func _ensure_bucket_array_for_write(buckets: Dictionary, bucket: Vector3i, copied_buckets: Dictionary) -> Array:
	if not copied_buckets.has(bucket) or not buckets.has(bucket):
		var existing_ids: Array = buckets.get(bucket, [])
		buckets[bucket] = existing_ids.duplicate()
		copied_buckets[bucket] = true
	return buckets[bucket]


func _add_bucket_id(buckets: Dictionary, bucket: Vector3i, stable_id: String, copied_buckets: Dictionary) -> void:
	var ids: Array = _ensure_bucket_array_for_write(buckets, bucket, copied_buckets)
	ids.append(stable_id)
	buckets[bucket] = ids


func _remove_bucket_id(buckets: Dictionary, bucket: Vector3i, stable_id: String, copied_buckets: Dictionary) -> void:
	if not buckets.has(bucket):
		return
	var ids: Array = _ensure_bucket_array_for_write(buckets, bucket, copied_buckets)
	ids.erase(stable_id)
	if ids.is_empty():
		buckets.erase(bucket)
	else:
		buckets[bucket] = ids


func _collect_cardinal_neighbors(
	position: Vector3,
	patch_size: float,
	buckets: Dictionary,
	entries: Dictionary,
	excluded_stable_id: String = ""
) -> Array[String]:
	var neighbor_map: Dictionary = {}
	if patch_size <= 0.0:
		return []
	for side in SIDES:
		var target_bucket: Vector3i = _position_bucket(position + _side_offset(side, patch_size))
		for x_offset in range(-1, 2):
			for y_offset in range(-1, 2):
				for z_offset in range(-1, 2):
					var bucket: Vector3i = target_bucket + Vector3i(x_offset, y_offset, z_offset)
					var candidate_ids: Array = buckets.get(bucket, [])
					for candidate_id_value in candidate_ids:
						var candidate_id: String = str(candidate_id_value)
						if candidate_id == excluded_stable_id or not entries.has(candidate_id):
							continue
						var candidate_position: Vector3 = entries[candidate_id]["position"]
						if _side_between(position, candidate_position, patch_size) == side:
							neighbor_map[candidate_id] = true
	var neighbors: Array[String] = []
	for neighbor_id_value in neighbor_map.keys():
		neighbors.append(str(neighbor_id_value))
	neighbors.sort()
	return neighbors


func _build_descriptors_for_all(entries: Dictionary, buckets: Dictionary, patch_size: float) -> Dictionary:
	var selected_ids: Dictionary = {}
	for stable_id_value in entries.keys():
		selected_ids[str(stable_id_value)] = true
	return _build_descriptors_for_ids(entries, buckets, selected_ids, patch_size)


func _build_descriptors_for_ids(
	entries: Dictionary,
	buckets: Dictionary,
	selected_ids: Dictionary,
	patch_size: float
) -> Dictionary:
	var descriptors: Dictionary = {}
	if patch_size <= 0.0:
		return {"ok": true, "descriptors": descriptors}
	var stable_ids: Array[String] = []
	for stable_id_value in selected_ids.keys():
		stable_ids.append(str(stable_id_value))
	stable_ids.sort()
	for stable_id in stable_ids:
		if not entries.has(stable_id):
			continue
		var record: Dictionary = entries[stable_id]
		var neighbors: Array[String] = _collect_cardinal_neighbors(
			record["position"],
			patch_size,
			buckets,
			entries,
			stable_id
		)
		for neighbor_id in neighbors:
			var built: Dictionary = TransitionDescriptorScript.build(
				record["snapshot"],
				entries[neighbor_id]["snapshot"]
			)
			if not bool(built.get("ok", false)):
				return {"ok": false, "error": "descriptor_invalid:" + str(built.get("error", "unknown"))}
			var descriptor: Dictionary = built.get("descriptor", {})
			var edge_key: String = str(descriptor.get("edge_key", ""))
			if not descriptors.has(edge_key):
				descriptors[edge_key] = descriptor.duplicate(true)
	return {"ok": true, "descriptors": descriptors}


func _sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	result.sort()
	return result


func _position_bucket(position: Vector3) -> Vector3i:
	return Vector3i(
		floori(position.x / POSITION_TOLERANCE),
		floori(position.y / POSITION_TOLERANCE),
		floori(position.z / POSITION_TOLERANCE)
	)


func _side_offset(side: String, patch_size: float) -> Vector3:
	match side:
		"east": return Vector3(patch_size, 0.0, 0.0)
		"west": return Vector3(-patch_size, 0.0, 0.0)
		"north": return Vector3(0.0, 0.0, -patch_size)
		"south": return Vector3(0.0, 0.0, patch_size)
		_: return Vector3.ZERO


func _side_between(first: Vector3, second: Vector3, patch_size: float) -> String:
	var delta: Vector3 = second - first
	if absf(delta.y) > POSITION_TOLERANCE:
		return ""
	if absf(delta.x - patch_size) <= POSITION_TOLERANCE and absf(delta.z) <= POSITION_TOLERANCE:
		return "east"
	if absf(delta.x + patch_size) <= POSITION_TOLERANCE and absf(delta.z) <= POSITION_TOLERANCE:
		return "west"
	if absf(delta.z + patch_size) <= POSITION_TOLERANCE and absf(delta.x) <= POSITION_TOLERANCE:
		return "north"
	if absf(delta.z - patch_size) <= POSITION_TOLERANCE and absf(delta.x) <= POSITION_TOLERANCE:
		return "south"
	return ""


func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)

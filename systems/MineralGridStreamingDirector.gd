extends Node
class_name MineralGridStreamingDirector

## Spatial streaming coordinator for chunks supplied by a generator callback.
## It selects a square grid around a world position and delegates chunk ownership to
## MineralChunkController. Bounded async requests stage factory roots across frames; terrain
## generation stays in the factory and committed chunk ownership stays in the controller.
signal sync_failed(report: Dictionary)
signal async_sync_completed(request_id: int, report: Dictionary)

const ControllerScript = preload("res://systems/MineralChunkController.gd")
const MAX_SAFE_GRID_COORDINATE: float = 1000000000.0
const MAX_ASYNC_DIAGNOSTIC_HISTORY: int = 32

@export_range(1.0, 4096.0, 1.0) var chunk_size_x: float = 64.0
@export_range(1.0, 4096.0, 1.0) var chunk_size_z: float = 64.0
@export_range(0, 8, 1) var load_radius: int = 1

var _chunk_controller: Node3D
var chunk_controller: Node3D:
	get:
		return _chunk_controller
	set(value):
		bind_controller(value)

var _chunk_factory: Callable
var chunk_factory: Callable:
	get:
		return _chunk_factory
	set(value):
		bind_chunk_factory(value)
var _managed_chunk_ids: Dictionary = {} # chunk ID -> Vector2i coordinate
var _last_sync_report: Dictionary = {}
var _next_async_request_id: int = 1
var _active_async_request_id: int = -1
var _async_staged_roots_by_request: Dictionary = {}
var _async_request_diagnostics: Dictionary = {}
var _async_phase_profiling_enabled: bool = false

func bind_controller(candidate: Node3D) -> bool:
	if candidate == null or not is_instance_valid(candidate) or not candidate.is_inside_tree() or candidate.is_queued_for_deletion():
		return false
	# An in-flight request stages roots for this exact controller. Do not let a
	# dependency swap redirect its later non-yielding commit to another owner.
	if _active_async_request_id >= 0:
		return false
	for method_name in ["load_chunk", "unload_chunk", "is_chunk_loaded"]:
		if not candidate.has_method(method_name):
			return false
	if not _managed_chunk_ids.is_empty() and chunk_controller != candidate:
		return false
	_chunk_controller = candidate
	return true

## The factory receives a grid coordinate and must return a new, unparented Node3D root.
## Return null to signal generation failure. The director takes ownership only after load succeeds.
func bind_chunk_factory(factory: Callable) -> bool:
	if not factory.is_valid() or _active_async_request_id >= 0:
		return false
	# Keep one factory identity for the entire multi-frame staging transaction.
	_chunk_factory = factory
	return true

## Opt-in profiling for async Director phases. Disabled by default to avoid timing overhead in normal play.
func set_async_phase_profiling_enabled(enabled: bool) -> void:
	_async_phase_profiling_enabled = enabled

func is_async_phase_profiling_enabled() -> bool:
	return _async_phase_profiling_enabled

func _start_async_phase_timer(request_id: int) -> int:
	var diagnostic: Dictionary = _async_request_diagnostics.get(request_id, {})
	return Time.get_ticks_usec() if bool(diagnostic.get("phase_profile_enabled", false)) else -1

func _finish_async_phase_timer(request_id: int, key: String, started_usec: int) -> void:
	if started_usec < 0:
		return
	var diagnostic: Dictionary = _async_request_diagnostics.get(request_id, {})
	if diagnostic.is_empty() or not bool(diagnostic.get("phase_profile_enabled", false)):
		return
	diagnostic[key] = int(diagnostic.get(key, 0)) + maxi(0, Time.get_ticks_usec() - started_usec)
	_async_request_diagnostics[request_id] = diagnostic

func _increment_async_phase_counter(request_id: int, key: String) -> void:
	var diagnostic: Dictionary = _async_request_diagnostics.get(request_id, {})
	if diagnostic.is_empty() or not bool(diagnostic.get("phase_profile_enabled", false)):
		return
	diagnostic[key] = int(diagnostic.get(key, 0)) + 1
	_async_request_diagnostics[request_id] = diagnostic

func _validate_async_staged_roots_profiled(request_id: int, staged_roots: Dictionary) -> Dictionary:
	var started_usec: int = _start_async_phase_timer(request_id)
	var result: Dictionary = _validate_async_staged_roots(staged_roots)
	_finish_async_phase_timer(request_id, "staged_validation_usec", started_usec)
	return result

func sync_to_world_position(world_position: Vector3, now_unix: int = -1) -> bool:
	if _active_async_request_id >= 0:
		cancel_async_sync_request(_active_async_request_id)
	if _controller_ready_for_sync() and chunk_controller.has_method("has_pending_terrain_adjacency_recovery") and bool(chunk_controller.call("has_pending_terrain_adjacency_recovery")):
		var recovery_result: Dictionary = chunk_controller.call("retry_terrain_adjacency_recovery")
		if not bool(recovery_result.get("ok", false)):
			_set_sync_report(false, "terrain_adjacency_recovery", "Controller must finish its retained terrain transaction before another window shift.", false, {"recovery": recovery_result.duplicate(true)})
			return false
		_reconcile_managed_chunk_ids_from_controller()
	# A queued root may still occupy the Controller's Stable-ID slot. Its same-ID
	# replacement path must retire that root immediately, not stage it as a pending
	# batch unload and overwrite the slot before the old root is finalized.
	var has_unloaded_managed_root: bool = false
	if _controller_ready_for_sync():
		for chunk_id_value in _managed_chunk_ids.keys():
			if not chunk_controller.is_chunk_loaded(str(chunk_id_value)):
				has_unloaded_managed_root = true
				break
	var supports_adjacency_batch: bool = (
		_controller_ready_for_sync()
		and not has_unloaded_managed_root
		and chunk_controller.has_method("begin_terrain_adjacency_batch")
		and chunk_controller.has_method("end_terrain_adjacency_batch")
	)
	if not supports_adjacency_batch:
		return _sync_to_world_position_unbatched(world_position, now_unix)
	if not bool(chunk_controller.call("begin_terrain_adjacency_batch")):
		_set_sync_report(false, "terrain_adjacency_batch", "Controller rejected the synchronous terrain adjacency batch.", true)
		return false

	var previous_managed: Dictionary = _managed_chunk_ids.duplicate(true)
	var sync_succeeded: bool = _sync_to_world_position_unbatched(world_position, now_unix)
	var sync_report: Dictionary = get_last_sync_report()
	var batch_result: Dictionary = _end_controller_terrain_adjacency_batch()
	if sync_succeeded and bool(batch_result.get("ok", false)):
		var success_details: Dictionary = sync_report.get("details", {}).duplicate(true)
		success_details["adjacency_batch"] = batch_result.duplicate(true)
		_set_sync_report(true, "complete", "", true, success_details)
		return true

	if not sync_succeeded:
		var failure_details: Dictionary = sync_report.get("details", {}).duplicate(true)
		failure_details["adjacency_batch"] = batch_result.duplicate(true)
		var rollback_complete: bool = (
			bool(sync_report.get("rollback_complete", false))
			and bool(batch_result.get("ok", false))
		)
		if not bool(batch_result.get("ok", false)):
			failure_details["adjacency_batch_error"] = str(batch_result.get("error", "unknown"))
		_reconcile_managed_chunk_ids_from_controller()
		_set_sync_report(
			false,
			str(sync_report.get("phase", "terrain_adjacency_batch")),
			str(sync_report.get("message", "Synchronous chunk window update failed.")),
			rollback_complete,
			failure_details
		)
		return false

	# The chunk registrations succeeded, but the shared terrain batch did not commit.
	# Restore the prior window in a second batch: retire newly loaded roots, recreate any
	# stale roots that the failed finalize already retired, then publish one coherent rebind.
	var commit_failure_details: Dictionary = sync_report.get("details", {}).duplicate(true)
	if chunk_controller.has_method("has_pending_terrain_adjacency_recovery") and bool(chunk_controller.call("has_pending_terrain_adjacency_recovery")):
		var pending_map_reconciled: bool = _reconcile_managed_chunk_ids_from_controller()
		commit_failure_details["controller_recovery_pending"] = true
		commit_failure_details["managed_map_reconciled"] = pending_map_reconciled
		_set_sync_report(
			false,
			"terrain_adjacency_recovery_pending",
			"Controller retained a multi-participant terrain transaction; chunk roots remain owned until its retry completes.",
			false,
			commit_failure_details
		)
		return false
	var newly_loaded_ids: Array[String] = []
	for raw_id in commit_failure_details.get("newly_loaded_ids", []):
		newly_loaded_ids.append(str(raw_id))
	var unloaded_stale_ids: Array[String] = []
	for raw_id in commit_failure_details.get("unloaded_stale_ids", []):
		unloaded_stale_ids.append(str(raw_id))
	var stale_restore_entries: Array[Dictionary] = []
	for stale_id in unloaded_stale_ids:
		if previous_managed.has(stale_id):
			stale_restore_entries.append({"id": stale_id, "coord": previous_managed[stale_id]})

	var recovery_started: bool = (
		_controller_ready_for_sync()
		and chunk_controller.has_method("begin_terrain_adjacency_batch")
		and bool(chunk_controller.call("begin_terrain_adjacency_batch"))
	)
	var new_loads_rollback_ok: bool = false
	var stale_restore_ok: bool = false
	var recovery_batch_result: Dictionary = {"ok": false, "error": "recovery_batch_not_started"}
	if recovery_started:
		new_loads_rollback_ok = _rollback_new_loads(newly_loaded_ids, now_unix)
		stale_restore_ok = _restore_unloaded_chunks(stale_restore_entries, now_unix)
		recovery_batch_result = _end_controller_terrain_adjacency_batch()
	var managed_map_reconciled: bool = _reconcile_managed_chunk_ids_from_controller()
	var recovery_complete: bool = (
		recovery_started
		and new_loads_rollback_ok
		and stale_restore_ok
		and bool(recovery_batch_result.get("ok", false))
		and managed_map_reconciled
	)
	commit_failure_details["adjacency_batch_commit"] = batch_result.duplicate(true)
	commit_failure_details["recovery_batch"] = recovery_batch_result.duplicate(true)
	commit_failure_details["new_loads_rollback_ok"] = new_loads_rollback_ok
	commit_failure_details["stale_restore_ok"] = stale_restore_ok
	commit_failure_details["managed_map_reconciled"] = managed_map_reconciled
	_set_sync_report(
		false,
		"terrain_adjacency_commit",
		"Controller failed to commit the synchronous terrain adjacency batch.",
		recovery_complete,
		commit_failure_details
	)
	if not recovery_complete:
		push_warning("Synchronous terrain batch recovery was incomplete; inspect get_last_sync_report().")
	return false


func _sync_to_world_position_unbatched(world_position: Vector3, now_unix: int = -1) -> bool:
	if not _controller_ready_for_sync() or not chunk_factory.is_valid():
		_set_sync_report(false, "validation", "Controller must be alive, inside the scene tree and not queued for deletion; chunk factory must be available.", true)
		return false
	if not _is_finite_world_position(world_position):
		_set_sync_report(false, "validation", "World position must contain only finite coordinates.", true)
		return false
	if not is_finite(chunk_size_x) or not is_finite(chunk_size_z) or chunk_size_x <= 0.0 or chunk_size_z <= 0.0 or load_radius < 0:
		_set_sync_report(false, "validation", "Chunk dimensions and load radius must be valid.", true)
		return false
	if not _is_safe_grid_position(world_position):
		_set_sync_report(false, "validation", "World position is outside supported grid-coordinate bounds.", true)
		return false

	var center := Vector2i(
		floori(world_position.x / chunk_size_x),
		floori(world_position.z / chunk_size_z)
	)
	var desired: Array[Vector2i] = []
	for z in range(center.y - load_radius, center.y + load_radius + 1):
		for x in range(center.x - load_radius, center.x + load_radius + 1):
			desired.append(Vector2i(x, z))
	desired.sort_custom(_coordinate_less)

	var desired_ids: Dictionary = {}
	for coord in desired:
		desired_ids[_chunk_id(coord)] = coord

	# Load first. If any generation or registration fails, preserve the previous active set.
	var newly_loaded: Array[String] = []
	for coord in desired:
		var id := _chunk_id(coord)
		if _managed_chunk_ids.has(id) and chunk_controller.is_chunk_loaded(id):
			continue
		var candidate: Variant = chunk_factory.call(coord)
		var controller_alive: bool = chunk_controller != null and is_instance_valid(chunk_controller)
		if not _controller_ready_for_sync():
			_free_unowned_root(candidate)
			var controller_detached: bool = controller_alive and not chunk_controller.is_inside_tree()
			var controller_queued: bool = controller_alive and chunk_controller.is_queued_for_deletion()
			var rollback_ok: bool = false
			if controller_alive:
				rollback_ok = _rollback_new_loads(newly_loaded, now_unix)
			else:
				_managed_chunk_ids.clear()
			_set_sync_report(false, "controller_lifecycle", "Controller became unavailable during synchronous chunk generation.", rollback_ok, {
					"controller_destroyed": not controller_alive,
					"controller_detached": controller_detached,
					"controller_queued_for_deletion": controller_queued,
					"newly_loaded_ids": newly_loaded.duplicate(),
					"new_loads_rollback_ok": rollback_ok
				})
			return false
		var candidate_is_node3d: bool = is_instance_valid(candidate) and candidate is Node3D
		var candidate_queued_for_deletion: bool = candidate_is_node3d and (candidate as Node3D).is_queued_for_deletion()
		if not is_instance_valid(candidate) or not (candidate is Node3D) or candidate_queued_for_deletion or candidate.get_parent() != null:
			_free_unowned_root(candidate)
			var rollback_ok: bool = _rollback_new_loads(newly_loaded, now_unix)
			_set_sync_report(false, "load_factory", "Chunk factory returned an invalid root.", rollback_ok, {
				"failed_chunk_id": id,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"new_loads_rollback_ok": rollback_ok,
				"factory_root_queued_for_deletion": candidate_queued_for_deletion
			})
			if not rollback_ok:
				push_warning("Mineral grid streaming rollback was incomplete after invalid chunk factory output.")
			return false
		var load_succeeded: bool = chunk_controller.load_chunk(id, candidate, now_unix)
		var controller_alive_after_load: bool = chunk_controller != null and is_instance_valid(chunk_controller)
		var controller_queued_after_load: bool = controller_alive_after_load and chunk_controller.is_queued_for_deletion()
		var controller_ready_after_load: bool = _controller_ready_for_sync()
		var controller_can_rollback: bool = controller_alive_after_load and not controller_queued_after_load
		var candidate_loaded: bool = (
			controller_can_rollback
			and chunk_controller.has_method("is_chunk_loaded")
			and chunk_controller.is_chunk_loaded(id)
		)
		if candidate_loaded:
			# Record ownership before any rollback attempt so a failed unload remains
			# visible in the Director's mirror instead of becoming an orphaned root.
			_managed_chunk_ids[id] = coord
			newly_loaded.append(id)
		if not load_succeeded or not controller_ready_after_load or not candidate_loaded:
			var candidate_cleanup_ok: bool = true
			if not candidate_loaded:
				if controller_can_rollback and is_instance_valid(candidate) and candidate is Node3D and candidate.get_parent() == chunk_controller:
					chunk_controller.remove_child(candidate)
					if not (candidate as Node3D).is_queued_for_deletion():
						(candidate as Node3D).queue_free()
				elif is_instance_valid(candidate) and candidate is Node3D and candidate.get_parent() != null:
					# A queued/destroyed owner will release its child; do not mutate it.
					candidate_cleanup_ok = false
				else:
					_free_unowned_root(candidate)
			var new_loads_rollback_ok: bool = _rollback_new_loads(newly_loaded, now_unix)
			var rollback_complete: bool = candidate_cleanup_ok and new_loads_rollback_ok
			var controller_detached_after_load: bool = controller_alive_after_load and not chunk_controller.is_inside_tree()
			_set_sync_report(false, "controller_lifecycle" if not controller_ready_after_load else "load_registration", "Controller became unavailable during synchronous chunk registration." if not controller_ready_after_load else "Chunk controller rejected or failed to register a new chunk.", rollback_complete, {
				"failed_chunk_id": id,
				"controller_destroyed": not controller_alive_after_load,
				"controller_detached": controller_detached_after_load,
				"controller_queued_for_deletion": controller_queued_after_load,
				"candidate_loaded": candidate_loaded,
				"candidate_cleanup_ok": candidate_cleanup_ok,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"new_loads_rollback_ok": new_loads_rollback_ok
			})
			if not rollback_complete:
				push_warning("Mineral grid streaming rollback was incomplete after synchronous chunk registration.")
			return false

	# Only unload stale chunks after every desired chunk has loaded successfully.
	var stale_ids: Array[String] = []
	for id in _managed_chunk_ids.keys():
		if not desired_ids.has(id):
			stale_ids.append(str(id))
	stale_ids.sort()
	var unloaded_stale: Array[Dictionary] = []
	for id in stale_ids:
		var stale_coord: Vector2i = _managed_chunk_ids[id]
		if not chunk_controller.unload_chunk(id, now_unix):
			# Unloading can fail after earlier stale chunks have already been removed.
			# Restore the previous active set instead of leaving a half-shifted window.
			var new_loads_restored: bool = _rollback_new_loads(newly_loaded, now_unix)
			var old_chunks_restored: bool = _restore_unloaded_chunks(unloaded_stale, now_unix)
			var rollback_complete: bool = new_loads_restored and old_chunks_restored
			var unloaded_ids: Array[String] = []
			for entry in unloaded_stale:
				unloaded_ids.append(str(entry.get("id", "")))
			_set_sync_report(false, "stale_unload", "Controller failed to unload a stale chunk.", rollback_complete, {
				"failed_chunk_id": id,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"unloaded_stale_ids": unloaded_ids,
				"new_loads_rollback_ok": new_loads_restored,
				"stale_restore_ok": old_chunks_restored
			})
			if not rollback_complete:
				push_warning("Mineral grid streaming rollback was incomplete after stale chunk unload failure; inspect get_last_sync_report().")
			return false
		unloaded_stale.append({"id": id, "coord": stale_coord})
		_managed_chunk_ids.erase(id)

	var unloaded_stale_ids: Array[String] = []
	for entry in unloaded_stale:
		unloaded_stale_ids.append(str(entry.get("id", "")))
	_set_sync_report(true, "complete", "", true, {
		"center": center,
		"desired_count": desired.size(),
		"newly_loaded_ids": newly_loaded.duplicate(),
		"unloaded_stale_ids": unloaded_stale_ids
	})
	return true


## Start a bounded async window shift. Missing roots are generated over multiple frames;
## controller registration and stale-chunk retirement are committed only after staging succeeds.
## A newer request supersedes any request that is still in its staging phase.
func _exit_tree() -> void:
	if _active_async_request_id >= 0:
		_record_async_diagnostic(_active_async_request_id, "cancelled", {}, true, "director_exit")
	_active_async_request_id = -1
	var request_ids: Array = _async_staged_roots_by_request.keys()
	for raw_request_id in request_ids:
		var request_id: int = int(raw_request_id)
		_release_async_staged_roots(request_id, _async_staged_roots_by_request.get(request_id, {}))

func request_sync_to_world_position_async(world_position: Vector3, now_unix: int = -1, max_staged_per_frame: int = 1) -> int:
	if _controller_ready_for_sync() and chunk_controller.has_method("has_pending_terrain_adjacency_recovery") and bool(chunk_controller.call("has_pending_terrain_adjacency_recovery")):
		var recovery_result: Dictionary = chunk_controller.call("retry_terrain_adjacency_recovery")
		if not bool(recovery_result.get("ok", false)):
			_set_sync_report(false, "terrain_adjacency_recovery", "Controller must finish its retained terrain transaction before async staging can begin.", false, {"recovery": recovery_result.duplicate(true)})
			return -1
		_reconcile_managed_chunk_ids_from_controller()
	if not _async_dependencies_available():
		return -1
	if not _is_finite_world_position(world_position) or not _is_safe_grid_position(world_position):
		return -1
	if not is_finite(chunk_size_x) or not is_finite(chunk_size_z) or chunk_size_x <= 0.0 or chunk_size_z <= 0.0 or load_radius < 0:
		return -1

	var request_id: int = _next_async_request_id
	_next_async_request_id += 1
	if _active_async_request_id >= 0:
		var superseded_request_id: int = _active_async_request_id
		_record_async_diagnostic(superseded_request_id, "cancelling", {}, false, "superseded_by_request:%d" % request_id)
		_release_async_staged_roots(superseded_request_id, _async_staged_roots_by_request.get(superseded_request_id, {}))
	_active_async_request_id = request_id
	_async_request_diagnostics[request_id] = {
		"request_id": request_id,
		"phase": "queued",
		"cancellation_reason": "",
		"started_usec": Time.get_ticks_usec(),
		"finished_usec": -1,
		"duration_usec": -1,
		"staged_count": 0,
		"desired_count": 0,
		"newly_loaded_count": 0,
		"unloaded_stale_count": 0,
		"phase_profile_enabled": _async_phase_profiling_enabled,
		"max_staged_per_frame": clampi(max_staged_per_frame, 1, 8),
		"frame_yield_count": 0,
		"request_plan_usec": 0,
		"dispatch_wait_usec": 0,
		"planning_usec": 0,
		"factory_build_usec": 0,
		"staged_validation_usec": 0,
		"frame_yield_wait_usec": 0,
		"controller_registration_usec": 0,
		"staged_map_erase_usec": 0,
		"stale_unload_usec": 0,
		"adjacency_finalize_call_usec": 0,
		"rollback_complete": true,
		"terminal": false,
		"details": {}
	}
	_prune_async_diagnostics()
	var request_plan_started_usec: int = _start_async_phase_timer(request_id)
	var center := Vector2i(
		floori(world_position.x / chunk_size_x),
		floori(world_position.z / chunk_size_z)
	)
	var desired: Array[Vector2i] = []
	for z in range(center.y - load_radius, center.y + load_radius + 1):
		for x in range(center.x - load_radius, center.x + load_radius + 1):
			desired.append(Vector2i(x, z))
	desired.sort_custom(_coordinate_less)
	_finish_async_phase_timer(request_id, "request_plan_usec", request_plan_started_usec)
	var timestamp: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var request_diagnostic: Dictionary = _async_request_diagnostics.get(request_id, {})
	if bool(request_diagnostic.get("phase_profile_enabled", false)):
		request_diagnostic["scheduled_usec"] = Time.get_ticks_usec()
		_async_request_diagnostics[request_id] = request_diagnostic
	call_deferred("_run_async_sync_request", request_id, desired, timestamp, clampi(max_staged_per_frame, 1, 8))
	return request_id

func cancel_async_sync_request(request_id: int = -1) -> bool:
	if _active_async_request_id < 0:
		return false
	if request_id >= 0 and request_id != _active_async_request_id:
		return false
	var cancelled_request_id: int = _active_async_request_id
	_record_async_diagnostic(cancelled_request_id, "cancelling", {}, false, "explicit_cancel")
	_active_async_request_id = -1
	_release_async_staged_roots(cancelled_request_id, _async_staged_roots_by_request.get(cancelled_request_id, {}))
	return true

func get_active_async_request_id() -> int:
	return _active_async_request_id

func get_async_request_diagnostics(request_id: int) -> Dictionary:
	var diagnostic: Dictionary = _async_request_diagnostics.get(request_id, {})
	return diagnostic.duplicate(true)

func get_recent_async_request_diagnostics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var request_ids: Array = _async_request_diagnostics.keys()
	request_ids.sort()
	for raw_request_id in request_ids:
		var diagnostic: Dictionary = _async_request_diagnostics[int(raw_request_id)]
		result.append(diagnostic.duplicate(true))
	return result

func _record_async_diagnostic(
	request_id: int,
	phase: String,
	details: Dictionary = {},
	terminal: bool = false,
	cancellation_reason: String = ""
) -> void:
	if not _async_request_diagnostics.has(request_id):
		return
	var diagnostic: Dictionary = _async_request_diagnostics[request_id].duplicate(true)
	diagnostic["phase"] = phase
	if not cancellation_reason.is_empty():
		diagnostic["cancellation_reason"] = cancellation_reason
	var merged_details: Dictionary = diagnostic.get("details", {}).duplicate(true)
	for key in details:
		merged_details[key] = details[key]
		diagnostic[key] = details[key]
	diagnostic["details"] = merged_details
	if terminal:
		var finished_usec: int = Time.get_ticks_usec()
		diagnostic["finished_usec"] = finished_usec
		diagnostic["duration_usec"] = maxi(0, finished_usec - int(diagnostic.get("started_usec", finished_usec)))
		diagnostic["terminal"] = true
	_async_request_diagnostics[request_id] = diagnostic
	_prune_async_diagnostics()

func _prune_async_diagnostics() -> void:
	var request_ids: Array = _async_request_diagnostics.keys()
	request_ids.sort()
	while request_ids.size() > MAX_ASYNC_DIAGNOSTIC_HISTORY:
		var oldest_request_id: int = int(request_ids.pop_front())
		if oldest_request_id != _active_async_request_id:
			_async_request_diagnostics.erase(oldest_request_id)

func _run_async_sync_request(request_id: int, desired: Array[Vector2i], now_unix: int, max_staged_per_frame: int) -> void:
	var request_diagnostic: Dictionary = _async_request_diagnostics.get(request_id, {})
	var dispatch_started_usec: int = int(request_diagnostic.get("scheduled_usec", -1))
	if dispatch_started_usec >= 0:
		_finish_async_phase_timer(request_id, "dispatch_wait_usec", dispatch_started_usec)
		request_diagnostic = _async_request_diagnostics.get(request_id, {})
		request_diagnostic.erase("scheduled_usec")
		_async_request_diagnostics[request_id] = request_diagnostic
	var staged_roots: Dictionary = {}
	_async_staged_roots_by_request[request_id] = staged_roots
	_record_async_diagnostic(request_id, "staging", {"desired_count": desired.size()}, false)
	if request_id != _active_async_request_id:
		_release_async_staged_roots(request_id, staged_roots)
		_emit_async_cancelled(request_id, 0)
		return
	var planning_started_usec: int = _start_async_phase_timer(request_id)
	if not _async_dependencies_available():
		_finish_async_phase_timer(request_id, "planning_usec", planning_started_usec)
		_abort_async_sync_request(request_id, staged_roots, 0)
		return
	var desired_ids: Dictionary = {}
	var to_load: Array[Dictionary] = []
	for coord in desired:
		var id: String = _chunk_id(coord)
		desired_ids[id] = coord
		if _managed_chunk_ids.has(id) and chunk_controller.is_chunk_loaded(id):
			continue
		to_load.append({"id": id, "coord": coord})
	_finish_async_phase_timer(request_id, "planning_usec", planning_started_usec)

	var staged_count: int = 0
	for entry in to_load:
		if request_id != _active_async_request_id:
			_release_async_staged_roots(request_id, staged_roots)
			_emit_async_cancelled(request_id, staged_count)
			return
		if not _async_dependencies_available():
			_abort_async_sync_request(request_id, staged_roots, staged_count)
			return
		var staged_validation_before_factory: Dictionary = _validate_async_staged_roots_profiled(request_id, staged_roots)
		if not bool(staged_validation_before_factory.get("ok", false)):
			_fail_async_staged_root_validation(request_id, staged_roots, staged_count, desired.size(), staged_validation_before_factory, null, [], now_unix)
			return
		var id: String = str(entry["id"])
		var coord: Vector2i = entry["coord"]
		var factory_started_usec: int = _start_async_phase_timer(request_id)
		var candidate: Variant = chunk_factory.call(coord)
		_finish_async_phase_timer(request_id, "factory_build_usec", factory_started_usec)
		var staged_validation_after_factory: Dictionary = _validate_async_staged_roots_profiled(request_id, staged_roots)
		if not bool(staged_validation_after_factory.get("ok", false)):
			_fail_async_staged_root_validation(request_id, staged_roots, staged_count, desired.size(), staged_validation_after_factory, candidate, [], now_unix)
			return
		var candidate_is_node3d: bool = is_instance_valid(candidate) and candidate is Node3D
		var candidate_queued_for_deletion: bool = candidate_is_node3d and (candidate as Node3D).is_queued_for_deletion()
		if not is_instance_valid(candidate) or not (candidate is Node3D) or candidate_queued_for_deletion or candidate.get_parent() != null:
			_free_unowned_root(candidate)
			_release_async_staged_roots(request_id, staged_roots)
			_finish_async_sync_request(request_id, false, "load_factory", "Chunk factory returned an invalid staged root.", true, {
				"failed_chunk_id": id,
				"staged_count": staged_count,
				"desired_count": desired.size(),
				"factory_root_queued_for_deletion": candidate_queued_for_deletion
			})
			return
		var duplicate_staged_root := false
		for staged_value in staged_roots.values():
			var staged_candidate: Variant = staged_value
			if staged_candidate == candidate:
				duplicate_staged_root = true
				break
		if duplicate_staged_root:
			# A factory must return one distinct detached root per coordinate. Detect reuse
			# before commit so one Node3D can never be registered under multiple chunk IDs.
			_release_async_staged_roots(request_id, staged_roots)
			_finish_async_sync_request(request_id, false, "load_factory", "Chunk factory reused a staged root instance.", true, {
				"failed_chunk_id": id,
				"staged_count": staged_count,
				"desired_count": desired.size(),
				"duplicate_staged_root_rejected": true
			})
			return
		staged_roots[id] = candidate
		staged_count += 1
		_record_async_diagnostic(request_id, "staging", {"staged_count": staged_count}, false)
		if staged_count % max_staged_per_frame == 0:
			var frame_yield_started_usec: int = _start_async_phase_timer(request_id)
			await get_tree().process_frame
			_finish_async_phase_timer(request_id, "frame_yield_wait_usec", frame_yield_started_usec)
			_increment_async_phase_counter(request_id, "frame_yield_count")
			if request_id != _active_async_request_id:
				_release_async_staged_roots(request_id, staged_roots)
				_emit_async_cancelled(request_id, staged_count)
				return
			if not _async_dependencies_available():
				_abort_async_sync_request(request_id, staged_roots, staged_count)
				return
			var staged_validation_after_yield: Dictionary = _validate_async_staged_roots_profiled(request_id, staged_roots)
			if not bool(staged_validation_after_yield.get("ok", false)):
				_fail_async_staged_root_validation(request_id, staged_roots, staged_count, desired.size(), staged_validation_after_yield, null, [], now_unix)
				return

	if request_id != _active_async_request_id:
		_release_async_staged_roots(request_id, staged_roots)
		_emit_async_cancelled(request_id, staged_count)
		return
	if not _async_dependencies_available():
		_abort_async_sync_request(request_id, staged_roots, staged_count)
		return
	var staged_validation_before_commit: Dictionary = _validate_async_staged_roots_profiled(request_id, staged_roots)
	if not bool(staged_validation_before_commit.get("ok", false)):
		_fail_async_staged_root_validation(request_id, staged_roots, staged_count, desired.size(), staged_validation_before_commit, null, [], now_unix)
		return

	# Commit is deliberately non-yielding: no newer request can interleave with registration,
	# adjacency rebuilding, and stale-root retirement.
	_record_async_diagnostic(request_id, "committing", {"staged_count": staged_count}, false)
	var adjacency_batch_started: bool = false
	if chunk_controller.has_method("begin_terrain_adjacency_batch"):
		adjacency_batch_started = bool(chunk_controller.call("begin_terrain_adjacency_batch"))
		if not adjacency_batch_started:
			_finish_async_sync_request(request_id, false, "terrain_adjacency_commit", "Controller rejected the terrain adjacency batch.", false, {"adjacency_batch_started": false})
			return
	var newly_loaded: Array[String] = []
	for entry in to_load:
		if not _async_dependencies_available():
			_abort_async_sync_request(request_id, staged_roots, staged_count, now_unix, newly_loaded, [])
			return
		var staged_validation_during_commit: Dictionary = _validate_async_staged_roots_profiled(request_id, staged_roots)
		if not bool(staged_validation_during_commit.get("ok", false)):
			_fail_async_staged_root_validation(request_id, staged_roots, staged_count, desired.size(), staged_validation_during_commit, null, newly_loaded, now_unix)
			return
		var id: String = str(entry["id"])
		var coord: Vector2i = entry["coord"]
		var candidate: Variant = staged_roots.get(id)
		var load_succeeded: bool = (
			is_instance_valid(candidate)
			and candidate is Node3D
			and not (candidate as Node3D).is_queued_for_deletion()
			and candidate.get_parent() == null
		)
		if load_succeeded:
			var registration_started_usec: int = _start_async_phase_timer(request_id)
			load_succeeded = chunk_controller.load_chunk(id, candidate, now_unix)
			_finish_async_phase_timer(request_id, "controller_registration_usec", registration_started_usec)
		var controller_alive_after_load: bool = chunk_controller != null and is_instance_valid(chunk_controller)
		var controller_queued_after_load: bool = controller_alive_after_load and chunk_controller.is_queued_for_deletion()
		var controller_ready_after_load: bool = _controller_ready_for_sync()
		var controller_can_rollback: bool = controller_alive_after_load and not controller_queued_after_load
		var candidate_loaded: bool = (
			controller_can_rollback
			and chunk_controller.has_method("is_chunk_loaded")
			and chunk_controller.is_chunk_loaded(id)
		)
		if candidate_loaded:
			_managed_chunk_ids[id] = coord
			newly_loaded.append(id)
		if not load_succeeded or not controller_ready_after_load or not candidate_loaded:
			var candidate_cleanup_ok: bool = true
			if not candidate_loaded:
				if controller_can_rollback and is_instance_valid(candidate) and candidate is Node3D and candidate.get_parent() == chunk_controller:
					chunk_controller.remove_child(candidate)
					if not (candidate as Node3D).is_queued_for_deletion():
						(candidate as Node3D).queue_free()
				elif is_instance_valid(candidate) and candidate is Node3D and candidate.get_parent() != null:
					candidate_cleanup_ok = false
				else:
					_free_unowned_root(candidate)
			var new_loads_rollback_ok: bool = _rollback_new_loads(newly_loaded, now_unix)
			var load_failure_adjacency_finalize: Dictionary = _end_controller_terrain_adjacency_batch()
			var rollback_complete: bool = controller_alive_after_load and not controller_queued_after_load and candidate_cleanup_ok and new_loads_rollback_ok and bool(load_failure_adjacency_finalize.get("ok", false))
			var controller_detached_after_load: bool = controller_alive_after_load and not controller_queued_after_load and not chunk_controller.is_inside_tree()
			var failure_phase: String = "dependency_unavailable" if not controller_ready_after_load else "load_registration"
			staged_roots.erase(id)
			var staged_roots_released: int = _release_async_staged_roots(request_id, staged_roots)
			_finish_async_sync_request(request_id, false, failure_phase, "Controller became unavailable during async chunk registration." if not controller_ready_after_load else "Chunk controller rejected or failed to register a staged chunk.", rollback_complete, {
				"failed_chunk_id": id,
				"controller_destroyed": not controller_alive_after_load,
				"controller_detached": controller_detached_after_load,
				"controller_queued_for_deletion": controller_queued_after_load,
				"candidate_loaded": candidate_loaded,
				"candidate_cleanup_ok": candidate_cleanup_ok,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"staged_count": staged_count,
				"staged_roots_released": staged_roots_released,
				"new_loads_rollback_ok": new_loads_rollback_ok
			})
			return
		var transfer_started_usec: int = _start_async_phase_timer(request_id)
		staged_roots.erase(id)
		_finish_async_phase_timer(request_id, "staged_map_erase_usec", transfer_started_usec)

	_release_async_staged_roots(request_id, staged_roots)
	var stale_ids: Array[String] = []
	for id in _managed_chunk_ids.keys():
		if not desired_ids.has(id):
			stale_ids.append(str(id))
	stale_ids.sort()
	var unloaded_stale: Array[Dictionary] = []
	for id in stale_ids:
		if not _async_dependencies_available():
			_abort_async_sync_request(request_id, staged_roots, staged_count, now_unix, newly_loaded, unloaded_stale)
			return
		var stale_coord: Vector2i = _managed_chunk_ids[id]
		var stale_unload_started_usec: int = _start_async_phase_timer(request_id)
		var stale_unload_succeeded: bool = chunk_controller.unload_chunk(id, now_unix)
		_finish_async_phase_timer(request_id, "stale_unload_usec", stale_unload_started_usec)
		if not stale_unload_succeeded:
			var new_loads_restored: bool = _rollback_new_loads(newly_loaded, now_unix)
			var old_chunks_restored: bool = _restore_unloaded_chunks(unloaded_stale, now_unix)
			var stale_failure_adjacency_finalize: Dictionary = _end_controller_terrain_adjacency_batch()
			var rollback_complete: bool = new_loads_restored and old_chunks_restored and bool(stale_failure_adjacency_finalize.get("ok", false))
			var unloaded_ids: Array[String] = []
			for item in unloaded_stale:
				unloaded_ids.append(str(item.get("id", "")))
			_finish_async_sync_request(request_id, false, "stale_unload", "Controller failed to unload a stale chunk.", rollback_complete, {
				"failed_chunk_id": id,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"unloaded_stale_ids": unloaded_ids,
				"new_loads_rollback_ok": new_loads_restored,
				"stale_restore_ok": old_chunks_restored
			})
			return
		unloaded_stale.append({"id": id, "coord": stale_coord})
		_managed_chunk_ids.erase(id)
		_record_async_diagnostic(request_id, "retiring", {
			"staged_count": staged_count,
			"newly_loaded_count": newly_loaded.size(),
			"unloaded_stale_count": unloaded_stale.size()
		}, false)

	if not _async_dependencies_available():
		_abort_async_sync_request(request_id, staged_roots, staged_count, now_unix, newly_loaded, unloaded_stale)
		return
	var adjacency_finalize_started_usec: int = _start_async_phase_timer(request_id)
	var success_adjacency_finalize: Dictionary = _end_controller_terrain_adjacency_batch()
	_finish_async_phase_timer(request_id, "adjacency_finalize_call_usec", adjacency_finalize_started_usec)
	if not bool(success_adjacency_finalize.get("ok", false)):
		if chunk_controller.has_method("has_pending_terrain_adjacency_recovery") and bool(chunk_controller.call("has_pending_terrain_adjacency_recovery")):
			_reconcile_managed_chunk_ids_from_controller()
			_finish_async_sync_request(request_id, false, "terrain_adjacency_recovery_pending", "Controller retained a multi-participant terrain transaction; staged and departing roots remain owned until retry completes.", false, {
				"adjacency_finalize": success_adjacency_finalize,
				"controller_recovery_pending": true,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"unloaded_stale_count": unloaded_stale.size()
			})
			return
		var adjacency_failure_new_loads_restored: bool = _rollback_new_loads(newly_loaded, now_unix)
		var adjacency_failure_stale_restored: bool = _restore_unloaded_chunks(unloaded_stale, now_unix) if adjacency_failure_new_loads_restored else false
		var adjacency_failure_refresh_ok: bool = bool(chunk_controller.call("refresh_terrain_adjacency")) if _controller_ready_for_sync() and chunk_controller.has_method("refresh_terrain_adjacency") else false
		_finish_async_sync_request(request_id, false, "terrain_adjacency_commit", "Terrain adjacency batch could not be committed; the prior window was restored where possible.", adjacency_failure_new_loads_restored and adjacency_failure_stale_restored and adjacency_failure_refresh_ok, {
			"adjacency_finalize": success_adjacency_finalize,
			"new_loads_rollback_ok": adjacency_failure_new_loads_restored,
			"stale_restore_ok": adjacency_failure_stale_restored,
			"refresh_ok": adjacency_failure_refresh_ok,
			"newly_loaded_ids": newly_loaded.duplicate(),
			"unloaded_stale_count": unloaded_stale.size()
		})
		return
	_finish_async_sync_request(request_id, true, "complete", "", true, {
		"center": desired[int((desired.size() - 1) / 2)] if not desired.is_empty() else Vector2i.ZERO,
		"desired_count": desired.size(),
		"staged_count": staged_count,
		"newly_loaded_ids": newly_loaded.duplicate(),
		"unloaded_stale_count": unloaded_stale.size()
	})

func _controller_ready_for_sync() -> bool:
	return (
		chunk_controller != null
		and is_instance_valid(chunk_controller)
		and chunk_controller.is_inside_tree()
		and not chunk_controller.is_queued_for_deletion()
		and chunk_controller.has_method("load_chunk")
		and chunk_controller.has_method("unload_chunk")
		and chunk_controller.has_method("is_chunk_loaded")
	)

func _async_dependencies_available() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and _controller_ready_for_sync() and chunk_factory.is_valid()

func _validate_async_staged_roots(staged_roots: Dictionary) -> Dictionary:
	for raw_id in staged_roots.keys():
		var chunk_id: String = str(raw_id)
		var candidate: Variant = staged_roots[raw_id]
		if not is_instance_valid(candidate) or not (candidate is Node3D):
			return {"ok": false, "failed_chunk_id": chunk_id, "failure_reason": "staged_root_invalid"}
		var staged_root: Node3D = candidate as Node3D
		if staged_root.is_queued_for_deletion():
			return {"ok": false, "failed_chunk_id": chunk_id, "failure_reason": "staged_root_queued_for_deletion"}
		if staged_root.get_parent() != null:
			return {"ok": false, "failed_chunk_id": chunk_id, "failure_reason": "staged_root_parented"}
	return {"ok": true}

func _fail_async_staged_root_validation(
	request_id: int,
	staged_roots: Dictionary,
	staged_count: int,
	desired_count: int,
	validation: Dictionary,
	unowned_candidate: Variant = null,
	newly_loaded: Array[String] = [],
	now_unix: int = -1
) -> void:
	_free_unowned_root(unowned_candidate)
	var released_count: int = _release_async_staged_roots(request_id, staged_roots)
	var rollback_ok: bool = _rollback_new_loads(newly_loaded, now_unix)
	var adjacency_finalize: Dictionary = _end_controller_terrain_adjacency_batch()
	rollback_ok = rollback_ok and bool(adjacency_finalize.get("ok", false))
	_finish_async_sync_request(
		request_id,
		false,
		"staged_root_validation",
		"A staged chunk root changed lifecycle before the async commit completed.",
		rollback_ok,
		{
			"failed_chunk_id": str(validation.get("failed_chunk_id", "")),
			"failure_reason": str(validation.get("failure_reason", "staged_root_invalid")),
			"staged_count": staged_count,
			"desired_count": desired_count,
			"staged_roots_released": released_count,
			"newly_loaded_ids": newly_loaded.duplicate(),
			"new_loads_rollback_ok": rollback_ok
		}
	)

func _abort_async_sync_request(
	request_id: int,
	staged_roots: Dictionary,
	staged_count: int,
	now_unix: int = -1,
	newly_loaded: Array[String] = [],
	unloaded_stale: Array[Dictionary] = []
) -> void:
	var released_count: int = _release_async_staged_roots(request_id, staged_roots)
	var controller_destroyed: bool = (
		chunk_controller == null
		or not is_instance_valid(chunk_controller)
		or chunk_controller.is_queued_for_deletion()
	)
	var controller_detached: bool = controller_destroyed
	if not controller_destroyed and is_instance_valid(chunk_controller):
		controller_detached = not chunk_controller.is_inside_tree()
	var new_loads_rollback_ok: bool = true
	var stale_restore_ok: bool = true
	var rollback_complete: bool = true
	if controller_destroyed:
		# The controller owns every committed root. Once it is destroyed, its active
		# window no longer exists and the director must be allowed to bind a replacement.
		_managed_chunk_ids.clear()
		rollback_complete = false
		new_loads_rollback_ok = newly_loaded.is_empty()
		stale_restore_ok = unloaded_stale.is_empty()
	else:
		if not newly_loaded.is_empty():
			new_loads_rollback_ok = _rollback_new_loads(newly_loaded, now_unix)
		if new_loads_rollback_ok and not unloaded_stale.is_empty():
			stale_restore_ok = _restore_unloaded_chunks(unloaded_stale, now_unix)
		rollback_complete = new_loads_rollback_ok and stale_restore_ok
	var adjacency_finalize: Dictionary = _end_controller_terrain_adjacency_batch()
	rollback_complete = rollback_complete and bool(adjacency_finalize.get("ok", false))
	var cancellation_reason: String = "factory_unavailable"
	if controller_destroyed:
		cancellation_reason = "controller_destroyed"
	elif controller_detached:
		cancellation_reason = "controller_detached"
	_record_async_diagnostic(request_id, "aborting", {
		"staged_count": staged_count,
		"staged_roots_released": released_count,
		"newly_loaded_count": newly_loaded.size(),
		"unloaded_stale_count": unloaded_stale.size(),
		"rollback_complete": rollback_complete
	}, false, cancellation_reason)
	if request_id != _active_async_request_id:
		_emit_async_cancelled(request_id, staged_count)
		return
	_finish_async_sync_request(
		request_id,
		false,
		"dependency_unavailable",
		"Async chunk staging lost its controller or factory before commit.",
		rollback_complete,
		{
			"staged_count": staged_count,
			"staged_roots_released": released_count,
			"controller_destroyed": controller_destroyed,
			"controller_detached": controller_detached,
			"factory_valid": chunk_factory.is_valid(),
			"newly_loaded_count": newly_loaded.size(),
			"unloaded_stale_count": unloaded_stale.size(),
			"new_loads_rollback_ok": new_loads_rollback_ok,
			"stale_restore_ok": stale_restore_ok
		}
	)

func _end_controller_terrain_adjacency_batch() -> Dictionary:
	if chunk_controller == null or not is_instance_valid(chunk_controller) or chunk_controller.is_queued_for_deletion():
		return {"ok": false, "error": "controller_unavailable"}
	if not chunk_controller.has_method("end_terrain_adjacency_batch"):
		return {"ok": true, "skipped": true}
	var result_value: Variant = chunk_controller.call("end_terrain_adjacency_batch")
	var result: Dictionary = result_value if result_value is Dictionary else {"ok": false, "error": "invalid_batch_result"}
	if not bool(result.get("ok", false)):
		result["managed_map_reconciled"] = _reconcile_managed_chunk_ids_from_controller()
	return result

func _reconcile_managed_chunk_ids_from_controller() -> bool:
	if not _controller_ready_for_sync() or not chunk_controller.has_method("get_loaded_chunk_ids"):
		return false
	var raw_ids: Variant = chunk_controller.call("get_loaded_chunk_ids")
	if not (raw_ids is Array or raw_ids is PackedStringArray):
		return false
	var reconciled: Dictionary = {}
	for raw_id in raw_ids:
		var chunk_id: String = str(raw_id)
		if chunk_id.begins_with("underground/"):
			continue
		var parsed: Dictionary = _parse_grid_chunk_id(chunk_id)
		if not bool(parsed.get("valid", false)):
			return false
		reconciled[chunk_id] = parsed["coordinate"]
	_managed_chunk_ids = reconciled
	return true

func _finish_async_sync_request(request_id: int, success: bool, phase: String, message: String, rollback_complete: bool, details: Dictionary) -> void:
	if request_id != _active_async_request_id:
		_release_async_staged_roots(request_id, _async_staged_roots_by_request.get(request_id, {}))
		_emit_async_cancelled(request_id, 0)
		return
	var failure_reason: String = ""
	if not success:
		match phase:
			"load_factory":
				failure_reason = "factory_invalid_root"
				if bool(details.get("duplicate_staged_root_rejected", false)):
					failure_reason = "factory_reused_staged_root"
			"controller_lifecycle":
				failure_reason = "controller_unavailable"
			"dependency_unavailable":
				if bool(details.get("controller_destroyed", false)):
					failure_reason = "controller_destroyed"
				elif bool(details.get("controller_detached", false)):
					failure_reason = "controller_detached"
				elif bool(details.get("controller_queued_for_deletion", false)):
					failure_reason = "controller_destroyed"
				elif not bool(details.get("factory_valid", true)):
					failure_reason = "factory_unavailable"
				else:
					failure_reason = "dependency_unavailable"
			"load_registration":
				failure_reason = "registration_rejected"
			"stale_unload":
				failure_reason = "stale_unload_failed"
			"terrain_adjacency_commit":
				failure_reason = "terrain_adjacency_commit_failed"
			"staged_root_validation":
				failure_reason = str(details.get("failure_reason", "staged_root_invalid"))
	var diagnostic_details: Dictionary = details.duplicate(true)
	diagnostic_details["success"] = success
	diagnostic_details["rollback_complete"] = rollback_complete
	_record_async_diagnostic(request_id, phase, diagnostic_details, true, failure_reason)
	_set_sync_report(success, phase, message, rollback_complete, details)
	_last_sync_report["request_id"] = request_id
	_last_sync_report["request_diagnostics"] = get_async_request_diagnostics(request_id)
	_active_async_request_id = -1
	async_sync_completed.emit(request_id, _last_sync_report.duplicate(true))

func _emit_async_cancelled(request_id: int, staged_count: int = 0) -> void:
	var existing: Dictionary = get_async_request_diagnostics(request_id)
	var reason: String = str(existing.get("cancellation_reason", "cancelled"))
	_record_async_diagnostic(request_id, "cancelled", {
		"staged_count": staged_count,
		"staged_roots_released": staged_count,
		"success": false,
		"rollback_complete": true
	}, true, reason)
	async_sync_completed.emit(request_id, {
		"success": false,
		"phase": "cancelled",
		"message": "Async chunk request was cancelled before commit.",
		"rollback_complete": true,
		"details": {
			"request_id": request_id,
			"staged_count": staged_count,
			"staged_roots_released": staged_count,
			"cancellation_reason": reason
		},
		"request_diagnostics": get_async_request_diagnostics(request_id),
		"managed_chunk_ids": get_managed_chunk_ids(),
		"controller_chunk_ids": _get_controller_loaded_ids()
	})

func get_async_staged_root_count(request_id: int) -> int:
	var roots: Dictionary = _async_staged_roots_by_request.get(request_id, {})
	return roots.size()

func get_async_staged_root_weakrefs(request_id: int) -> Array[WeakRef]:
	var references: Array[WeakRef] = []
	var roots: Dictionary = _async_staged_roots_by_request.get(request_id, {})
	for candidate in roots.values():
		if is_instance_valid(candidate):
			references.append(weakref(candidate))
	return references

func _release_async_staged_roots(request_id: int, staged_roots: Dictionary) -> int:
	var roots: Dictionary = staged_roots
	if roots.is_empty() and _async_staged_roots_by_request.has(request_id):
		roots = _async_staged_roots_by_request[request_id]
	var released_count: int = roots.size()
	_free_staged_roots(roots)
	_async_staged_roots_by_request.erase(request_id)
	return released_count

func _free_staged_roots(staged_roots: Dictionary) -> void:
	for candidate in staged_roots.values():
		_free_unowned_root(candidate)
	staged_roots.clear()

## Reconcile the managed map from the controller's actual IDs, then retry the target window.
## This is intended for recovery after a previous sync reported an incomplete rollback.
## Unknown ID formats are rejected before changing the director's current managed map.
func recover_to_world_position(world_position: Vector3, now_unix: int = -1) -> bool:
	if not _is_finite_world_position(world_position):
		_set_sync_report(false, "recovery_validation", "World position must contain only finite coordinates.", false)
		return false
	if not _is_safe_grid_position(world_position):
		_set_sync_report(false, "recovery_validation", "World position is outside supported grid-coordinate bounds.", false)
		return false
	if not _controller_ready_for_sync() or not chunk_controller.has_method("get_loaded_chunk_ids"):
		_set_sync_report(false, "recovery_validation", "Controller must be alive, inside the scene tree and not queued for deletion, and must provide its actual loaded chunk IDs.", false)
		return false
	var raw_ids: Variant = chunk_controller.call("get_loaded_chunk_ids")
	if not (raw_ids is Array or raw_ids is PackedStringArray):
		_set_sync_report(false, "recovery_validation", "Controller returned an invalid loaded-ID collection.", false)
		return false
	var reconciled: Dictionary = {}
	var invalid_ids: Array[String] = []
	for raw_id in raw_ids:
		var chunk_id: String = str(raw_id)
		# This director owns the surface grid. The underground layer has a
		# separate lifecycle; preserve its IDs without parsing them as surface cells.
		if chunk_id.begins_with("underground/"):
			continue
		var parsed: Dictionary = _parse_grid_chunk_id(chunk_id)
		if not bool(parsed.get("valid", false)):
			invalid_ids.append(chunk_id)
			continue
		reconciled[chunk_id] = parsed["coordinate"]
	if not invalid_ids.is_empty():
		_set_sync_report(false, "recovery_validation", "Controller contains IDs that cannot be mapped to grid coordinates.", false, {
			"unrecognized_chunk_ids": invalid_ids
		})
		return false
	_managed_chunk_ids = reconciled
	return sync_to_world_position(world_position, now_unix)

func _parse_grid_chunk_id(chunk_id: String) -> Dictionary:
	const prefix: String = "surface/chunk_"
	if not chunk_id.begins_with(prefix):
		return {"valid": false, "coordinate": Vector2i.ZERO}
	var parts: PackedStringArray = chunk_id.substr(prefix.length()).split("_", false)
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return {"valid": false, "coordinate": Vector2i.ZERO}
	var coordinate := Vector2i(parts[0].to_int(), parts[1].to_int())
	if _chunk_id(coordinate) != chunk_id:
		return {"valid": false, "coordinate": Vector2i.ZERO}
	if absf(float(coordinate.x)) > MAX_SAFE_GRID_COORDINATE or absf(float(coordinate.y)) > MAX_SAFE_GRID_COORDINATE:
		return {"valid": false, "coordinate": Vector2i.ZERO}
	return {"valid": true, "coordinate": coordinate}
## Returns a snapshot of the last sync outcome, including actual active IDs from both owners.
## On failure, callers can inspect phase/details or subscribe to sync_failed(report).
func get_last_sync_report() -> Dictionary:
	return _last_sync_report.duplicate(true)

func get_managed_chunk_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id in _managed_chunk_ids.keys():
		ids.append(str(id))
	ids.sort()
	return ids

func get_grid_coordinate(world_position: Vector3) -> Vector2i:
	if not _is_safe_grid_position(world_position):
		return Vector2i.ZERO
	return Vector2i(floori(world_position.x / chunk_size_x), floori(world_position.z / chunk_size_z))

func _is_safe_grid_position(world_position: Vector3) -> bool:
	if not _is_finite_world_position(world_position):
		return false
	if not is_finite(chunk_size_x) or not is_finite(chunk_size_z) or chunk_size_x <= 0.0 or chunk_size_z <= 0.0 or load_radius < 0:
		return false
	var grid_x: float = world_position.x / chunk_size_x
	var grid_z: float = world_position.z / chunk_size_z
	return is_finite(grid_x) and is_finite(grid_z) and absf(grid_x) <= MAX_SAFE_GRID_COORDINATE and absf(grid_z) <= MAX_SAFE_GRID_COORDINATE

func _is_finite_world_position(world_position: Vector3) -> bool:
	return is_finite(world_position.x) and is_finite(world_position.y) and is_finite(world_position.z)

func _chunk_id(coord: Vector2i) -> String:
	return "surface/chunk_%d_%d" % [coord.x, coord.y]

func _rollback_new_loads(ids: Array[String], now_unix: int) -> bool:
	if (
		chunk_controller == null
		or not is_instance_valid(chunk_controller)
		or chunk_controller.is_queued_for_deletion()
		or not chunk_controller.has_method("is_chunk_loaded")
		or not chunk_controller.has_method("unload_chunk")
	):
		# A queued/destroyed Controller owns the roots that are about to disappear.
		# Do not call into it during rollback; discard the Director's stale mirror.
		_managed_chunk_ids.clear()
		return ids.is_empty()
	var success := true
	for i in range(ids.size() - 1, -1, -1):
		if chunk_controller == null or not is_instance_valid(chunk_controller) or chunk_controller.is_queued_for_deletion():
			_managed_chunk_ids.clear()
			return false
		var id: String = ids[i]
		var loaded: bool = chunk_controller.is_chunk_loaded(id)
		if chunk_controller == null or not is_instance_valid(chunk_controller) or chunk_controller.is_queued_for_deletion():
			_managed_chunk_ids.clear()
			return false
		if not loaded:
			_managed_chunk_ids.erase(id)
			continue
		if chunk_controller.unload_chunk(id, now_unix):
			_managed_chunk_ids.erase(id)
		else:
			success = false
		if chunk_controller == null or not is_instance_valid(chunk_controller) or chunk_controller.is_queued_for_deletion():
			_managed_chunk_ids.clear()
			return false
	return success

func _restore_unloaded_chunks(chunks: Array[Dictionary], now_unix: int) -> bool:
	var success := true
	for entry in chunks:
		if not _controller_ready_for_sync():
			success = false
			break
		var id: String = str(entry.get("id", ""))
		var coord: Vector2i = entry["coord"]
		if chunk_controller.has_method("is_chunk_loaded") and bool(chunk_controller.call("is_chunk_loaded", id)):
			var pending_cancel_ok: bool = (
				not chunk_controller.has_method("cancel_pending_chunk_unload")
				or bool(chunk_controller.call("cancel_pending_chunk_unload", id, now_unix))
			)
			if pending_cancel_ok:
				_managed_chunk_ids[id] = coord
				continue
			success = false
			continue
		if not chunk_factory.is_valid():
			success = false
			break
		var candidate: Variant = chunk_factory.call(coord)
		if not _controller_ready_for_sync() or not chunk_factory.is_valid():
			_free_unowned_root(candidate)
			success = false
			break
		var candidate_is_node3d: bool = is_instance_valid(candidate) and candidate is Node3D
		var candidate_queued_for_deletion: bool = candidate_is_node3d and (candidate as Node3D).is_queued_for_deletion()
		if not is_instance_valid(candidate) or not (candidate is Node3D) or candidate_queued_for_deletion or candidate.get_parent() != null:
			_free_unowned_root(candidate)
			success = false
			continue

		var load_succeeded: bool = chunk_controller.load_chunk(id, candidate, now_unix)
		var controller_ready_after_load: bool = _controller_ready_for_sync()
		var controller_can_rollback: bool = (
			chunk_controller != null
			and is_instance_valid(chunk_controller)
			and not chunk_controller.is_queued_for_deletion()
		)
		var candidate_loaded: bool = (
			controller_can_rollback
			and chunk_controller.has_method("is_chunk_loaded")
			and chunk_controller.is_chunk_loaded(id)
		)
		if not load_succeeded or not controller_ready_after_load or not candidate_loaded:
			var candidate_rollback_ok: bool = false
			if candidate_loaded:
				candidate_rollback_ok = chunk_controller.has_method("unload_chunk") and chunk_controller.unload_chunk(id, now_unix)
			elif controller_can_rollback and is_instance_valid(candidate) and candidate is Node3D and candidate.get_parent() == chunk_controller:
				chunk_controller.remove_child(candidate)
				if not (candidate as Node3D).is_queued_for_deletion():
					(candidate as Node3D).queue_free()
				candidate_rollback_ok = true
			elif is_instance_valid(candidate) and candidate is Node3D and candidate.get_parent() != null:
				candidate_rollback_ok = false
			else:
				_free_unowned_root(candidate)
				candidate_rollback_ok = true
			if not controller_can_rollback:
				_managed_chunk_ids.clear()
			elif candidate_loaded and not candidate_rollback_ok:
				_managed_chunk_ids[id] = coord
			success = false
			if not controller_ready_after_load:
				break
			continue
		_managed_chunk_ids[id] = coord
	return success

func _free_unowned_root(candidate: Variant) -> void:
	if is_instance_valid(candidate) and candidate is Node3D and candidate.get_parent() == null and not (candidate as Node3D).is_queued_for_deletion():
		candidate.free()

func _set_sync_report(success: bool, phase: String, message: String, rollback_complete: bool, details: Dictionary = {}) -> void:
	_last_sync_report = {
		"success": success,
		"phase": phase,
		"message": message,
		"rollback_complete": rollback_complete,
		"details": details.duplicate(true),
		"managed_chunk_ids": get_managed_chunk_ids(),
		"controller_chunk_ids": _get_controller_loaded_ids()
	}
	if not success:
		sync_failed.emit(_last_sync_report.duplicate(true))

func _get_controller_loaded_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if chunk_controller != null and is_instance_valid(chunk_controller) and not chunk_controller.is_queued_for_deletion() and chunk_controller.has_method("get_loaded_chunk_ids"):
		var raw_ids: Variant = chunk_controller.call("get_loaded_chunk_ids")
		if raw_ids is Array or raw_ids is PackedStringArray:
			for item in raw_ids:
				ids.append(str(item))
	ids.sort()
	return ids

static func _coordinate_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y == b.y:
		return a.x < b.x
	return a.y < b.y

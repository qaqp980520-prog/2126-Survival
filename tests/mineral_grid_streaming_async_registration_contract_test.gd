extends SceneTree

const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const FakeController = preload("res://tests/helpers/FakeMineralChunkController.gd")

var _failures: Array[String] = []
var _factory_roots: Array[WeakRef] = []
var _test_time: int = 0
var _completed_async_reports: Dictionary = {}
var _supersede_on_next_factory_call: bool = false
var _superseding_director: Node = null
var _superseding_position: Vector3 = Vector3.ZERO
var _superseding_now_unix: int = -1
var _superseding_request_id: int = -1
var _superseded_root_ref: WeakRef = null

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_time = int(Time.get_unix_time_from_system()) + 100
	await _test_async_false_after_registration_is_rolled_back()
	await _test_async_superseded_during_staging_releases_roots()
	await _test_async_queued_controller_after_prior_loads_does_not_receive_rollback_calls()
	await _test_async_failed_rollback_keeps_ownership_mirrored()
	await _test_async_true_without_registration_is_rejected()
	await _test_stale_restore_true_without_registration_is_rejected()
	await _test_async_controller_detach_during_commit_reports_dependency_unavailable()
	await _test_async_factory_unavailable_preserves_diagnostic_reason()
	if _failures.is_empty():
		print("Mineral grid async registration result contract tests passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)

func _make_pair(radius: int) -> Dictionary:
	_factory_roots.clear()
	var controller := FakeController.new()
	var director := Director.new()
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	director.set("chunk_size_x", 10.0)
	director.set("chunk_size_z", 10.0)
	director.set("load_radius", radius)
	_expect(bool(director.call("bind_controller", controller)), "async registration fixture binds a live Controller")
	_expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_chunk"))), "async registration fixture binds its deterministic factory")
	return {"controller": controller, "director": director}

func _test_async_superseded_during_staging_releases_roots() -> void:
	var pair: Dictionary = await _make_pair(0)
	var controller: Variant = pair["controller"]
	var director: Node = pair["director"]
	_completed_async_reports.clear()
	director.async_sync_completed.connect(Callable(self, "_capture_async_report"))
	_superseding_director = director
	_superseding_position = Vector3(10.0, 0.0, 0.0)
	_superseding_now_unix = _test_time + 21
	_superseding_request_id = -1
	_superseded_root_ref = null
	_supersede_on_next_factory_call = true

	var superseded_request_id: int = int(director.call("request_sync_to_world_position_async", Vector3.ZERO, _test_time + 20, 1))
	var waited_frames: int = 0
	while waited_frames < 120 and (
		not _completed_async_reports.has(superseded_request_id)
		or _superseding_request_id < 0
		or not _completed_async_reports.has(_superseding_request_id)
	):
		await process_frame
		waited_frames += 1

	var replacement_request_id: int = _superseding_request_id
	var superseded_report: Dictionary = _completed_async_reports.get(superseded_request_id, {})
	var replacement_report: Dictionary = _completed_async_reports.get(replacement_request_id, {})
	var superseded_details: Dictionary = superseded_report.get("details", {})
	var superseded_diagnostics: Dictionary = superseded_report.get("request_diagnostics", {})
	_expect(superseded_request_id > 0, "superseded staging request is accepted")
	_expect(replacement_request_id > superseded_request_id, "factory-triggered replacement request receives a newer ID")
	_expect(waited_frames < 120, "superseded and replacement requests both reach terminal reports")
	_expect(str(superseded_report.get("phase", "")) == "cancelled", "older staging request terminates as cancelled")
	_expect(not bool(superseded_report.get("success", true)), "superseded staging request cannot report success")
	_expect(str(superseded_diagnostics.get("cancellation_reason", "")) == "superseded_by_request:%d" % replacement_request_id, "superseded request preserves the replacement request ID in its cancellation reason")
	_expect(bool(superseded_report.get("rollback_complete", false)), "superseded staging cleanup is reported complete")
	_expect(int(superseded_details.get("staged_count", 0)) == 1, "superseded request staged exactly one root before yielding")
	_expect(int(superseded_details.get("staged_roots_released", 0)) == 1, "superseded request reports releasing its staged root")
	_expect(int(director.call("get_async_staged_root_count", superseded_request_id)) == 0, "superseded request retains no staged-root dictionary entries")
	await process_frame
	_expect(_superseded_root_ref != null and _superseded_root_ref.get_ref() == null, "superseded staged root is freed after cancellation")
	_expect(bool(replacement_report.get("success", false)), "replacement request completes successfully")
	_expect(str(replacement_report.get("phase", "")) == "complete", "replacement request reaches the complete phase")
	var expected_ids := PackedStringArray(["surface/chunk_1_0"])
	_expect(controller.get_loaded_chunk_ids() == expected_ids, "only the replacement request's target chunk is registered")
	_expect(director.call("get_managed_chunk_ids") == expected_ids, "Director ownership mirrors the replacement request's actual chunk")
	_expect(controller.get_child_count() == 1, "superseded root is not left beside the replacement root")
	_expect(int(director.call("get_active_async_request_id")) == -1, "replacement completion clears the active async request")
	_expect_batch_closed(controller, 1, "superseded staging replacement")
	controller.queue_free()
	director.queue_free()
	await process_frame
	_superseding_director = null
	_supersede_on_next_factory_call = false
	_superseding_request_id = -1
	_superseded_root_ref = null


func _test_async_false_after_registration_is_rolled_back() -> void:
	var pair: Dictionary = await _make_pair(0)
	var controller: Variant = pair["controller"]
	var director: Node = pair["director"]
	controller.fail_after_register_on_load_call = 1
	var request_id: int = int(director.call("request_sync_to_world_position_async", Vector3.ZERO, _test_time, 1))
	var report: Dictionary = await _wait_for_request(director, request_id)
	_expect(request_id > 0, "false-after-registration async request is accepted")
	_expect(not bool(report.get("success", true)), "async commit rejects a false result after the Controller registered the candidate")
	_expect(str(report.get("phase", "")) == "load_registration", "false-after-registration is reported as a registration failure")
	_expect(bool(report.get("rollback_complete", false)), "false-after-registration async rollback is complete")
	_expect(controller.get_loaded_chunk_ids().is_empty(), "false-after-registration leaves no Controller chunk")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "false-after-registration leaves no Director ownership")
	await process_frame
	_expect(controller.get_child_count() == 0, "false-after-registration releases the candidate root instead of orphaning it")
	_expect_batch_closed(controller, 1, "false-after-registration rollback")
	for reference in _factory_roots:
		_expect(reference.get_ref() == null, "false-after-registration candidate weak reference is released")
	controller.queue_free()
	director.queue_free()
	await process_frame


func _test_async_queued_controller_after_prior_loads_does_not_receive_rollback_calls() -> void:
	var pair: Dictionary = await _make_pair(1)
	var controller: Variant = pair["controller"]
	var director: Node = pair["director"]
	var controller_ref: WeakRef = weakref(controller)
	controller.queue_on_load_call = 9
	var request_id: int = int(director.call("request_sync_to_world_position_async", Vector3.ZERO, _test_time + 6, 8))
	var report: Dictionary = await _wait_for_request(director, request_id)
	var newly_loaded: Array = report.get("details", {}).get("newly_loaded_ids", [])
	_expect(request_id > 0, "queued-controller async request is accepted")
	_expect(controller.load_calls == 9, "the queued async registration follows eight successful chunk registrations")
	_expect(controller.is_queued_for_deletion(), "the final async registration queues the Controller for deletion")
	_expect(controller.unload_calls == 0, "no rollback method is invoked on the queued Controller after prior async loads")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "queued async Controller teardown clears the Director ownership mirror")
	_expect(str(report.get("phase", "")) == "dependency_unavailable", "queued async registration is reported as a dependency lifecycle failure")
	_expect(not bool(report.get("rollback_complete", true)), "queued async Controller teardown is honestly reported as incomplete")
	_expect(bool(report.get("details", {}).get("controller_queued_for_deletion", false)), "async report identifies the queued Controller")
	_expect(not bool(report.get("details", {}).get("new_loads_rollback_ok", true)), "async report records that prior loads were released by Controller teardown rather than explicit rollback")
	_expect(int(controller.get("adjacency_batch_begin_calls")) == 1, "queued-controller commit opens one adjacency batch")
	_expect(int(controller.get("adjacency_batch_end_calls")) == 0, "queued Controller is not called to close its batch")
	_expect(int(controller.get("adjacency_batch_depth")) == 1, "queued Controller retains its open batch only until its own teardown")
	_expect(int(controller.get("adjacency_batch_finalize_calls")) == 0, "queued Controller does not report a false adjacency finalization")
	_expect(newly_loaded.size() == 8, "async report records the eight chunks registered before the Controller was queued")
	_expect(_factory_roots.size() == 9, "queued async fixture created all nine staged chunk roots")
	await process_frame
	_expect(controller_ref.get_ref() == null, "queued async Controller is released by frame cleanup")
	for reference in _factory_roots:
		_expect(reference.get_ref() == null, "queued async Controller teardown releases every committed chunk root")
	director.queue_free()
	await process_frame


func _test_async_failed_rollback_keeps_ownership_mirrored() -> void:
	var pair: Dictionary = await _make_pair(0)
	var controller: Variant = pair["controller"]
	var director: Node = pair["director"]
	controller.fail_after_register_on_load_call = 1
	controller.fail_on_unload_call = 1
	var request_id: int = int(director.call("request_sync_to_world_position_async", Vector3.ZERO, _test_time + 1, 1))
	var report: Dictionary = await _wait_for_request(director, request_id)
	_expect(not bool(report.get("success", true)), "async registration failure remains a failed request when rollback unload fails")
	_expect(not bool(report.get("rollback_complete", true)), "failed async rollback is reported as incomplete")
	_expect(not bool(report.get("details", {}).get("new_loads_rollback_ok", true)), "report identifies the failed candidate unload")
	var expected_ids := PackedStringArray(["surface/chunk_0_0"])
	_expect(controller.get_loaded_chunk_ids() == expected_ids, "Controller retains the chunk that could not be unloaded")
	_expect(director.call("get_managed_chunk_ids") == expected_ids, "Director retains ownership for the chunk still loaded by the Controller")
	_expect(controller.get_child_count() == 1, "failed rollback retains exactly one owned root instead of orphaning it")
	_expect_batch_closed(controller, 1, "failed rollback")
	_expect(bool(director.call("sync_to_world_position", Vector3.ZERO, _test_time + 2)), "a later sync can reconcile the retained, actually loaded chunk")
	_expect(controller.get_loaded_chunk_ids() == director.call("get_managed_chunk_ids"), "retry preserves Controller and Director ownership agreement")
	controller.queue_free()
	director.queue_free()
	await process_frame

func _test_async_true_without_registration_is_rejected() -> void:
	var pair: Dictionary = await _make_pair(0)
	var controller: Variant = pair["controller"]
	var director: Node = pair["director"]
	controller.return_success_without_register_on_load_call = 1
	var request_id: int = int(director.call("request_sync_to_world_position_async", Vector3.ZERO, _test_time + 1, 1))
	var report: Dictionary = await _wait_for_request(director, request_id)
	_expect(request_id > 0, "unregistered-success async request is accepted")
	_expect(not bool(report.get("success", true)), "async commit rejects true when the Controller did not register the candidate")
	_expect(str(report.get("phase", "")) == "load_registration", "unregistered success is reported as a registration failure")
	_expect(not bool(report.get("details", {}).get("candidate_loaded", true)), "unregistered-success report records the missing Controller registration")
	_expect(bool(report.get("details", {}).get("candidate_cleanup_ok", false)), "unregistered-success report confirms candidate cleanup")
	_expect(bool(report.get("rollback_complete", false)), "unregistered-success async rollback is complete")
	_expect(controller.get_loaded_chunk_ids().is_empty(), "unregistered-success leaves no Controller chunk")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "unregistered-success leaves no Director ownership")
	await process_frame
	_expect(controller.get_child_count() == 0, "unregistered-success removes the attached but unregistered root")
	_expect_batch_closed(controller, 0, "unregistered-success cleanup")
	for reference in _factory_roots:
		_expect(reference.get_ref() == null, "unregistered-success candidate weak reference is released")
	controller.queue_free()
	director.queue_free()
	await process_frame

func _test_stale_restore_true_without_registration_is_rejected() -> void:
	var pair: Dictionary = await _make_pair(1)
	var controller: Variant = pair["controller"]
	var director: Node = pair["director"]
	_expect(bool(director.call("sync_to_world_position", Vector3.ZERO, _test_time + 2)), "stale-restore fixture creates its original 3x3 window")
	var original_ids: PackedStringArray = controller.get_loaded_chunk_ids()
	_expect(original_ids.size() == 9, "stale-restore fixture starts with nine registered chunks")
	_factory_roots.clear()
	controller.fail_on_unload_call = controller.unload_calls + 2
	# The shift loads three new chunks before the second stale unload fails.
	# The next registration callback is therefore the first stale-root restoration.
	controller.return_success_without_register_on_load_call = controller.load_calls + 4
	var request_id: int = int(director.call("request_sync_to_world_position_async", Vector3(10.0, 0.0, 0.0), _test_time + 3, 3))
	var report: Dictionary = await _wait_for_request(director, request_id)
	_expect(request_id > 0, "stale-restore async request is accepted")
	_expect(str(report.get("phase", "")) == "stale_unload", "partial stale retirement is reported at the stale-unload phase")
	_expect(not bool(report.get("success", true)), "stale-unload failure does not report a successful window commit")
	_expect(not bool(report.get("details", {}).get("stale_restore_ok", true)), "restore helper rejects a true result without actual registration")
	_expect(not bool(report.get("rollback_complete", true)), "failed stale-root restoration is reported as incomplete")
	var actual_ids: PackedStringArray = controller.get_loaded_chunk_ids()
	_expect(actual_ids.size() == 8, "failed restoration leaves only the eight roots that are actually registered")
	_expect(actual_ids == director.call("get_managed_chunk_ids"), "Director ownership mirrors the actual partially restored Controller state")
	await process_frame
	_expect(controller.get_child_count() == 8, "unregistered restoration candidate is removed rather than retained as an orphan child")
	_expect_batch_closed(controller, 1, "stale-root restore failure")
	for reference in _factory_roots:
		_expect(reference.get_ref() == null, "new and unregistered restoration candidates are released")
	controller.queue_free()
	director.queue_free()
	await process_frame


func _test_async_controller_detach_during_commit_reports_dependency_unavailable() -> void:
	var pair: Dictionary = await _make_pair(0)
	var controller: Variant = pair["controller"]
	var director: Node = pair["director"]
	controller.detach_on_load_call = 1
	var request_id: int = int(director.call("request_sync_to_world_position_async", Vector3.ZERO, _test_time + 4, 1))
	var report: Dictionary = await _wait_for_request(director, request_id)
	_expect(request_id > 0, "controller-detach async request is accepted")
	_expect(str(report.get("phase", "")) == "dependency_unavailable", "controller detachment during commit uses the dependency-unavailable phase")
	_expect(not bool(report.get("success", true)), "detached controller cannot commit a new chunk window")
	_expect(bool(report.get("rollback_complete", false)), "detached live controller rolls back the newly registered chunk")
	_expect(bool(report.get("details", {}).get("controller_detached", false)), "report identifies a detached but live controller")
	_expect(not bool(report.get("details", {}).get("controller_destroyed", true)), "detached controller is distinguished from destroyed controller")
	_expect(controller.get_parent() == null, "fault-injected Controller remains detached after rollback")
	_expect(controller.get_loaded_chunk_ids().is_empty(), "detached Controller has no newly committed chunk after rollback")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "Director ownership is cleared after detached-controller rollback")
	await process_frame
	_expect(controller.get_child_count() == 0, "detached-controller rollback releases its candidate root")
	_expect_batch_closed(controller, 1, "detached-controller rollback")
	for reference in _factory_roots:
		_expect(reference.get_ref() == null, "detached-controller candidate weak reference is released")
	controller.queue_free()
	director.queue_free()
	await process_frame


func _test_async_factory_unavailable_preserves_diagnostic_reason() -> void:
	var pair: Dictionary = await _make_pair(0)
	var controller: Variant = pair["controller"]
	var director: Node = pair["director"]
	var request_id: int = int(director.call("request_sync_to_world_position_async", Vector3.ZERO, _test_time + 5, 1))
	director.set("_chunk_factory", Callable())
	var report: Dictionary = await _wait_for_request(director, request_id)
	var diagnostics: Dictionary = report.get("request_diagnostics", {})
	_expect(request_id > 0, "factory-loss async request is accepted before the dependency changes")
	_expect(str(report.get("phase", "")) == "dependency_unavailable", "factory loss during async staging reports dependency unavailability")
	_expect(not bool(report.get("success", true)), "factory loss cannot commit an async chunk window")
	_expect(str(diagnostics.get("cancellation_reason", "")) == "factory_unavailable", "factory-loss diagnostic reason is preserved instead of being mislabeled as Controller loss")
	_expect(controller.get_loaded_chunk_ids().is_empty(), "factory loss leaves the Controller window unchanged")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "factory loss leaves the Director ownership map unchanged")
	_expect(int(controller.get("adjacency_batch_begin_calls")) == 0, "factory loss during staging does not open a commit batch")
	_expect(int(controller.get("adjacency_batch_end_calls")) == 1, "factory loss during staging safely invokes the idempotent batch finalizer")
	_expect(int(controller.get("adjacency_batch_depth")) == 0, "factory loss leaves no open batch")
	controller.queue_free()
	director.queue_free()
	await process_frame

func _wait_for_request(director: Node, request_id: int) -> Dictionary:
	if request_id < 0:
		return {}
	while true:
		var emitted: Array = await director.async_sync_completed
		if int(emitted[0]) == request_id:
			return emitted[1]
	return {}

func _make_chunk(coord: Vector2i) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "AsyncRegistration_%d_%d" % [coord.x, coord.y]
	var reference: WeakRef = weakref(chunk)
	_factory_roots.append(reference)
	if _supersede_on_next_factory_call:
		_supersede_on_next_factory_call = false
		_superseded_root_ref = reference
		if is_instance_valid(_superseding_director):
			_superseding_request_id = int(_superseding_director.call(
				"request_sync_to_world_position_async",
				_superseding_position,
				_superseding_now_unix,
				1
			))
	return chunk

func _capture_async_report(request_id: int, report: Dictionary) -> void:
	_completed_async_reports[request_id] = report.duplicate(true)

func _expect_batch_closed(controller: Variant, expected_finalizations: int, label: String) -> void:
	_expect(int(controller.get("adjacency_batch_begin_calls")) == 1, "%s opens exactly one adjacency batch" % label)
	_expect(int(controller.get("adjacency_batch_end_calls")) >= 1, "%s invokes the idempotent batch finalizer" % label)
	_expect(int(controller.get("adjacency_batch_depth")) == 0, "%s leaves no open adjacency batch" % label)
	_expect(int(controller.get("adjacency_batch_finalize_calls")) == expected_finalizations, "%s records the expected finalization count" % label)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)

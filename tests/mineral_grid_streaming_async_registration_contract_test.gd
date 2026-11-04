extends SceneTree

const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const FakeController = preload("res://tests/helpers/FakeMineralChunkController.gd")

var _failures: Array[String] = []
var _factory_roots: Array[WeakRef] = []
var _test_time: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_time = int(Time.get_unix_time_from_system()) + 100
	await _test_async_false_after_registration_is_rolled_back()
	await _test_async_failed_rollback_keeps_ownership_mirrored()
	await _test_async_true_without_registration_is_rejected()
	await _test_stale_restore_true_without_registration_is_rejected()
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
	for reference in _factory_roots:
		_expect(reference.get_ref() == null, "false-after-registration candidate weak reference is released")
	controller.queue_free()
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
	for reference in _factory_roots:
		_expect(reference.get_ref() == null, "new and unregistered restoration candidates are released")
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
	_factory_roots.append(weakref(chunk))
	return chunk

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)

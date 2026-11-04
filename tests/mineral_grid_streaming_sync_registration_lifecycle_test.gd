extends SceneTree

const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const FakeController = preload("res://tests/helpers/FakeMineralChunkController.gd")

var _failures: Array[String] = []
var _factory_roots: Array[WeakRef] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_detach_on_final_sync_registration_rolls_back_entire_window()
	await _test_queued_controller_is_not_called_during_sync_rollback()
	await _test_queued_controller_after_prior_sync_loads_does_not_receive_rollback_calls()
	if _failures.is_empty():
		print("Mineral grid synchronous registration lifecycle tests passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)

func _make_pair(radius: int) -> Dictionary:
	var controller := FakeController.new()
	var director := Director.new()
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	director.set("chunk_size_x", 10.0)
	director.set("chunk_size_z", 10.0)
	director.set("load_radius", radius)
	_expect(director.call("bind_controller", controller), "Director binds a live synchronous lifecycle Controller")
	_expect(director.call("bind_chunk_factory", Callable(self, "_make_chunk")), "Director binds the synchronous lifecycle factory")
	return {"controller": controller, "director": director}

func _test_detach_on_final_sync_registration_rolls_back_entire_window() -> void:
	_factory_roots.clear()
	var pair: Dictionary = await _make_pair(1)
	var controller: Variant = pair["controller"]
	var director: Node = pair["director"]
	controller.detach_on_load_call = 9
	var success: bool = director.call("sync_to_world_position", Vector3.ZERO, 4000)
	var report: Dictionary = director.call("get_last_sync_report")
	_expect(not success, "sync rejects a Controller detached by its final chunk registration")
	_expect(controller.load_calls == 9, "the final registration callback is reached after eight prior chunks load")
	_expect(controller.unload_calls == 9, "all nine newly registered chunks are rolled back on the detached live Controller")
	_expect(controller.get_loaded_chunk_ids().is_empty(), "detached Controller retains no partially committed window")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "Director clears all rolled-back chunk ownership")
	_expect(str(report.get("phase", "")) == "controller_lifecycle", "sync report identifies the registration lifecycle failure")
	_expect(bool(report.get("rollback_complete", false)), "sync report confirms the complete window rollback")
	_expect(bool(report.get("details", {}).get("controller_detached", false)), "sync report records the detached Controller")
	await process_frame
	for reference in _factory_roots:
		_expect(reference.get_ref() == null, "rolled-back synchronous chunk root is released")

	controller.queue_free()
	director.queue_free()
	await process_frame

func _test_queued_controller_is_not_called_during_sync_rollback() -> void:
	_factory_roots.clear()
	var pair: Dictionary = await _make_pair(0)
	var controller: Variant = pair["controller"]
	var director: Node = pair["director"]
	controller.queue_on_load_call = 1
	var success: bool = director.call("sync_to_world_position", Vector3.ZERO, 5000)
	var report: Dictionary = director.call("get_last_sync_report")
	_expect(not success, "sync rejects a Controller queued during its only registration callback")
	_expect(controller.load_calls == 1, "queued-controller registration is attempted exactly once")
	_expect(controller.unload_calls == 0, "queued Controller receives no rollback method calls")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "queued Controller leaves no stale Director ownership")
	_expect(str(report.get("phase", "")) == "controller_lifecycle", "queued registration is reported as a lifecycle failure")
	_expect(not bool(report.get("rollback_complete", true)), "queued Controller cleanup is honestly reported as incomplete")
	_expect(bool(report.get("details", {}).get("controller_queued_for_deletion", false)), "sync report identifies the queued Controller")
	await process_frame
	for reference in _factory_roots:
		_expect(reference.get_ref() == null, "queued Controller releases its child root on frame cleanup")

	director.queue_free()
	await process_frame

func _test_queued_controller_after_prior_sync_loads_does_not_receive_rollback_calls() -> void:
	_factory_roots.clear()
	var pair: Dictionary = await _make_pair(1)
	var controller: Variant = pair["controller"]
	var director: Node = pair["director"]
	controller.queue_on_load_call = 9
	var success: bool = director.call("sync_to_world_position", Vector3.ZERO, 6000)
	var report: Dictionary = director.call("get_last_sync_report")
	_expect(not success, "sync rejects a Controller queued during the final registration after prior chunks loaded")
	_expect(controller.load_calls == 9, "the queued final registration follows eight successful chunk registrations")
	_expect(controller.is_queued_for_deletion(), "the final registration callback queues the Controller for deletion")
	_expect(controller.unload_calls == 0, "no rollback method is invoked on the queued Controller, even with prior loads")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "queued Controller clears the Director's stale ownership mirror")
	_expect(str(report.get("phase", "")) == "controller_lifecycle", "late queued registration is reported as a lifecycle failure")
	_expect(not bool(report.get("rollback_complete", true)), "late queued registration reports owner-teardown cleanup as incomplete")
	_expect(bool(report.get("details", {}).get("controller_queued_for_deletion", false)), "late report identifies the queued Controller")
	await process_frame
	for reference in _factory_roots:
		_expect(reference.get_ref() == null, "queued owner teardown releases every newly loaded chunk root")

	director.queue_free()
	await process_frame

func _make_chunk(coord: Vector2i) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "SyncLifecycle_%d_%d" % [coord.x, coord.y]
	_factory_roots.append(weakref(chunk))
	return chunk

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)

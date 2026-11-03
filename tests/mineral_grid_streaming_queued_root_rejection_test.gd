extends SceneTree

const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const FakeController = preload("res://tests/helpers/FakeMineralChunkController.gd")
const RegistryScript = preload("res://systems/MineralVeinRegistry.gd")
const ControllerScript = preload("res://systems/MineralChunkController.gd")

var failures: Array[String] = []
var completed_reports: Dictionary = {}
var queued_roots: Array[WeakRef] = []
var factory_calls: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_controller_boundary()
	await _test_director_sync_and_restore()
	await _test_director_async()

	if failures.is_empty():
		print("Mineral grid queued-root rejection regression passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_controller_boundary() -> void:
	var registry: Node = RegistryScript.new()
	var controller: Node3D = ControllerScript.new()
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	_expect(bool(controller.call("bind_registry", registry)), "production controller binds its mineral registry")
	var queued_root := Node3D.new()
	queued_root.name = "QueuedForDeletionRoot"
	var queued_ref: WeakRef = weakref(queued_root)
	queued_root.queue_free()
	_expect(not bool(controller.call("load_chunk", "surface/chunk_0_0", queued_root, 1700000000)), "production controller rejects a root already queued for deletion")
	_expect(controller.call("get_loaded_chunk_ids").is_empty(), "controller ownership map remains empty after queued-root rejection")
	await process_frame
	_expect(queued_ref.get_ref() == null, "controller rejection does not double-free the queued root")
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _test_director_sync_and_restore() -> void:
	var controller: Node = FakeController.new()
	var director: Node = Director.new()
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	director.chunk_size_x = 10.0
	director.chunk_size_z = 10.0
	director.load_radius = 0
	_expect(bool(director.call("bind_controller", controller)), "director binds fake controller before synchronous test")
	_expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_queued_root"))), "director binds queued-root factory")
	_expect(not bool(director.call("sync_to_world_position", Vector3.ZERO, 1700000001)), "synchronous streaming rejects a queued-for-deletion factory root")
	var sync_report: Dictionary = director.call("get_last_sync_report")
	var sync_details: Dictionary = sync_report.get("details", {})
	_expect(str(sync_report.get("phase", "")) == "load_factory", "sync rejection is attributed to the factory phase")
	_expect(bool(sync_details.get("factory_root_queued_for_deletion", false)), "sync report identifies queued-for-deletion factory output")
	_expect(controller.call("get_loaded_chunk_ids").is_empty(), "sync rejection registers no chunk with the controller")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "sync rejection leaves the director ownership map empty")
	await process_frame
	_expect(_last_queued_root_released(), "synchronous rejection leaves the queued root to its scheduled deletion")

	var restore_entries: Array[Dictionary] = [{"id": "surface/chunk_3_3", "coord": Vector2i(3, 3)}]
	_expect(not bool(director.call("_restore_unloaded_chunks", restore_entries, 1700000002)), "rollback restoration rejects a queued-for-deletion root")
	_expect(controller.call("get_loaded_chunk_ids").is_empty(), "restore rejection does not register a queued root")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "restore rejection keeps director ownership empty")
	await process_frame
	_expect(_last_queued_root_released(), "restore rejection does not double-free a queued root")
	director.queue_free()
	controller.queue_free()
	await process_frame

func _test_director_async() -> void:
	var controller: Node = FakeController.new()
	var director: Node = Director.new()
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	director.chunk_size_x = 10.0
	director.chunk_size_z = 10.0
	director.load_radius = 0
	_expect(bool(director.call("bind_controller", controller)), "director binds fake controller before async test")
	_expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_queued_root"))), "director binds queued-root factory for async test")
	director.connect("async_sync_completed", Callable(self, "_on_async_completed"))
	var request_id: int = int(director.call("request_sync_to_world_position_async", Vector3.ZERO, 1700000003, 1))
	_expect(request_id > 0, "async request accepts a valid one-chunk window")
	var report: Dictionary = await _wait_for_request(request_id)
	_expect(not report.is_empty(), "async queued-root request reaches a terminal report")
	_expect(not bool(report.get("success", true)), "async streaming rejects queued-for-deletion factory output")
	_expect(str(report.get("phase", "")) == "load_factory", "async rejection is attributed to the factory phase")
	var details: Dictionary = report.get("details", {})
	_expect(bool(details.get("factory_root_queued_for_deletion", false)), "async report identifies queued-for-deletion factory output")
	_expect(controller.call("get_loaded_chunk_ids").is_empty(), "async rejection registers no chunk with the controller")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "async rejection leaves the director ownership map empty")
	_expect(int(director.call("get_active_async_request_id")) == -1, "async rejection releases the active request lock")
	await process_frame
	_expect(_last_queued_root_released(), "async rejection leaves the queued root to its scheduled deletion")
	director.queue_free()
	controller.queue_free()
	await process_frame

func _make_queued_root(_coord: Vector2i) -> Node3D:
	factory_calls += 1
	var candidate := Node3D.new()
	candidate.name = "QueuedRoot_%d" % factory_calls
	queued_roots.append(weakref(candidate))
	candidate.queue_free()
	return candidate

func _last_queued_root_released() -> bool:
	if queued_roots.is_empty():
		return false
	return queued_roots.back().get_ref() == null

func _on_async_completed(request_id: int, report: Dictionary) -> void:
	completed_reports[request_id] = report.duplicate(true)

func _wait_for_request(request_id: int) -> Dictionary:
	for _frame in range(120):
		if completed_reports.has(request_id):
			return completed_reports[request_id].duplicate(true)
		await process_frame
	return {}

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

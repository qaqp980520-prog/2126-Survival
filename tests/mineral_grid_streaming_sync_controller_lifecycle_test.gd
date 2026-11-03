extends SceneTree

const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const FakeController = preload("res://tests/helpers/FakeMineralChunkController.gd")

var _failures: Array[String] = []
var _factory_calls: int = 0
var _factory_controller: Node3D
var _detach_on_next_factory: bool = false
var _last_factory_root: WeakRef

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_detached_controller_rejection()
	await _test_factory_detaches_controller()
	await _test_queued_controller_rejection()
	if _failures.is_empty():
		print("Mineral grid synchronous controller lifecycle regression passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)

func _make_pair() -> Dictionary:
	var controller := FakeController.new()
	var director := Director.new()
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	director.chunk_size_x = 10.0
	director.chunk_size_z = 10.0
	director.load_radius = 1
	_expect(director.bind_controller(controller), "Director binds a live in-tree controller")
	_expect(director.bind_chunk_factory(Callable(self, "_make_chunk")), "Director binds the test factory")
	return {"controller": controller, "director": director}

func _test_detached_controller_rejection() -> void:
	var pair: Dictionary = await _make_pair()
	var controller: Node3D = pair["controller"]
	var director: Node = pair["director"]
	_expect(director.sync_to_world_position(Vector3(1.0, 0.0, 1.0), 1000), "baseline sync loads the initial window")
	var previous_ids: PackedStringArray = director.get_managed_chunk_ids()
	_expect(previous_ids.size() == 9, "baseline window contains nine chunks")
	root.remove_child(controller)
	_factory_calls = 0
	_expect(not director.sync_to_world_position(Vector3(21.0, 0.0, 1.0), 1001), "sync rejects a detached controller")
	var report: Dictionary = director.get_last_sync_report()
	_expect(str(report.get("phase", "")) == "validation", "detached-controller sync reports validation failure")
	_expect(_factory_calls == 0, "detached-controller rejection happens before factory invocation")
	_expect(director.get_managed_chunk_ids() == previous_ids, "detached-controller rejection preserves managed IDs")
	_expect(not director.recover_to_world_position(Vector3(21.0, 0.0, 1.0), 1002), "recovery also rejects a detached controller")
	_expect(str(director.get_last_sync_report().get("phase", "")) == "recovery_validation", "detached recovery reports its validation phase")
	root.add_child(controller)
	await process_frame
	_expect(director.sync_to_world_position(Vector3(1.0, 0.0, 1.0), 1003), "reattached controller can resume synchronous streaming")
	director.queue_free()
	controller.queue_free()
	await process_frame

func _test_factory_detaches_controller() -> void:
	var pair: Dictionary = await _make_pair()
	var controller: Node3D = pair["controller"]
	var director: Node = pair["director"]
	_expect(director.sync_to_world_position(Vector3(1.0, 0.0, 1.0), 1500), "factory-callback baseline sync loads the initial window")
	var previous_ids: PackedStringArray = director.get_managed_chunk_ids()
	_factory_controller = controller
	_detach_on_next_factory = true
	_factory_calls = 0
	_expect(not director.sync_to_world_position(Vector3(21.0, 0.0, 1.0), 1501), "sync aborts when the factory detaches its controller")
	var report: Dictionary = director.get_last_sync_report()
	_expect(str(report.get("phase", "")) == "controller_lifecycle", "factory detachment reports controller_lifecycle")
	_expect(bool(report.get("details", {}).get("controller_detached", false)), "report identifies the detached controller")
	_expect(_factory_calls == 1, "factory callback is observed exactly once before abort")
	_expect(director.get_managed_chunk_ids() == previous_ids, "factory detachment preserves the prior managed window")
	_expect(_last_factory_root == null or _last_factory_root.get_ref() == null, "uncommitted factory candidate is released")
	root.add_child(controller)
	await process_frame
	_expect(director.sync_to_world_position(Vector3(21.0, 0.0, 1.0), 1502), "reattached controller can complete the requested window")
	director.queue_free()
	controller.queue_free()
	_factory_controller = null
	await process_frame

func _test_queued_controller_rejection() -> void:
	var pair: Dictionary = await _make_pair()
	var controller: Node3D = pair["controller"]
	var director: Node = pair["director"]
	_expect(director.sync_to_world_position(Vector3(1.0, 0.0, 1.0), 2000), "queued-controller baseline sync loads the initial window")
	var previous_ids: PackedStringArray = director.get_managed_chunk_ids()
	controller.queue_free()
	_factory_calls = 0
	_expect(not director.sync_to_world_position(Vector3(21.0, 0.0, 1.0), 2001), "sync rejects a controller queued for deletion")
	var report: Dictionary = director.get_last_sync_report()
	_expect(str(report.get("phase", "")) == "validation", "queued-controller sync reports validation failure")
	_expect(_factory_calls == 0, "queued-controller rejection happens before factory invocation")
	_expect(director.get_managed_chunk_ids() == previous_ids, "queued-controller rejection preserves managed IDs")
	_expect(not director.recover_to_world_position(Vector3(21.0, 0.0, 1.0), 2002), "recovery rejects a controller queued for deletion")
	_expect(str(director.get_last_sync_report().get("phase", "")) == "recovery_validation", "queued recovery reports its validation phase")
	director.queue_free()
	await process_frame

func _make_chunk(coord: Vector2i) -> Node3D:
	_factory_calls += 1
	var chunk := Node3D.new()
	chunk.name = "Run107Chunk_%d_%d" % [coord.x, coord.y]
	_last_factory_root = weakref(chunk)
	if _detach_on_next_factory:
		_detach_on_next_factory = false
		if is_instance_valid(_factory_controller):
			var current_parent: Node = _factory_controller.get_parent()
			if current_parent != null:
				current_parent.remove_child(_factory_controller)
	return chunk

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

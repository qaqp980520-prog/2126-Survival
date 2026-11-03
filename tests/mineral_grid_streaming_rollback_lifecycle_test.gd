extends SceneTree

const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const FakeController = preload("res://tests/helpers/FakeMineralChunkController.gd")

var _failures: Array[String] = []
var _factory_calls: int = 0
var _controller_to_detach: Node3D
var _detach_on_factory: bool = false
var _last_factory_root: WeakRef

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_factory_detaches_controller_before_restore()
	await _test_controller_detaches_during_restore_registration()
	await _test_rollback_skips_queued_controller()
	if _failures.is_empty():
		print("Mineral grid rollback lifecycle regression passed.")
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
	_expect(director.bind_controller(controller), "Director binds a live rollback-test Controller")
	_expect(director.bind_chunk_factory(Callable(self, "_make_chunk")), "Director binds the rollback-test factory")
	return {"controller": controller, "director": director}

func _test_factory_detaches_controller_before_restore() -> void:
	var pair: Dictionary = await _make_pair()
	var controller: Node3D = pair["controller"]
	var director: Node = pair["director"]
	_controller_to_detach = controller
	_detach_on_factory = true
	_factory_calls = 0
	var chunks: Array[Dictionary] = [{"id": "surface/chunk_2_0", "coord": Vector2i(2, 0)}]
	var restored: bool = bool(director.call("_restore_unloaded_chunks", chunks, 1000))
	_expect(not restored, "restore aborts when the factory detaches the Controller")
	_expect(_factory_calls == 1, "factory is invoked exactly once before lifecycle rejection")
	_expect(controller.load_calls == 0, "detached Controller receives no restoration registration")
	_expect(director.get_managed_chunk_ids().is_empty(), "failed pre-registration restore does not claim a chunk")
	_expect(_last_factory_root == null or _last_factory_root.get_ref() == null, "unowned candidate is released after factory detachment")
	controller.queue_free()
	director.queue_free()
	_controller_to_detach = null
	await process_frame

func _test_controller_detaches_during_restore_registration() -> void:
	var pair: Dictionary = await _make_pair()
	var controller: Node3D = pair["controller"]
	var director: Node = pair["director"]
	controller.detach_on_next_load = true
	_factory_calls = 0
	var chunks: Array[Dictionary] = [{"id": "surface/chunk_3_0", "coord": Vector2i(3, 0)}]
	var restored: bool = bool(director.call("_restore_unloaded_chunks", chunks, 2000))
	_expect(not restored, "restore reports failure when Controller detaches during registration")
	_expect(controller.load_calls == 1, "registration callback is reached exactly once")
	_expect(controller.unload_calls == 1, "newly restored root is rolled back after detachment")
	_expect(controller.get_loaded_chunk_ids().is_empty(), "detached Controller retains no partial restored root")
	_expect(director.get_managed_chunk_ids().is_empty(), "Director does not claim the rejected restoration")
	_expect(_last_factory_root == null or _last_factory_root.get_ref() == null, "rolled-back restoration root is released")
	controller.queue_free()
	director.queue_free()
	await process_frame

func _test_rollback_skips_queued_controller() -> void:
	var pair: Dictionary = await _make_pair()
	var controller: Node3D = pair["controller"]
	var director: Node = pair["director"]
	director.set("_managed_chunk_ids", {"surface/chunk_0_0": Vector2i.ZERO})
	controller.queue_free()
	var ids: Array[String] = ["surface/chunk_0_0"]
	var rollback_ok: bool = bool(director.call("_rollback_new_loads", ids, 3000))
	_expect(not rollback_ok, "rollback reports incomplete when its Controller is queued for deletion")
	_expect(controller.unload_calls == 0, "queued Controller receives no rollback method calls")
	_expect(director.get_managed_chunk_ids().is_empty(), "queued Controller clears stale Director ownership")
	director.queue_free()
	await process_frame

func _make_chunk(coord: Vector2i) -> Node3D:
	_factory_calls += 1
	var chunk := Node3D.new()
	chunk.name = "Run108Restore_%d_%d" % [coord.x, coord.y]
	_last_factory_root = weakref(chunk)
	if _detach_on_factory:
		_detach_on_factory = false
		if is_instance_valid(_controller_to_detach):
			var current_parent: Node = _controller_to_detach.get_parent()
			if current_parent != null:
				current_parent.remove_child(_controller_to_detach)
	return chunk

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)

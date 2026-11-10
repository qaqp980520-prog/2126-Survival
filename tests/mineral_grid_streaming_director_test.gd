extends SceneTree

const Registry = preload("res://systems/MineralVeinRegistry.gd")
const Controller = preload("res://systems/MineralChunkController.gd")
const Director = preload("res://systems/MineralGridStreamingDirector.gd")

class BatchFailureController extends Node3D:
	var _loaded: Dictionary = {}
	var _pending_unloads: Dictionary = {}
	var _batch_depth: int = 0
	var begin_calls: int = 0
	var end_calls: int = 0
	var fail_next_end: bool = false

	func begin_terrain_adjacency_batch() -> bool:
		if _batch_depth == 0 and not _pending_unloads.is_empty():
			return false
		begin_calls += 1
		_batch_depth += 1
		return true

	func end_terrain_adjacency_batch() -> Dictionary:
		if _batch_depth <= 0:
			return {"ok": true, "active": false}
		_batch_depth -= 1
		if _batch_depth > 0:
			return {"ok": true, "deferred": true}
		end_calls += 1
		if fail_next_end:
			fail_next_end = false
			# Match the production Controller's failed-commit contract: pending
			# retirements are cancelled, while newly registered roots remain owned.
			_pending_unloads.clear()
			return {"ok": false, "error": "injected_adjacency_commit_failure"}
		var retiring: Array = _pending_unloads.keys()
		for raw_id in retiring:
			_retire_chunk(str(raw_id))
		return {"ok": true, "retired_chunk_count": retiring.size()}

	func load_chunk(chunk_id: String, chunk_root: Node3D, _now_unix: int = -1) -> bool:
		if _loaded.has(chunk_id) or not is_instance_valid(chunk_root) or chunk_root.get_parent() != null:
			return false
		add_child(chunk_root)
		_loaded[chunk_id] = chunk_root
		return true

	func unload_chunk(chunk_id: String, _now_unix: int = -1) -> bool:
		if not _loaded.has(chunk_id):
			return false
		if _batch_depth > 0:
			_pending_unloads[chunk_id] = true
			return true
		_retire_chunk(chunk_id)
		return true

	func is_chunk_loaded(chunk_id: String) -> bool:
		return _loaded.has(chunk_id)

	func get_loaded_chunk_ids() -> PackedStringArray:
		var ids := PackedStringArray()
		for chunk_id in _loaded.keys():
			ids.append(str(chunk_id))
		ids.sort()
		return ids

	func _retire_chunk(chunk_id: String) -> void:
		if not _loaded.has(chunk_id):
			_pending_unloads.erase(chunk_id)
			return
		var chunk_root: Node3D = _loaded[chunk_id] as Node3D
		_loaded.erase(chunk_id)
		_pending_unloads.erase(chunk_id)
		if is_instance_valid(chunk_root) and chunk_root.get_parent() == self:
			remove_child(chunk_root)
			if not chunk_root.is_queued_for_deletion():
				chunk_root.queue_free()

var _fail_coordinate := Vector2i(999, 999)
var _created_coordinates: Array[Vector2i] = []

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await _test_load_move_and_unload()
	await process_frame
	await _test_generation_failure_preserves_active_set()
	await process_frame
	await _test_failed_batch_commit_restores_previous_window()
	await process_frame
	await _test_queued_root_recovery_uses_unbatched_fallback()
	await process_frame
	print("Mineral grid streaming director tests passed.")
	quit(0)

func _test_load_move_and_unload() -> void:
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	var director: Node = Director.new()
	root.add_child(registry)
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	assert(controller.bind_registry(registry))
	director.chunk_size_x = 10.0
	director.chunk_size_z = 10.0
	director.load_radius = 1
	assert(director.bind_controller(controller))
	assert(director.bind_chunk_factory(Callable(self, "_make_chunk")))
	assert(director.sync_to_world_position(Vector3(1, 0, 1), 1000))
	assert(controller.get_terrain_adjacency_rebuild_count() == 1, "initial nine-chunk window performs one shared adjacency rebind")
	assert(director.get_managed_chunk_ids().size() == 9)
	assert(controller.is_chunk_loaded("surface/chunk_0_0"))
	assert(controller.is_chunk_loaded("surface/chunk_-1_-1"))
	assert(director.sync_to_world_position(Vector3(21, 0, 1), 1001))
	assert(controller.get_terrain_adjacency_rebuild_count() == 2, "window movement batches three loads and three retirements into one adjacency rebind")
	assert(director.get_managed_chunk_ids().size() == 9)
	assert(controller.is_chunk_loaded("surface/chunk_2_0"))
	assert(not controller.is_chunk_loaded("surface/chunk_-1_0"))
	director.queue_free()
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _test_generation_failure_preserves_active_set() -> void:
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	var director: Node = Director.new()
	root.add_child(registry)
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	assert(controller.bind_registry(registry))
	director.chunk_size_x = 10.0
	director.chunk_size_z = 10.0
	director.load_radius = 1
	assert(director.bind_controller(controller))
	assert(director.bind_chunk_factory(Callable(self, "_make_chunk")))
	assert(director.sync_to_world_position(Vector3(1, 0, 1), 2000))
	var previous: PackedStringArray = director.get_managed_chunk_ids()
	# During the move to grid (2, 0), chunk (2, -1) loads before (3, -1) fails.
	# The director must roll that partial load back and preserve all nine old chunks.
	_fail_coordinate = Vector2i(3, -1)
	assert(not director.sync_to_world_position(Vector3(21, 0, 1), 2001))
	assert(director.get_managed_chunk_ids() == previous)
	assert(controller.is_chunk_loaded("surface/chunk_0_0"))
	assert(not controller.is_chunk_loaded("surface/chunk_2_-1"))
	assert(not controller.is_chunk_loaded("surface/chunk_3_-1"))
	assert(controller.get_terrain_adjacency_rebuild_count() == 2, "failed partial window load still closes with one rollback rebind")
	director.queue_free()
	controller.queue_free()
	registry.queue_free()
	await process_frame
	_fail_coordinate = Vector2i(999, 999)

func _test_failed_batch_commit_restores_previous_window() -> void:
	var controller := BatchFailureController.new()
	var director: Node = Director.new()
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	director.set("chunk_size_x", 10.0)
	director.set("chunk_size_z", 10.0)
	director.set("load_radius", 1)
	assert(bool(director.call("bind_controller", controller)), "Director binds a batch-aware Controller")
	assert(bool(director.call("bind_chunk_factory", Callable(self, "_make_chunk"))), "Director binds the batch recovery factory")
	assert(bool(director.call("sync_to_world_position", Vector3(1, 0, 1), 3000)), "initial batch-aware window commits")
	var previous_ids: PackedStringArray = director.call("get_managed_chunk_ids")
	assert(previous_ids.size() == 9, "initial batch-aware window owns nine chunks")

	controller.fail_next_end = true
	var shifted: bool = bool(director.call("sync_to_world_position", Vector3(21, 0, 1), 3001))
	var report: Dictionary = director.call("get_last_sync_report")
	assert(not shifted, "Director reports a failed terrain batch commit")
	assert(str(report.get("phase", "")) == "terrain_adjacency_commit", "failed batch commit has a distinct report phase")
	assert(bool(report.get("rollback_complete", false)), "failed batch commit restores the complete previous window")
	assert(controller.get_loaded_chunk_ids() == previous_ids, "Controller owns exactly the original nine chunks after recovery")
	assert(director.call("get_managed_chunk_ids") == previous_ids, "Director mirror matches the restored Controller window")
	assert(controller.begin_calls == 3 and controller.end_calls == 3, "one failed commit is recovered by exactly one second batch")
	controller.queue_free()
	director.queue_free()
	await process_frame

func _test_queued_root_recovery_uses_unbatched_fallback() -> void:
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	var director: Node = Director.new()
	root.add_child(registry)
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	assert(controller.bind_registry(registry))
	director.chunk_size_x = 10.0
	director.chunk_size_z = 10.0
	director.load_radius = 0
	assert(director.bind_controller(controller))
	assert(director.bind_chunk_factory(Callable(self, "_make_chunk")))
	assert(director.sync_to_world_position(Vector3(1, 0, 1), 4000))
	var chunk_id := "surface/chunk_0_0"
	var old_root: Node3D = controller.get_chunk_root(chunk_id)
	var old_root_ref: WeakRef = weakref(old_root)
	assert(is_instance_valid(old_root))
	old_root.queue_free()
	assert(not controller.is_chunk_loaded(chunk_id), "queued root is not reported as a live chunk")
	assert(director.sync_to_world_position(Vector3(1, 0, 1), 4001), "same-ID queued-root recovery uses the immediate replacement path")
	var replacement_root: Node3D = controller.get_chunk_root(chunk_id)
	assert(is_instance_valid(replacement_root) and replacement_root != old_root, "queued-root recovery registers a new root instance")
	assert(controller.get_terrain_adjacency_rebuild_count() == 2, "queued-root replacement performs one immediate rebind instead of a pending batch overwrite")
	await process_frame
	assert(old_root_ref.get_ref() == null, "replaced queued root is released after recovery")
	director.queue_free()
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _make_chunk(coord: Vector2i) -> Node3D:
	if coord == _fail_coordinate:
		return null
	_created_coordinates.append(coord)
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	return chunk

extends SceneTree

const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const FakeController = preload("res://tests/helpers/FakeMineralChunkController.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: Node3D = FakeController.new()
	var director: Node = Director.new()
	root.add_child(controller)
	root.add_child(director)
	await process_frame

	director.chunk_size_x = 10.0
	director.chunk_size_z = 10.0
	director.load_radius = 1
	assert(director.bind_controller(controller))
	assert(director.bind_chunk_factory(Callable(self, "_make_chunk")))
	assert(director.sync_to_world_position(Vector3(1.0, 0.0, 1.0), 1000))
	var original_ids: PackedStringArray = director.get_managed_chunk_ids()
	assert(original_ids.size() == 9)
	assert(controller.get_loaded_chunk_ids() == original_ids)

	# The second stale unload fails after the first one has already succeeded.
	# The director must roll back newly loaded chunks and recreate the unloaded stale chunk.
	controller.fail_on_unload_call = controller.unload_calls + 2
	assert(not director.sync_to_world_position(Vector3(21.0, 0.0, 1.0), 1001))
	assert(director.get_managed_chunk_ids() == original_ids)
	assert(controller.get_loaded_chunk_ids() == original_ids)
	print("Mineral grid streaming transactional rollback tests passed.")
	director.queue_free()
	controller.queue_free()
	await process_frame
	quit(0)

func _make_chunk(coord: Vector2i) -> Node3D:
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]
	return chunk_root

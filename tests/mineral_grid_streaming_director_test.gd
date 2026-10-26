extends SceneTree

const Registry = preload("res://systems/MineralVeinRegistry.gd")
const Controller = preload("res://systems/MineralChunkController.gd")
const Director = preload("res://systems/MineralGridStreamingDirector.gd")

var _fail_coordinate := Vector2i(999, 999)
var _created_coordinates: Array[Vector2i] = []

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await _test_load_move_and_unload()
	await process_frame
	await _test_generation_failure_preserves_active_set()
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
	assert(director.get_managed_chunk_ids().size() == 9)
	assert(controller.is_chunk_loaded("surface/chunk_0_0"))
	assert(controller.is_chunk_loaded("surface/chunk_-1_-1"))
	assert(director.sync_to_world_position(Vector3(21, 0, 1), 1001))
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
	director.load_radius = 0
	assert(director.bind_controller(controller))
	assert(director.bind_chunk_factory(Callable(self, "_make_chunk")))
	assert(director.sync_to_world_position(Vector3(1, 0, 1), 2000))
	var previous := director.get_managed_chunk_ids()
	_fail_coordinate = Vector2i(1, 0)
	assert(not director.sync_to_world_position(Vector3(11, 0, 1), 2001))
	assert(director.get_managed_chunk_ids() == previous)
	assert(controller.is_chunk_loaded("surface/chunk_0_0"))
	assert(not controller.is_chunk_loaded("surface/chunk_1_0"))
	director.queue_free()
	controller.queue_free()
	registry.queue_free()
	await process_frame
	_fail_coordinate = Vector2i(999, 999)

func _make_chunk(coord: Vector2i) -> Node3D:
	if coord == _fail_coordinate:
		return null
	_created_coordinates.append(coord)
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	return chunk

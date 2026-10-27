extends SceneTree

const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const FakeController = preload("res://tests/helpers/FakeMineralChunkController.gd")

var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var controller: Node3D = FakeController.new()
	var director: Node = Director.new()
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	director.chunk_size_x = 10.0
	director.chunk_size_z = 10.0
	director.load_radius = 0
	_check(bool(director.bind_controller(controller)), "Director should bind controller.")
	_check(bool(director.bind_chunk_factory(Callable(self, "_make_chunk"))), "Director should bind factory.")

	var seed_root := Node3D.new()
	seed_root.name = "SeedChunk"
	_check(bool(controller.call("load_chunk", "surface/chunk_0_0", seed_root, 1000)), "Seed chunk should load.")
	var actual_before: PackedStringArray = controller.call("get_loaded_chunk_ids")
	var managed_before: PackedStringArray = director.get_managed_chunk_ids()

	_check(not bool(director.recover_to_world_position(Vector3(NAN, 0.0, 0.0), 1001)), "Recovery must reject NaN coordinates.")
	var recovery_report: Dictionary = director.get_last_sync_report()
	_check(str(recovery_report.get("phase", "")) == "recovery_validation", "NaN recovery should report recovery_validation.")
	_check(director.get_managed_chunk_ids() == managed_before, "Rejected NaN recovery must not mutate the managed map.")
	_check(PackedStringArray(controller.call("get_loaded_chunk_ids")) == actual_before, "Rejected NaN recovery must not mutate controller chunks.")

	_check(not bool(director.sync_to_world_position(Vector3(INF, 0.0, 0.0), 1002)), "Sync must reject infinite coordinates.")
	var sync_report: Dictionary = director.get_last_sync_report()
	_check(str(sync_report.get("phase", "")) == "validation", "Infinite sync should report validation.")
	_check(director.get_managed_chunk_ids() == managed_before, "Rejected infinite sync must not mutate the managed map.")
	_check(PackedStringArray(controller.call("get_loaded_chunk_ids")) == actual_before, "Rejected infinite sync must not mutate controller chunks.")
	_check(not bool(director.sync_to_world_position(Vector3(1.0e30, 0.0, 0.0), 1003)), "Sync must reject huge but finite coordinates before integer conversion.")
	var huge_sync_report: Dictionary = director.get_last_sync_report()
	_check(str(huge_sync_report.get("phase", "")) == "validation", "Huge finite sync should report validation.")
	_check(director.get_managed_chunk_ids() == managed_before, "Rejected huge sync must not mutate the managed map.")
	_check(PackedStringArray(controller.call("get_loaded_chunk_ids")) == actual_before, "Rejected huge sync must not mutate controller chunks.")
	_check(not bool(director.recover_to_world_position(Vector3(-1.0e30, 0.0, 0.0), 1004)), "Recovery must reject huge but finite coordinates.")
	var huge_recovery_report: Dictionary = director.get_last_sync_report()
	_check(str(huge_recovery_report.get("phase", "")) == "recovery_validation", "Huge finite recovery should report recovery_validation.")
	_check(director.get_managed_chunk_ids() == managed_before, "Rejected huge recovery must not mutate the managed map.")
	_check(PackedStringArray(controller.call("get_loaded_chunk_ids")) == actual_before, "Rejected huge recovery must not mutate controller chunks.")
	_check(director.get_grid_coordinate(Vector3(NAN, 0.0, 0.0)) == Vector2i.ZERO, "Coordinate helper should safely return zero for non-finite input.")
	_check(director.get_grid_coordinate(Vector3(1.0e30, 0.0, 0.0)) == Vector2i.ZERO, "Coordinate helper should safely return zero for out-of-range input.")
	director.chunk_size_x = NAN
	_check(not bool(director.sync_to_world_position(Vector3(1.0, 0.0, 1.0), 1005)), "Sync must reject a non-finite chunk size.")
	_check(director.get_managed_chunk_ids() == managed_before, "Invalid chunk size must not mutate the managed map.")
	director.chunk_size_x = 10.0

	director.queue_free()
	controller.queue_free()
	await process_frame
	if _failed:
		print("Mineral grid streaming position validation tests failed.")
		quit(1)
	else:
		print("Mineral grid streaming position validation tests passed.")
		quit(0)

func _make_chunk(coord: Vector2i) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	return chunk

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

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

	var original_chunk_size_x: float = director.chunk_size_x
	var original_chunk_size_z: float = director.chunk_size_z
	var original_radius: int = director.load_radius
	_check(bool(director.call("_is_valid_grid_configuration")), "Default and existing valid grid configuration is accepted.")

	director.chunk_size_x = 1.0
	director.chunk_size_z = 4096.0
	_check(bool(director.call("_is_valid_grid_configuration")), "Inclusive minimum and maximum chunk dimensions are accepted.")
	director.chunk_size_x = 4096.0
	director.chunk_size_z = 1.0
	_check(bool(director.call("_is_valid_grid_configuration")), "Both chunk axes accept the opposite inclusive dimension boundaries.")

	director.chunk_size_x = 0.999
	_check(not bool(director.call("_is_valid_grid_configuration")), "Chunk width below the Inspector minimum is rejected.")
	_check(not bool(director.sync_to_world_position(Vector3(15.0, 0.0, 15.0), 1010)), "Synchronous streaming rejects a chunk width below one.")
	var narrow_width_report: Dictionary = director.get_last_sync_report()
	_check(str(narrow_width_report.get("phase", "")) == "validation" and str(narrow_width_report.get("message", "")).contains("between 1 and 4096"), "Narrow-width rejection reports the supported dimension range.")
	_check(not bool(director.recover_to_world_position(Vector3(15.0, 0.0, 15.0), 1011)), "Recovery rejects a chunk width below one before ownership reconciliation.")
	_check(director.get_managed_chunk_ids() == managed_before and PackedStringArray(controller.call("get_loaded_chunk_ids")) == actual_before, "Rejected narrow-width sync and recovery preserve both ownership maps.")

	director.chunk_size_x = 4096.001
	_check(not bool(director.sync_to_world_position(Vector3(15.0, 0.0, 15.0), 1012)), "Synchronous streaming rejects a chunk width above 4096.")
	_check(director.get_managed_chunk_ids() == managed_before and PackedStringArray(controller.call("get_loaded_chunk_ids")) == actual_before, "Rejected oversized width leaves both ownership maps unchanged.")

	director.chunk_size_x = original_chunk_size_x
	director.chunk_size_z = 0.999
	_check(not bool(director.sync_to_world_position(Vector3(15.0, 0.0, 15.0), 1013)), "Synchronous streaming rejects a chunk depth below one.")
	_check(director.get_managed_chunk_ids() == managed_before and PackedStringArray(controller.call("get_loaded_chunk_ids")) == actual_before, "Rejected narrow depth leaves both ownership maps unchanged.")

	director.chunk_size_z = 4096.001
	_check(not bool(director.recover_to_world_position(Vector3(15.0, 0.0, 15.0), 1014)), "Recovery rejects a chunk depth above 4096 before ownership reconciliation.")
	var oversized_depth_report: Dictionary = director.get_last_sync_report()
	_check(str(oversized_depth_report.get("phase", "")) == "recovery_validation" and str(oversized_depth_report.get("message", "")).contains("between 1 and 4096"), "Oversized-depth recovery reports the supported dimension range.")
	_check(director.get_managed_chunk_ids() == managed_before and PackedStringArray(controller.call("get_loaded_chunk_ids")) == actual_before, "Rejected oversized depth preserves both ownership maps.")

	director.chunk_size_z = INF
	_check(not bool(director.recover_to_world_position(Vector3(15.0, 0.0, 15.0), 1014)), "Recovery rejects an infinite chunk depth before ownership reconciliation.")
	var infinite_depth_report: Dictionary = director.get_last_sync_report()
	_check(str(infinite_depth_report.get("phase", "")) == "recovery_validation" and str(infinite_depth_report.get("message", "")).contains("between 1 and 4096"), "Infinite-depth recovery reports the supported dimension range.")
	_check(director.get_managed_chunk_ids() == managed_before and PackedStringArray(controller.call("get_loaded_chunk_ids")) == actual_before, "Rejected infinite depth preserves both ownership maps.")

	director.chunk_size_z = -10.0
	_check(not bool(director.call("_is_safe_grid_position", Vector3(15.0, 0.0, 15.0))), "Shared configuration guard rejects a negative chunk depth.")
	_check(director.get_grid_coordinate(Vector3(15.0, 0.0, 15.0)) == Vector2i.ZERO, "Coordinate helper rejects a negative chunk depth.")
	_check(not bool(director.recover_to_world_position(Vector3(15.0, 0.0, 15.0), 1014)), "Recovery rejects a negative chunk depth before ownership reconciliation.")
	_check(director.get_managed_chunk_ids() == managed_before and PackedStringArray(controller.call("get_loaded_chunk_ids")) == actual_before, "Rejected negative depth preserves both ownership maps.")

	director.chunk_size_x = original_chunk_size_x
	director.chunk_size_z = original_chunk_size_z
	director.load_radius = 8
	_check(bool(director.call("_is_valid_grid_configuration")) and bool(director.call("_is_safe_grid_position", Vector3(15.0, 0.0, 15.0))), "Maximum supported runtime radius eight remains valid.")
	director.load_radius = 9
	_check(not bool(director.sync_to_world_position(Vector3(15.0, 0.0, 15.0), 1015)), "Synchronous streaming rejects a runtime radius above eight.")
	var excessive_radius_report: Dictionary = director.get_last_sync_report()
	_check(str(excessive_radius_report.get("phase", "")) == "validation" and str(excessive_radius_report.get("message", "")).contains("0 and 8"), "Excessive-radius sync reports the supported 0–8 range.")
	_check(not bool(director.recover_to_world_position(Vector3(15.0, 0.0, 15.0), 1016)), "Recovery rejects an excessive runtime radius before ownership reconciliation.")
	_check(str(director.get_last_sync_report().get("phase", "")) == "recovery_validation", "Excessive-radius recovery reports recovery_validation.")
	_check(director.get_managed_chunk_ids() == managed_before and PackedStringArray(controller.call("get_loaded_chunk_ids")) == actual_before, "Rejected excessive radius preserves both ownership maps.")
	_check(director.get_grid_coordinate(Vector3(15.0, 0.0, 15.0)) == Vector2i.ZERO, "Coordinate helper safely rejects an excessive runtime radius.")

	director.load_radius = -1
	_check(not bool(director.call("_is_valid_grid_configuration")), "Negative runtime radius is rejected by the shared configuration guard.")
	_check(not bool(director.sync_to_world_position(Vector3(15.0, 0.0, 15.0), 1017)), "Synchronous streaming rejects a negative runtime radius.")
	_check(not bool(director.recover_to_world_position(Vector3(15.0, 0.0, 15.0), 1018)), "Recovery rejects a negative runtime radius.")
	_check(director.get_managed_chunk_ids() == managed_before and PackedStringArray(controller.call("get_loaded_chunk_ids")) == actual_before, "Rejected negative radius preserves both ownership maps.")
	_check(director.get_grid_coordinate(Vector3(15.0, 0.0, 15.0)) == Vector2i.ZERO, "Coordinate helper safely rejects a negative runtime radius.")

	director.chunk_size_x = original_chunk_size_x
	director.chunk_size_z = original_chunk_size_z
	director.load_radius = original_radius

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

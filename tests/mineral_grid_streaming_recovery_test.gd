extends SceneTree

const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const FakeController = preload("res://tests/helpers/FakeMineralChunkController.gd")

var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var controller: Variant = FakeController.new()
	var director: Node = Director.new()
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	director.chunk_size_x = 10.0
	director.chunk_size_z = 10.0
	director.load_radius = 1
	_check(bool(director.bind_controller(controller)), "Director should bind the fake controller.")
	_check(bool(director.bind_chunk_factory(Callable(self, "_make_chunk"))), "Director should bind the factory.")

	# Seed the controller with the state left by an incomplete rollback: eight valid
	# grid chunks, with surface/chunk_-1_-1 missing and no trusted director map.
	for z in range(-1, 2):
		for x in range(-1, 2):
			if x == -1 and z == -1:
				continue
			var chunk_id: String = "surface/chunk_%d_%d" % [x, z]
			var chunk_root := Node3D.new()
			chunk_root.name = "Chunk_%d_%d" % [x, z]
			_check(bool(controller.load_chunk(chunk_id, chunk_root, 1000)), "Seed chunk should load into the fake controller.")

	_check(controller.get_loaded_chunk_ids().size() == 8, "Seed state must contain eight loaded chunks.")
	_check(bool(director.recover_to_world_position(Vector3(1.0, 0.0, 1.0), 1001)), "Recovery should fill the missing chunk in the target window.")
	_check(controller.get_loaded_chunk_ids().size() == 9, "Recovered controller should own nine chunks.")
	_check(director.get_managed_chunk_ids() == controller.get_loaded_chunk_ids(), "Recovered director/controller ID sets must match.")
	_check(controller.get_loaded_chunk_ids().has("surface/chunk_-1_-1"), "Recovery should restore the missing grid chunk.")
	var report: Dictionary = director.get_last_sync_report()
	_check(bool(report.get("success", false)), "Successful recovery must publish a successful report.")
	_check(str(report.get("phase", "")) == "complete", "Successful recovery report phase should be complete.")

	# A foreign ID must be rejected before the current managed map is changed.
	var unknown_root := Node3D.new()
	unknown_root.name = "UnknownChunk"
	_check(bool(controller.load_chunk("custom/not-a-grid-id", unknown_root, 1002)), "Test should inject a foreign controller ID.")
	var before_invalid_recovery: PackedStringArray = director.get_managed_chunk_ids()
	_check(not bool(director.recover_to_world_position(Vector3(1.0, 0.0, 1.0), 1003)), "Unknown ID format must be rejected.")
	var invalid_report: Dictionary = director.get_last_sync_report()
	_check(str(invalid_report.get("phase", "")) == "recovery_validation", "Unknown IDs should report recovery_validation.")
	_check(director.get_managed_chunk_ids() == before_invalid_recovery, "Rejected recovery must not mutate the managed map.")
	_check(bool(controller.unload_chunk("custom/not-a-grid-id", 1004)), "Remove the first invalid test ID.")
	var alias_root := Node3D.new()
	alias_root.name = "AliasedChunk"
	_check(bool(controller.load_chunk("surface/chunk_01_1", alias_root, 1005)), "Inject a parseable but non-canonical chunk ID.")
	var before_alias_recovery: PackedStringArray = director.get_managed_chunk_ids()
	var before_alias_controller: PackedStringArray = controller.get_loaded_chunk_ids()
	_check(not bool(director.recover_to_world_position(Vector3(1.0, 0.0, 1.0), 1006)), "Recovery must reject non-canonical coordinate aliases.")
	var alias_report: Dictionary = director.get_last_sync_report()
	var alias_details: Dictionary = alias_report.get("details", {})
	_check(str(alias_report.get("phase", "")) == "recovery_validation", "Non-canonical IDs should report recovery_validation.")
	_check(alias_details.get("unrecognized_chunk_ids", []).has("surface/chunk_01_1"), "Report should identify the non-canonical ID.")
	_check(director.get_managed_chunk_ids() == before_alias_recovery, "Rejected alias recovery must not mutate the managed map.")
	_check(controller.get_loaded_chunk_ids() == before_alias_controller, "Rejected alias recovery must not mutate controller chunks.")

	director.queue_free()
	controller.queue_free()
	await process_frame
	if _failed:
		print("Mineral grid streaming recovery tests failed.")
		quit(1)
	else:
		print("Mineral grid streaming recovery tests passed.")
		quit(0)

func _make_chunk(coord: Vector2i) -> Node3D:
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]
	return chunk_root

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

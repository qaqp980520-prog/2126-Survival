extends SceneTree

const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const FakeController = preload("res://tests/helpers/FakeMineralChunkController.gd")

var _failed: bool = false
var _failure_signal_count: int = 0
var _failure_report: Dictionary = {}
var _fail_restore_coord: Vector2i = Vector2i(999999, 999999)

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
	director.sync_failed.connect(_on_sync_failed)
	_check(bool(director.bind_controller(controller)), "Director should bind the fake controller.")
	_check(bool(director.bind_chunk_factory(Callable(self, "_make_chunk"))), "Director should bind its factory.")
	_check(bool(director.sync_to_world_position(Vector3(1.0, 0.0, 1.0), 1000)), "Initial window should load.")
	var success_report: Dictionary = director.get_last_sync_report()
	_check(bool(success_report.get("success", false)), "Successful sync should be reported.")
	_check(str(success_report.get("phase", "")) == "complete", "Successful sync phase should be complete.")
	_check(bool(success_report.get("rollback_complete", false)), "Successful sync should have no rollback failure.")

	# The first stale chunk unload succeeds, the second fails, and restoring the first
	# chunk fails at the factory. The report must expose the incomplete rollback.
	controller.fail_on_unload_call = controller.unload_calls + 2
	_fail_restore_coord = Vector2i(-1, -1)
	_check(not bool(director.sync_to_world_position(Vector3(21.0, 0.0, 1.0), 1001)), "Injected stale unload failure should fail sync.")
	var report: Dictionary = director.get_last_sync_report()
	var details: Dictionary = report.get("details", {})
	_check(str(report.get("phase", "")) == "stale_unload", "Failure phase should identify stale unload.")
	_check(not bool(report.get("success", true)), "Failed sync must not be reported as successful.")
	_check(not bool(report.get("rollback_complete", true)), "Failed restoration must be reported as incomplete.")
	_check(bool(details.get("new_loads_rollback_ok", false)), "New chunks should be rolled back.")
	_check(not bool(details.get("stale_restore_ok", true)), "Failed stale restoration should be explicit.")
	var managed_ids: PackedStringArray = report.get("managed_chunk_ids", PackedStringArray())
	var controller_ids: PackedStringArray = report.get("controller_chunk_ids", PackedStringArray())
	_check(managed_ids == controller_ids, "Report must show the director and controller actual active sets.")
	_check(not managed_ids.has("surface/chunk_-1_-1"), "Report must expose the stale chunk that could not be restored.")
	_check(_failure_signal_count == 1, "Exactly one failure signal should be emitted for the failed sync.")
	_check(str(_failure_report.get("phase", "")) == "stale_unload", "Failure signal should carry the same phase.")

	# Recover the previous window after removing the injected factory failure.
	_fail_restore_coord = Vector2i(999999, 999999)
	_check(bool(director.recover_to_world_position(Vector3(1.0, 0.0, 1.0), 1002)), "Recovery should restore the previous grid window.")
	_check(controller.get_loaded_chunk_ids().size() == 9, "Recovered controller should again own nine chunks.")
	_check(director.get_managed_chunk_ids() == controller.get_loaded_chunk_ids(), "Recovered director/controller ID sets must match.")
	_check(controller.get_loaded_chunk_ids().has("surface/chunk_-1_-1"), "Recovery should reload the missing stale chunk.")

	# Unknown controller IDs must be rejected without replacing the managed map.
	var unknown_root := Node3D.new()
	unknown_root.name = "UnknownChunk"
	_check(bool(controller.load_chunk("custom/not-a-grid-id", unknown_root, 1003)), "Test should inject a foreign controller ID.")
	var before_invalid_recovery: PackedStringArray = director.get_managed_chunk_ids()
	_check(not bool(director.recover_to_world_position(Vector3(1.0, 0.0, 1.0), 1003)), "Unknown ID format must be rejected.")
	var invalid_report: Dictionary = director.get_last_sync_report()
	_check(str(invalid_report.get("phase", "")) == "recovery_validation", "Unknown IDs should report recovery_validation.")
	_check(director.get_managed_chunk_ids() == before_invalid_recovery, "Rejected recovery must not mutate the managed map.")
	director.queue_free()
	controller.queue_free()
	await process_frame
	if _failed:
		print("Mineral grid streaming failure diagnostics tests failed.")
		OS.set_exit_code(1)
		quit(1)
	else:
		print("Mineral grid streaming failure diagnostics and recovery tests passed.")
		OS.set_exit_code(0)
		quit(0)

func _make_chunk(coord: Vector2i) -> Node3D:
	if coord == _fail_restore_coord:
		return null
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]
	return chunk_root

func _on_sync_failed(report: Dictionary) -> void:
	_failure_signal_count += 1
	_failure_report = report.duplicate(true)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


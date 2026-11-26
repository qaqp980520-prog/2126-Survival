extends SceneTree

const Registry = preload("res://systems/MineralVeinRegistry.gd")
const Controller = preload("res://systems/MineralChunkController.gd")
const Adapter = preload("res://systems/MineralChunkLifecycleAdapter.gd")
const MiningNode = preload("res://systems/MineralMiningNode.gd")
const Director = preload("res://systems/MineralGridStreamingDirector.gd")

class RecoveryReportingController extends "res://systems/MineralChunkController.gd":
	var fail_next_load_with_recovery: bool = false
	var fail_next_unload_with_recovery: bool = false
	var recovery_pending: bool = false
	var unload_recovery_pending: bool = false
	var unload_attempt_count: int = 0
	var last_load_report: Dictionary = {}

	func load_chunk(chunk_id: String, chunk_root: Node3D, now_unix: int = -1) -> bool:
		if fail_next_load_with_recovery:
			fail_next_load_with_recovery = false
			recovery_pending = true
			last_load_report = {
				"success": false,
				"phase": "world_object_restore",
				"rollback_complete": false,
				"recovery_required": true,
				"details": {"crop_registry_ok": false}
			}
			return false
		return super.load_chunk(chunk_id, chunk_root, now_unix)

	func unload_chunk(chunk_id: String, now_unix: int = -1) -> bool:
		unload_attempt_count += 1
		if unload_recovery_pending:
			return false
		if fail_next_unload_with_recovery:
			fail_next_unload_with_recovery = false
			unload_recovery_pending = true
			last_load_report = {
				"success": false,
				"phase": "world_object_capture",
				"rollback_complete": false,
				"recovery_required": true,
				"details": {"world_object_registry_rollback_ok": false}
			}
			return false
		return super.unload_chunk(chunk_id, now_unix)

	func has_pending_chunk_load_recovery() -> bool:
		return recovery_pending or unload_recovery_pending

	func get_last_chunk_load_report() -> Dictionary:
		return last_load_report.duplicate(true)

	func recover_failed_chunk_load() -> bool:
		recovery_pending = false
		unload_recovery_pending = false
		last_load_report = {
			"success": true,
			"phase": "recovery_complete",
			"rollback_complete": true,
			"recovery_required": false,
			"details": {}
		}
		return true

var _fail_coordinate := Vector2i(999, 999)
var _registration_fail_coordinate := Vector2i(999, 999)
var _registration_now: int = 0
var _registration_first: Node
var _registration_second: Node
var _registration_first_before: Dictionary = {}
var _registration_second_before: Dictionary = {}
var _created_coordinates: Array[Vector2i] = []

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await _test_load_move_and_unload()
	await process_frame
	await _test_generation_failure_preserves_active_set()
	await process_frame
	await _test_registration_failure_preserves_active_window()
	await process_frame
	await _test_controller_rollback_state_propagates_to_director_report()
	await process_frame
	await _test_controller_unload_recovery_barrier_propagates_to_director_report()
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
	director.queue_free()
	controller.queue_free()
	registry.queue_free()
	await process_frame
	_fail_coordinate = Vector2i(999, 999)

func _test_registration_failure_preserves_active_window() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	_registration_now = now
	_registration_fail_coordinate = Vector2i(3, -1)
	_registration_first = null
	_registration_second = null

	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	var director: Node = Director.new()
	root.add_child(registry)
	root.add_child(controller)
	root.add_child(director)
	await process_frame

	var chunk_id := "surface/chunk_3_-1"
	var first_id: String = Adapter.make_stable_id(chunk_id, "Chunk_3_-1/gold-01")
	var second_id: String = Adapter.make_stable_id(chunk_id, "Chunk_3_-1/iron-02")
	var saved_first: Dictionary = {
		"schema_version": 2,
		"mineral_id": "gold_ore",
		"remaining_units": 3,
		"max_units": 8,
		"regen_interval_seconds": 60,
		"last_regen_unix": now - 120
	}
	var saved_second: Dictionary = saved_first.duplicate(true)
	saved_second["remaining_units"] = 2
	assert(registry.restore_save_dict({
		"schema_version": 1,
		"veins": {first_id: saved_first, second_id: saved_second}
	}, now), "Seed the target chunk with a compatible first record and an incompatible later record")
	var registry_before: Dictionary = registry.to_save_dict()

	assert(controller.bind_registry(registry))
	director.chunk_size_x = 10.0
	director.chunk_size_z = 10.0
	director.load_radius = 1
	assert(director.bind_controller(controller))
	assert(director.bind_chunk_factory(Callable(self, "_make_chunk")))
	assert(director.sync_to_world_position(Vector3(1, 0, 1), now), "Initial active window should load before the registration failure")
	var previous_managed: PackedStringArray = director.get_managed_chunk_ids()
	var previous_controller: PackedStringArray = controller.get_loaded_chunk_ids()
	assert(previous_managed.size() == 9 and previous_controller == previous_managed, "Initial Director and Controller active windows should match")

	# The move to grid (2, 0) loads chunk (2, -1) before the target (3, -1)
	# fails its second saved-record mineral identity check. The new batch API must
	# leave the target nodes and Registry payload unchanged, then Director must
	# roll back the earlier new chunk and preserve the previous nine-chunk window.
	assert(not director.sync_to_world_position(Vector3(21, 0, 1), now), "A later saved-record mineral mismatch must reject the new active window")
	var report: Dictionary = director.get_last_sync_report()
	var details: Dictionary = report.get("details", {})
	assert(not bool(report.get("success", true)), "Rejected registration must publish a failed sync report")
	assert(str(report.get("phase", "")) == "load_registration", "Saved-record mismatch should report load_registration")
	assert(bool(report.get("rollback_complete", false)), "Director should report complete rollback of the previous active window")
	assert(bool(details.get("candidate_cleanup_ok", false)), "Rejected candidate root should be cleaned up")
	assert(bool(details.get("new_loads_rollback_ok", false)), "Earlier newly loaded chunks should roll back successfully")
	assert(details.get("newly_loaded_ids", []).has("surface/chunk_2_-1"), "Report should identify the earlier new chunk that was rolled back")
	assert(director.get_managed_chunk_ids() == previous_managed, "Director must restore its exact previous active-window ID set")
	assert(controller.get_loaded_chunk_ids() == previous_controller, "Controller must restore its exact previous loaded-chunk ID set")
	assert(not controller.is_chunk_loaded("surface/chunk_2_-1"), "Earlier newly loaded chunk must not remain after rollback")
	assert(not controller.is_chunk_loaded(chunk_id), "Rejected target chunk must not be published")
	assert(registry.get_registered_ids().is_empty(), "Failed target registration must commit no live mineral IDs")
	assert(registry.to_save_dict() == registry_before, "Failed target registration must preserve the complete Registry save payload")
	assert(not is_instance_valid(_registration_first) and not is_instance_valid(_registration_second), "Director must release the rejected candidate root after Controller detaches it")

	director.queue_free()
	controller.queue_free()
	registry.queue_free()
	await process_frame
	_registration_fail_coordinate = Vector2i(999, 999)
	_registration_first = null
	_registration_second = null

func _test_controller_rollback_state_propagates_to_director_report() -> void:
	var registry: Node = Registry.new()
	var controller: Node3D = RecoveryReportingController.new()
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
	assert(director.sync_to_world_position(Vector3(1, 0, 1), 3000))
	var previous: PackedStringArray = director.get_managed_chunk_ids()
	assert(previous.size() == 1)

	controller.set("fail_next_load_with_recovery", true)
	assert(not director.sync_to_world_position(Vector3(21, 0, 1), 3001))
	var report: Dictionary = director.get_last_sync_report()
	var details: Dictionary = report.get("details", {})
	assert(str(report.get("phase", "")) == "load_registration")
	assert(bool(details.get("candidate_cleanup_ok", false)), "The rejected detached candidate was safely retained for recovery")
	assert(bool(details.get("new_loads_rollback_ok", false)), "No earlier new chunks needed rollback in this radius-zero move")
	assert(bool(details.get("controller_load_recovery_required", false)), "The Director surfaces the Controller recovery barrier")
	assert(not bool(details.get("controller_load_rollback_complete", true)), "The Controller's incomplete rollback is propagated")
	assert(not bool(report.get("rollback_complete", true)), "The Director must not claim complete rollback when the Controller reports incomplete recovery")
	assert(director.get_pending_recovery_root_count() == 1, "The failed detached candidate is retained so Controller recovery references remain valid")
	assert(director.get_managed_chunk_ids() == previous, "The previous Director active set remains unchanged")
	assert(controller.get_loaded_chunk_ids() == previous, "The previous Controller active set remains unchanged")

	assert(director.recover_to_world_position(Vector3(21, 0, 1), 3002), "Explicit Director recovery retries Controller recovery before reconciling the window")
	assert(director.get_pending_recovery_root_count() == 0, "The retained failed candidate is released only after Controller recovery succeeds")
	assert(director.get_managed_chunk_ids().size() == 1)
	assert(controller.get_loaded_chunk_ids() == director.get_managed_chunk_ids())
	director.queue_free()
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _test_controller_unload_recovery_barrier_propagates_to_director_report() -> void:
	var registry: Node = Registry.new()
	var controller: Node3D = RecoveryReportingController.new()
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
	assert(director.sync_to_world_position(Vector3(1, 0, 1), 4000), "Initial active chunk loads")
	assert(controller.get_loaded_chunk_ids().size() == 1)
	controller.set("fail_next_unload_with_recovery", true)
	var unload_attempts_before: int = int(controller.get("unload_attempt_count"))

	assert(not director.sync_to_world_position(Vector3(21, 0, 1), 4001), "A stale unload with pending participant recovery stops the window shift")
	assert(int(controller.get("unload_attempt_count")) == unload_attempts_before + 1, "Director must not issue compensating unloads while the Controller recovery barrier is active")
	var report: Dictionary = director.get_last_sync_report()
	var details: Dictionary = report.get("details", {})
	assert(str(report.get("phase", "")) == "stale_unload")
	assert(not bool(report.get("rollback_complete", true)), "Director cannot claim a complete rollback while Controller recovery is pending")
	assert(bool(details.get("controller_load_recovery_required", false)))
	assert(bool(details.get("new_loads_rollback_deferred", false)))
	assert(bool(details.get("stale_restore_deferred", false)))
	assert(director.get_managed_chunk_ids().size() == 2 and controller.get_loaded_chunk_ids().size() == 2, "The report preserves the actual partial window for explicit recovery")

	assert(director.recover_to_world_position(Vector3(21, 0, 1), 4002), "Director recovery clears the Controller barrier, reconciles actual ownership, and retries the requested window")
	assert(int(controller.get("unload_attempt_count")) == unload_attempts_before + 2, "Only the post-recovery stale unload is attempted")
	assert(director.get_managed_chunk_ids().size() == 1)
	assert(director.get_managed_chunk_ids() == controller.get_loaded_chunk_ids())
	assert(controller.is_chunk_loaded("surface/chunk_2_0"))
	assert(not controller.is_chunk_loaded("surface/chunk_0_0"))
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
	if coord == _registration_fail_coordinate:
		var first: Node = MiningNode.new()
		first.name = "gold-01"
		first.set("mineral_id", "gold_ore")
		first.set("max_units", 8)
		first.set("remaining_units", 7)
		first.set("regen_interval_seconds", 60)
		first.set("last_regen_unix", _registration_now)
		var second: Node = MiningNode.new()
		second.name = "iron-02"
		second.set("mineral_id", "iron_ore")
		second.set("max_units", 8)
		second.set("remaining_units", 6)
		second.set("regen_interval_seconds", 60)
		second.set("last_regen_unix", _registration_now)
		_registration_first = first
		_registration_second = second
		chunk.add_child(first)
		chunk.add_child(second)
	return chunk

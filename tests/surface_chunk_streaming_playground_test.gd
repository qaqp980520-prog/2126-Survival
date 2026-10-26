extends SceneTree

const PlaygroundScene = preload("res://prototypes/SurfaceChunkStreamingPlayground.tscn")
const Adapter = preload("res://systems/MineralChunkLifecycleAdapter.gd")
var _failed: bool = false
var _finished: bool = false

func _initialize() -> void:
	call_deferred("_run_tests")
	call_deferred("_watchdog")

func _watchdog() -> void:
	await create_timer(25.0).timeout
	if not _finished:
		push_error("Surface chunk streaming playground integration test timed out.")
		quit(1)

func _run_tests() -> void:
	var playground: Variant = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	if playground == null or playground.chunk_controller == null or playground.director == null or playground.registry == null:
		push_error("Surface playground did not initialize its streaming stack.")
		_failed = true
		_finish()
		return

	var now: int = int(Time.get_unix_time_from_system())
	_check(playground.chunk_controller.get_loaded_chunk_ids().size() == 9, "Initial player window should load 3x3 chunks")
	_check(playground.director.get_managed_chunk_ids() == playground.chunk_controller.get_loaded_chunk_ids(), "Director and controller active IDs must match")
	_check(playground.director.get_grid_coordinate(Vector3(-0.1, 0.0, -0.1)) == Vector2i(-1, -1), "Negative positions must use floor-based grid coordinates")
	_check(playground.director.get_grid_coordinate(Vector3(10.0, 0.0, 10.0)) == Vector2i(1, 1), "Exact positive chunk boundaries must map to the next chunk")

	var original_root: Node3D = playground.chunk_controller.get_chunk_root("surface/chunk_0_0")
	if original_root == null:
		push_error("Initial chunk surface/chunk_0_0 was not created.")
		_failed = true
		_finish()
		return
	var original_position: Vector3 = playground.player.global_position
	var original_ore: Node = original_root.get_node_or_null("Ore_0_0")
	if original_ore == null:
		push_error("Expected mineral node Ore_0_0 was not created.")
		_failed = true
		_finish()
		return
	original_ore.set("remaining_units", 2)
	var stable_id: String = Adapter.make_stable_id("surface/chunk_0_0", "Chunk_0_0/Ore_0_0")
	var save_payload: Dictionary = playground.serialize_stream_state()
	var mineral_payload: Dictionary = save_payload.get("minerals", {})
	var saved_veins: Dictionary = mineral_payload.get("veins", {})
	_check(saved_veins.has(stable_id), "Save must include the loaded vein")
	_check(saved_veins.size() == 9, "Initial save should contain all nine active veins")

	if not bool(playground.debug_move_player_to(Vector3(21.0, 2.0, 1.0), now)):
		push_error("Moving across chunks should shift the stream window.")
		_failed = true
		_finish()
		return
	_check(playground.chunk_controller.get_loaded_chunk_ids().size() == 9, "Active window should remain 3x3 after movement")
	_check(not playground.chunk_controller.is_chunk_loaded("surface/chunk_0_0"), "Stale origin chunk should be unloaded")
	_check(playground.registry.get_saved_ids().size() == 15, "Registry should retain six unloaded veins plus nine active-window veins")

	if not bool(playground.restore_stream_state(save_payload, now)):
		push_error("Valid save should restore position and mineral state.")
		_failed = true
		_finish()
		return
	_check(playground.director.get_managed_chunk_ids().size() == 9, "Restored stream should have nine managed chunks")
	_check(playground.chunk_controller.is_chunk_loaded("surface/chunk_0_0"), "Restore should return to the saved origin chunk")
	var restored_root: Node3D = playground.chunk_controller.get_chunk_root("surface/chunk_0_0")
	var restored_ore: Node = restored_root.get_node_or_null("Ore_0_0") if restored_root != null else null
	if restored_ore == null:
		push_error("Restored origin chunk is missing Ore_0_0.")
		_failed = true
		_finish()
		return
	_check(int(restored_ore.get("remaining_units")) == 2, "Stable ID must restore saved vein stock after streaming away and back")
	_check(playground.player.global_position.is_equal_approx(original_position), "Restore must return the player to the exact saved position")

	var bad_save: Dictionary = save_payload.duplicate(true)
	bad_save["schema_version"] = 99
	var before_position: Vector3 = playground.player.global_position
	var before_ids: PackedStringArray = playground.chunk_controller.get_loaded_chunk_ids()
	var before_saved_ids: PackedStringArray = playground.registry.get_saved_ids()
	var before_units: int = int(restored_ore.get("remaining_units"))
	_check(not bool(playground.restore_stream_state(bad_save, now)), "Invalid schema must be rejected")
	_check(playground.player.global_position.is_equal_approx(before_position), "Rejected save must not change player position")
	_check(playground.chunk_controller.get_loaded_chunk_ids() == before_ids, "Rejected save must not change active chunks")
	_check(playground.registry.get_saved_ids() == before_saved_ids, "Rejected save must not change registry IDs")
	_check(int(restored_ore.get("remaining_units")) == before_units, "Rejected save must not change live mineral stock")
	playground.queue_free()
	await process_frame
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

func _finish() -> void:
	_finished = true
	if _failed:
		print("Surface chunk streaming playground integration tests failed.")
		quit(1)
	else:
		print("Surface chunk streaming playground integration tests passed.")
		quit(0)

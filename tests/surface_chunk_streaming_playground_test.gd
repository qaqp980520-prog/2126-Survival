extends SceneTree

const PlaygroundScene = preload("res://prototypes/SurfaceChunkStreamingPlayground.tscn")
const Adapter = preload("res://systems/MineralChunkLifecycleAdapter.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var playground: Node3D = PlaygroundScene.instantiate() as Node3D
	root.add_child(playground)
	await process_frame
	var now: int = int(Time.get_unix_time_from_system())
	assert(playground.chunk_controller.get_loaded_chunk_ids().size() == 9, "Initial player window should load 3x3 chunks")
	assert(playground.director.get_managed_chunk_ids() == playground.chunk_controller.get_loaded_chunk_ids())

	var original_root: Node3D = playground.chunk_controller.get_chunk_root("surface/chunk_0_0")
	assert(original_root != null)
	var original_position: Vector3 = playground.player.global_position
	var original_ore: Node = original_root.get_node("Ore_0_0")
	original_ore.remaining_units = 2
	var stable_id: String = Adapter.make_stable_id("surface/chunk_0_0", "Chunk_0_0/Ore_0_0")
	var save_payload: Dictionary = playground.serialize_stream_state()
	assert(save_payload.get("minerals", {}).get("veins", {}).has(stable_id), "Save must include the loaded vein")

	assert(playground.debug_move_player_to(Vector3(21.0, 2.0, 1.0), now), "Moving two chunks should shift the stream window")
	assert(playground.chunk_controller.get_loaded_chunk_ids().size() == 9)
	assert(not playground.chunk_controller.is_chunk_loaded("surface/chunk_0_0"))
	assert(playground.registry.get_saved_ids().size() == 15, "Registry must retain six unloaded veins plus nine active-window veins")

	assert(playground.restore_stream_state(save_payload, now), "Valid save should restore position and mineral state")
	assert(playground.director.get_managed_chunk_ids().size() == 9)
	assert(playground.chunk_controller.is_chunk_loaded("surface/chunk_0_0"))
	var restored_root: Node3D = playground.chunk_controller.get_chunk_root("surface/chunk_0_0")
	var restored_ore: Node = restored_root.get_node("Ore_0_0")
	assert(restored_ore.remaining_units == 2, "Stable ID must restore the saved vein stock after streaming away and back")
	assert(playground.player.global_position.is_equal_approx(original_position), "Restore must return the player to the exact saved position")

	var bad_save := save_payload.duplicate(true)
	bad_save["schema_version"] = 99
	var before_position: Vector3 = playground.player.global_position
	var before_ids: PackedStringArray = playground.chunk_controller.get_loaded_chunk_ids()
	assert(not playground.restore_stream_state(bad_save, now), "Invalid schema must be rejected")
	assert(playground.player.global_position.is_equal_approx(before_position))
	assert(playground.chunk_controller.get_loaded_chunk_ids() == before_ids)
	print("Surface chunk streaming playground integration tests passed.")
	playground.queue_free()
	await process_frame
	quit(0)

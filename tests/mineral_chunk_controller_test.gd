extends SceneTree

const MiningNode = preload("res://systems/MineralMiningNode.gd")
const Registry = preload("res://systems/MineralVeinRegistry.gd")
const Controller = preload("res://systems/MineralChunkController.gd")
const Adapter = preload("res://systems/MineralChunkLifecycleAdapter.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await _test_chunk_save_unload_reload_with_offline_regeneration()
	await process_frame
	await _test_empty_chunk_and_duplicate_id()
	await process_frame
	print("Mineral chunk controller integration tests passed.")
	quit(0)

func _test_chunk_save_unload_reload_with_offline_regeneration() -> void:
	var base_time: int = int(Time.get_unix_time_from_system()) - 5
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(registry))

	var chunk_id := "earth/sector-2/chunk--4"
	var first_chunk: Node3D = _new_mineral_chunk(1, base_time)
	assert(controller.load_chunk(chunk_id, first_chunk, base_time + 5))
	var stable_id: String = Adapter.make_stable_id(chunk_id, "ChunkRoot/gold-01")
	assert(registry.get_registered_ids().has(stable_id))
	assert(controller.get_chunk_root(chunk_id) == first_chunk)
	assert(controller.unload_chunk(chunk_id, base_time + 5))
	assert(not registry.get_registered_ids().has(stable_id))
	assert(registry.get_saved_ids().has(stable_id))
	var payload: Dictionary = controller.to_save_dict()
	assert(payload.get("veins", {}).has(stable_id))

	controller.queue_free()
	registry.queue_free()
	await process_frame

	var restored_registry: Node = Registry.new()
	root.add_child(restored_registry)
	await process_frame
	assert(restored_registry.restore_save_dict(payload, base_time + 125))
	var restored_controller: Node3D = Controller.new()
	root.add_child(restored_controller)
	await process_frame
	assert(restored_controller.bind_registry(restored_registry))

	var replacement: Node3D = _new_mineral_chunk(8, int(Time.get_unix_time_from_system()))
	assert(restored_controller.load_chunk(chunk_id, replacement, base_time + 125))
	var restored_vein: Node = replacement.get_node("gold-01")
	assert(restored_vein.remaining_units == 3, "Reload should restore one saved unit plus two elapsed regeneration intervals")
	assert(restored_registry.get_registered_ids().has(stable_id))
	assert(restored_controller.unload_chunk(chunk_id, base_time + 125))
	restored_controller.queue_free()
	restored_registry.queue_free()
	await process_frame

func _test_empty_chunk_and_duplicate_id() -> void:
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(registry))
	var empty_chunk := Node3D.new()
	empty_chunk.name = "EmptyChunk"
	assert(controller.load_chunk("earth/empty-chunk", empty_chunk, int(Time.get_unix_time_from_system())))
	assert(controller.is_chunk_loaded("earth/empty-chunk"))
	var duplicate := Node3D.new()
	duplicate.name = "DifferentChunk"
	assert(not controller.load_chunk("earth/empty-chunk", duplicate), "A duplicate chunk ID must not replace the live root")
	assert(controller.get_chunk_root("earth/empty-chunk") == empty_chunk)
	assert(controller.unload_chunk("earth/empty-chunk"))
	assert(not controller.is_chunk_loaded("earth/empty-chunk"))
	duplicate.free()
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _new_mineral_chunk(units: int, regen_time: int) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "ChunkRoot"
	var vein: Node3D = MiningNode.new()
	vein.name = "gold-01"
	vein.mineral_id = "gold_ore"
	vein.max_units = 8
	vein.remaining_units = units
	vein.regen_interval_seconds = 60
	vein.last_regen_unix = regen_time
	chunk.add_child(vein)
	return chunk

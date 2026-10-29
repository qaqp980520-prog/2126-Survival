extends SceneTree

const MiningNode = preload("res://systems/MineralMiningNode.gd")
const Registry = preload("res://systems/MineralVeinRegistry.gd")
const Controller = preload("res://systems/MineralChunkController.gd")
const Adapter = preload("res://systems/MineralChunkLifecycleAdapter.gd")
const ObjectRegistry = preload("res://systems/WorldObjectStateRegistry.gd")
const StatefulProp = preload("res://systems/WorldObjectStatefulProp.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await _test_chunk_save_unload_reload_with_offline_regeneration()
	await process_frame
	await _test_empty_chunk_and_duplicate_id()
	await process_frame
	await _test_failed_load_preserves_caller_root()
	await process_frame
	await _test_failed_unload_rolls_back_registration()
	await process_frame
	await _test_stateful_object_survives_unload_reload()
	await process_frame
	await _test_failed_object_state_application_is_atomic()
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
	var first_chunk: Node3D = _new_mineral_chunk(1, base_time + 5)
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

func _test_failed_load_preserves_caller_root() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(registry))
	var chunk_id := "earth/conflict"
	var stable_id: String = Adapter.make_stable_id(chunk_id, "ChunkRoot/gold-01")
	var existing: Node3D = MiningNode.new()
	existing.name = "ExistingGold"
	existing.mineral_id = "gold_ore"
	existing.max_units = 8
	existing.remaining_units = 4
	existing.regen_interval_seconds = 60
	existing.last_regen_unix = now
	assert(registry.register_vein(stable_id, existing, now))
	var incoming: Node3D = _new_mineral_chunk(2, now)
	assert(not controller.load_chunk(chunk_id, incoming, now), "Duplicate stable ID must reject the incoming chunk")
	assert(is_instance_valid(incoming), "Failed load must not free the caller-owned root")
	assert(incoming.get_parent() == null, "Failed load must detach the root so it can be retried")
	assert(registry.get_registered_ids().has(stable_id))
	assert(registry.unregister_vein(stable_id, existing, now))
	incoming.free()
	existing.free()
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _test_failed_unload_rolls_back_registration() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(registry))
	var chunk_id := "earth/rollback"
	var chunk: Node3D = _new_two_mineral_chunk(now)
	assert(controller.load_chunk(chunk_id, chunk, now))
	var first_id: String = Adapter.make_stable_id(chunk_id, "ChunkRoot/gold-01")
	var second_id: String = Adapter.make_stable_id(chunk_id, "ChunkRoot/iron-02")
	var second: Node = chunk.get_node("iron-02")
	second.mineral_id = "missing_mineral"
	assert(not controller.unload_chunk(chunk_id, now), "Invalid second vein must abort unload")
	assert(controller.is_chunk_loaded(chunk_id), "Failed unload must retain controller ownership")
	assert(controller.get_chunk_root(chunk_id) == chunk)
	assert(chunk.get_parent() == controller)
	assert(registry.get_registered_ids().has(first_id), "Previously unregistered first vein must be restored")
	assert(registry.get_registered_ids().has(second_id), "Failed vein must remain registered")
	second.mineral_id = "iron_ore"
	assert(controller.unload_chunk(chunk_id, now), "Unload should succeed after repairing invalid vein data")
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _test_stateful_object_survives_unload_reload() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var mineral_registry: Node = Registry.new()
	var object_registry: Node = ObjectRegistry.new()
	var controller: Node3D = Controller.new()
	root.add_child(mineral_registry)
	root.add_child(object_registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(mineral_registry))
	assert(controller.bind_object_state_registry(object_registry))
	var chunk_id := "earth/object-sector"
	var first_chunk: Node3D = _new_stateful_chunk()
	assert(controller.load_chunk(chunk_id, first_chunk, now))
	var stable_id := chunk_id + "/object/ChunkRoot/SalvageCrate"
	var crate: Node = first_chunk.get_node("SalvageCrate")
	assert(int(object_registry.get_object_state(stable_id).get("state", {}).get("loot_remaining", -1)) == 2, "First load seeds the object's default state")
	assert(bool(crate.call("interact")), "The stateful prop can be interacted with")
	assert(controller.capture_loaded_world_object_states(), "Saving captures current live prop state")
	assert(controller.unload_chunk(chunk_id, now), "Chunk unload captures object state before freeing nodes")
	var saved: Dictionary = object_registry.get_object_state(stable_id).get("state", {})
	assert(bool(saved.get("opened", false)) and int(saved.get("loot_remaining", -1)) == 1, "Unload stores the opened crate state")
	var replacement: Node3D = _new_stateful_chunk()
	assert(controller.load_chunk(chunk_id, replacement, now), "Reload reapplies the saved object state")
	var restored: Node = replacement.get_node("SalvageCrate")
	assert(bool(restored.get("opened")) and int(restored.get("loot_remaining")) == 1, "Reloaded prop matches its stable-ID record")
	var registry_before_invalid_capture: Dictionary = object_registry.to_save_dict()
	restored.set("opened", true)
	restored.set("loot_remaining", 2)
	assert(not controller.capture_loaded_world_object_states(), "Capture rejects semantically invalid live state")
	assert(object_registry.to_save_dict() == registry_before_invalid_capture, "Invalid live state cannot partially mutate the registry")
	assert(bool(restored.call("apply_world_object_state", {"opened": true, "loot_remaining": 1})), "Prop can be repaired to a valid state after rejected capture")
	assert(controller.unload_chunk(chunk_id, now))
	controller.queue_free()
	object_registry.queue_free()
	mineral_registry.queue_free()
	await process_frame

func _test_failed_object_state_application_is_atomic() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var mineral_registry: Node = Registry.new()
	var object_registry: Node = ObjectRegistry.new()
	var controller: Node3D = Controller.new()
	root.add_child(mineral_registry)
	root.add_child(object_registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(mineral_registry))
	assert(controller.bind_object_state_registry(object_registry))
	var chunk_id := "earth/object-reject"
	var stable_id := chunk_id + "/object/ChunkRoot/SalvageCrate"
	assert(object_registry.set_object_state(stable_id, chunk_id, {"opened": true, "loot_remaining": 2}), "Registry accepts bounded primitive state even if a specific prop rejects the semantic combination")
	var before: Dictionary = object_registry.to_save_dict()
	var incoming: Node3D = _new_stateful_chunk()
	assert(not controller.load_chunk(chunk_id, incoming, now), "Prop must reject an incompatible saved state")
	assert(incoming.get_parent() == null, "Failed state application leaves the caller-owned chunk detached")
	var incoming_crate: Node = incoming.get_node("SalvageCrate")
	assert(not bool(incoming_crate.get("opened")) and int(incoming_crate.get("loot_remaining")) == 2, "Failed apply restores the incoming prop's original state")
	assert(object_registry.to_save_dict() == before, "Failed apply restores the object registry snapshot atomically")
	assert(not controller.is_chunk_loaded(chunk_id), "Failed object restoration must not register a partial chunk")
	incoming.free()
	controller.queue_free()
	object_registry.queue_free()
	mineral_registry.queue_free()
	await process_frame

func _new_stateful_chunk() -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "ChunkRoot"
	var crate: Node3D = StatefulProp.new()
	crate.name = "SalvageCrate"
	chunk.add_child(crate)
	return chunk

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

func _new_two_mineral_chunk(now: int) -> Node3D:
	var chunk: Node3D = _new_mineral_chunk(3, now)
	var second: Node3D = MiningNode.new()
	second.name = "iron-02"
	second.mineral_id = "iron_ore"
	second.max_units = 8
	second.remaining_units = 5
	second.regen_interval_seconds = 60
	second.last_regen_unix = now
	chunk.add_child(second)
	return chunk

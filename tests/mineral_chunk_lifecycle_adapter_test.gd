extends SceneTree

const MiningNode = preload("res://systems/MineralMiningNode.gd")
const Registry = preload("res://systems/MineralVeinRegistry.gd")
const ChunkAdapter = preload("res://systems/MineralChunkLifecycleAdapter.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await _test_chunk_load_unload_reload()
	await process_frame
	await _test_duplicate_chunk_rejected()
	await process_frame
	await _test_failed_batch_load_is_atomic_for_all_veins()
	await process_frame
	print("Mineral chunk lifecycle adapter tests passed.")
	quit(0)

func _test_chunk_load_unload_reload() -> void:
	var registry = Registry.new()
	var adapter = ChunkAdapter.new()
	root.add_child(registry)
	root.add_child(adapter)
	await process_frame
	assert(adapter.bind_registry(registry))

	var first = _new_vein("gold_ore", 1)
	root.add_child(first)
	await process_frame
	first.last_regen_unix = 1000
	var chunk_id := "earth/sector-2/chunk--4"
	assert(adapter.load_chunk(chunk_id, {"gold-01": first}, 1000))
	var stable_id := ChunkAdapter.make_stable_id(chunk_id, "gold-01")
	assert(registry.get_registered_ids().has(stable_id))
	assert(adapter.is_chunk_loaded(chunk_id))
	assert(adapter.unload_chunk(chunk_id, 1000))
	assert(not registry.get_registered_ids().has(stable_id))
	assert(registry.get_saved_ids().has(stable_id))
	assert(not adapter.is_chunk_loaded(chunk_id))
	first.queue_free()
	await process_frame

	var replacement = _new_vein("gold_ore", 8)
	root.add_child(replacement)
	await process_frame
	assert(adapter.load_chunk(chunk_id, {"gold-01": replacement}, 1120))
	assert(replacement.remaining_units == 3, "Reload should restore one saved unit plus two elapsed regeneration intervals")
	assert(registry.get_registered_ids().has(stable_id))
	assert(adapter.unload_chunk(chunk_id, 1120))
	replacement.queue_free()
	adapter.queue_free()
	registry.queue_free()
	await process_frame

func _test_duplicate_chunk_rejected() -> void:
	var registry = Registry.new()
	var adapter = ChunkAdapter.new()
	root.add_child(registry)
	root.add_child(adapter)
	await process_frame
	assert(adapter.bind_registry(registry))
	var first = _new_vein("iron_ore", 4)
	var second = _new_vein("iron_ore", 4)
	root.add_child(first)
	root.add_child(second)
	await process_frame
	first.last_regen_unix = 1000
	second.last_regen_unix = 1000
	assert(adapter.load_chunk("earth/chunk-0", {"iron-01": first}, 1000))
	assert(not adapter.load_chunk("earth/chunk-0", {"iron-01": second}, 1000), "A repeated chunk ID cannot replace a live node")
	assert(registry.get_registered_ids().size() == 1)
	assert(adapter.unload_chunk("earth/chunk-0", 1000))
	first.queue_free()
	second.queue_free()
	adapter.queue_free()
	registry.queue_free()
	await process_frame

func _test_failed_batch_load_is_atomic_for_all_veins() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var registry = Registry.new()
	var adapter = ChunkAdapter.new()
	root.add_child(registry)
	root.add_child(adapter)
	await process_frame
	assert(adapter.bind_registry(registry))

	var chunk_id := "earth/adapter-load-atomic"
	var first_id: String = ChunkAdapter.make_stable_id(chunk_id, "gold-01")
	var second_id: String = ChunkAdapter.make_stable_id(chunk_id, "iron-02")
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
	var payload: Dictionary = {
		"schema_version": 1,
		"veins": {
			first_id: saved_first,
			second_id: saved_second
		}
	}
	assert(registry.restore_save_dict(payload, now), "Seed valid saved records with a deliberately incompatible later participant")

	var first: Node = _new_vein("gold_ore", 7)
	var second: Node = _new_vein("iron_ore", 6)
	root.add_child(first)
	root.add_child(second)
	await process_frame
	first.set("last_regen_unix", now)
	second.set("last_regen_unix", now)
	var first_before: Dictionary = first.call("to_save_dict")
	var second_before: Dictionary = second.call("to_save_dict")
	var registry_before: Dictionary = registry.to_save_dict()

	assert(not adapter.load_chunk("earth/adapter-duplicate-node", {"gold-a": first, "gold-b": first}, now), "One live node cannot be registered under two stable IDs in the same batch")
	assert(first.call("to_save_dict") == first_before, "Duplicate-node rejection leaves the shared node unchanged")
	assert(registry.to_save_dict() == registry_before, "Duplicate-node rejection leaves saved records unchanged")
	assert(registry.get_registered_ids().is_empty(), "Duplicate-node rejection commits no registry entry")

	assert(not adapter.load_chunk(chunk_id, {"gold-01": first, "iron-02": second}, now), "A later saved-record mineral mismatch rejects the complete adapter batch")
	assert(first.call("to_save_dict") == first_before, "Earlier live vein remains unchanged after a later participant rejects")
	assert(second.call("to_save_dict") == second_before, "Rejected live vein remains unchanged")
	assert(registry.to_save_dict() == registry_before, "Registry records remain byte-for-byte equivalent at the Variant level")
	assert(registry.get_registered_ids().is_empty(), "No live registry entry is committed on batch rejection")
	assert(not adapter.is_chunk_loaded(chunk_id), "Adapter does not publish a partially loaded chunk")

	var repaired_payload: Dictionary = registry_before.duplicate(true)
	repaired_payload["veins"][second_id]["mineral_id"] = "iron_ore"
	assert(registry.restore_save_dict(repaired_payload, now), "Repair the incompatible saved record")
	assert(adapter.load_chunk(chunk_id, {"gold-01": first, "iron-02": second}, now), "The same nodes can be registered after repair")
	assert(int(first.get("remaining_units")) == 5, "First vein restores and regenerates exactly two intervals")
	assert(int(second.get("remaining_units")) == 4, "Second vein restores and regenerates exactly two intervals")
	assert(adapter.unload_chunk(chunk_id, now), "The successfully registered batch can be atomically unregistered")

	first.queue_free()
	second.queue_free()
	adapter.queue_free()
	registry.queue_free()
	await process_frame

func _new_vein(mineral_id: String, units: int) -> Node:
	var vein = MiningNode.new()
	vein.mineral_id = mineral_id
	vein.max_units = 8
	vein.remaining_units = units
	vein.regen_interval_seconds = 60
	return vein

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

func _new_vein(mineral_id: String, units: int) -> Node:
	var vein = MiningNode.new()
	vein.mineral_id = mineral_id
	vein.max_units = 8
	vein.remaining_units = units
	vein.regen_interval_seconds = 60
	return vein

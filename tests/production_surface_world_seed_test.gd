extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const Factory = preload("res://systems/UndergroundMineFactory.gd")
const LEGACY_SEED: int = 0
const MAX_SEED: int = 2147483647

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: Node3D = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld instantiates for world-seed integration")
	if world == null:
		quit(1)
		return
	world.set("world_seed", 42)
	root.add_child(world)
	await process_frame
	await physics_frame

	_expect(int(world.get("world_seed")) == 42, "configured world seed is retained during world initialization")
	var saved: Dictionary = world.call("serialize_stream_state")
	_expect(int(saved.get("world_seed", -1)) == 42, "schema-1 world save includes the configured world seed")
	var original_cache_ids: Array[String] = _loaded_cache_ids(world)
	var mine_director: Node = world.get("mine_director") as Node
	var chunk_controller: Node3D = world.get("chunk_controller") as Node3D
	var player: CharacterBody3D = world.get("player") as CharacterBody3D
	_expect(original_cache_ids == _expected_cache_ids(42), "production mine cache identities match the saved world seed")

	var same_seed_first: Array[Dictionary] = Factory.get_cache_spawn_data(Vector2i(-2, 3), 2, 42)
	var same_seed_second: Array[Dictionary] = Factory.get_cache_spawn_data(Vector2i(-2, 3), 2, 42)
	_expect(same_seed_first == same_seed_second, "the same world seed produces identical cache data")
	var different_seed_count: int = 0
	for y in range(-6, 7):
		for x in range(-6, 7):
			var coord := Vector2i(x, y)
			if Factory.get_cache_spawn_data(coord, 2, 42) != Factory.get_cache_spawn_data(coord, 2, 84):
				different_seed_count += 1
	_expect(different_seed_count > 0, "different world seeds change deterministic regional cache layouts")
	_expect(Factory.get_cache_spawn_data(Vector2i.ZERO, 0, 42) == Factory.get_cache_spawn_data(Vector2i.ZERO, 0, LEGACY_SEED), "origin layer-zero service caches remain seed-independent")

	var invalid_fractional: Dictionary = saved.duplicate(true)
	invalid_fractional["world_seed"] = 42.5
	var position_before: Vector3 = player.global_position
	_expect(not bool(world.call("restore_stream_state", invalid_fractional, 1793400000)), "fractional world seeds are rejected before mutation")
	_expect(int(world.get("world_seed")) == 42 and player.global_position.is_equal_approx(position_before), "fractional seed rejection preserves the live world")
	var invalid_negative: Dictionary = saved.duplicate(true)
	invalid_negative["world_seed"] = -1
	_expect(not bool(world.call("restore_stream_state", invalid_negative, 1793400001)), "negative world seeds are rejected")
	var invalid_large: Dictionary = saved.duplicate(true)
	invalid_large["world_seed"] = MAX_SEED + 1
	_expect(not bool(world.call("restore_stream_state", invalid_large, 1793400002)), "out-of-range world seeds are rejected")

	var away := Vector3(21.5, -8.25, 7.5)
	_expect(bool(mine_director.call("sync_to_world_position", away, 1793400010)), "mine director can unload the saved origin window before seed restore")
	_expect(not chunk_controller.is_chunk_loaded("underground/mine_0_0"), "origin room is unloaded before restoring the saved seed")
	world.set("world_seed", 7)
	_expect(bool(world.call("restore_stream_state", saved, 1793400011)), "world restore regenerates the mine window using the saved seed")
	_expect(int(world.get("world_seed")) == 42, "successful restore applies the saved world seed")
	_expect(_loaded_cache_ids(world) == original_cache_ids, "seeded cache identities are stable across unload, restore and reload")

	var legacy_world: Node3D = WorldScene.instantiate() as Node3D
	legacy_world.set("world_seed", LEGACY_SEED)
	root.add_child(legacy_world)
	await process_frame
	await physics_frame
	var legacy_save: Dictionary = legacy_world.call("serialize_stream_state")
	legacy_save.erase("world_seed")
	_expect(not legacy_save.has("world_seed"), "legacy compatibility fixture omits the newly optional world_seed field")
	legacy_world.queue_free()
	await process_frame
	_expect(bool(mine_director.call("sync_to_world_position", away, 1793400020)), "legacy compatibility fixture unloads the origin window")
	world.set("world_seed", 84)
	_expect(bool(world.call("restore_stream_state", legacy_save, 1793400021)), "legacy schema-1 save without world_seed remains loadable")
	_expect(int(world.get("world_seed")) == LEGACY_SEED, "legacy saves without world_seed fall back to the original deterministic seed")
	_expect(_loaded_cache_ids(world) == _expected_cache_ids(LEGACY_SEED), "legacy fallback recreates the original cache identities")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("Production SurfaceWorld world-seed integration tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _loaded_cache_ids(world: Node) -> Array[String]:
	var result: Array[String] = []
	var chunk_controller: Node3D = world.get("chunk_controller") as Node3D
	for prop in chunk_controller.get_loaded_world_state_nodes():
		if not is_instance_valid(prop) or prop.global_position.y >= -7.0:
			continue
		var parent_node: Node = prop.get_parent()
		if is_instance_valid(parent_node):
			result.append("%s/%s" % [str(parent_node.name), str(prop.name)])
	result.sort()
	return result

func _expected_cache_ids(seed: int) -> Array[String]:
	var result: Array[String] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			var chunk_name: String = "UndergroundMine_%d_%d" % [x, y]
			for entry in Factory.get_cache_spawn_data(Vector2i(x, y), 0, seed):
				result.append("%s/%s" % [chunk_name, str(entry.get("node_name", ""))])
	result.sort()
	return result

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

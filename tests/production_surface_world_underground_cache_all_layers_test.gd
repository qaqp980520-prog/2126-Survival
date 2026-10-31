extends SceneTree
const WorldScene = preload("res://world/SurfaceWorld.tscn")
const Factory = preload("res://systems/UndergroundMineFactory.gd")
const RegistryScript = preload("res://systems/WorldObjectStateRegistry.gd")
const MAX_LAYER_INDEX: int = Factory.MAX_LAYER_INDEX
const SAMPLE_MIN: int = -2
const SAMPLE_MAX: int = 2
const INTERACTION_LAYER: int = 1 << 1
var failures: Array[String] = []
var world: Node3D
var controller: Node
var registry: Node
var mine_director: Node
var inventory_bridge: Node
var chunks_checked: int = 0
var caches_checked: int = 0
var layer_cache_counts: Dictionary = {}
var all_stable_ids: Array[String] = []

class TestInventoryBridge extends Node:
	var inventory: Dictionary = {"seed": 1}
	func serialize_inventory() -> Dictionary:
		return inventory.duplicate(true)
	func restore_inventory(snapshot: Dictionary) -> bool:
		inventory = snapshot.duplicate(true)
		return true
	func collect_world_item(item_id: String, amount: int) -> bool:
		if item_id.is_empty() or amount <= 0:
			return false
		inventory[item_id] = int(inventory.get(item_id, 0)) + amount
		return true

func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld instantiates for all-layer cache lifecycle coverage")
	if world == null:
		quit(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	controller = world.get("chunk_controller") as Node
	registry = world.get("object_state_registry") as Node
	mine_director = world.get("mine_director") as Node
	inventory_bridge = TestInventoryBridge.new()
	world.add_child(inventory_bridge)
	_expect(controller != null and registry != null and mine_director != null and inventory_bridge != null, "production world binds chunk controller, object registry, mine director and deterministic inventory adapter")
	if controller == null or registry == null or mine_director == null or inventory_bridge == null:
		await _finish(1)
		return
	var now: int = int(Time.get_unix_time_from_system())
	for layer_index in range(MAX_LAYER_INDEX + 1):
		layer_cache_counts[layer_index] = 0
		for z in range(SAMPLE_MIN, SAMPLE_MAX + 1):
			for x in range(SAMPLE_MIN, SAMPLE_MAX + 1):
				var coord := Vector2i(x, z)
				var entries: Array[Dictionary] = Factory.get_cache_spawn_data(coord, layer_index, 0)
				if entries.is_empty():
					continue
				var chunk_id: String = str(mine_director.call("get_chunk_id", coord, layer_index))
				_expect(not chunk_id.is_empty(), "layer %d room %d,%d has a stable chunk ID" % [layer_index, x, z])
				var chunk_root: Node3D = Factory.make_chunk(now, coord, layer_index, 0)
				_expect(chunk_root != null, "factory builds cache room at layer %d coordinate %d,%d" % [layer_index, x, z])
				if chunk_root == null:
					await _finish(1)
					return
				if not bool(controller.call("load_chunk", chunk_id, chunk_root, now)):
					_expect(false, "controller registers cache room at layer %d coordinate %d,%d" % [layer_index, x, z])
					if is_instance_valid(chunk_root) and chunk_root.get_parent() == null:
						chunk_root.free()
					await _finish(1)
					return
				await process_frame
				var original_caches: Array[Node3D] = _get_cache_nodes(chunk_root)
				_expect(original_caches.size() == entries.size(), "layer %d room %d,%d loads every deterministic cache placement" % [layer_index, x, z])
				if original_caches.size() != entries.size():
					await _finish(1)
					return
				var cache_records: Array[Dictionary] = []
				for cache in original_caches:
					var proxy: Area3D = cache.get_node_or_null("InteractionArea") as Area3D
					var local_path: String = "%s/%s" % [str(chunk_root.name), str(cache.name)]
					var stable_id: String = str(controller.call("_make_world_object_stable_id", chunk_id, local_path))
					var item_id: String = str(cache.get("loot_item_id"))
					_expect(not stable_id.is_empty(), "cache %s receives a stable ID" % cache.name)
					_expect(_valid_proxy(proxy), "cache %s owns a live interaction proxy" % cache.name)
					_expect(int(cache.get("loot_remaining")) == 2, "cache %s begins with two recoverable units" % cache.name)
					var old_node_id: int = cache.get_instance_id()
					var old_proxy_id: int = proxy.get_instance_id() if proxy != null else 0
					_expect(_collect_cache(cache), "cache %s records its first recovered unit" % cache.name)
					_expect(int(cache.get("loot_remaining")) == 1 and bool(cache.get("opened")), "cache %s enters its opened one-unit state" % cache.name)
					cache_records.append({"name":str(cache.name),"stable_id":stable_id,"item_id":item_id,"node":cache,"proxy":proxy,"node_id":old_node_id,"proxy_id":old_proxy_id})
					all_stable_ids.append(stable_id)
				var first_unload: bool = bool(controller.call("unload_chunk", chunk_id, now + 1))
				_expect(first_unload, "controller unloads layer %d cache room %d,%d" % [layer_index, x, z])
				await process_frame
				_expect(not is_instance_valid(chunk_root), "old layer %d cache chunk root is released" % layer_index)
				for record in cache_records:
					_expect(not is_instance_valid(record["node"]) and not is_instance_valid(record["proxy"]), "old cache node and proxy are released for %s" % record["stable_id"])
					var saved: Dictionary = registry.call("get_object_state", str(record["stable_id"]))
					var saved_state: Dictionary = saved.get("state", {})
					_expect(bool(saved_state.get("opened", false)) and int(saved_state.get("loot_remaining", -1)) == 1, "registry saves opened state and one remaining unit for %s" % record["stable_id"])
					_expect(str(saved_state.get("loot_item_id", "")) == str(record["item_id"]), "registry saves the original loot item for %s" % record["stable_id"])
				var restored_root: Node3D = Factory.make_chunk(now + 2, coord, layer_index, 0)
				_expect(restored_root != null, "factory recreates layer %d cache room %d,%d" % [layer_index, x, z])
				if restored_root == null or not bool(controller.call("load_chunk", chunk_id, restored_root, now + 2)):
					_expect(false, "controller reloads layer %d cache room %d,%d" % [layer_index, x, z])
					if is_instance_valid(restored_root) and restored_root.get_parent() == null:
						restored_root.free()
					await _finish(1)
					return
				await process_frame
				for record in cache_records:
					var restored_cache: Node3D = _find_cache_by_name(restored_root, str(record["name"]))
					_expect(restored_cache != null, "reloaded room recreates cache %s" % record["name"])
					if restored_cache == null:
						await _finish(1)
						return
					var restored_proxy: Area3D = restored_cache.get_node_or_null("InteractionArea") as Area3D
					var restored_path: String = "%s/%s" % [str(restored_root.name), str(restored_cache.name)]
					var restored_id: String = str(controller.call("_make_world_object_stable_id", chunk_id, restored_path))
					_expect(restored_cache.get_instance_id() != int(record["node_id"]), "cache %s is a fresh node instance" % record["name"])
					_expect(restored_id == str(record["stable_id"]), "cache %s retains its stable ID" % record["name"])
					_expect(_valid_proxy(restored_proxy), "cache %s recreates a fresh interaction proxy" % record["name"])
					if _valid_proxy(restored_proxy):
						_expect(restored_proxy.get_instance_id() != int(record["proxy_id"]), "cache %s proxy is a fresh instance" % record["name"])
						_expect((restored_proxy.collision_layer & INTERACTION_LAYER) != 0, "cache %s proxy keeps the interaction collision layer" % record["name"])
					_expect(bool(restored_cache.get("opened")) and int(restored_cache.get("loot_remaining")) == 1, "cache %s restores its opened state and exact remaining stock" % record["name"])
					_expect(str(restored_cache.get("loot_item_id")) == str(record["item_id"]), "cache %s restores its original loot item" % record["name"])
					_expect(_collect_cache(restored_cache), "reloaded cache %s can be collected again" % record["name"])
					_expect(int(restored_cache.get("loot_remaining")) == 0, "reloaded cache %s reaches zero remaining stock" % record["name"])
				var second_unload: bool = bool(controller.call("unload_chunk", chunk_id, now + 3))
				_expect(second_unload, "controller unloads completed cache room at layer %d" % layer_index)
				await process_frame
				for record in cache_records:
					var final_record: Dictionary = registry.call("get_object_state", str(record["stable_id"]))
					var final_state: Dictionary = final_record.get("state", {})
					_expect(bool(final_state.get("opened", false)) and int(final_state.get("loot_remaining", -1)) == 0, "final cache state remains exhausted after second unload")
					_expect(str(final_state.get("loot_item_id", "")) == str(record["item_id"]), "final cache item identity remains stable")
				chunks_checked += 1
				caches_checked += cache_records.size()
				layer_cache_counts[layer_index] = int(layer_cache_counts[layer_index]) + cache_records.size()
	_expect(chunks_checked > 0 and caches_checked > 0, "sample contains generated cache placements")
	for layer_index in range(MAX_LAYER_INDEX + 1):
		_expect(int(layer_cache_counts.get(layer_index, 0)) > 0, "all mine layer %d has cache lifecycle coverage" % layer_index)
	_expect(caches_checked >= 100, "five-by-five sample across nine layers covers at least one hundred generated caches")
	var save_payload: Dictionary = registry.call("to_save_dict")
	var registry_copy = RegistryScript.new()
	_expect(bool(registry_copy.call("restore_save_dict", save_payload)), "schema-1 registry payload restores into a fresh registry")
	for stable_id in all_stable_ids:
		var copied: Dictionary = registry_copy.call("get_object_state", stable_id)
		var copied_state: Dictionary = copied.get("state", {})
		_expect(int(copied_state.get("loot_remaining", -1)) == 0 and bool(copied_state.get("opened", false)), "schema-1 registry roundtrip preserves exhausted cache %s" % stable_id)
	registry_copy.free()
	await _finish(0 if failures.is_empty() else 1)
func _collect_cache(cache: Node) -> bool:
	var result: Dictionary = cache.call("interact_with_inventory", inventory_bridge)
	return bool(result.get("ok", false))

func _get_cache_nodes(chunk_root: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in chunk_root.get_children():
		if child is Node3D and str(child.name).begins_with("MineCache_"):
			result.append(child as Node3D)
	return result
func _find_cache_by_name(chunk_root: Node3D, node_name: String) -> Node3D:
	for cache in _get_cache_nodes(chunk_root):
		if str(cache.name) == node_name:
			return cache
	return null
func _valid_proxy(proxy: Area3D) -> bool:
	return proxy != null and is_instance_valid(proxy) and proxy.is_inside_tree() and (proxy.collision_layer & INTERACTION_LAYER) != 0
func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
func _finish(exit_code: int) -> void:
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("Production SurfaceWorld all-layer cache lifecycle tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

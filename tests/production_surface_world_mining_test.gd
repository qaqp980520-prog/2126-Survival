extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const MINE_ID: String = "underground/mine_0_0"
const MineralCatalog = preload("res://systems/MineralCatalog.gd")
var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "playable surface world instantiates")
	if world == null:
		_finish(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	_expect(bool(world.get("_mine_chunk_ready")), "underground mine factory is registered")
	_expect(world.chunk_controller.is_chunk_loaded(MINE_ID), "mine chunk is loaded under a stable underground ID")
	var mine_veins: Array[Node3D] = []
	for vein in world.chunk_controller.get_loaded_mineral_nodes():
		if vein.global_position.y < -7.0:
			mine_veins.append(vein)
	_expect(mine_veins.size() == 27, "nine underground rooms expose twenty-seven mineral veins below the surface")
	var mine_director: Node = world.get("mine_director")
	_expect(mine_director != null and mine_director.get_managed_chunk_ids().size() == 9, "underground director manages a bounded nine-room window")
	_expect(not bool(world.get("_is_underground")), "new game begins on the surface")
	var recovery_position: Vector3 = world.player.global_position
	_expect(bool(world.director.call("recover_to_world_position", recovery_position, int(Time.get_unix_time_from_system()))), "surface director recovery ignores independently managed underground layer IDs")
	_expect(world.chunk_controller.is_chunk_loaded(MINE_ID), "surface director recovery preserves the underground mine chunk")
	var surface_mine_attempt: Dictionary = world.call("_interact_nearest_mineral")
	_expect(str(surface_mine_attempt.get("action", "")) == "underground_only", "surface layer rejects mining")
	_expect(not bool(world.call("_toggle_mine_access")), "mine shaft cannot be used from outside its interaction range")
	world.player.global_position = Vector3(1.5, 2.0, 7.5)
	_expect(bool(world.call("_toggle_mine_access")), "player can descend through the mine shaft")
	_expect(bool(world.get("_is_underground")) and world.player.global_position.y < -7.0, "player enters the underground layer")
	var underground_cache_count: int = 0
	for prop in world.chunk_controller.get_loaded_world_state_nodes():
		if is_instance_valid(prop) and prop.global_position.y < -7.0:
			underground_cache_count += 1
	_expect(underground_cache_count == 7, "initial mine window registers two origin caches and five deterministic regional caches")
	var underground_buttons: Dictionary = world.get("touch_buttons")
	_expect((underground_buttons["crate"] as Button).text == "CACHE", "underground touch action is relabeled for salvage caches")
	var nearest: Node3D = _nearest_mine_vein()
	_expect(nearest != null, "mine exposes a nearby vein")
	if nearest == null:
		_finish(1)
		return
	var item_id: String = str(nearest.get("mineral_id"))
	var stock_before: int = int(nearest.get("remaining_units"))
	var now: int = int(Time.get_unix_time_from_system())
	var weight_before: float = float(world.inventory_bridge.call("get_summary").get("weight_kg", 0.0))
	var first_mine: Dictionary = world.call("_interact_nearest_world_prop", now)
	_expect(bool(first_mine.get("ok", false)) and int(first_mine.get("amount", 0)) == 1, "F interaction routes to underground mining and grants one ore")
	_expect(int(nearest.get("remaining_units")) == stock_before - 1, "successful mining consumes exactly one vein unit")
	_expect(_inventory_count(item_id) == 1, "mined ore enters the shared surface-world inventory")
	var saved_weight: float = float(world.inventory_bridge.call("get_summary").get("weight_kg", 0.0))
	_expect(saved_weight > weight_before, "mining immediately increases shared carry weight")
	var gold_cache: Node3D = _find_mine_cache("MineCache_Gold")
	_expect(gold_cache != null, "origin mine room contains a real stateful gold salvage cache")
	if gold_cache == null:
		_finish(1)
		return
	var cache_instance_id: int = gold_cache.get_instance_id()
	var cache_item_id: String = str(gold_cache.get("loot_item_id"))
	_expect(cache_item_id == "gold_ore" and int(gold_cache.get("loot_remaining")) == 2, "gold cache starts with its deterministic item identity and two units")
	var cache_stable_id: String = MINE_ID + "/object/UndergroundMine_0_0/MineCache_Gold"
	world.player.global_position = gold_cache.global_position + Vector3(0.0, 1.0, 0.0)
	var cache_result: Dictionary = world.call("_interact_nearest_world_prop", now + 1)
	_expect(bool(cache_result.get("ok", false)) and str(cache_result.get("item_id", "")) == "gold_ore", "F interaction selects a nearer underground cache over a more distant vein")
	_expect(int(cache_result.get("remaining", -1)) == 1 and _inventory_count("gold_ore") == 1, "cache transaction grants exactly one gold ore and leaves one unit")
	var regional_cache: Node3D = _find_room_cache("UndergroundMine_-1_1", "MineCache_coal_ore")
	_expect(regional_cache != null, "regional west-table room exposes its deterministic coal cache")
	var regional_item_id: String = str(regional_cache.get("loot_item_id")) if regional_cache != null else ""
	var regional_stable_id: String = "underground/mine_-1_1/object/UndergroundMine_-1_1/MineCache_coal_ore"
	var regional_instance_id: int = regional_cache.get_instance_id() if regional_cache != null else 0
	var regional_weight_before: float = float(world.inventory_bridge.call("get_summary").get("weight_kg", 0.0))
	if regional_cache != null:
		world.player.global_position = regional_cache.global_position + Vector3(0.0, 1.0, 0.0)
		var regional_result: Dictionary = world.call("_interact_nearest_world_prop", now + 2)
		_expect(bool(regional_result.get("ok", false)) and str(regional_result.get("item_id", "")) == "coal_ore", "regional cache grants its room-table mineral through the shared inventory bridge")
		var regional_weight_after: float = float(world.inventory_bridge.call("get_summary").get("weight_kg", 0.0))
		var coal_weight: float = float(MineralCatalog.get_mineral("coal_ore").get("weight_kg", 0.0))
		_expect(_inventory_count("coal_ore") == 1, "regional cache adds exactly one coal item")
		_expect(is_equal_approx(regional_weight_after - regional_weight_before, coal_weight), "regional cache immediately applies the catalog weight to shared inventory")
	world.player.global_position = Vector3(1.5, -8.25, 7.5)
	await physics_frame
	var cache_save: Dictionary = world.call("serialize_stream_state")
	var cache_records: Dictionary = cache_save.get("world_objects", {}).get("objects", {})
	var cache_record: Dictionary = cache_records.get(cache_stable_id, {})
	var cache_saved_state: Dictionary = cache_record.get("state", {})
	_expect(not cache_record.is_empty() and str(cache_record.get("chunk_id", "")) == MINE_ID, "world save includes the underground cache stable ID and chunk ownership")
	_expect(int(cache_saved_state.get("loot_remaining", -1)) == 1 and str(cache_saved_state.get("loot_item_id", "")) == "gold_ore", "world save captures the cache's remaining stock and item identity")
	var away_position := Vector3(21.5, -8.25, 7.5)
	world.player.global_position = away_position
	await physics_frame
	_expect(not bool(world.call("_toggle_mine_access")), "player cannot teleport back to the shaft from a distant mine room")
	_expect(bool(mine_director.call("get_managed_chunk_ids").size() == 9), "underground physics keeps the managed window bounded")
	_expect(world.chunk_controller.is_chunk_loaded("underground/mine_2_0"), "walking two mine cells east streams the eastern room")
	await process_frame
	_expect(not world.chunk_controller.is_chunk_loaded(MINE_ID), "origin mine chunk unloads outside the underground radius")
	_expect(world.chunk_controller.is_chunk_loaded("underground/mine_2_0"), "new eastern mine chunk loads with a stable coordinate ID")
	_expect(mine_director.get_managed_chunk_ids().size() == 9, "underground active window remains bounded to nine chunks")
	var return_position := Vector3(1.5, -8.25, 7.5)
	world.player.global_position = return_position
	await physics_frame
	await process_frame
	_expect(world.chunk_controller.is_chunk_loaded(MINE_ID), "returning through the mine tunnels reloads the origin room")
	var reloaded_cache: Node3D = _find_mine_cache("MineCache_Gold")
	_expect(reloaded_cache != null and reloaded_cache.get_instance_id() != cache_instance_id, "reloaded mine cache is a new scene instance")
	_expect(reloaded_cache != null and int(reloaded_cache.get("loot_remaining")) == 1 and str(reloaded_cache.get("loot_item_id")) == "gold_ore", "underground cache state survives chunk unload and reload")
	var persisted_cache_record: Dictionary = world.object_state_registry.call("get_object_state", cache_stable_id)
	_expect(int(persisted_cache_record.get("state", {}).get("loot_remaining", -1)) == 1, "underground cache remains in the shared object-state registry after reload")
	_expect(_inventory_count("gold_ore") == 1, "mine cache reload does not duplicate the collected gold")
	var reloaded_regional_cache: Node3D = _find_room_cache("UndergroundMine_-1_1", "MineCache_coal_ore")
	_expect(reloaded_regional_cache != null and reloaded_regional_cache.get_instance_id() != regional_instance_id, "regional cache is recreated as a fresh node after chunk reload")
	_expect(reloaded_regional_cache != null and int(reloaded_regional_cache.get("loot_remaining")) == 1 and str(reloaded_regional_cache.get("loot_item_id")) == regional_item_id, "regional cache restores its room-specific identity and remaining stock")
	_expect(_inventory_count("coal_ore") == 1, "regional cache reload does not duplicate its inventory grant")
	_expect(int(world.object_state_registry.call("get_object_state", regional_stable_id).get("state", {}).get("loot_remaining", -1)) == 1, "regional cache state remains registered under its stable room ID")
	var reloaded_nearest: Node3D = _nearest_mine_vein()
	_expect(reloaded_nearest != null and str(reloaded_nearest.get("mineral_id")) == item_id and int(reloaded_nearest.get("remaining_units")) == stock_before - 1, "mined mineral identity and stock survive director unload/reload")
	_expect(_inventory_count(item_id) == 1, "mine window reload does not duplicate inventory")
	var saved: Dictionary = world.call("serialize_stream_state")
	_expect(str(saved.get("location_layer", "")) == "underground", "world save records the underground location layer")
	_expect(saved.get("surface_return_position", []) is Array, "world save records the surface return point")
	_expect(bool(world.call("_toggle_mine_access")), "player can ascend to the surface")
	_expect(not bool(world.get("_is_underground")) and world.player.global_position.y > 0.0, "ascending returns player to the surface")
	_expect(bool(world.call("restore_stream_state", saved, now + 3)), "world save restores the underground location")
	_expect(bool(world.get("_is_underground")) and world.player.global_position.y < -7.0, "restored player returns to the underground layer")
	_expect(_inventory_count(item_id) == 1, "world restore preserves the saved mining inventory count")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("location_layer")
	legacy.erase("surface_return_position")
	legacy["player_position"] = [1.5, 2.0, 7.5]
	_expect(bool(world.call("restore_stream_state", legacy, now + 4)), "legacy schema-1 surface save without layer metadata still loads")
	_expect(not bool(world.get("_is_underground")) and world.player.global_position.y > 0.0, "legacy save defaults to the surface layer")
	var buttons: Dictionary = world.get("touch_buttons")
	_expect(buttons.has("shaft") and buttons.has("crate"), "touch HUD exposes shaft and mining action buttons")
	_expect((buttons["crate"] as Button).text == "CRATE" and not (buttons["crop"] as Button).disabled, "surface HUD restores crate and crop controls")
	_finish(0 if failures.is_empty() else 1)

func _nearest_mine_vein() -> Node3D:
	var nearest: Node3D = null
	var distance_limit: float = 3.5
	for vein in world.chunk_controller.get_loaded_mineral_nodes():
		if vein.global_position.y >= -7.0 or not bool(vein.get("visible")) or int(vein.get("remaining_units")) <= 0:
			continue
		var distance: float = world.player.global_position.distance_to(vein.global_position)
		if distance <= distance_limit:
			nearest = vein
			distance_limit = distance
	return nearest

func _find_mine_cache(node_name: String) -> Node3D:
	for prop in world.chunk_controller.get_loaded_world_state_nodes():
		if is_instance_valid(prop) and prop.name == node_name and prop.global_position.y < -7.0:
			return prop
	return null

func _find_room_cache(chunk_name: String, node_name: String) -> Node3D:
	for prop in world.chunk_controller.get_loaded_world_state_nodes():
		if not is_instance_valid(prop) or prop.name != node_name:
			continue
		var parent_node: Node = prop.get_parent()
		if is_instance_valid(parent_node) and parent_node.name == chunk_name:
			return prop
	return null

func _inventory_count(item_id: String) -> int:
	var payload: Dictionary = world.inventory_bridge.call("serialize_inventory")
	var counts: Dictionary = payload.get("inventory", {})
	return int(counts.get(item_id, 0))

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish(exit_code: int) -> void:
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("Production surface underground mining tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

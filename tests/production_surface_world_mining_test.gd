extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const MINE_ID: String = "underground/mine_0_0"
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
	var away_position := Vector3(21.5, -8.25, 7.5)
	world.player.global_position = away_position
	world.call("_physics_process", 0.016)
	_expect(not bool(world.call("_toggle_mine_access")), "player cannot teleport back to the shaft from a distant mine room")
	_expect(bool(mine_director.call("get_managed_chunk_ids").size() == 9), "underground physics keeps the managed window bounded")
	_expect(world.chunk_controller.is_chunk_loaded("underground/mine_2_0"), "walking two mine cells east streams the eastern room")
	await process_frame
	_expect(not world.chunk_controller.is_chunk_loaded(MINE_ID), "origin mine chunk unloads outside the underground radius")
	_expect(world.chunk_controller.is_chunk_loaded("underground/mine_2_0"), "new eastern mine chunk loads with a stable coordinate ID")
	_expect(mine_director.get_managed_chunk_ids().size() == 9, "underground active window remains bounded to nine chunks")
	var return_position := Vector3(1.5, -8.25, 7.5)
	world.player.global_position = return_position
	world.call("_physics_process", 0.016)
	_expect(world.chunk_controller.is_chunk_loaded(MINE_ID), "returning through the mine tunnels reloads the origin room")
	await process_frame
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

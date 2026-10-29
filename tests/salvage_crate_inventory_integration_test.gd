extends SceneTree

const PlaygroundScene = preload("res://prototypes/SurfaceChunkStreamingPlayground.tscn")
const InventoryModel = preload("res://systems/SurvivalInventory.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: Node3D = PlaygroundScene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	_expect(world.get("chunk_controller") != null and world.get("inventory_bridge") != null, "surface world initializes chunk and inventory systems")
	if world.get("chunk_controller") == null or world.get("inventory_bridge") == null:
		_finish(world)
		return
	var chunk_controller: Node = world.get("chunk_controller")
	var bridge: Node = world.get("inventory_bridge")
	var origin: Node3D = chunk_controller.call("get_chunk_root", "surface/chunk_0_0") as Node3D
	var crate: Node = origin.get_node_or_null("SalvageCrate") if origin != null else null
	_expect(crate != null and crate.has_method("interact_with_inventory"), "active chunk creates a transactional salvage crate")
	var initial_crate_state: Dictionary = crate.call("get_world_object_state") if crate != null else {}
	_expect(str(initial_crate_state.get("loot_item_id", "")) == "iron_ore", "origin chunk uses its deterministic iron-ore loot identity")
	if crate == null:
		_finish(world)
		return
	var player: CharacterBody3D = world.get("player") as CharacterBody3D
	player.global_position = crate.global_position + Vector3(0.0, 1.0, 0.0)
	var before_count: int = _inventory_count(bridge, "iron_ore")
	var before_weight: float = float(bridge.call("get_weight_kg"))
	var now: int = int(Time.get_unix_time_from_system())
	var first: Dictionary = world.call("_interact_nearest_world_prop", now)
	_expect(bool(first.get("ok", false)) and str(first.get("action", "")) == "interacted", "nearby crate grants loot through the world interaction")
	_expect(str(first.get("item_id", "")) == "iron_ore", "inventory receipt reports the persisted loot item identity")
	_expect(_inventory_count(bridge, "iron_ore") == before_count + 1, "one iron ore is added to inventory")
	_expect(bool(crate.get("opened")) and int(crate.get("loot_remaining")) == 1, "crate state changes only after successful inventory grant")
	_expect(is_equal_approx(float(bridge.call("get_weight_kg")), before_weight + 3.0), "inventory weight updates with the collected ore")
	var saved: Dictionary = world.call("serialize_stream_state")
	var world_objects_payload: Dictionary = saved.get("world_objects", {})
	var object_payload: Dictionary = world_objects_payload.get("objects", {})
	var saved_crate_state: Dictionary = {}
	for object_id in object_payload.keys():
		var record: Variant = object_payload[object_id]
		if not (record is Dictionary) or str(record.get("chunk_id", "")) != "surface/chunk_0_0":
			continue
		var candidate_state: Variant = record.get("state", {})
		if candidate_state is Dictionary and candidate_state.has("loot_remaining") and candidate_state.has("opened"):
			saved_crate_state = candidate_state.duplicate(true)
			break
	_expect(bool(saved_crate_state.get("opened", false)) and int(saved_crate_state.get("loot_remaining", -1)) == 1, "world save captures the crate after one collection")
	var second: Dictionary = world.call("_interact_nearest_world_prop", now + 1)
	_expect(bool(second.get("ok", false)) and int(crate.get("loot_remaining")) == 0, "second interaction consumes the final salvage unit")
	_expect(_inventory_count(bridge, "iron_ore") == before_count + 2, "second collection adds exactly one more item")
	_expect(bool(world.call("restore_stream_state", saved, now + 2)), "saved world state restores successfully")
	origin = chunk_controller.call("get_chunk_root", "surface/chunk_0_0") as Node3D
	crate = origin.get_node_or_null("SalvageCrate") if origin != null else null
	_expect(crate != null and int(crate.get("loot_remaining")) == 1 and bool(crate.get("opened")), "restored crate returns to its saved one-loot state")
	_expect(_inventory_count(bridge, "iron_ore") == before_count + 1, "inventory and crate state restore together")
	var inventory: Object = bridge.get("inventory")
	var inventory_counts: Dictionary = inventory.get("counts")
	inventory_counts["iron_ore"] = InventoryModel.MAX_SAVED_COUNT
	var full_state: Dictionary = crate.call("get_world_object_state")
	var rejected: Dictionary = world.call("_interact_nearest_world_prop", now + 3)
	_expect(not bool(rejected.get("ok", false)) and str(rejected.get("action", "")) == "inventory_rejected", "full inventory rejects crate collection")
	_expect(crate.call("get_world_object_state") == full_state, "rejected collection leaves crate state unchanged")
	_expect(_inventory_count(bridge, "iron_ore", -1) == InventoryModel.MAX_SAVED_COUNT, "rejected collection does not overfill inventory")
	_finish(world)


func _inventory_count(bridge: Node, item_id: String, default_value: int = 0) -> int:
	var inventory: Object = bridge.get("inventory")
	if inventory == null:
		return default_value
	var counts_value: Variant = inventory.get("counts")
	if not (counts_value is Dictionary):
		return default_value
	return int(counts_value.get(item_id, default_value))

func _finish(world: Node) -> void:
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("Salvage crate inventory integration test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

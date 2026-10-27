extends SceneTree

const CaveScene = preload("res://prototypes/UndergroundMiningPlayground.tscn")
const SurfaceScene = preload("res://prototypes/SurfaceChunkStreamingPlayground.tscn")
const CAVE_CHUNK_ID := "underground/cave_0_0"
const MAX_SAVED_COUNT := 1000000000
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var cave := CaveScene.instantiate()
	root.add_child(cave)
	await process_frame
	await physics_frame

	var bridge: Node = cave.get("inventory_bridge")
	var controller: Node = cave.get("chunk_controller")
	var player: CharacterBody3D = cave.get("player")
	var veins: Array = cave.get("veins")
	_expect(bridge != null, "underground scene creates the shared inventory bridge")
	_expect(controller != null, "underground scene creates the mineral chunk controller")
	_expect(player != null, "underground scene creates a controllable player")
	_expect(veins.size() == 3, "underground cave creates three mineral veins")
	if controller != null:
		_expect(controller.call("is_chunk_loaded", CAVE_CHUNK_ID), "underground cave is registered under a stable underground chunk ID")
	if veins.size() == 3:
		for vein_value in veins:
			var vein := vein_value as Node3D
			_expect(vein.global_position.y < -1.0, "mineable mineral vein is located below world surface")
		var vein := veins[0] as Node3D
		var before_units := int(vein.get("remaining_units"))
		var before_save: Dictionary = cave.call("serialize_mineral_state")
		player.global_position = vein.global_position + Vector3(-0.6, 0.3, 0.0)
		var mined := int(cave.call("mine_nearest_vein"))
		_expect(mined > 0, "nearby underground vein transfers ore through SurvivalWorldBridge")
		_expect(int(vein.get("remaining_units")) < before_units, "accepted mining reduces vein stock")
		_expect(float(bridge.call("get_weight_kg")) > 0.0, "mined ore immediately affects shared inventory weight")
		_expect(cave.call("restore_mineral_state", before_save), "mineral save snapshot restores through the chunk controller")
		_expect(int(vein.get("remaining_units")) == before_units, "restored snapshot returns the live vein to its saved stock")
		var weight_before_drop := float(bridge.call("get_weight_kg"))
		_expect(bridge.call("drop_item", str(vein.get("mineral_id")), 1), "shared bridge accepts a valid ore drop")
		_expect(float(bridge.call("get_weight_kg")) < weight_before_drop, "dropping ore immediately recalculates inventory weight")

		# Inject a full-count inventory: the bridge must reject the next ore unit,
		# and the vein must not consume stock that the inventory did not accept.
		var inventory: RefCounted = bridge.get("inventory")
		var original_inventory: Dictionary = inventory.call("to_save_dict")
		var overflow_save: Dictionary = original_inventory.duplicate(true)
		var overflow_counts: Dictionary = (overflow_save.get("inventory", {}) as Dictionary).duplicate(true)
		overflow_counts["iron_ore"] = MAX_SAVED_COUNT
		overflow_save["inventory"] = overflow_counts
		_expect(inventory.call("load_save_dict", overflow_save), "test can install a valid maximum-count inventory fixture")
		var stock_before_rejected_mine := int(vein.get("remaining_units"))
		var rejected_mine := int(cave.call("mine_nearest_vein"))
		_expect(rejected_mine == 0, "inventory count overflow rejects mining")
		_expect(int(vein.get("remaining_units")) == stock_before_rejected_mine, "rejected mining leaves underground vein stock unchanged")
		_expect(inventory.call("load_save_dict", original_inventory), "restore the original inventory after overflow injection")

	cave.queue_free()
	await process_frame

	var surface := SurfaceScene.instantiate()
	root.add_child(surface)
	await process_frame
	await physics_frame
	_expect(not surface.has_method("mine_nearest_vein"), "surface scene does not expose underground mining interaction")
	var surface_controller: Node = surface.get("chunk_controller")
	if surface_controller != null:
		var chunk: Node3D = surface_controller.call("get_chunk_root", "surface/chunk_0_0")
		var surface_vein: Node3D = chunk.get_node_or_null("Ore_0_0") as Node3D if chunk != null else null
		_expect(surface_vein != null and surface_vein.global_position.y < -0.5, "surface chunk stores veins below the ground slab")
		_expect(float(surface.get("inventory_bridge").call("get_weight_kg")) == 0.0, "surface exploration cannot collect ore without entering the mine")

	surface.queue_free()
	await process_frame
	if failures.is_empty():
		print("Underground mining playground integration tests passed.")
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

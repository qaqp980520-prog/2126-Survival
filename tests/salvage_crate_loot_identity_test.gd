extends SceneTree

const PropScript = preload("res://systems/WorldObjectStatefulProp.gd")
const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const RegistryScript = preload("res://systems/WorldObjectStateRegistry.gd")
const InventoryModel = preload("res://systems/SurvivalInventory.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var bridge: Node = BridgeScript.new()
	root.add_child(bridge)
	var source: Node3D = PropScript.new()
	root.add_child(source)
	var registry: Node = RegistryScript.new()
	root.add_child(registry)
	await process_frame

	_expect(bool(source.call("set_loot_item", "copper_ore")), "factory can assign a catalog-backed copper loot identity")
	var source_state: Dictionary = source.call("get_world_object_state")
	_expect(str(source_state.get("loot_item_id", "")) == "copper_ore", "loot identity is included in saved prop state")
	var stable_id: String = "surface/chunk_1_0/Chunk_1_0/SalvageCrate"
	var chunk_id: String = "surface/chunk_1_0"
	_expect(bool(registry.call("set_object_state", stable_id, chunk_id, source_state)), "registry accepts the loot identity record")
	var save: Dictionary = registry.call("to_save_dict")

	var restored_registry: Node = RegistryScript.new()
	root.add_child(restored_registry)
	await process_frame
	_expect(bool(restored_registry.call("restore_save_dict", save)), "registry round-trip preserves loot identity")
	var saved_record: Dictionary = restored_registry.call("get_object_state", stable_id)
	var saved_state: Dictionary = saved_record.get("state", {})

	var restored: Node3D = PropScript.new()
	root.add_child(restored)
	await process_frame
	_expect(bool(restored.call("set_loot_item", "gold_ore")), "fresh chunk factory may assign a provisional deterministic item")
	_expect(bool(restored.call("apply_world_object_state", saved_state)), "saved state overrides provisional loot identity")
	_expect(str(restored.get("loot_item_id")) == "copper_ore", "reloaded prop retains the saved copper identity")

	var legacy_prop: Node3D = PropScript.new()
	root.add_child(legacy_prop)
	await process_frame
	_expect(bool(legacy_prop.call("set_loot_item", "copper_ore")), "legacy fixture receives its deterministic factory item")
	_expect(bool(legacy_prop.call("apply_world_object_state", {"opened": false, "loot_remaining": 2})), "legacy two-field prop state remains accepted")
	_expect(str(legacy_prop.get("loot_item_id")) == "copper_ore", "legacy state without item ID preserves the factory-assigned identity")

	var invalid_state: Dictionary = saved_state.duplicate(true)
	invalid_state["loot_item_id"] = "unknown_ore"
	var before_invalid: Dictionary = restored.call("get_world_object_state")
	_expect(not bool(restored.call("validate_world_object_state", invalid_state)), "unknown mineral loot IDs are rejected")
	_expect(not bool(restored.call("apply_world_object_state", invalid_state)), "invalid loot identity cannot be applied")
	_expect(restored.call("get_world_object_state") == before_invalid, "invalid loot restore leaves live prop unchanged")

	var inconsistent_states: Array[Dictionary] = [
		{"opened": false, "loot_remaining": 1},
		{"opened": false, "loot_remaining": 0},
		{"opened": true, "loot_remaining": WorldObjectStatefulProp.MAX_LOOT}
	]
	for inconsistent_state in inconsistent_states:
		_expect(not bool(restored.call("validate_world_object_state", inconsistent_state)), "inconsistent opened/remaining combination is rejected")
		_expect(not bool(restored.call("apply_world_object_state", inconsistent_state)), "inconsistent state cannot mutate a live crate")
		_expect(restored.call("get_world_object_state") == before_invalid, "rejected state preserves the live crate snapshot")
	_expect(not bool(restored.call("validate_world_object_state", {"opened": false, "loot_remaining": 2, "unexpected": "x"})), "unknown third state field is rejected")

	var before_count: int = _inventory_count(bridge, "copper_ore")
	var result: Dictionary = restored.call("interact_with_inventory", bridge)
	_expect(bool(result.get("ok", false)) and str(result.get("item_id", "")) == "copper_ore", "crate grants its persisted item identity")
	_expect(_inventory_count(bridge, "copper_ore") == before_count + 1, "matching item is added to the shared inventory")
	_expect(int(restored.get("loot_remaining")) == 1, "successful collection decrements loot only after grant")
	var inventory_snapshot: Dictionary = bridge.call("serialize_inventory")
	var inventory: Object = bridge.get("inventory")
	var counts: Dictionary = inventory.get("counts")
	counts["copper_ore"] = InventoryModel.MAX_SAVED_COUNT
	var before_rejected_state: Dictionary = restored.call("get_world_object_state")
	var rejected: Dictionary = restored.call("interact_with_inventory", bridge)
	_expect(not bool(rejected.get("ok", false)) and str(rejected.get("reason", "")) == "inventory_rejected", "full inventory rejects a non-default loot item")
	_expect(restored.call("get_world_object_state") == before_rejected_state, "rejected copper collection preserves the crate state")
	_expect(bool(bridge.call("restore_inventory", inventory_snapshot)), "rejection fixture restores the valid inventory snapshot")

	var post_state: Dictionary = restored.call("get_world_object_state")
	_expect(bool(restored_registry.call("set_object_state", stable_id, chunk_id, post_state)), "updated prop state remains registry-valid")
	var post_save: Dictionary = restored_registry.call("to_save_dict")
	var final_registry: Node = RegistryScript.new()
	root.add_child(final_registry)
	await process_frame
	_expect(bool(final_registry.call("restore_save_dict", post_save)), "post-collection save remains valid")
	var final_record: Dictionary = final_registry.call("get_object_state", stable_id)
	var final_prop: Node3D = PropScript.new()
	root.add_child(final_prop)
	await process_frame
	_expect(bool(final_prop.call("apply_world_object_state", final_record.get("state", {}))), "post-collection state applies to a new chunk instance")
	_expect(str(final_prop.get("loot_item_id")) == "copper_ore" and int(final_prop.get("loot_remaining")) == 1 and bool(final_prop.get("opened")), "reloaded crate preserves item, count and opened state")

	for node in [final_prop, final_registry, legacy_prop, restored, restored_registry, registry, source, bridge]:
		node.queue_free()
	await process_frame
	if failures.is_empty():
		print("Salvage crate loot identity tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _inventory_count(bridge: Node, item_id: String) -> int:
	var inventory: Object = bridge.get("inventory")
	if inventory == null:
		return 0
	var counts_value: Variant = inventory.get("counts")
	if not (counts_value is Dictionary):
		return 0
	return int(counts_value.get(item_id, 0))

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

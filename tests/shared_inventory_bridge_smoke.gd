extends SceneTree

const INVENTORY_SCRIPT = preload("res://systems/SurvivalInventory.gd")
const BRIDGE_SCRIPT = preload("res://systems/SurvivalWorldBridge.gd")

class InvalidInventory:
	extends RefCounted

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var failures: Array[String] = []
	var inventory = INVENTORY_SCRIPT.new()
	var bridge = BRIDGE_SCRIPT.new()

	# Injection should succeed before the node enters the tree.
	if not bridge.bind_inventory(inventory):
		failures.append("valid inventory instance should bind")
	if bridge.inventory != inventory:
		failures.append("bridge should retain the exact injected instance")

	# Invalid objects must be rejected without replacing the valid instance.
	var invalid = InvalidInventory.new()
	if bridge.bind_inventory(invalid):
		failures.append("object missing inventory methods should be rejected")
	if bridge.inventory != inventory:
		failures.append("failed bind must not replace current inventory")

	root.add_child(bridge)
	await process_frame

	if bridge.inventory != inventory:
		failures.append("_ready must not replace an injected inventory")

	# Pickup and mining must mutate the same inventory.
	if not bridge.collect_world_item("berries", 5):
		failures.append("world pickup should succeed")
	if not bridge.collect_mined_ore("iron_ore", 2):
		failures.append("mined ore pickup should succeed")
	if int(inventory.counts.get("berries", 0)) != 5:
		failures.append("world pickup count should be reflected in injected inventory")
	if int(inventory.counts.get("iron_ore", 0)) != 2:
		failures.append("mined ore count should be reflected in injected inventory")

	# Dropping should update count and weight immediately.
	if not bridge.drop_item("berries", 2):
		failures.append("drop should succeed")
	if int(inventory.counts.get("berries", 0)) != 3:
		failures.append("drop should reduce the same inventory count")

	# Serialization round-trip through the bridge should preserve data.
	var saved: Dictionary = bridge.serialize_inventory()
	var restored = INVENTORY_SCRIPT.new()
	if not restored.load_save_dict(saved):
		failures.append("inventory save payload should restore")
	if int(restored.counts.get("berries", 0)) != 3 or int(restored.counts.get("iron_ore", 0)) != 2:
		failures.append("save/load round-trip should preserve inventory counts")

	if failures.is_empty():
		print("PASS: shared inventory bridge smoke tests")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

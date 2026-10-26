extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const InventoryScript = preload("res://systems/SurvivalInventory.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_binding_tests")

func _run_binding_tests() -> void:
	var bridge = BridgeScript.new()
	var shared_inventory = InventoryScript.new({"meat": 2}, 3)
	_expect(bool(bridge.call("bind_inventory", shared_inventory)), "accept valid shared inventory before tree entry")
	root.add_child(bridge)
	await process_frame
	_expect(bridge.get("inventory") == shared_inventory, "_ready preserves pre-bound inventory instance")
	_expect(bool(bridge.call("collect_world_item", "berries", 2)), "world pickup routes through shared instance")
	_expect(int(shared_inventory.counts.get("berries", 0)) == 2, "shared inventory receives pickup")

	var invalid_candidate: RefCounted = RefCounted.new()
	_expect(not bool(bridge.call("bind_inventory", invalid_candidate)), "reject object missing inventory contract")
	_expect(bridge.get("inventory") == shared_inventory, "invalid binding does not replace live inventory")

	var second_bridge = BridgeScript.new()
	root.add_child(second_bridge)
	await process_frame
	var replacement_inventory = InventoryScript.new({"rock": 2}, 1)
	_expect(bool(second_bridge.call("bind_inventory", replacement_inventory)), "allow valid binding after ready")
	_expect(second_bridge.get("inventory") == replacement_inventory, "post-ready binding switches source of truth")
	_expect(is_equal_approx(float(second_bridge.call("get_weight_kg")), 5.0), "weight query reads bound instance")
	_expect(not bool(second_bridge.call("bind_inventory", invalid_candidate)), "reject invalid replacement")
	_expect(second_bridge.get("inventory") == replacement_inventory, "invalid replacement preserves current instance")

	root.remove_child(bridge)
	bridge.free()
	root.remove_child(second_bridge)
	second_bridge.free()
	if failures.is_empty():
		print("SurvivalWorldBridge binding tests passed.")
		quit(0)
	else:
		push_error("SurvivalWorldBridge binding failures: " + str(failures))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

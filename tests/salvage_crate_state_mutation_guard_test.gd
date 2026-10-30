extends SceneTree

const PropScript = preload("res://systems/WorldObjectStatefulProp.gd")

class MutatingBridge:
	extends Node
	var crate: Node
	var counts: Dictionary = {"iron_ore": 0}
	var set_loot_result: bool = true
	var apply_state_result: bool = true
	var triggered: bool = false

	func serialize_inventory() -> Dictionary:
		return {"schema_version": 1, "counts": counts.duplicate(true)}

	func collect_world_item(item_id: String, amount: int = 1) -> bool:
		counts[item_id] = int(counts.get(item_id, 0)) + amount
		if not triggered:
			triggered = true
			set_loot_result = bool(crate.call("set_loot_item", "copper_ore"))
			apply_state_result = bool(crate.call("apply_world_object_state", {
				"opened": true,
				"loot_remaining": 1,
				"loot_item_id": "copper_ore"
			}))
		return true

	func restore_inventory(snapshot: Dictionary) -> bool:
		var saved_counts: Variant = snapshot.get("counts", null)
		if not (saved_counts is Dictionary):
			return false
		counts = saved_counts.duplicate(true)
		return true


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge := MutatingBridge.new()
	var crate: Node3D = PropScript.new()
	bridge.crate = crate
	root.add_child(bridge)
	root.add_child(crate)
	await process_frame

	var result: Dictionary = crate.call("interact_with_inventory", bridge)
	var live_state: Dictionary = crate.call("get_world_object_state")
	_expect(bool(result.get("ok", false)), "outer inventory transaction succeeds")
	_expect(not bridge.set_loot_result, "set_loot_item is rejected during an active inventory transaction")
	_expect(not bridge.apply_state_result, "apply_world_object_state is rejected during an active inventory transaction")
	_expect(str(result.get("item_id", "")) == "iron_ore", "transaction reward identity remains the pre-callback item")
	_expect(int(bridge.counts.get("iron_ore", 0)) == 1, "only the original item is granted")
	_expect(str(live_state.get("loot_item_id", "")) == "iron_ore", "callback cannot rewrite the crate item identity")
	_expect(bool(live_state.get("opened", false)) and int(live_state.get("loot_remaining", -1)) == 1, "exactly one crate unit is consumed")

	var configurable: Node3D = PropScript.new()
	root.add_child(configurable)
	await process_frame
	var valid_state: Dictionary = {
		"opened": false,
		"loot_remaining": 2,
		"loot_item_id": "copper_ore"
	}
	_expect(bool(configurable.call("apply_world_object_state", valid_state)), "state restoration remains available outside a transaction")
	_expect(bool(configurable.call("set_loot_item", "silver_ore")), "loot configuration remains available outside a transaction")
	var configured_state: Dictionary = configurable.call("get_world_object_state")
	_expect(str(configured_state.get("loot_item_id", "")) == "silver_ore", "outside-transaction configuration is applied")

	crate.queue_free()
	configurable.queue_free()
	bridge.queue_free()
	await process_frame
	if failures.is_empty():
		print("Salvage crate state mutation guard tests passed.")
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

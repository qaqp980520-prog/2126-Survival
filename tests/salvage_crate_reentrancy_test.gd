extends SceneTree

const PropScript = preload("res://systems/WorldObjectStatefulProp.gd")

class ReentrantBridge:
	extends Node
	var crate: Node
	var counts: Dictionary = {"iron_ore": 0}
	var nested_inventory_result: Dictionary = {}
	var legacy_interact_result: bool = true
	var triggered: bool = false

	func serialize_inventory() -> Dictionary:
		return {"schema_version": 1, "counts": counts.duplicate(true)}

	func collect_world_item(item_id: String, amount: int = 1) -> bool:
		counts[item_id] = int(counts.get(item_id, 0)) + amount
		if not triggered:
			triggered = true
			nested_inventory_result = crate.call("interact_with_inventory", self)
			legacy_interact_result = bool(crate.call("interact"))
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
	var bridge := ReentrantBridge.new()
	var crate: Node3D = PropScript.new()
	bridge.crate = crate
	root.add_child(bridge)
	root.add_child(crate)
	await process_frame

	var result: Dictionary = crate.call("interact_with_inventory", bridge)
	_expect(bool(result.get("ok", false)), "outer inventory interaction succeeds")
	_expect(str(bridge.nested_inventory_result.get("reason", "")) == "interaction_in_progress", "reentrant inventory interaction is rejected")
	_expect(not bridge.legacy_interact_result, "legacy state-only interaction is blocked during transaction")
	_expect(int(bridge.counts.get("iron_ore", 0)) == 1, "reentrant callbacks cannot duplicate the reward")
	var state: Dictionary = crate.call("get_world_object_state")
	_expect(int(state.get("loot_remaining", -1)) == 1 and bool(state.get("opened", false)), "one successful transaction consumes exactly one unit")

	var second: Dictionary = crate.call("interact_with_inventory", bridge)
	_expect(bool(second.get("ok", false)), "a later independent transaction remains available")
	_expect(int(bridge.counts.get("iron_ore", 0)) == 2, "separate successful interaction grants one additional unit")
	_expect(int(crate.call("get_world_object_state").get("loot_remaining", -1)) == 0, "crate reaches empty state after two successful transactions")

	if failures.is_empty():
		print("Salvage crate reentrancy tests passed.")
		crate.queue_free()
		bridge.queue_free()
		await process_frame
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		crate.queue_free()
		bridge.queue_free()
		await process_frame
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

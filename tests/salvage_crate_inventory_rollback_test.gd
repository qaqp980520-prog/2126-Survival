extends SceneTree

const PropScript = preload("res://systems/WorldObjectStatefulProp.gd")

class PartiallyRejectingBridge:
	extends Node
	var counts: Dictionary = {"iron_ore": 0}
	var restore_calls: int = 0
	var fail_restore: bool = false

	func serialize_inventory() -> Dictionary:
		return {"schema_version": 1, "counts": counts.duplicate(true)}

	func collect_world_item(item_id: String, amount: int = 1) -> bool:
		counts[item_id] = int(counts.get(item_id, 0)) + amount
		return false

	func restore_inventory(snapshot: Dictionary) -> bool:
		if fail_restore:
			return false
		var saved_counts: Variant = snapshot.get("counts", null)
		if not (saved_counts is Dictionary):
			return false
		counts = saved_counts.duplicate(true)
		restore_calls += 1
		return true

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var bridge := PartiallyRejectingBridge.new()
	var crate: Node3D = PropScript.new()
	root.add_child(bridge)
	root.add_child(crate)
	await process_frame

	var before_state: Dictionary = crate.call("get_world_object_state")
	var first: Dictionary = crate.call("interact_with_inventory", bridge)
	_expect(not bool(first.get("ok", false)) and str(first.get("reason", "")) == "inventory_rejected", "partial mutation followed by rejection is reported")
	_expect(int(bridge.counts.get("iron_ore", -1)) == 0, "rejected grant restores the inventory snapshot")
	_expect(bridge.restore_calls == 1, "rejection path calls restore exactly once")
	_expect(crate.call("get_world_object_state") == before_state, "rejected grant leaves crate state unchanged")

	bridge.fail_restore = true
	var second: Dictionary = crate.call("interact_with_inventory", bridge)
	_expect(not bool(second.get("ok", false)) and str(second.get("reason", "")) == "inventory_rollback_failed", "failed compensation is surfaced explicitly")
	_expect(crate.call("get_world_object_state") == before_state, "failed inventory compensation still leaves crate state unchanged")
	_expect(int(bridge.counts.get("iron_ore", -1)) == 1, "test confirms the adapter mutation remains when compensation itself fails")

	crate.queue_free()
	bridge.queue_free()
	await process_frame
	if failures.is_empty():
		print("Salvage crate inventory rollback tests passed.")
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

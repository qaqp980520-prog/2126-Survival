extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")

class OperationFixture extends RefCounted:
	var counts: Dictionary = {"meat":0,"berries":2}
	var game_day: int = 3
	var add_mode: String = "normal"
	var remove_mode: String = "normal"
	var snapshot_mode: String = "normal"
	var load_calls: int = 0

	func add_item(item_id: String, amount: int = 1) -> Variant:
		var current: int = int(counts.get(item_id, 0))
		match add_mode:
			"no_mutation":
				return amount
			"over_report":
				counts[item_id] = current + amount
				return amount + 1
			"under_report":
				counts[item_id] = current + amount
				return maxi(0, amount - 1)
			"fractional":
				counts[item_id] = current + amount
				return float(amount) - 0.5
			"string":
				counts[item_id] = current + amount
				return str(amount)
			"boolean":
				counts[item_id] = current + amount
				return true
			"collateral":
				counts[item_id] = current + amount
				counts["berries"] = int(counts.get("berries", 0)) + 1
				return amount
			"rollback_fail":
				counts[item_id] = current + amount
				return 0
			_:
				counts[item_id] = current + amount
				return amount

	func remove_item(item_id: String, amount: int = 1) -> Variant:
		var current: int = int(counts.get(item_id, 0))
		var removed: int = mini(amount, current)
		match remove_mode:
			"no_mutation":
				return amount
			"over_report":
				counts[item_id] = current - removed
				return removed + 1
			"under_report":
				counts[item_id] = current - removed
				return maxi(0, removed - 1)
			"string":
				counts[item_id] = current - removed
				return str(removed)
			_:
				counts[item_id] = current - removed
				return removed

	func total_weight_kg() -> float:
		return float(counts.get("meat", 0)) * 0.75
	func carry_limit_kg() -> float:
		return 65.0
	func movement_multiplier() -> float:
		return 1.0
	func can_jump() -> bool:
		return true
	func is_overweight() -> bool:
		return false
	func is_super_heavy() -> bool:
		return false
	func to_save_dict() -> Variant:
		if snapshot_mode == "invalid":
			return "not-a-dictionary"
		return {"schema_version":1,"game_day":game_day,"inventory":counts.duplicate(true)}
	func load_save_dict(data: Dictionary) -> bool:
		load_calls += 1
		if add_mode == "rollback_fail":
			counts = {"meat":999,"berries":999}
			game_day = 99
			return false
		counts = data.get("inventory", {}).duplicate(true)
		game_day = int(data.get("game_day", 1))
		return true

class MethodOnlyFixture extends RefCounted:
	var _stored_counts: Dictionary = {"meat":0}
	var add_mode: String = "normal"
	var load_calls: int = 0

	func add_item(item_id: String, amount: int = 1) -> Variant:
		_stored_counts[item_id] = int(_stored_counts.get(item_id, 0)) + amount
		return str(amount) if add_mode == "string" else amount
	func remove_item(item_id: String, amount: int = 1) -> int:
		var current: int = int(_stored_counts.get(item_id, 0))
		var removed: int = mini(current, amount)
		_stored_counts[item_id] = current - removed
		return removed
	func get_item_count(item_id: String) -> int:
		return int(_stored_counts.get(item_id, 0))
	func total_weight_kg() -> float:
		return 0.0
	func carry_limit_kg() -> float:
		return 65.0
	func movement_multiplier() -> float:
		return 1.0
	func can_jump() -> bool:
		return true
	func is_overweight() -> bool:
		return false
	func is_super_heavy() -> bool:
		return false
	func to_save_dict() -> Dictionary:
		return {"schema_version":1,"game_day":1,"inventory":_stored_counts.duplicate(true)}
	func load_save_dict(data: Dictionary) -> bool:
		load_calls += 1
		_stored_counts = data.get("inventory", {}).duplicate(true)
		return true

class RefreshListener extends Node:
	var count: int = 0
	func on_changed(_summary: Dictionary) -> void:
		count += 1

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var bridge: Node = BridgeScript.new()
	root.add_child(bridge)
	await process_frame
	var fixture := OperationFixture.new()
	_expect(bool(bridge.call("bind_inventory", fixture)), "custom inventory with a serialized inventory Dictionary binds")

	var listener := RefreshListener.new()
	root.add_child(listener)
	bridge.inventory_changed.connect(Callable(listener, "on_changed"))
	var collected_events: Array[int] = []
	var dropped_events: Array[int] = []
	var consumed_events: Array[int] = []
	bridge.item_collected.connect(func(_item_id: String, amount: int) -> void: collected_events.append(amount))
	bridge.item_dropped.connect(func(_item_id: String, amount: int) -> void: dropped_events.append(amount))
	bridge.item_consumed.connect(func(_item_id: String, amount: int) -> void: consumed_events.append(amount))

	_expect(bool(bridge.call("collect_world_item", "meat", 2)), "matching add result and serialized count delta are accepted")
	_expect(int(fixture.counts["meat"]) == 2 and int(bridge.call("get_item_count", "meat")) == 2, "successful collection is observable")
	_expect(collected_events == [2] and listener.count == 1, "successful collection emits one item event and one refresh")

	var baseline: Dictionary = fixture.to_save_dict()
	fixture.add_mode = "under_report"
	_expect(not bool(bridge.call("collect_world_item", "meat", 2)), "under-reported add is rejected")
	_expect(fixture.to_save_dict() == baseline, "under-report mutation is rolled back exactly")
	_expect(collected_events == [2] and listener.count == 1, "verified rollback emits neither item event nor misleading refresh")

	fixture.add_mode = "over_report"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "over-reported add is rejected")
	_expect(fixture.to_save_dict() == baseline, "over-report mutation is rolled back")
	fixture.add_mode = "fractional"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "fractional result is rejected and rolled back")
	_expect(fixture.to_save_dict() == baseline, "fractional result cannot leave partial inventory changes")
	fixture.add_mode = "string"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "string result is rejected and rolled back")
	_expect(fixture.to_save_dict() == baseline, "string result cannot leave partial inventory changes")
	fixture.add_mode = "boolean"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "Boolean result is rejected and rolled back")
	_expect(fixture.to_save_dict() == baseline, "Boolean result cannot leave partial inventory changes")
	fixture.add_mode = "collateral"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "unrelated serialized-field mutation is rejected")
	_expect(fixture.to_save_dict() == baseline, "collateral mutation is rolled back with the target item")
	fixture.add_mode = "no_mutation"
	var no_op_rollback_calls: int = fixture.load_calls
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "positive result without a count delta is rejected")
	_expect(fixture.to_save_dict() == baseline, "no-op mismatch leaves the baseline unchanged")
	_expect(fixture.load_calls == no_op_rollback_calls + 1, "even a serialized no-op mismatch attempts snapshot rollback")
	_expect(listener.count == 1, "verified failed operations do not emit false refreshes")

	fixture.add_mode = "normal"
	_expect(bool(bridge.call("drop_item", "meat", 1)), "matching remove result and serialized count delta are accepted")
	_expect(dropped_events == [1] and int(fixture.counts["meat"]) == 1, "valid drop emits the exact removed amount")
	var after_drop: Dictionary = fixture.to_save_dict()
	fixture.remove_mode = "over_report"
	_expect(not bool(bridge.call("drop_item", "meat", 1)), "over-reported removal is rejected")
	_expect(fixture.to_save_dict() == after_drop, "failed drop restores the pre-drop snapshot")
	_expect(dropped_events == [1], "failed drop never emits a dropped-item event")
	fixture.remove_mode = "under_report"
	_expect(not bool(bridge.call("consume_item", "meat", 1)), "under-reported consumption is rejected")
	_expect(fixture.to_save_dict() == after_drop, "failed consumption restores the pre-consumption snapshot")
	_expect(consumed_events.is_empty(), "failed consumption never emits a consumed-item event")

	fixture.add_mode = "rollback_fail"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "operation with failed rollback is rejected")
	_expect(int(fixture.counts.get("meat", 0)) == 999, "broken custom rollback is exposed rather than hidden")
	_expect(listener.count == 3, "unverified rollback emits one defensive inventory refresh")
	_expect(collected_events == [2], "unverified rollback still emits no success event")

	fixture.snapshot_mode = "invalid"
	var calls_before: int = fixture.load_calls
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "invalid pre-operation snapshot fails closed")
	_expect(fixture.load_calls == calls_before, "invalid snapshot prevents mutation and rollback calls")

	var method_only := MethodOnlyFixture.new()
	_expect(bool(bridge.call("bind_inventory", method_only)), "method-only custom inventory remains compatible")
	_expect(bool(bridge.call("collect_world_item", "meat", 2)), "method-only inventory uses its serialized snapshot for verification")
	_expect(int(bridge.call("get_item_count", "meat")) == 2, "method-only count accessor reports the accepted mutation")
	var refresh_before: int = listener.count
	method_only.add_mode = "string"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "malformed method-only result is rejected")
	_expect(int(bridge.call("get_item_count", "meat")) == 2, "method-only hidden state is restored from its serialized snapshot")
	_expect(listener.count == refresh_before, "verified method-only rollback needs no defensive refresh")
	_expect(collected_events == [2, 2], "malformed method-only result emits no additional item-collected event")

	bridge.queue_free()
	listener.queue_free()
	await process_frame
	if failures.is_empty():
		# Preserve the legacy Run 113 workflow marker while exposing the stronger Run 116 contract.
		print("World bridge inventory operation result validation tests passed.")
		print("World bridge inventory operation atomicity tests passed.")
		quit(0)
	else:
		push_error("World bridge inventory operation atomicity failures: " + str(failures))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

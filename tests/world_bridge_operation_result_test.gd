extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")

class OperationFixture extends RefCounted:
	var counts: Dictionary = {"meat":0}
	var add_mode: String = "normal"
	var remove_mode: String = "normal"

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
			"string":
				counts[item_id] = current - removed
				return str(removed)
			_:
				counts[item_id] = current - removed
				return removed

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
		return {"schema_version":1,"game_day":1,"inventory":counts.duplicate(true)}
	func load_save_dict(_data: Dictionary) -> bool:
		return true

class MethodOnlyFixture extends RefCounted:
	var _stored_counts: Dictionary = {"meat":0}
	var add_mode: String = "normal"
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
	func load_save_dict(_data: Dictionary) -> bool:
		return true

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var bridge: Node = BridgeScript.new()
	root.add_child(bridge)
	await process_frame

	var fixture := OperationFixture.new()
	_expect(bool(bridge.call("bind_inventory", fixture)), "custom inventory with a counts dictionary binds")
	var collected_events: Array[int] = []
	var dropped_events: Array[int] = []
	var consumed_events: Array[int] = []
	var refresh_events: Array[int] = []
	bridge.item_collected.connect(func(_item_id: String, amount: int) -> void: collected_events.append(amount))
	bridge.item_dropped.connect(func(_item_id: String, amount: int) -> void: dropped_events.append(amount))
	bridge.item_consumed.connect(func(_item_id: String, amount: int) -> void: consumed_events.append(amount))
	bridge.inventory_changed.connect(func(_summary: Dictionary) -> void: refresh_events.append(1))

	_expect(bool(bridge.call("collect_world_item", "meat", 2)), "matching add result and count delta are accepted")
	_expect(int(fixture.counts["meat"]) == 2 and int(bridge.call("get_item_count", "meat")) == 2, "public count dictionary is observable through the bridge")
	_expect(collected_events == [2], "valid collection mutates once and emits the requested amount")

	fixture.add_mode = "over_report"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "over-reported add count is rejected")
	_expect(int(fixture.counts["meat"]) == 3, "unexpected custom mutation remains visible rather than hidden")
	_expect(collected_events.size() == 1 and refresh_events.size() == 2, "over-report emits no collection event but refreshes changed inventory")

	fixture.add_mode = "under_report"
	_expect(not bool(bridge.call("collect_world_item", "meat", 2)), "under-reported add count is rejected when the dictionary delta differs")
	_expect(int(fixture.counts["meat"]) == 5, "under-report mutation remains observable")
	_expect(refresh_events.size() == 3, "under-report mismatch refreshes the inventory view")

	fixture.add_mode = "no_mutation"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "a positive return without an actual count change is rejected")
	_expect(refresh_events.size() == 3, "no-op mismatch does not emit a false refresh")

	fixture.add_mode = "fractional"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "fractional operation result is rejected")
	fixture.add_mode = "string"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "string operation result is rejected")
	fixture.add_mode = "boolean"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "Boolean operation result is rejected")
	_expect(collected_events.size() == 1 and refresh_events.size() == 6, "malformed results never emit item-collected events and changed counts trigger refresh")

	fixture.remove_mode = "normal"
	_expect(bool(bridge.call("drop_item", "meat", 2)), "matching remove result and count delta are accepted")
	_expect(dropped_events == [2], "valid drop emits the exact removed amount")
	fixture.remove_mode = "over_report"
	_expect(not bool(bridge.call("drop_item", "meat", 1)), "over-reported remove count is rejected")
	_expect(dropped_events.size() == 1 and refresh_events.size() == 8, "invalid drop emits no drop event but refreshes an actual mutation")
	fixture.remove_mode = "no_mutation"
	_expect(not bool(bridge.call("consume_item", "meat", 1)), "consume rejects a positive result without a count change")
	_expect(consumed_events.is_empty(), "invalid consume does not emit an item-consumed event")
	fixture.remove_mode = "normal"
	_expect(bool(bridge.call("consume_item", "meat", 1)), "valid consume remains compatible")
	_expect(consumed_events == [1], "valid consume emits its exact removed amount")

	var method_only := MethodOnlyFixture.new()
	_expect(bool(bridge.call("bind_inventory", method_only)), "method-only custom inventory remains compatible")
	_expect(bool(bridge.call("collect_world_item", "meat", 2)), "method-only inventory with no public counts property trusts a validated return count")
	_expect(int(bridge.call("get_item_count", "meat")) == 2, "method-only count accessor reports the accepted mutation")
	var refresh_before_invalid: int = refresh_events.size()
	method_only.add_mode = "string"
	_expect(not bool(bridge.call("collect_world_item", "meat", 1)), "method-only inventory rejects a malformed string result")
	_expect(int(bridge.call("get_item_count", "meat")) == 3, "method-only inventory mutation remains observable through its accessor")
	_expect(refresh_events.size() == refresh_before_invalid + 1, "invalid method-only result emits a defensive inventory refresh")
	_expect(collected_events.size() == 2, "invalid method-only result does not emit an additional item-collected event")

	bridge.queue_free()
	await process_frame
	if failures.is_empty():
		print("World bridge inventory operation result validation tests passed.")
		quit(0)
	else:
		push_error("World bridge operation result validation failures: " + str(failures))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

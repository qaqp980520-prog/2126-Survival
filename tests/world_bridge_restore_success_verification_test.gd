extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const InventoryModel = preload("res://systems/SurvivalInventory.gd")

class RestoreFixture extends RefCounted:
	var counts: Dictionary = {"meat": 3}
	var game_day: int = 4
	var mode: String = "normal"
	var load_calls: int = 0
	var bridge: Node
	var replacement: RefCounted
	var nested_restore_accepted: bool = false
	var nested_collect_accepted: bool = false
	var rebind_accepted: bool = false
	var direct_rebind_blocked: bool = false

	func add_item(_item_id: String, _amount: int = 1) -> int:
		return 0
	func remove_item(_item_id: String, _amount: int = 1) -> int:
		return 0
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
	func to_save_dict() -> Dictionary:
		return {"schema_version": 1, "game_day": game_day, "inventory": counts.duplicate(true)}
	func load_save_dict(data: Dictionary) -> bool:
		load_calls += 1
		if load_calls == 1 and mode == "reentrant":
			nested_restore_accepted = bool(bridge.call("restore_inventory", data))
			nested_collect_accepted = bool(bridge.call("collect_world_item", "meat", 1))
			rebind_accepted = bool(bridge.call("bind_inventory", replacement))
			bridge.set("inventory", replacement)
			direct_rebind_blocked = bridge.get("inventory") == null
		if load_calls == 1 and mode == "lying_success":
			counts = {"meat": 999}
			game_day = 99
			return true
		if load_calls == 1 and mode == "no_op_success":
			return true
		if load_calls == 1 and mode == "lying_success_rollback_fail":
			counts = {"meat": 999}
			game_day = 99
			return true
		if load_calls >= 2 and mode == "lying_success_rollback_fail":
			counts = {"meat": 777}
			game_day = 77
			return true
		counts = data.get("inventory", {}).duplicate(true)
		game_day = int(data.get("game_day", 1))
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
	var fixture := RestoreFixture.new()
	_expect(bool(bridge.call("bind_inventory", fixture)), "custom restore fixture satisfies the inventory contract")
	var listener := RefreshListener.new()
	root.add_child(listener)
	bridge.inventory_changed.connect(Callable(listener, "on_changed"))

	var original: Dictionary = fixture.to_save_dict()
	var payload := {"schema_version": 1, "game_day": 9, "inventory": {"meat": 40}}
	fixture.mode = "lying_success"
	_expect(not bool(bridge.call("restore_inventory", payload)), "a true result with the wrong serialized state is rejected")
	_expect(fixture.to_save_dict() == original, "lying success is rolled back to the exact prior snapshot")
	_expect(fixture.load_calls == 2 and listener.count == 0, "verified rollback is silent and performs one rollback")

	fixture.load_calls = 0
	fixture.mode = "no_op_success"
	_expect(not bool(bridge.call("restore_inventory", payload)), "a true no-op restore is rejected")
	_expect(fixture.to_save_dict() == original, "no-op success leaves the prior snapshot intact")
	_expect(fixture.load_calls == 2 and listener.count == 0, "no-op mismatch is rolled back without a misleading refresh")

	fixture.load_calls = 0
	fixture.mode = "lying_success_rollback_fail"
	_expect(not bool(bridge.call("restore_inventory", payload)), "unverifiable rollback after a lying success remains a failure")
	_expect(listener.count == 1, "unverifiable rollback emits one defensive inventory refresh")

	fixture.load_calls = 0
	fixture.mode = "normal"
	fixture.counts = {"meat": 3}
	fixture.game_day = 4
	_expect(bool(bridge.call("restore_inventory", payload)), "a custom loader whose serialized state matches the payload succeeds")
	_expect(fixture.counts == {"meat": 40} and fixture.game_day == 9, "verified custom restore applies the requested data")
	_expect(listener.count == 2, "verified successful restore emits exactly one refresh")

	fixture.counts = {"meat": 3}
	fixture.game_day = 4
	fixture.load_calls = 0
	fixture.mode = "reentrant"
	fixture.bridge = bridge
	fixture.replacement = RestoreFixture.new()
	_expect(bool(bridge.call("restore_inventory", payload)), "outer restore succeeds while custom loader attempts reentrant bridge mutations")
	_expect(not fixture.nested_restore_accepted, "nested restore is rejected while a restore transaction is active")
	_expect(not fixture.nested_collect_accepted, "collect operation is rejected during restore callback")
	_expect(not fixture.rebind_accepted, "bind_inventory cannot replace the active inventory during restore")
	_expect(fixture.direct_rebind_blocked and bridge.get("inventory") == fixture, "direct inventory property assignment is blocked during restore")
	_expect(fixture.counts == {"meat": 40} and fixture.game_day == 9, "outer restore applies only its requested snapshot")
	_expect(listener.count == 3, "reentrant attempts do not emit extra inventory notifications")

	fixture.load_calls = 0
	fixture.mode = "normal"

	fixture.load_calls = 0
	var invalid_day_payload := {"schema_version": 1, "game_day": 0, "inventory": {"meat": 2}}
	_expect(not bool(bridge.call("restore_inventory", invalid_day_payload)), "invalid game-day payload is rejected")
	_expect(fixture.load_calls == 0, "invalid payload is rejected before calling the custom loader")
	var invalid_count_payload := {"schema_version": 1, "game_day": 2, "inventory": {"meat": 1.5}}
	_expect(not bool(bridge.call("restore_inventory", invalid_count_payload)), "fractional inventory count payload is rejected")
	_expect(fixture.load_calls == 0, "fractional payload is rejected before mutation")

	var built_bridge: Node = BridgeScript.new()
	root.add_child(built_bridge)
	await process_frame
	var built_inventory = InventoryModel.new({"meat": 3}, 4)
	_expect(bool(built_bridge.call("bind_inventory", built_inventory)), "built-in SurvivalInventory binds")
	var built_listener := RefreshListener.new()
	root.add_child(built_listener)
	built_bridge.inventory_changed.connect(Callable(built_listener, "on_changed"))
	_expect(bool(built_bridge.call("restore_inventory", payload)), "built-in model accepts a compact payload and canonical zero entries")
	_expect(built_inventory.get_item_count("meat") == 40 and built_inventory.game_day == 9, "built-in restore applies the compact payload")
	_expect(built_inventory.counts.size() == InventoryModel.ITEM_WEIGHTS.size(), "built-in restore retains the complete known-item key set")
	_expect(built_listener.count == 1, "built-in verified restore emits one refresh")

	var world_save := {"version": 2, "game_day": 6, "inventory": {"iron_ore": 2}}
	_expect(bool(built_bridge.call("restore_world_save", world_save)), "world-save restore verifies its canonical adapter payload")
	_expect(built_inventory.get_item_count("iron_ore") == 2 and built_inventory.game_day == 6, "world-save data is applied after verification")
	_expect(built_listener.count == 2, "world-save verified restore emits one refresh")

	bridge.queue_free()
	built_bridge.queue_free()
	listener.queue_free()
	built_listener.queue_free()
	await process_frame
	if failures.is_empty():
		print("World bridge restore success verification tests passed.")
		quit(0)
	else:
		push_error("World bridge restore success verification failures: " + str(failures))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

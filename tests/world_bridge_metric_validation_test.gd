extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")

class MetricInventory extends RefCounted:
	var weight_value: Variant = 0.0
	var limit_value: Variant = 65.0
	var movement_value: Variant = 1.0
	var jump_value: Variant = true
	var overweight_value: Variant = false
	var super_heavy_value: Variant = false

	func add_item(_item_id: String, _amount: int = 1) -> int:
		return 0
	func remove_item(_item_id: String, _amount: int = 1) -> int:
		return 0
	func total_weight_kg() -> Variant:
		return weight_value
	func carry_limit_kg() -> Variant:
		return limit_value
	func movement_multiplier() -> Variant:
		return movement_value
	func can_jump() -> Variant:
		return jump_value
	func is_overweight() -> Variant:
		return overweight_value
	func is_super_heavy() -> Variant:
		return super_heavy_value
	func to_save_dict() -> Dictionary:
		return {}
	func load_save_dict(_data: Dictionary) -> bool:
		return true

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var bridge: Node = BridgeScript.new()
	root.add_child(bridge)
	await process_frame
	var fixture := MetricInventory.new()
	_expect(bool(bridge.call("bind_inventory", fixture)), "accept a custom inventory implementing the required method contract")

	fixture.weight_value = NAN
	fixture.limit_value = INF
	fixture.movement_value = NAN
	fixture.jump_value = "yes"
	fixture.overweight_value = 1
	fixture.super_heavy_value = "false"
	var summary: Dictionary = bridge.call("get_summary")
	_expect(is_equal_approx(float(summary["weight_kg"]), 0.0), "non-finite custom weight falls back to zero")
	_expect(is_equal_approx(float(summary["limit_kg"]), 65.0), "non-finite custom carry limit falls back to the base limit")
	_expect(not bool(summary["overweight"]) and not bool(summary["super_heavy"]), "non-boolean status values are derived from validated metrics")
	_expect(is_equal_approx(float(summary["movement_multiplier"]), 1.0), "non-finite movement multiplier uses the safe normal fallback")
	_expect(bool(summary["can_jump"]), "invalid jump flag falls back to the derived safe state")

	fixture.weight_value = 120.0
	fixture.limit_value = 65.0
	fixture.movement_value = -0.25
	fixture.jump_value = "invalid"
	fixture.overweight_value = "invalid"
	fixture.super_heavy_value = false
	summary = bridge.call("get_summary")
	_expect(is_equal_approx(float(summary["weight_kg"]), 120.0), "valid finite weight is preserved")
	_expect(bool(summary["overweight"]), "invalid overweight flag is derived from weight and limit")
	_expect(not bool(summary["super_heavy"]), "valid custom super-heavy flag is preserved")
	_expect(is_equal_approx(float(summary["movement_multiplier"]), 0.68), "invalid movement multiplier falls back to the overweight penalty")
	_expect(bool(summary["can_jump"]), "valid custom jump permission is preserved")

	fixture.super_heavy_value = "invalid"
	summary = bridge.call("get_summary")
	_expect(bool(summary["super_heavy"]), "invalid super-heavy flag is derived from the default threshold")
	_expect(is_equal_approx(float(summary["movement_multiplier"]), 0.42), "derived super-heavy state selects the stronger movement penalty")
	_expect(not bool(summary["can_jump"]), "invalid jump flag falls back to the derived no-jump state")

	fixture.weight_value = "bad"
	fixture.limit_value = -10.0
	fixture.movement_value = 1.5
	fixture.jump_value = 1
	fixture.overweight_value = true
	fixture.super_heavy_value = false
	summary = bridge.call("get_summary")
	_expect(is_equal_approx(float(summary["weight_kg"]), 0.0), "string weight is rejected")
	_expect(is_equal_approx(float(summary["limit_kg"]), 65.0), "non-positive carry limit is rejected")
	_expect(is_equal_approx(float(summary["movement_multiplier"]), 0.68), "movement multipliers above one are rejected and use the validated overweight fallback")
	_expect(bool(summary["overweight"]), "valid custom boolean status is preserved")
	_expect(bool(summary["can_jump"]), "non-boolean numeric jump flag is rejected and derived")

	_expect(is_equal_approx(float(bridge.call("get_weight_kg")), 0.0), "public weight getter uses the validated summary")
	_expect(is_equal_approx(float(bridge.call("get_carry_limit_kg")), 65.0), "public carry-limit getter uses the validated summary")
	_expect(is_equal_approx(float(bridge.call("get_movement_multiplier")), 0.68), "public movement getter uses the validated summary")
	_expect(bool(bridge.call("can_player_jump")), "public jump getter uses the validated summary")

	bridge.queue_free()
	await process_frame
	if failures.is_empty():
		print("World bridge metric validation tests passed.")
		quit(0)
	else:
		push_error("World bridge metric validation failures: " + str(failures))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")

class AliasingInventory extends RefCounted:
	var counts: Dictionary = {"meat":2}
	var game_day: int = 3
	var snapshot_mode: String = "normal"

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
	func to_save_dict() -> Variant:
		match snapshot_mode:
			"invalid_type":
				return "not-a-dictionary"
			"invalid_payload":
				return {"schema_version":1,"game_day":game_day,"inventory":{"unknown_item":5}}
		return {"schema_version":1,"game_day":game_day,"inventory":counts}
	func load_save_dict(data: Dictionary) -> bool:
		counts = data.get("inventory", {}).duplicate(true)
		game_day = int(data.get("game_day", 1))
		return true

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var bridge: Node = BridgeScript.new()
	root.add_child(bridge)
	await process_frame
	var fixture := AliasingInventory.new()
	_expect(bool(bridge.call("bind_inventory", fixture)), "custom inventory contract binds")

	var snapshot: Dictionary = bridge.call("serialize_inventory")
	snapshot["inventory"]["meat"] = 999
	_expect(int(fixture.counts.get("meat", 0)) == 2, "mutating serialized snapshot cannot mutate live custom inventory")

	var world_source := {
		"version":2,
		"game_day":7,
		"inventory":{"credits":20},
		"player":{"position":{"x":1.0,"y":2.0}}
	}
	var source_before: Dictionary = world_source.duplicate(true)
	var exported: Dictionary = bridge.call("serialize_world_save", world_source)
	_expect(bool(exported.get("ok", false)), "valid aliased custom snapshot exports through the save adapter")
	_expect(world_source == source_before, "world-save export leaves the caller envelope unchanged")
	var output: Dictionary = exported.get("world_save", {})
	_expect(int(output.get("inventory", {}).get("meat", 0)) == 2, "export uses the captured inventory values")
	_expect(output.get("player", {}) == source_before.get("player", {}), "unrelated world fields survive export")
	output["inventory"]["meat"] = 777
	_expect(int(fixture.counts.get("meat", 0)) == 2, "mutating exported world save cannot mutate live custom inventory")
	_expect(world_source == source_before, "mutating exported result cannot mutate the source envelope")

	fixture.snapshot_mode = "invalid_type"
	var invalid_snapshot: Dictionary = bridge.call("serialize_inventory")
	_expect(invalid_snapshot.is_empty(), "non-Dictionary custom snapshots return a safe empty inventory payload")
	var invalid_export: Dictionary = bridge.call("serialize_world_save", world_source)
	_expect(not bool(invalid_export.get("ok", true)), "non-Dictionary snapshot blocks world-save export")
	_expect(str(invalid_export.get("error", "")) == "invalid_inventory_snapshot", "invalid snapshot reports a precise export error")

	fixture.snapshot_mode = "invalid_payload"
	var raw_invalid: Dictionary = bridge.call("serialize_inventory")
	_expect(raw_invalid.get("inventory", {}).has("unknown_item"), "Dictionary snapshots preserve raw invalid fields for strict downstream validation")
	var rejected_export: Dictionary = bridge.call("serialize_world_save", world_source)
	_expect(not bool(rejected_export.get("ok", true)), "invalid Dictionary payload is rejected by the save adapter")
	_expect(str(rejected_export.get("error", "")) == "invalid_inventory_payload", "save adapter reports invalid inventory payload")

	bridge.queue_free()
	await process_frame
	if failures.is_empty():
		print("World bridge serialization snapshot tests passed.")
		quit(0)
	else:
		push_error("World bridge serialization snapshot failures: " + str(failures))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

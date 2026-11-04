extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")

class PartialRestoreInventory extends RefCounted:
	var counts: Dictionary = {"meat":3}
	var game_day: int = 4
	var mode: String = "partial_fail"
	var snapshot_mode: String = "normal"
	var load_calls: int = 0

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
		if snapshot_mode == "invalid":
			return "not-a-dictionary"
		return {
			"schema_version":1,
			"game_day":game_day,
			"inventory":counts.duplicate(true)
		}
	func load_save_dict(data: Dictionary) -> Variant:
		load_calls += 1
		if mode == "partial_fail" and load_calls == 1:
			counts = data.get("inventory", {}).duplicate(true)
			game_day = int(data.get("game_day", 1))
			return false
		if mode == "rollback_fail" and load_calls == 2:
			counts = {"meat":999}
			game_day = 99
			return false
		if mode == "lying_rollback" and load_calls == 2:
			counts = {"meat":999}
			game_day = 99
			return true
		if mode == "partial_fail" and load_calls >= 2:
			counts = data.get("inventory", {}).duplicate(true)
			game_day = int(data.get("game_day", 1))
			return true
		if mode == "success":
			counts = data.get("inventory", {}).duplicate(true)
			game_day = int(data.get("game_day", 1))
			return true
		return false

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var bridge: Node = BridgeScript.new()
	root.add_child(bridge)
	await process_frame
	var fixture := PartialRestoreInventory.new()
	_expect(bool(bridge.call("bind_inventory", fixture)), "custom inventory with snapshot and load methods binds")

	var refresh_events: Array[int] = []
	bridge.inventory_changed.connect(func(_summary: Dictionary) -> void: refresh_events.append(1))

	var original: Dictionary = fixture.to_save_dict()
	var partial_payload := {"schema_version":1,"game_day":9,"inventory":{"meat":40}}
	_expect(not bool(bridge.call("restore_inventory", partial_payload)), "partial custom restore failure is reported")
	_expect(fixture.to_save_dict() == original, "failed restore rolls back the exact prior snapshot")
	_expect(refresh_events.is_empty(), "verified rollback does not emit a misleading inventory refresh")
	_expect(fixture.load_calls == 2, "failed restore performs one restore attempt and one rollback")

	fixture.load_calls = 0
	fixture.mode = "partial_fail"
	var world_save := {"version":2,"game_day":8,"inventory":{"meat":22}}
	_expect(not bool(bridge.call("restore_world_save", world_save)), "partial world-save restore failure is reported")
	_expect(fixture.to_save_dict() == original, "world-save failure restores the exact prior snapshot")
	_expect(refresh_events.is_empty(), "verified world-save rollback leaves observers unchanged")

	fixture.load_calls = 0
	fixture.mode = "rollback_fail"
	_expect(not bool(bridge.call("restore_inventory", partial_payload)), "failed rollback never reports restore success")
	_expect(refresh_events.size() == 1, "unverified rollback emits one defensive refresh")

	fixture.load_calls = 0
	fixture.mode = "lying_rollback"
	_expect(not bool(bridge.call("restore_inventory", partial_payload)), "a rollback that returns true but restores the wrong snapshot is rejected")
	_expect(refresh_events.size() == 2, "snapshot mismatch after rollback emits a second defensive refresh")

	fixture.load_calls = 0
	fixture.mode = "success"
	_expect(bool(bridge.call("restore_inventory", partial_payload)), "valid custom restore succeeds")
	_expect(fixture.counts.get("meat", 0) == 40 and fixture.game_day == 9, "successful restore applies the requested payload")
	_expect(refresh_events.size() == 3, "successful restore emits exactly one inventory refresh")

	fixture.load_calls = 0
	fixture.snapshot_mode = "invalid"
	var before_invalid_calls: int = fixture.load_calls
	_expect(not bool(bridge.call("restore_inventory", partial_payload)), "invalid pre-restore snapshot rejects the operation before mutation")
	_expect(fixture.load_calls == before_invalid_calls, "invalid snapshot does not call the custom loader")
	_expect(refresh_events.size() == 3, "invalid snapshot does not emit a refresh")

	fixture.snapshot_mode = "normal"
	fixture.load_calls = 0
	var invalid_world_save := {"version":2,"game_day":1,"inventory":{"unknown_item":5}}
	_expect(not bool(bridge.call("restore_world_save", invalid_world_save)), "invalid world-save payload is rejected before custom loading")
	_expect(fixture.load_calls == 0, "invalid world-save payload does not call the custom loader")
	_expect(refresh_events.size() == 3, "invalid world-save payload leaves observers unchanged")

	bridge.queue_free()
	await process_frame
	if failures.is_empty():
		print("World bridge restore atomicity tests passed.")
		quit(0)
	else:
		push_error("World bridge restore atomicity failures: " + str(failures))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

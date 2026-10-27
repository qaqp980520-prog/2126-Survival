extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const InventoryScript = preload("res://systems/SurvivalInventory.gd")

var failures: Array[String] = []
var _finished: bool = false
var _watchdog_timer: Timer
var _bridge: Node

func _initialize() -> void:
	_watchdog_timer = Timer.new()
	_watchdog_timer.one_shot = true
	_watchdog_timer.wait_time = 30.0
	root.add_child(_watchdog_timer)
	_watchdog_timer.timeout.connect(_on_watchdog_timeout)
	call_deferred("_start_watchdog")
	call_deferred("_run_integration_test")

func _start_watchdog() -> void:
	if not _finished and is_instance_valid(_watchdog_timer) and _watchdog_timer.is_inside_tree():
		_watchdog_timer.start()

func _run_integration_test() -> void:
	print("Starting SurvivalWorldBridge save adapter integration test.")
	_bridge = BridgeScript.new()
	_bridge.set("inventory_script", InventoryScript)
	root.add_child(_bridge)

	var legacy_world := {
		"version": 2,
		"game_day": 4,
		"inventory": {"meat": 2, "rock": 3},
		"world_seed": 12345,
		"stamina": 75.0,
		"hotbar_slots": ["", "meat", "", "food", "", "", "", "", "", ""],
		"selected_hotbar": 2,
		"player_position": [1.5, 2.0, -3.5],
		"crops": [{"id": "crop_a", "growth": 0.5}],
		"world_state": {"harvested_world_crop_ids": ["crop_1"]}
	}
	var original_world: Dictionary = legacy_world.duplicate(true)

	var restored_ok: bool = bool(_bridge.call("restore_world_save", legacy_world))
	_expect(restored_ok, "restore valid legacy world save")
	if not restored_ok:
		_finish(1)
		return

	var payload: Dictionary = _bridge.call("serialize_inventory")
	_expect(payload.get("game_day", -1) == 4, "restored game day")
	var counts: Dictionary = payload.get("inventory", {})
	_expect(counts.get("meat", -1) == 2 and counts.get("rock", -1) == 3, "restored item counts")
	_expect(is_equal_approx(float(_bridge.call("get_weight_kg")), 9.0), "restored inventory weight")

	var collected: bool = bool(_bridge.call("collect_world_item", "berries", 3))
	_expect(collected, "collect berries through world bridge")
	var snapshot: Dictionary = _bridge.call("serialize_inventory").duplicate(true)
	var serialized: Dictionary = _bridge.call("serialize_world_save", legacy_world)
	var export_ok: bool = bool(serialized.get("ok", false))
	_expect(export_ok, "serialize inventory into legacy world envelope")
	if export_ok:
		var updated: Dictionary = serialized["world_save"]
		var updated_counts: Dictionary = updated.get("inventory", {})
		_expect(updated_counts.get("meat", -1) == 2, "export preserves meat count")
		_expect(updated_counts.get("rock", -1) == 3, "export preserves rock count")
		_expect(updated_counts.get("berries", -1) == 3, "export includes newly collected berries")
		_expect(updated.get("game_day", -1) == 4, "export preserves game day")
		_expect(updated.get("world_seed", -1) == 12345, "export preserves world seed")
		_expect(updated.get("stamina", -1.0) == 75.0, "export preserves stamina")
		_expect(updated.get("hotbar_slots", []) == legacy_world["hotbar_slots"], "export preserves hotbar slots")
		_expect(updated.get("selected_hotbar", -1) == 2, "export preserves selected hotbar slot")
		_expect(updated.get("player_position", []) == legacy_world["player_position"], "export preserves player position")
		_expect(updated.get("crops", []) == legacy_world["crops"], "export preserves crops")
		_expect(updated.get("world_state", {}) == legacy_world["world_state"], "export preserves world state")
	_expect(legacy_world == original_world, "export does not mutate input envelope")

	var invalid_cases: Array[Dictionary] = []
	var bad_container: Dictionary = legacy_world.duplicate(true)
	bad_container["inventory"] = []
	invalid_cases.append({"label": "non-dictionary inventory", "data": bad_container})
	var unknown_item: Dictionary = legacy_world.duplicate(true)
	unknown_item["inventory"] = {"mystery_item": 9}
	invalid_cases.append({"label": "unknown item ID", "data": unknown_item})
	var fractional_count: Dictionary = legacy_world.duplicate(true)
	fractional_count["inventory"] = {"meat": 1.5}
	invalid_cases.append({"label": "fractional item count", "data": fractional_count})
	var negative_count: Dictionary = legacy_world.duplicate(true)
	negative_count["inventory"] = {"meat": -1}
	invalid_cases.append({"label": "negative item count", "data": negative_count})
	var out_of_range_count: Dictionary = legacy_world.duplicate(true)
	out_of_range_count["inventory"] = {"rock": 1000000001}
	invalid_cases.append({"label": "out-of-range item count", "data": out_of_range_count})
	var invalid_day: Dictionary = legacy_world.duplicate(true)
	invalid_day["game_day"] = 0
	invalid_cases.append({"label": "invalid game day", "data": invalid_day})
	var unsupported_version: Dictionary = legacy_world.duplicate(true)
	unsupported_version["version"] = 3
	invalid_cases.append({"label": "unsupported world schema", "data": unsupported_version})

	for entry in invalid_cases:
		var bad_world: Dictionary = entry["data"]
		_expect_rejected_restore_unchanged(_bridge, bad_world, snapshot, str(entry["label"]))

	var unsupported_before: Dictionary = unsupported_version.duplicate(true)
	var rejected_export: Dictionary = _bridge.call("serialize_world_save", unsupported_version)
	_expect(not bool(rejected_export.get("ok", false)), "reject unsupported world schema during export")
	_expect(unsupported_version == unsupported_before, "rejected export leaves input envelope unchanged")
	_finish(0 if failures.is_empty() else 1)

func _expect_rejected_restore_unchanged(bridge: Node, bad_world: Dictionary, expected_inventory: Dictionary, label: String) -> void:
	var restored: bool = bool(bridge.call("restore_world_save", bad_world))
	_expect(not restored, label + " rejected")
	var after: Dictionary = bridge.call("serialize_inventory")
	_expect(after == expected_inventory, label + " preserves live inventory")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish(exit_code: int) -> void:
	if _finished:
		return
	_finished = true
	if is_instance_valid(_watchdog_timer):
		_watchdog_timer.stop()
		root.remove_child(_watchdog_timer)
		_watchdog_timer.free()
	if is_instance_valid(_bridge):
		root.remove_child(_bridge)
		_bridge.free()
	if exit_code == 0:
		print("SurvivalWorldBridge save adapter integration tests passed.")
	else:
		push_error("SurvivalWorldBridge integration failures: " + str(failures))
	quit(exit_code)

func _on_watchdog_timeout() -> void:
	if _finished:
		return
	push_error("SurvivalWorldBridge integration test timed out.")
	_finish(2)

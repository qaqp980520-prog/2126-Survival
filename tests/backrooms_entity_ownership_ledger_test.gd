extends SceneTree

const LedgerScript = preload("res://systems/BackroomsEntityOwnershipLedger.gd")
const EntityDirectorScript = preload("res://systems/BackroomsEntityDirector.gd")
const LayoutScript = preload("res://systems/BackroomsMazeLayout.gd")
const RoutePlannerScript = preload("res://systems/BackroomsCellRoutePlanner.gd")

const LEVEL_ID: String = "Level 2"
const WORLD_SEED: int = 20261118
const CELL_SIZE: float = 8.0
const SPAWN_VERSION: int = 1

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture: Dictionary = _find_transfer_fixture()
	_expect(not fixture.is_empty(), "fixture finds a deterministic mobile spawn with an open adjacent edge")
	if fixture.is_empty():
		_finish()
		return
	var spawn_cell: Vector2i = fixture["spawn_cell"]
	var target_cell: Vector2i = fixture["target_cell"]
	var direction: Vector2i = fixture["direction"]
	var entity_id: String = str(fixture["entity_id"])
	var spawn_key: String = _cell_key(spawn_cell)
	var target_key: String = _cell_key(target_cell)
	var unrelated_cell: Vector2i = spawn_cell + Vector2i(2, 2)
	var unrelated_key: String = _cell_key(unrelated_cell)
	var loaded_keys: Array = [spawn_key, target_key, unrelated_key]
	var ledger: RefCounted = LedgerScript.new()
	_expect(
		bool(ledger.call("configure", LEVEL_ID, WORLD_SEED, CELL_SIZE, SPAWN_VERSION, 7, 3, loaded_keys)),
		"ledger configures a bounded loaded-cell snapshot"
	)
	var registration: Dictionary = ledger.call("register_deterministic_spawns")
	_expect(bool(registration.get("ok", false)), "ledger registers deterministic mobile spawn identities")
	var initial_record: Dictionary = ledger.call("get_record", spawn_key, entity_id)
	_expect(
		str(initial_record.get("spawn_cell_key", "")) == spawn_key
		and str(initial_record.get("owner_cell_key", "")) == spawn_key
		and int(initial_record.get("owner_revision", -1)) == 0,
		"new entity identity starts with immutable spawn cell and owner revision zero"
	)
	var duplicate_registration: Dictionary = ledger.call("register_deterministic_spawns")
	_expect(
		bool(duplicate_registration.get("ok", false))
		and int(duplicate_registration.get("registered_count", -1)) == 0,
		"re-registering a loaded window never duplicates or resets an existing owner"
	)

	var forward_route: Dictionary = _make_route(spawn_cell, target_cell, direction, loaded_keys, 7, 3)
	var unrelated_target: Dictionary = ledger.call("plan_transfer", spawn_key, entity_id, unrelated_key, forward_route)
	_expect(
		not bool(unrelated_target.get("ok", false)),
		"loaded but non-route target cannot bypass the route's first hop"
	)
	var forward_plan_result: Dictionary = ledger.call("plan_transfer", spawn_key, entity_id, target_key, forward_route)
	_expect(bool(forward_plan_result.get("ok", false)), "ledger prepares a one-hop transfer along a current reciprocal route")
	if not bool(forward_plan_result.get("ok", false)):
		_finish()
		return
	var forward_plan: Dictionary = forward_plan_result["plan"]
	_expect(int(ledger.call("get_pending_transfer_count")) == 1, "prepared transfer is tracked as pending")
	var pending_save: Dictionary = ledger.call("to_save_dict")
	_expect(pending_save.is_empty(), "save is rejected while an ownership transfer is pending")
	var committed: Dictionary = ledger.call("commit_transfer", forward_plan)
	_expect(bool(committed.get("ok", false)), "exact pending transfer commits")
	var moved_record: Dictionary = ledger.call("get_record", spawn_key, entity_id)
	_expect(
		str(moved_record.get("spawn_cell_key", "")) == spawn_key
		and str(moved_record.get("owner_cell_key", "")) == target_key
		and int(moved_record.get("owner_revision", -1)) == 1,
		"commit changes only runtime owner cell and increments its revision"
	)
	_expect(not bool(ledger.call("commit_transfer", forward_plan).get("ok", false)), "a committed plan cannot be replayed")

	var reverse_route: Dictionary = _make_route(target_cell, spawn_cell, -direction, loaded_keys, 7, 3)
	var rollback_result: Dictionary = ledger.call("plan_transfer", spawn_key, entity_id, spawn_key, reverse_route)
	_expect(bool(rollback_result.get("ok", false)), "a reverse one-hop transfer can be prepared")
	if bool(rollback_result.get("ok", false)):
		_expect(bool(ledger.call("rollback_transfer", rollback_result["plan"])), "rollback cancels the pending reverse transfer")
		_expect(
			str(ledger.call("get_record", spawn_key, entity_id).get("owner_cell_key", "")) == target_key,
			"rollback leaves the previously committed owner unchanged"
		)

	var stale_route: Dictionary = _make_route(target_cell, spawn_cell, -direction, loaded_keys, 7, 3)
	var stale_plan_result: Dictionary = ledger.call("plan_transfer", spawn_key, entity_id, spawn_key, stale_route)
	_expect(bool(stale_plan_result.get("ok", false)), "a second transfer can be prepared before a stream revision")
	if bool(stale_plan_result.get("ok", false)):
		_expect(bool(ledger.call("set_loaded_window", loaded_keys, 8, 3)), "a committed stream generation replaces the loaded-window snapshot")
		_expect(
			not bool(ledger.call("commit_transfer", stale_plan_result["plan"]).get("ok", false)),
			"stream-window generation change invalidates the outstanding transfer token"
		)
		_expect(int(ledger.call("get_pending_transfer_count")) == 0, "stream-window replacement clears pending transfer state")
		_expect(
			str(ledger.call("get_record", spawn_key, entity_id).get("owner_cell_key", "")) == target_key,
			"stale transfer rejection preserves the committed owner"
		)
	_expect(
		not bool(ledger.call("plan_transfer", spawn_key, entity_id, spawn_key, stale_route).get("ok", false)),
		"route snapshots from a previous stream generation are rejected"
	)

	var fresh_reverse_route: Dictionary = _make_route(target_cell, spawn_cell, -direction, loaded_keys, 8, 3)
	var fresh_reverse: Dictionary = ledger.call("plan_transfer", spawn_key, entity_id, spawn_key, fresh_reverse_route)
	_expect(bool(fresh_reverse.get("ok", false)), "fresh route snapshot prepares a transfer after the stream revision")
	if bool(fresh_reverse.get("ok", false)):
		_expect(bool(ledger.call("commit_transfer", fresh_reverse["plan"]).get("ok", false)), "fresh transfer commits after stream revision")
	var fresh_forward_route: Dictionary = _make_route(spawn_cell, target_cell, direction, loaded_keys, 8, 3)
	var fresh_forward: Dictionary = ledger.call("plan_transfer", spawn_key, entity_id, target_key, fresh_forward_route)
	_expect(bool(fresh_forward.get("ok", false)), "entity can transfer back to the adjacent owner cell")
	if bool(fresh_forward.get("ok", false)):
		_expect(bool(ledger.call("commit_transfer", fresh_forward["plan"]).get("ok", false)), "second owner change commits")
	var saved: Dictionary = ledger.call("to_save_dict")
	_expect(int(saved.get("schema_version", -1)) == 1, "ownership ledger writes its independent schema version")
	var restored: RefCounted = LedgerScript.new()
	_expect(
		bool(restored.call("configure", LEVEL_ID, WORLD_SEED, CELL_SIZE, SPAWN_VERSION, 9, 3, loaded_keys)),
		"fresh ledger configures for restore"
	)
	_expect(bool(restored.call("load_save_dict", saved)), "ownership save restores transactionally")
	var restored_record: Dictionary = restored.call("get_record", spawn_key, entity_id)
	_expect(
		str(restored_record.get("spawn_cell_key", "")) == spawn_key
		and str(restored_record.get("owner_cell_key", "")) == target_key
		and int(restored_record.get("owner_revision", -1)) == 3,
		"save/load preserves immutable spawn identity and mutable owner revision"
	)

	var before_invalid: Dictionary = restored.call("to_save_dict")
	var invalid_owner_payload: Dictionary = before_invalid.duplicate(true)
	var invalid_owner_records: Array = invalid_owner_payload.get("records", []).duplicate(true)
	for index in range(invalid_owner_records.size()):
		var record: Dictionary = invalid_owner_records[index]
		if str(record.get("spawn_cell_key", "")) == spawn_key and str(record.get("entity_id", "")) == entity_id:
			record["owner_cell_key"] = "1000001,0"
			invalid_owner_records[index] = record
			break
	invalid_owner_payload["records"] = invalid_owner_records
	_expect(not bool(restored.call("load_save_dict", invalid_owner_payload)), "out-of-range owner cell is rejected")
	_expect(restored.call("to_save_dict") == before_invalid, "rejected ownership restore leaves the prior ledger unchanged")

	var invalid_spawn_payload: Dictionary = before_invalid.duplicate(true)
	var invalid_spawn_records: Array = invalid_spawn_payload.get("records", []).duplicate(true)
	for index in range(invalid_spawn_records.size()):
		var record: Dictionary = invalid_spawn_records[index]
		if str(record.get("spawn_cell_key", "")) == spawn_key and str(record.get("entity_id", "")) == entity_id:
			record["spawn_cell_key"] = "1000001,0"
			invalid_spawn_records[index] = record
			break
	invalid_spawn_payload["records"] = invalid_spawn_records
	_expect(not bool(restored.call("load_save_dict", invalid_spawn_payload)), "out-of-range immutable spawn identity is rejected")
	_expect(restored.call("to_save_dict") == before_invalid, "invalid spawn identity cannot partially replace the restored ledger")

	var foreign_seed_payload: Dictionary = before_invalid.duplicate(true)
	foreign_seed_payload["world_seed"] = WORLD_SEED + 1
	_expect(not bool(restored.call("load_save_dict", foreign_seed_payload)), "foreign-world ownership payload is rejected")

	var tampered_route: Dictionary = _make_route(target_cell, spawn_cell, -direction, loaded_keys, 9, 3)
	tampered_route["edge_directions"] = [direction]
	_expect(
		not bool(restored.call("plan_transfer", spawn_key, entity_id, spawn_key, tampered_route).get("ok", false)),
		"tampered route direction is rejected before ownership changes"
	)
	var foreign_route: Dictionary = _make_route(target_cell, spawn_cell, -direction, loaded_keys, 9, 3)
	foreign_route["world_seed"] = WORLD_SEED + 1
	_expect(
		not bool(restored.call("plan_transfer", spawn_key, entity_id, spawn_key, foreign_route).get("ok", false)),
		"foreign-world route snapshot cannot authorize an ownership transfer"
	)

	var noncanonical: RefCounted = LedgerScript.new()
	_expect(
		not bool(noncanonical.call("configure", LEVEL_ID, WORLD_SEED, CELL_SIZE, SPAWN_VERSION, 0, 0, ["01,0"])),
		"noncanonical loaded-cell keys are rejected during configuration"
	)
	_finish()

func _find_transfer_fixture() -> Dictionary:
	for z in range(-100, 101):
		for x in range(-100, 101):
			var cell := Vector2i(x, z)
			for entity_id in ["hound", "skin_stealer"]:
				if not EntityDirectorScript.get_cell_spawns(LEVEL_ID, cell).has(entity_id):
					continue
				for direction in [
					Vector2i(0, -1),
					Vector2i(1, 0),
					Vector2i(0, 1),
					Vector2i(-1, 0)
				]:
					if LayoutScript.edge_is_open(cell, direction, WORLD_SEED):
						return {
							"spawn_cell": cell,
							"target_cell": cell + direction,
							"direction": direction,
							"entity_id": entity_id
						}
	return {}

func _make_route(
	start_cell: Vector2i,
	target_cell: Vector2i,
	direction: Vector2i,
	loaded_keys: Array,
	generation: int,
	revision: int
) -> Dictionary:
	return {
		"ok": true,
		"route_snapshot_version": RoutePlannerScript.ROUTE_SNAPSHOT_VERSION,
		"start_cell": start_cell,
		"goal_cell": target_cell,
		"cell_path": [start_cell, target_cell],
		"cell_keys": [_cell_key(start_cell), _cell_key(target_cell)],
		"edge_directions": [direction],
		"route_cell_count": 2,
		"expanded_count": 1,
		"level_id": LEVEL_ID,
		"world_seed": WORLD_SEED,
		"layout_algorithm_version": LayoutScript.ALGORITHM_VERSION,
		"stream_generation": generation,
		"configuration_revision": revision,
		"loaded_cell_count": loaded_keys.size()
	}

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures.append(label)
		push_error("FAIL: " + label)

func _finish() -> void:
	if failures.is_empty():
		print("Backrooms entity ownership ledger tests passed.")
		quit(0)
	else:
		printerr("Backrooms entity ownership ledger tests failed: %d" % failures.size())
		quit(1)

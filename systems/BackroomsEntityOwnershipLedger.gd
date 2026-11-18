extends RefCounted
class_name BackroomsEntityOwnershipLedger

## Renderer-independent, transactional ownership metadata for mobile Backrooms entities.
## Spawn identity is immutable; runtime owner-cell identity may advance one validated route hop.
## This ledger does not reparent Nodes or enable roaming by itself.
const LayoutScript = preload("res://systems/BackroomsMazeLayout.gd")
const EntityDirectorScript = preload("res://systems/BackroomsEntityDirector.gd")
const RoutePlannerScript = preload("res://systems/BackroomsCellRoutePlanner.gd")

const SCHEMA_VERSION: int = 1
const PLAN_VERSION: int = 1
const MAX_WORLD_SEED: int = 2147483647
const MAX_RECORDS: int = 4096
const MAX_ROUTE_CELLS: int = 289
const MAX_RETAINED_OWNER_CELLS: int = 361
const MAX_OWNER_REVISION: int = 1000000000
const MOBILE_ENTITY_IDS: Array[String] = [
	"smiler", "hound", "skin_stealer", "faceling", "duller", "deathmoth"
]

var configured: bool = false
var level_id: String = ""
var world_seed: int = 0
var cell_size: float = 8.0
var spawn_algorithm_version: int = EntityDirectorScript.SPAWN_ALGORITHM_VERSION
var stream_generation: int = 0
var configuration_revision: int = 0
var _loaded_cell_keys: Dictionary = {}
var _records: Dictionary = {}
var _pending_transfers: Dictionary = {}

func configure(
	requested_level_id: String,
	requested_world_seed: int,
	requested_cell_size: float,
	requested_spawn_algorithm_version: int,
	requested_stream_generation: int,
	requested_configuration_revision: int,
	loaded_cell_keys: Array
) -> bool:
	if configured:
		return false
	if not ["Level 0", "Level 1", "Level 2", "Level 3", "Level 4", "Level 5"].has(requested_level_id):
		return false
	if requested_world_seed < 0 or requested_world_seed > MAX_WORLD_SEED:
		return false
	if not is_finite(requested_cell_size) or requested_cell_size <= 1.3 or requested_cell_size > LayoutScript.MAX_CELL_SIZE:
		return false
	if not EntityDirectorScript.is_spawn_algorithm_version_supported(requested_spawn_algorithm_version):
		return false
	if requested_stream_generation < 0 or requested_configuration_revision < 0:
		return false
	var loaded_result: Dictionary = _parse_loaded_cell_keys(loaded_cell_keys)
	if not bool(loaded_result.get("ok", false)):
		return false
	level_id = requested_level_id
	world_seed = requested_world_seed
	cell_size = requested_cell_size
	spawn_algorithm_version = requested_spawn_algorithm_version
	stream_generation = requested_stream_generation
	configuration_revision = requested_configuration_revision
	_loaded_cell_keys = loaded_result.get("keys", {})
	configured = true
	return true

## Replace the committed loaded-window snapshot. Any outstanding transfer plan becomes stale.
func set_loaded_window(
	loaded_cell_keys: Array,
	requested_stream_generation: int,
	requested_configuration_revision: int
) -> bool:
	if not configured:
		return false
	if requested_stream_generation < stream_generation or requested_configuration_revision < configuration_revision:
		return false
	var loaded_result: Dictionary = _parse_loaded_cell_keys(loaded_cell_keys)
	if not bool(loaded_result.get("ok", false)):
		return false
	var candidate_keys: Dictionary = loaded_result.get("keys", {})
	var same_revision: bool = (
		requested_stream_generation == stream_generation
		and requested_configuration_revision == configuration_revision
	)
	if same_revision and candidate_keys != _loaded_cell_keys:
		return false
	if not same_revision:
		_pending_transfers.clear()
	_loaded_cell_keys = candidate_keys
	stream_generation = requested_stream_generation
	configuration_revision = requested_configuration_revision
	return true

## Register deterministic mobile spawns in the currently loaded window without overwriting
## an existing owner-cell assignment.
## Prune records whose current owner cell is outside the runtime's retained window
## (loaded window plus its one-cell halo). A pending transaction blocks pruning.
## An empty retained set intentionally evicts every committed record.
func prune_to_retained_owner_cells(
	retained_owner_cell_keys: Array,
	expected_stream_generation: int,
	expected_configuration_revision: int
) -> Dictionary:
	if not configured:
		return _failure("ledger_not_configured")
	if not _pending_transfers.is_empty():
		return _failure("pending_transfer_exists")
	if expected_stream_generation != stream_generation or expected_configuration_revision != configuration_revision:
		return _failure("retention_snapshot_stale")
	var retained_result: Dictionary = _validate_retained_owner_cell_keys(retained_owner_cell_keys)
	if not bool(retained_result.get("ok", false)):
		return retained_result
	var retained_keys: Dictionary = retained_result.get("keys", {})
	var candidate: Dictionary = _records.duplicate(true)
	var removed_count: int = 0
	for key_value in candidate.keys():
		var key: String = str(key_value)
		var record: Dictionary = candidate[key]
		if not retained_keys.has(str(record.get("owner_cell_key", ""))):
			candidate.erase(key)
			removed_count += 1
	_records = candidate
	return {
		"ok": true,
		"removed_count": removed_count,
		"record_count": _records.size()
	}

func register_deterministic_spawns() -> Dictionary:
	if not configured:
		return _failure("ledger_not_configured")
	var candidate: Dictionary = _records.duplicate(true)
	var registered_count: int = 0
	for cell_key in _sorted_keys(_loaded_cell_keys):
		var parsed: Dictionary = parse_cell_key(cell_key)
		if not bool(parsed.get("ok", false)):
			return _failure("loaded_cell_key_invalid")
		var cell: Vector2i = parsed["cell"]
		var descriptors: Array[Dictionary] = EntityDirectorScript.get_cell_spawn_descriptors(
			level_id,
			cell,
			cell_size,
			_open_edges_for_cell(cell),
			spawn_algorithm_version
		)
		for descriptor in descriptors:
			var entity_id: String = str(descriptor.get("entity_id", ""))
			if not MOBILE_ENTITY_IDS.has(entity_id):
				continue
			var key: String = get_state_key(cell_key, entity_id)
			if candidate.has(key):
				var existing: Dictionary = candidate[key]
				if str(existing.get("spawn_cell_key", "")) != cell_key:
					return _failure("spawn_identity_collision")
				if int(existing.get("spawn_algorithm_version", 0)) != spawn_algorithm_version:
					return _failure("spawn_algorithm_version_mismatch")
				continue
			if candidate.size() >= MAX_RECORDS:
				return _failure("ownership_record_limit_exceeded")
			candidate[key] = {
				"spawn_cell_key": cell_key,
				"entity_id": entity_id,
				"owner_cell_key": cell_key,
				"spawn_algorithm_version": spawn_algorithm_version,
				"owner_revision": 0
			}
			registered_count += 1
	_records = candidate
	return {
		"ok": true,
		"registered_count": registered_count,
		"record_count": _records.size()
	}

## Prepare exactly one adjacent ownership hop along a current, validated loaded-cell route.
## The returned plan is a transaction token; it has no effect until commit_transfer succeeds.
func plan_transfer(
	spawn_cell_key: String,
	entity_id: String,
	target_owner_cell_key: String,
	route_snapshot: Dictionary
) -> Dictionary:
	if not configured:
		return _failure("ledger_not_configured")
	if not MOBILE_ENTITY_IDS.has(entity_id):
		return _failure("entity_not_mobile")
	var spawn_parse: Dictionary = parse_cell_key(spawn_cell_key)
	var target_parse: Dictionary = parse_cell_key(target_owner_cell_key)
	if not bool(spawn_parse.get("ok", false)) or not bool(target_parse.get("ok", false)):
		return _failure("transfer_cell_key_invalid")
	var key: String = get_state_key(spawn_cell_key, entity_id)
	if not _records.has(key):
		return _failure("spawn_identity_not_registered")
	if _pending_transfers.has(key):
		return _failure("transfer_already_pending")
	var record: Dictionary = _records[key]
	var current_owner: String = str(record.get("owner_cell_key", ""))
	if current_owner == target_owner_cell_key:
		return _failure("transfer_target_is_current_owner")
	if not _loaded_cell_keys.has(current_owner) or not _loaded_cell_keys.has(target_owner_cell_key):
		return _failure("transfer_cell_not_loaded")
	if not _validate_route_snapshot(route_snapshot, current_owner, target_owner_cell_key):
		return _failure("route_snapshot_invalid_or_stale")
	var plan := {
		"plan_version": PLAN_VERSION,
		"spawn_cell_key": spawn_cell_key,
		"entity_id": entity_id,
		"from_owner_cell_key": current_owner,
		"to_owner_cell_key": target_owner_cell_key,
		"owner_revision": int(record.get("owner_revision", -1)),
		"stream_generation": stream_generation,
		"configuration_revision": configuration_revision,
		"route_snapshot": route_snapshot.duplicate(true)
	}
	_pending_transfers[key] = plan.duplicate(true)
	return {"ok": true, "plan": plan}

## Commit only the exact pending plan against the same owner revision and stream generation.
func commit_transfer(plan: Dictionary) -> Dictionary:
	if not configured:
		return _failure("ledger_not_configured")
	var identity_result: Dictionary = _plan_identity(plan)
	if not bool(identity_result.get("ok", false)):
		return _failure("transfer_plan_invalid")
	var key: String = str(identity_result["key"])
	if not _pending_transfers.has(key):
		return _failure("transfer_plan_not_pending")
	var pending: Dictionary = _pending_transfers[key]
	if not _plans_match(plan, pending):
		return _failure("transfer_plan_mismatch")
	if int(plan.get("stream_generation", -1)) != stream_generation:
		return _failure("transfer_stream_generation_stale")
	if int(plan.get("configuration_revision", -1)) != configuration_revision:
		return _failure("transfer_configuration_revision_stale")
	if not _loaded_cell_keys.has(str(plan.get("to_owner_cell_key", ""))):
		return _failure("transfer_target_no_longer_loaded")
	var record: Dictionary = _records.get(key, {})
	if record.is_empty():
		return _failure("spawn_identity_not_registered")
	if str(record.get("owner_cell_key", "")) != str(plan.get("from_owner_cell_key", "")):
		return _failure("transfer_owner_changed")
	if int(record.get("owner_revision", -1)) != int(plan.get("owner_revision", -2)):
		return _failure("transfer_owner_revision_changed")
	var route_value: Variant = plan.get("route_snapshot", null)
	if not (route_value is Dictionary) or not _validate_route_snapshot(
		route_value,
		str(plan.get("from_owner_cell_key", "")),
		str(plan.get("to_owner_cell_key", ""))
	):
		return _failure("transfer_route_no_longer_valid")
	var next_revision: int = int(record.get("owner_revision", 0)) + 1
	if next_revision > MAX_OWNER_REVISION:
		return _failure("owner_revision_limit_exceeded")
	var updated: Dictionary = record.duplicate(true)
	updated["owner_cell_key"] = str(plan.get("to_owner_cell_key", ""))
	updated["owner_revision"] = next_revision
	_records[key] = updated
	_pending_transfers.erase(key)
	return {"ok": true, "record": updated.duplicate(true)}

## Cancel a prepared transfer without changing immutable identity or current ownership.
func rollback_transfer(plan: Dictionary) -> bool:
	if not configured:
		return false
	var identity_result: Dictionary = _plan_identity(plan)
	if not bool(identity_result.get("ok", false)):
		return false
	var key: String = str(identity_result["key"])
	if not _pending_transfers.has(key):
		return false
	var pending: Dictionary = _pending_transfers[key]
	if not _plans_match(plan, pending):
		return false
	_pending_transfers.erase(key)
	return true

func get_record(spawn_cell_key: String, entity_id: String) -> Dictionary:
	if not configured:
		return {}
	var value: Variant = _records.get(get_state_key(spawn_cell_key, entity_id), null)
	return value.duplicate(true) if value is Dictionary else {}

func get_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _sorted_keys(_records):
		var value: Variant = _records[key]
		if value is Dictionary:
			result.append(value.duplicate(true))
	return result

func get_pending_transfer_count() -> int:
	return _pending_transfers.size()

## Pending transfers are deliberately not serialized. Saving during a half-completed ownership
## change fails closed so a load cannot observe a transfer that was never committed.
func to_save_dict(
	retained_owner_cell_keys: Array,
	expected_stream_generation: int,
	expected_configuration_revision: int
) -> Dictionary:
	if not configured or not _pending_transfers.is_empty():
		return {}
	if expected_stream_generation != stream_generation or expected_configuration_revision != configuration_revision:
		return {}
	var retained_result: Dictionary = _validate_retained_owner_cell_keys(retained_owner_cell_keys)
	if not bool(retained_result.get("ok", false)):
		return {}
	var retained_keys: Dictionary = retained_result.get("keys", {})
	for record_value in _records.values():
		if not (record_value is Dictionary):
			return {}
		var record: Dictionary = record_value
		if not retained_keys.has(str(record.get("owner_cell_key", ""))):
			return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"level_id": level_id,
		"world_seed": world_seed,
		"cell_size": cell_size,
		"spawn_algorithm_version": spawn_algorithm_version,
		"records": get_records()
	}

func load_save_dict(
	payload: Dictionary,
	retained_owner_cell_keys: Array,
	expected_stream_generation: int,
	expected_configuration_revision: int
) -> bool:
	if not configured or not _pending_transfers.is_empty():
		return false
	if expected_stream_generation != stream_generation or expected_configuration_revision != configuration_revision:
		return false
	var retained_result: Dictionary = _validate_retained_owner_cell_keys(retained_owner_cell_keys)
	if not bool(retained_result.get("ok", false)):
		return false
	var retained_keys: Dictionary = retained_result.get("keys", {})
	var schema_result: Dictionary = _read_integer(payload.get("schema_version", null), SCHEMA_VERSION, SCHEMA_VERSION)
	var level_value: Variant = payload.get("level_id", null)
	var seed_result: Dictionary = _read_integer(payload.get("world_seed", null), 0, MAX_WORLD_SEED)
	var size_value: Variant = payload.get("cell_size", null)
	var spawn_version_result: Dictionary = _read_integer(payload.get("spawn_algorithm_version", null), 1, MAX_WORLD_SEED)
	var records_value: Variant = payload.get("records", null)
	if not bool(schema_result.get("ok", false)):
		return false
	if not (level_value is String) or str(level_value) != level_id:
		return false
	if not bool(seed_result.get("ok", false)) or int(seed_result.get("value", -1)) != world_seed:
		return false
	if not (size_value is int or size_value is float) or not is_finite(float(size_value)) or not is_equal_approx(float(size_value), cell_size):
		return false
	if not bool(spawn_version_result.get("ok", false)) or int(spawn_version_result.get("value", -1)) != spawn_algorithm_version:
		return false
	if not (records_value is Array):
		return false
	var records: Array = records_value
	if records.size() > MAX_RECORDS:
		return false
	var candidate: Dictionary = {}
	for record_value in records:
		if not (record_value is Dictionary):
			return false
		var record: Dictionary = record_value
		var spawn_key_value: Variant = record.get("spawn_cell_key", null)
		var owner_key_value: Variant = record.get("owner_cell_key", null)
		var entity_value: Variant = record.get("entity_id", null)
		var version_result: Dictionary = _read_integer(record.get("spawn_algorithm_version", null), 1, MAX_WORLD_SEED)
		var revision_result: Dictionary = _read_integer(record.get("owner_revision", null), 0, MAX_OWNER_REVISION)
		if not (spawn_key_value is String) or not (owner_key_value is String) or not (entity_value is String):
			return false
		if not MOBILE_ENTITY_IDS.has(str(entity_value)):
			return false
		if not bool(version_result.get("ok", false)) or int(version_result.get("value", -1)) != spawn_algorithm_version:
			return false
		if not bool(revision_result.get("ok", false)):
			return false
		var spawn_parse: Dictionary = parse_cell_key(str(spawn_key_value))
		var owner_parse: Dictionary = parse_cell_key(str(owner_key_value))
		if not bool(spawn_parse.get("ok", false)) or not bool(owner_parse.get("ok", false)):
			return false
		if not retained_keys.has(str(owner_key_value)):
			return false
		if not _is_deterministic_spawn(spawn_parse["cell"], str(entity_value)):
			return false
		var key: String = get_state_key(str(spawn_key_value), str(entity_value))
		if candidate.has(key):
			return false
		candidate[key] = {
			"spawn_cell_key": str(spawn_key_value),
			"entity_id": str(entity_value),
			"owner_cell_key": str(owner_key_value),
			"spawn_algorithm_version": int(version_result.get("value", spawn_algorithm_version)),
			"owner_revision": int(revision_result.get("value", 0))
		}
	_records = candidate
	_pending_transfers.clear()
	return true

static func get_state_key(spawn_cell_key: String, entity_id: String) -> String:
	if spawn_cell_key.is_empty() or entity_id.is_empty():
		return ""
	return spawn_cell_key + "|" + entity_id

static func parse_cell_key(cell_key: String) -> Dictionary:
	if cell_key.is_empty():
		return {"ok": false, "reason": "cell_key_empty"}
	var parts: PackedStringArray = cell_key.split(",", false)
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return {"ok": false, "reason": "cell_key_invalid"}
	var x_value: int = parts[0].to_int()
	var z_value: int = parts[1].to_int()
	if x_value < -LayoutScript.MAX_ABS_CELL_COORD or x_value > LayoutScript.MAX_ABS_CELL_COORD:
		return {"ok": false, "reason": "cell_key_out_of_range"}
	if z_value < -LayoutScript.MAX_ABS_CELL_COORD or z_value > LayoutScript.MAX_ABS_CELL_COORD:
		return {"ok": false, "reason": "cell_key_out_of_range"}
	if ("%d,%d" % [x_value, z_value]) != cell_key:
		return {"ok": false, "reason": "cell_key_noncanonical"}
	return {"ok": true, "cell": Vector2i(x_value, z_value)}

func _validate_route_snapshot(route: Dictionary, expected_start_key: String, expected_next_key: String) -> bool:
	var ok_value: Variant = route.get("ok", null)
	var version_value: Variant = route.get("route_snapshot_version", null)
	var level_value: Variant = route.get("level_id", null)
	var seed_value: Variant = route.get("world_seed", null)
	var layout_value: Variant = route.get("layout_algorithm_version", null)
	var generation_value: Variant = route.get("stream_generation", null)
	var revision_value: Variant = route.get("configuration_revision", null)
	var start_value: Variant = route.get("start_cell", null)
	var goal_value: Variant = route.get("goal_cell", null)
	var count_value: Variant = route.get("route_cell_count", null)
	var expanded_value: Variant = route.get("expanded_count", null)
	var loaded_count_value: Variant = route.get("loaded_cell_count", null)
	var cells_value: Variant = route.get("cell_path", null)
	var keys_value: Variant = route.get("cell_keys", null)
	var directions_value: Variant = route.get("edge_directions", null)
	if not (ok_value is bool) or not bool(ok_value):
		return false
	if not (version_value is int) or int(version_value) != RoutePlannerScript.ROUTE_SNAPSHOT_VERSION:
		return false
	if not (level_value is String) or str(level_value) != level_id:
		return false
	if not (seed_value is int) or int(seed_value) != world_seed:
		return false
	if not (layout_value is int) or int(layout_value) != LayoutScript.ALGORITHM_VERSION:
		return false
	if not (generation_value is int) or int(generation_value) != stream_generation:
		return false
	if not (revision_value is int) or int(revision_value) != configuration_revision:
		return false
	if not (start_value is Vector2i) or not (goal_value is Vector2i):
		return false
	if not (count_value is int) or not (expanded_value is int) or not (loaded_count_value is int):
		return false
	if int(loaded_count_value) != _loaded_cell_keys.size():
		return false
	if not (cells_value is Array) or not (keys_value is Array) or not (directions_value is Array):
		return false
	var cells: Array = cells_value
	var keys: Array = keys_value
	var directions: Array = directions_value
	if cells.size() < 2 or cells.size() > MAX_ROUTE_CELLS:
		return false
	if keys.size() != cells.size() or directions.size() != cells.size() - 1:
		return false
	if int(count_value) != cells.size() or int(expanded_value) < 1 or int(expanded_value) > MAX_ROUTE_CELLS:
		return false
	if start_value != cells.front() or goal_value != cells.back():
		return false
	if str(keys.front()) != expected_start_key or str(keys[1]) != expected_next_key:
		return false
	var seen: Dictionary = {}
	for index in range(cells.size()):
		var cell_value: Variant = cells[index]
		if not (cell_value is Vector2i):
			return false
		var cell: Vector2i = cell_value
		var canonical_key: String = "%d,%d" % [cell.x, cell.y]
		if not (keys[index] is String) or str(keys[index]) != canonical_key:
			return false
		if seen.has(canonical_key) or not _loaded_cell_keys.has(canonical_key):
			return false
		seen[canonical_key] = true
		if index + 1 >= cells.size():
			continue
		var next_value: Variant = cells[index + 1]
		var direction_value: Variant = directions[index]
		if not (next_value is Vector2i) or not (direction_value is Vector2i):
			return false
		var next_cell: Vector2i = next_value
		var direction: Vector2i = direction_value
		if absi(direction.x) + absi(direction.y) != 1 or next_cell - cell != direction:
			return false
		if not LayoutScript.edge_is_open(cell, direction, world_seed):
			return false
		if not LayoutScript.edge_is_open(next_cell, -direction, world_seed):
			return false
	return true

func _is_deterministic_spawn(spawn_cell: Vector2i, entity_id: String) -> bool:
	if not MOBILE_ENTITY_IDS.has(entity_id):
		return false
	var descriptors: Array[Dictionary] = EntityDirectorScript.get_cell_spawn_descriptors(
		level_id,
		spawn_cell,
		cell_size,
		_open_edges_for_cell(spawn_cell),
		spawn_algorithm_version
	)
	for descriptor in descriptors:
		if str(descriptor.get("entity_id", "")) == entity_id:
			return true
	return false

func _open_edges_for_cell(cell: Vector2i) -> Dictionary:
	return {
		"north": LayoutScript.edge_is_open(cell, Vector2i(0, -1), world_seed),
		"east": LayoutScript.edge_is_open(cell, Vector2i(1, 0), world_seed),
		"south": LayoutScript.edge_is_open(cell, Vector2i(0, 1), world_seed),
		"west": LayoutScript.edge_is_open(cell, Vector2i(-1, 0), world_seed)
	}

func _validate_retained_owner_cell_keys(keys: Array) -> Dictionary:
	var parsed_result: Dictionary = _parse_cell_key_set(keys, MAX_RETAINED_OWNER_CELLS)
	if not bool(parsed_result.get("ok", false)):
		return _failure("retained_owner_cell_keys_invalid")
	var retained_keys: Dictionary = parsed_result.get("keys", {})
	var loaded_cells: Array[Vector2i] = []
	for loaded_key_value in _loaded_cell_keys.keys():
		var loaded_key: String = str(loaded_key_value)
		if not retained_keys.has(loaded_key):
			return _failure("retained_window_missing_loaded_cell")
		var loaded_parse: Dictionary = parse_cell_key(loaded_key)
		if not bool(loaded_parse.get("ok", false)):
			return _failure("loaded_cell_key_invalid")
		var loaded_cell: Vector2i = loaded_parse["cell"]
		loaded_cells.append(loaded_cell)
	for retained_key_value in retained_keys.keys():
		var retained_parse: Dictionary = parse_cell_key(str(retained_key_value))
		if not bool(retained_parse.get("ok", false)):
			return _failure("retained_owner_cell_key_invalid")
		var retained_cell: Vector2i = retained_parse["cell"]
		var within_one_cell_halo: bool = false
		for loaded_cell in loaded_cells:
			if abs(retained_cell.x - loaded_cell.x) <= 1 and abs(retained_cell.y - loaded_cell.y) <= 1:
				within_one_cell_halo = true
				break
		if not within_one_cell_halo:
			return _failure("retained_owner_cell_outside_one_cell_halo")
	return {"ok": true, "keys": retained_keys}

func _parse_loaded_cell_keys(keys: Array) -> Dictionary:
	return _parse_cell_key_set(keys, MAX_ROUTE_CELLS)

func _parse_cell_key_set(keys: Array, maximum_count: int) -> Dictionary:
	if maximum_count < 1 or keys.is_empty() or keys.size() > maximum_count:
		return {"ok": false, "reason": "cell_key_count_invalid"}
	var result: Dictionary = {}
	for key_value in keys:
		if not (key_value is String):
			return {"ok": false, "reason": "cell_key_invalid"}
		var key: String = str(key_value)
		if not bool(parse_cell_key(key).get("ok", false)) or result.has(key):
			return {"ok": false, "reason": "cell_key_duplicate_or_invalid"}
		result[key] = true
	return {"ok": true, "keys": result}

func _plan_identity(plan: Dictionary) -> Dictionary:
	var spawn_value: Variant = plan.get("spawn_cell_key", null)
	var entity_value: Variant = plan.get("entity_id", null)
	var version_value: Variant = plan.get("plan_version", null)
	if not (spawn_value is String) or not (entity_value is String) or not (version_value is int):
		return {"ok": false}
	if int(version_value) != PLAN_VERSION or not MOBILE_ENTITY_IDS.has(str(entity_value)):
		return {"ok": false}
	if not bool(parse_cell_key(str(spawn_value)).get("ok", false)):
		return {"ok": false}
	return {"ok": true, "key": get_state_key(str(spawn_value), str(entity_value))}

func _plans_match(left: Dictionary, right: Dictionary) -> bool:
	var fields: Array[String] = [
		"plan_version",
		"spawn_cell_key",
		"entity_id",
		"from_owner_cell_key",
		"to_owner_cell_key",
		"owner_revision",
		"stream_generation",
		"configuration_revision"
	]
	for field in fields:
		if left.get(field, null) != right.get(field, null):
			return false
	var left_route: Variant = left.get("route_snapshot", null)
	var right_route: Variant = right.get("route_snapshot", null)
	return left_route is Dictionary and right_route is Dictionary and left_route == right_route

func _sorted_keys(dictionary: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_value in dictionary.keys():
		result.append(str(key_value))
	result.sort()
	return result

static func _read_integer(value: Variant, minimum: int, maximum: int) -> Dictionary:
	var parsed: int
	if value is int:
		parsed = int(value)
	elif value is float:
		var numeric: float = float(value)
		if not is_finite(numeric) or floor(numeric) != numeric:
			return {"ok": false}
		# Check bounds before int() so huge finite floats cannot overflow conversion.
		if numeric < float(minimum) or numeric > float(maximum):
			return {"ok": false}
		parsed = int(numeric)
	else:
		return {"ok": false}
	if parsed < minimum or parsed > maximum:
		return {"ok": false}
	return {"ok": true, "value": parsed}

func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

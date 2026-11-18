extends RefCounted
class_name BackroomsEntityRuntimeState
## Bounded, validated persistence for mobile entities owned by streamed maze cells.
## Runtime state is cached in a one-cell halo around the loaded window.
const BrainScript = preload("res://systems/BackroomsEntityBrain.gd")
const EntityDirectorScript = preload("res://systems/BackroomsEntityDirector.gd")
const LayoutScript = preload("res://systems/BackroomsMazeLayout.gd")
const STATE_VERSION: int = 1
const MAX_RECORDS: int = 4096
const SAFE_CELL_MARGIN: float = 0.65
const MIN_LOCAL_Y: float = -0.25
const MAX_LOCAL_Y: float = 3.0
const MOBILE_ENTITY_IDS := ["smiler", "hound", "skin_stealer", "faceling", "duller", "deathmoth"]

static func get_state_key(record: Dictionary) -> String:
	return str(record.get("cell_key", "")) + "|" + str(record.get("entity_id", ""))

static func parse_cell_key(cell_key: String) -> Dictionary:
	if cell_key.is_empty():
		return {"ok": false, "reason": "cell_key_empty"}
	var parts: PackedStringArray = cell_key.split(",", false)
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return {"ok": false, "reason": "cell_key_invalid"}
	var cell := Vector2i(parts[0].to_int(), parts[1].to_int())
	if absi(cell.x) > LayoutScript.MAX_ABS_CELL_COORD or absi(cell.y) > LayoutScript.MAX_ABS_CELL_COORD or ("%d,%d" % [cell.x, cell.y]) != cell_key:
		return {"ok": false, "reason": "cell_key_out_of_range_or_noncanonical"}
	return {"ok": true, "cell": cell}

static func capture_cell_states(cell_root: Node3D) -> Dictionary:
	if cell_root == null or not is_instance_valid(cell_root):
		return {"ok": false, "reason": "cell_root_unavailable"}
	var cell_key: String = str(cell_root.get_meta("backrooms_cell_key", ""))
	var cell_parse: Dictionary = parse_cell_key(cell_key)
	if not bool(cell_parse.get("ok", false)):
		return {"ok": false, "reason": "cell_identity_invalid"}
	var cell: Vector2i = cell_parse["cell"]
	var cell_meta: Variant = cell_root.get_meta("backrooms_cell", null)
	var world_seed: int = int(cell_root.get_meta("backrooms_world_seed", -1))
	var spawn_version: int = int(cell_root.get_meta("backrooms_entity_spawn_algorithm_version", 0))
	if not (cell_meta is Vector2i) or cell_meta != cell or world_seed < 0:
		return {"ok": false, "reason": "cell_metadata_mismatch"}
	if not EntityDirectorScript.is_spawn_algorithm_version_supported(spawn_version):
		return {"ok": false, "reason": "spawn_algorithm_version_unsupported"}
	var records: Array[Dictionary] = []
	for child in cell_root.get_children():
		if not (child is CharacterBody3D) or not child.has_meta("backrooms_entity_id"):
			continue
		var entity_root: CharacterBody3D = child as CharacterBody3D
		var entity_id: String = str(entity_root.get_meta("backrooms_entity_id", ""))
		if not MOBILE_ENTITY_IDS.has(entity_id):
			continue
		var brain: Node = entity_root.get_node_or_null("AI")
		if brain == null or not brain.has_method("to_save_dict"):
			return {"ok": false, "reason": "entity_brain_save_contract_unavailable"}
		var brain_state_value: Variant = brain.call("to_save_dict")
		if not (brain_state_value is Dictionary):
			return {"ok": false, "reason": "entity_brain_snapshot_invalid"}
		var local_position: Vector3 = entity_root.position
		if not _is_finite_vector3(local_position):
			return {"ok": false, "reason": "entity_position_invalid"}
		var patrol_index: int = int(entity_root.get_meta("backrooms_patrol_index", _initial_patrol_index(cell, world_seed)))
		records.append({
			"cell_key": cell_key,
			"entity_id": entity_id,
			"spawn_algorithm_version": spawn_version,
			"position": _vector_to_array(local_position),
			"brain_state": brain_state_value.duplicate(true),
			"patrol_index": patrol_index
		})
	return {"ok": true, "records": records}

static func validate_records(records: Array, level_id: String, world_seed: int, cell_size: float, spawn_algorithm_version: int) -> Dictionary:
	if records.size() > MAX_RECORDS:
		return {"ok": false, "reason": "entity_runtime_state_limit_exceeded"}
	if not EntityDirectorScript.is_spawn_algorithm_version_supported(spawn_algorithm_version):
		return {"ok": false, "reason": "spawn_algorithm_version_unsupported"}
	if not is_finite(cell_size) or cell_size <= SAFE_CELL_MARGIN * 2.0:
		return {"ok": false, "reason": "cell_size_invalid"}
	var seen: Dictionary = {}
	var normalized: Array[Dictionary] = []
	for raw_value in records:
		if not (raw_value is Dictionary):
			return {"ok": false, "reason": "entity_runtime_record_invalid"}
		var raw: Dictionary = raw_value
		var cell_key_value: Variant = raw.get("cell_key", null)
		var entity_id_value: Variant = raw.get("entity_id", null)
		if not (cell_key_value is String) or not (entity_id_value is String):
			return {"ok": false, "reason": "entity_runtime_identity_invalid"}
		var cell_key: String = str(cell_key_value)
		var cell_parse: Dictionary = parse_cell_key(cell_key)
		if not bool(cell_parse.get("ok", false)):
			return {"ok": false, "reason": "entity_runtime_cell_invalid"}
		var cell: Vector2i = cell_parse["cell"]
		var entity_id: String = str(entity_id_value)
		if not MOBILE_ENTITY_IDS.has(entity_id):
			return {"ok": false, "reason": "entity_runtime_entity_not_mobile"}
		var key: String = cell_key + "|" + entity_id
		if seen.has(key):
			return {"ok": false, "reason": "entity_runtime_duplicate"}
		seen[key] = true
		var record_spawn_version: Variant = raw.get("spawn_algorithm_version", null)
		if not _is_integer_value(record_spawn_version) or int(record_spawn_version) != spawn_algorithm_version:
			return {"ok": false, "reason": "entity_runtime_spawn_version_mismatch"}
		var open_edges := {
			"north": LayoutScript.edge_is_open(cell, Vector2i(0, -1), world_seed),
			"east": LayoutScript.edge_is_open(cell, Vector2i(1, 0), world_seed),
			"south": LayoutScript.edge_is_open(cell, Vector2i(0, 1), world_seed),
			"west": LayoutScript.edge_is_open(cell, Vector2i(-1, 0), world_seed)
		}
		var spawn_descriptors: Array[Dictionary] = EntityDirectorScript.get_cell_spawn_descriptors(level_id, cell, cell_size, open_edges, spawn_algorithm_version)
		var spawn_exists: bool = false
		for descriptor in spawn_descriptors:
			if str(descriptor.get("entity_id", "")) == entity_id:
				spawn_exists = true
				break
		if not spawn_exists:
			return {"ok": false, "reason": "entity_runtime_spawn_not_in_deterministic_cell"}
		var position_result: Dictionary = _parse_vector3(raw.get("position", null))
		if not bool(position_result.get("ok", false)):
			return {"ok": false, "reason": "entity_runtime_position_invalid"}
		var local_position: Vector3 = position_result["value"]
		var half_extent: float = cell_size * 0.5 - SAFE_CELL_MARGIN
		if absf(local_position.x) > half_extent or absf(local_position.z) > half_extent or local_position.y < MIN_LOCAL_Y or local_position.y > MAX_LOCAL_Y:
			return {"ok": false, "reason": "entity_runtime_position_out_of_bounds"}
		var brain_value: Variant = raw.get("brain_state", null)
		if not (brain_value is Dictionary) or not BrainScript.validate_save_dict(brain_value, entity_id, level_id, cell, world_seed):
			return {"ok": false, "reason": "entity_runtime_brain_state_invalid"}
		var patrol_value: Variant = raw.get("patrol_index", null)
		if not _is_integer_value(patrol_value) or int(patrol_value) < 0 or int(patrol_value) > 3:
			return {"ok": false, "reason": "entity_runtime_patrol_index_invalid"}
		normalized.append({
			"cell_key": cell_key,
			"entity_id": entity_id,
			"spawn_algorithm_version": spawn_algorithm_version,
			"position": _vector_to_array(local_position),
			"brain_state": brain_value.duplicate(true),
			"patrol_index": int(patrol_value)
		})
	normalized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return get_state_key(left) < get_state_key(right))
	return {"ok": true, "records": normalized}

static func restore_entity_state(cell_root: Node3D, entity_root: CharacterBody3D, record: Dictionary) -> bool:
	if cell_root == null or not is_instance_valid(cell_root) or entity_root == null or not is_instance_valid(entity_root):
		return false
	var cell_key: String = str(cell_root.get_meta("backrooms_cell_key", ""))
	if cell_key != str(record.get("cell_key", "")):
		return false
	var entity_id: String = str(record.get("entity_id", ""))
	if entity_id != str(entity_root.get_meta("backrooms_entity_id", "")):
		return false
	var cell_parse: Dictionary = parse_cell_key(cell_key)
	if not bool(cell_parse.get("ok", false)) or entity_root.get_meta("spawn_cell", null) != cell_parse["cell"]:
		return false
	var position_result: Dictionary = _parse_vector3(record.get("position", null))
	if not bool(position_result.get("ok", false)):
		return false
	var brain: Node = entity_root.get_node_or_null("AI")
	if brain == null or not brain.has_method("load_save_dict"):
		return false
	var brain_state: Variant = record.get("brain_state", null)
	if not (brain_state is Dictionary) or not bool(brain.call("load_save_dict", brain_state)):
		return false
	entity_root.position = position_result["value"]
	entity_root.set_meta("backrooms_patrol_index", int(record.get("patrol_index", 0)))
	return true

static func _initial_patrol_index(cell: Vector2i, world_seed: int) -> int:
	var value: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ world_seed
	return posmod(value, 4)

static func _vector_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _parse_vector3(value: Variant) -> Dictionary:
	if not (value is Array) or value.size() != 3:
		return {"ok": false}
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)):
			return {"ok": false}
	return {"ok": true, "value": Vector3(float(value[0]), float(value[1]), float(value[2]))}

static func _is_integer_value(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var number: float = float(value)
		return is_finite(number) and floorf(number) == number
	return false

static func _is_finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

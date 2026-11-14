extends RefCounted
class_name BackroomsEntityDirector

## Level-scoped entity whitelist and deterministic cell spawn selection.
const SPAWN_ALGORITHM_VERSION: int = 1

const LEVEL_ENTITY_RULES := {
	"Level 0": [],
	"Level 1": ["window", "smiler"],
	"Level 2": ["hound", "skin_stealer"],
	"Level 3": ["clump", "faceling"],
	"Level 4": ["duller"],
	"Level 5": ["deathmoth"]
}

const ENTITY_CHANCES := {
	"window": 18,
	"smiler": 7,
	"hound": 8,
	"skin_stealer": 5,
	"clump": 6,
	"faceling": 8,
	"duller": 6,
	"deathmoth": 4
}

const ENTITY_POSITION_SALTS := {
	"smiler": [910, 911],
	"hound": [1524, 1525],
	"skin_stealer": [2033, 2034],
	"clump": [2710, 2711],
	"faceling": [3184, 3185],
	"duller": [3652, 3653],
	"deathmoth": [4188, 4189]
}

static func is_spawn_algorithm_version_supported(version: int) -> bool:
	return version == SPAWN_ALGORITHM_VERSION

static func get_allowed_entities(level_name: String) -> Array[String]:
	var result: Array[String] = []
	var configured: Variant = LEVEL_ENTITY_RULES.get(level_name, [])
	if configured is Array:
		for entity_id in configured:
			result.append(str(entity_id))
	return result

static func get_cell_spawns(level_name: String, cell: Vector2i) -> Array[String]:
	var result: Array[String] = []
	var allowed := get_allowed_entities(level_name)
	for entity_id in allowed:
		var chance := int(ENTITY_CHANCES.get(entity_id, 0))
		if chance <= 0:
			continue
		if posmod(_stable_hash(cell.x, cell.y, _entity_salt(entity_id)), 100) < chance:
			result.append(entity_id)
	return result

## Build renderer-independent spawn descriptors for one production maze cell.
## Window is only emitted when this cell owns a closed north or west boundary.
static func get_cell_spawn_descriptors(
	level_name: String,
	cell: Vector2i,
	cell_size: float,
	open_edges: Dictionary,
	spawn_algorithm_version: int = SPAWN_ALGORITHM_VERSION
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_spawn_algorithm_version_supported(spawn_algorithm_version):
		return result
	if not is_finite(cell_size) or cell_size <= 0.0:
		return result
	var allowed := get_allowed_entities(level_name)
	for entity_id in get_cell_spawns(level_name, cell):
		if not allowed.has(entity_id):
			continue
		var placement: Dictionary = _get_spawn_placement(entity_id, cell, cell_size, open_edges)
		if not bool(placement.get("ok", false)):
			continue
		result.append({
			"entity_id": entity_id,
			"cell": cell,
			"local_position": placement.get("local_position", Vector3.ZERO),
			"wall_direction": placement.get("wall_direction", Vector2i.ZERO),
			"spawn_algorithm_version": spawn_algorithm_version
		})
	return result

static func _get_spawn_placement(
	entity_id: String,
	cell: Vector2i,
	cell_size: float,
	open_edges: Dictionary
) -> Dictionary:
	if entity_id == "window":
		var wall_direction := _owned_closed_wall_direction(open_edges)
		if wall_direction == Vector2i.ZERO:
			return {"ok": false, "reason": "no_owned_closed_wall"}
		var half: float = cell_size * 0.5
		var wall_inset: float = 0.09
		var window_position := Vector3(0.0, 1.2, -half + wall_inset)
		if wall_direction == Vector2i(-1, 0):
			window_position = Vector3(-half + wall_inset, 1.2, 0.0)
		return {
			"ok": true,
			"local_position": window_position,
			"wall_direction": wall_direction
		}

	var salts_value: Variant = ENTITY_POSITION_SALTS.get(entity_id, null)
	if not (salts_value is Array) or salts_value.size() != 2:
		return {"ok": false, "reason": "entity_position_salt_missing"}
	var spread: float = minf(cell_size * 0.08, 0.64)
	var offset_x: float = float(posmod(_stable_hash(cell.x, cell.y, int(salts_value[0])), 5) - 2) * spread
	var offset_z: float = float(posmod(_stable_hash(cell.x, cell.y, int(salts_value[1])), 5) - 2) * spread
	var height: float = 0.0
	match entity_id:
		"smiler":
			height = 1.75
		"hound":
			height = 0.55
		"clump":
			height = 0.42
		"deathmoth":
			height = 1.55
	return {
		"ok": true,
		"local_position": Vector3(offset_x, height, offset_z),
		"wall_direction": Vector2i.ZERO
	}

static func _owned_closed_wall_direction(open_edges: Dictionary) -> Vector2i:
	if not bool(open_edges.get("north", true)):
		return Vector2i(0, -1)
	if not bool(open_edges.get("west", true)):
		return Vector2i(-1, 0)
	return Vector2i.ZERO

static func _entity_salt(entity_id: String) -> int:
	match entity_id:
		"window":
			return 4103
		"smiler":
			return 9127
		"hound":
			return 15241
		"skin_stealer":
			return 20333
		"clump":
			return 27103
		"faceling":
			return 31847
		"duller":
			return 36529
		"deathmoth":
			return 41887
	return 0

static func _stable_hash(x: int, y: int, salt: int) -> int:
	var value: int = posmod(x * 73856093 ^ y * 19349663 ^ salt * 83492791, 2147483647)
	value = value ^ (value >> 13)
	value = value * 1274126177
	value = value ^ (value >> 16)
	return absi(value)

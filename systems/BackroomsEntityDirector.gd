extends RefCounted
class_name BackroomsEntityDirector

## Level-scoped entity whitelist and deterministic cell spawn selection.
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

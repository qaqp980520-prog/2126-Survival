extends RefCounted
class_name BackroomsPortalDirector

const SAVE_SCHEMA_VERSION: int = 1
const MIN_SPAWN_INTERVAL: float = 45.0
const MAX_SPAWN_INTERVAL: float = 75.0
const RETRY_INTERVAL: float = 5.0
const MAX_PORTAL_SERIAL: int = 1000000000
const TARGET_LEVELS: Array[String] = ["Level 0", "Level 1", "Level 2", "Level 3"]
const SPAWN_PADDING: float = 16.0

var _rng: RandomNumberGenerator
var world_bounds: Rect2
var min_player_distance: float
var next_spawn_in: float = 0.0
var portal_serial: int = 0
var active_portal: Dictionary = {}

func _init(seed_value: int = -1, bounds: Rect2 = Rect2(-500.0, -500.0, 1000.0, 1000.0), safe_distance: float = 24.0) -> void:
    _rng = RandomNumberGenerator.new()
    if seed_value >= 0:
        _rng.seed = seed_value
    else:
        _rng.randomize()
    world_bounds = bounds
    min_player_distance = maxf(0.0, safe_distance)
    _schedule_next_spawn()

func tick(delta: float, player_position: Vector2) -> Dictionary:
    if not is_finite(delta) or delta <= 0.0 or not active_portal.is_empty():
        return {"event": "none"}
    next_spawn_in = maxf(0.0, next_spawn_in - delta)
    if next_spawn_in > 0.0:
        return {"event": "none"}
    var candidate: Dictionary = _find_spawn_position(player_position)
    if not bool(candidate.get("ok", false)):
        next_spawn_in = RETRY_INTERVAL
        return {"event": "retry", "retry_in": next_spawn_in}
    portal_serial += 1
    active_portal = {"id": portal_serial, "position": candidate["position"]}
    return {"event": "spawned", "portal": active_portal.duplicate(true)}

func consume_portal(portal_id: int) -> Dictionary:
    if active_portal.is_empty() or portal_id <= 0 or int(active_portal.get("id", -1)) != portal_id:
        return {"ok": false, "reason": "portal_not_active"}
    var destination: String = TARGET_LEVELS[_rng.randi_range(0, TARGET_LEVELS.size() - 1)]
    var position: Vector2 = active_portal["position"]
    active_portal.clear()
    _schedule_next_spawn()
    return {"ok": true, "event": "entered", "portal_id": portal_id, "position": position, "destination_level": destination}

func to_save_dict() -> Dictionary:
    var portal_payload: Dictionary = {}
    if not active_portal.is_empty():
        var position: Vector2 = active_portal["position"]
        portal_payload = {"id": int(active_portal["id"]), "position": [position.x, position.y]}
    return {
        "schema_version": SAVE_SCHEMA_VERSION,
        "next_spawn_in": next_spawn_in,
        "portal_serial": portal_serial,
        "active_portal": portal_payload
    }

func load_save_dict(data: Dictionary) -> bool:
    # Validate everything into locals first. A bad save must not partially mutate live state.
    var schema: Variant = data.get("schema_version", null)
    if not _is_integer_in_range(schema, SAVE_SCHEMA_VERSION, SAVE_SCHEMA_VERSION):
        return false
    var countdown: Variant = data.get("next_spawn_in", null)
    if not _is_finite_number_in_range(countdown, 0.0, MAX_SPAWN_INTERVAL):
        return false
    var saved_serial: Variant = data.get("portal_serial", null)
    if not _is_integer_in_range(saved_serial, 0, MAX_PORTAL_SERIAL):
        return false
    var saved_portal: Variant = data.get("active_portal", null)
    if not (saved_portal is Dictionary):
        return false
    var restored_portal: Dictionary = {}
    if not saved_portal.is_empty():
        var saved_id: Variant = saved_portal.get("id", null)
        if not _is_integer_in_range(saved_id, 1, int(saved_serial)):
            return false
        var saved_position: Variant = saved_portal.get("position", null)
        if not (saved_position is Array) or saved_position.size() != 2:
            return false
        if not _is_finite_number_in_range(saved_position[0], -1.0e12, 1.0e12) or not _is_finite_number_in_range(saved_position[1], -1.0e12, 1.0e12):
            return false
        var point := Vector2(float(saved_position[0]), float(saved_position[1]))
        if not world_bounds.has_point(point):
            return false
        restored_portal = {"id": int(saved_id), "position": point}
    next_spawn_in = float(countdown)
    portal_serial = int(saved_serial)
    active_portal = restored_portal
    return true

func _schedule_next_spawn() -> void:
    next_spawn_in = _rng.randf_range(MIN_SPAWN_INTERVAL, MAX_SPAWN_INTERVAL)

func _find_spawn_position(player_position: Vector2) -> Dictionary:
    if world_bounds.size.x <= SPAWN_PADDING * 2.0 or world_bounds.size.y <= SPAWN_PADDING * 2.0:
        return {"ok": false}
    var left: float = world_bounds.position.x + SPAWN_PADDING
    var top: float = world_bounds.position.y + SPAWN_PADDING
    var right: float = world_bounds.end.x - SPAWN_PADDING
    var bottom: float = world_bounds.end.y - SPAWN_PADDING
    for attempt in range(64):
        var point := Vector2(_rng.randf_range(left, right), _rng.randf_range(top, bottom))
        if point.distance_to(player_position) >= min_player_distance:
            return {"ok": true, "position": point}
    return {"ok": false}

func _is_integer_in_range(value: Variant, minimum: int, maximum: int) -> bool:
    if not (value is int or value is float):
        return false
    var number := float(value)
    return is_finite(number) and number >= float(minimum) and number <= float(maximum) and floorf(number) == number

func _is_finite_number_in_range(value: Variant, minimum: float, maximum: float) -> bool:
    if not (value is int or value is float):
        return false
    var number := float(value)
    return is_finite(number) and number >= minimum and number <= maximum

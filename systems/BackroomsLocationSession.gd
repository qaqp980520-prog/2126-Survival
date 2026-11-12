extends RefCounted
class_name BackroomsLocationSession

## Transactional state for a single SurfaceWorld -> Backrooms visit.
## The session is deliberately separate from scene ownership: SurfaceWorld commits
## the transition only after its Backrooms runtime has been created successfully.

const PortalDirectorScript = preload("res://systems/BackroomsPortalDirector.gd")
const SAVE_SCHEMA_VERSION: int = 1
const MAX_WORLD_SEED: int = 2147483647

var active: bool = false
var level_id: String = ""
var entry_portal_id: int = 0
var surface_return_position: Vector3 = Vector3.ZERO
var backrooms_position: Vector3 = Vector3.ZERO
var surface_world_seed: int = 0
var backrooms_seed: int = 0

func can_begin_transition(
	destination_level: String,
	portal_id: int,
	return_position: Vector3,
	source_world_seed: int,
	entry_position: Vector3 = Vector3.ZERO
) -> bool:
	if active:
		return false
	if not PortalDirectorScript.TARGET_LEVELS.has(destination_level):
		return false
	if portal_id < 1 or portal_id > PortalDirectorScript.MAX_PORTAL_SERIAL:
		return false
	if not _is_finite_vector3(return_position) or not _is_finite_vector3(entry_position):
		return false
	if source_world_seed < 0 or source_world_seed > MAX_WORLD_SEED:
		return false
	return true

func begin_transition(
	destination_level: String,
	portal_id: int,
	return_position: Vector3,
	source_world_seed: int,
	entry_position: Vector3 = Vector3.ZERO
) -> bool:
	if not can_begin_transition(destination_level, portal_id, return_position, source_world_seed, entry_position):
		return false
	active = true
	level_id = destination_level
	entry_portal_id = portal_id
	surface_return_position = return_position
	backrooms_position = entry_position
	surface_world_seed = source_world_seed
	backrooms_seed = _derive_backrooms_seed(source_world_seed, portal_id)
	return true

func can_begin_from_portal_result(
	portal_result: Dictionary,
	return_position: Vector3,
	source_world_seed: int,
	entry_position: Vector3 = Vector3.ZERO
) -> bool:
	if not bool(portal_result.get("ok", false)):
		return false
	if not ["prepared", "entered"].has(str(portal_result.get("event", ""))):
		return false
	var destination_value: Variant = portal_result.get("destination_level", null)
	var portal_id_value: Variant = portal_result.get("portal_id", null)
	if not (destination_value is String) or not (portal_id_value is int):
		return false
	return can_begin_transition(
		str(destination_value),
		int(portal_id_value),
		return_position,
		source_world_seed,
		entry_position
	)

func begin_from_portal_result(
	portal_result: Dictionary,
	return_position: Vector3,
	source_world_seed: int,
	entry_position: Vector3 = Vector3.ZERO
) -> bool:
	if str(portal_result.get("event", "")) != "entered":
		return false
	if not can_begin_from_portal_result(portal_result, return_position, source_world_seed, entry_position):
		return false
	return begin_transition(
		str(portal_result["destination_level"]),
		int(portal_result["portal_id"]),
		return_position,
		source_world_seed,
		entry_position
	)

func set_backrooms_position(position: Vector3) -> bool:
	if not active or not _is_finite_vector3(position):
		return false
	backrooms_position = position
	return true

func get_return_context() -> Dictionary:
	if not active:
		return {}
	return {
		"surface_return_position": surface_return_position,
		"surface_world_seed": surface_world_seed,
		"entry_portal_id": entry_portal_id
	}

## Call only after the surface world has been restored successfully.
## Until this method is called, the original return context remains available.
func complete_return() -> Dictionary:
	if not active:
		return {"ok": false, "reason": "session_not_active"}
	var result: Dictionary = get_return_context()
	result["ok"] = true
	_reset()
	return result

func get_current_level() -> String:
	return level_id if active else "Surface"

func is_active() -> bool:
	return active

func to_save_dict() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"active": active,
		"level_id": level_id,
		"entry_portal_id": entry_portal_id,
		"surface_return_position": _vector_to_array(surface_return_position),
		"backrooms_position": _vector_to_array(backrooms_position),
		"surface_world_seed": surface_world_seed,
		"backrooms_seed": backrooms_seed
	}

## Validate the complete candidate into locals before changing any live field.
## Inactive saves use one canonical empty representation to reject stale/tampered data.
func load_save_dict(payload: Dictionary) -> bool:
	var schema_value: Variant = payload.get("schema_version", null)
	var active_value: Variant = payload.get("active", null)
	var level_value: Variant = payload.get("level_id", null)
	var portal_id_value: Variant = payload.get("entry_portal_id", null)
	var source_seed_value: Variant = payload.get("surface_world_seed", null)
	var backrooms_seed_value: Variant = payload.get("backrooms_seed", null)
	if not _is_integer_in_range(schema_value, SAVE_SCHEMA_VERSION, SAVE_SCHEMA_VERSION):
		return false
	if not (active_value is bool) or not (level_value is String):
		return false
	if not _is_integer_in_range(portal_id_value, 0, PortalDirectorScript.MAX_PORTAL_SERIAL):
		return false
	if not _is_integer_in_range(source_seed_value, 0, MAX_WORLD_SEED):
		return false
	if not _is_integer_in_range(backrooms_seed_value, 0, MAX_WORLD_SEED):
		return false
	var return_parse: Dictionary = _parse_vector3(payload.get("surface_return_position", null))
	var player_parse: Dictionary = _parse_vector3(payload.get("backrooms_position", null))
	if not bool(return_parse.get("ok", false)) or not bool(player_parse.get("ok", false)):
		return false
	var next_active: bool = bool(active_value)
	var next_level: String = str(level_value)
	var next_portal_id: int = int(portal_id_value)
	var next_return_position: Vector3 = return_parse["value"]
	var next_player_position: Vector3 = player_parse["value"]
	var next_source_seed: int = int(source_seed_value)
	var next_backrooms_seed: int = int(backrooms_seed_value)
	if next_active:
		if not PortalDirectorScript.TARGET_LEVELS.has(next_level):
			return false
		if next_portal_id < 1:
			return false
		if next_backrooms_seed != _derive_backrooms_seed(next_source_seed, next_portal_id):
			return false
	else:
		if next_level != "" or next_portal_id != 0:
			return false
		if next_return_position != Vector3.ZERO or next_player_position != Vector3.ZERO:
			return false
		if next_source_seed != 0 or next_backrooms_seed != 0:
			return false
	active = next_active
	level_id = next_level
	entry_portal_id = next_portal_id
	surface_return_position = next_return_position
	backrooms_position = next_player_position
	surface_world_seed = next_source_seed
	backrooms_seed = next_backrooms_seed
	return true

func _reset() -> void:
	active = false
	level_id = ""
	entry_portal_id = 0
	surface_return_position = Vector3.ZERO
	backrooms_position = Vector3.ZERO
	surface_world_seed = 0
	backrooms_seed = 0

func _derive_backrooms_seed(source_seed: int, portal_id: int) -> int:
	# All products remain inside signed 64-bit range for the validated inputs.
	var mixed: int = source_seed * 1103515245 + portal_id * 12345 + 1013904223
	return posmod(mixed, MAX_WORLD_SEED + 1)

func _is_finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _vector_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _parse_vector3(value: Variant) -> Dictionary:
	if not (value is Array) or value.size() != 3:
		return {"ok": false}
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)):
			return {"ok": false}
	return {
		"ok": true,
		"value": Vector3(float(value[0]), float(value[1]), float(value[2]))
	}

func _is_integer_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int):
		return false
	return int(value) >= minimum and int(value) <= maximum

extends RefCounted
class_name BackroomsLightingController

## Transactional WorldEnvironment override for the active Backrooms destination.
const ProfileScript = preload("res://systems/BackroomsLightingProfile.gd")

var _active: bool = false
var _level_id: String = ""
var _world_environment: WorldEnvironment
var _surface_environment: Environment
var _backrooms_environment: Environment
var _sun: DirectionalLight3D
var _surface_sun_energy: float = 1.0
var _surface_sun_visible: bool = true

func enter_backrooms(
	world_environment: WorldEnvironment,
	sun: DirectionalLight3D,
	level_id: String
) -> Dictionary:
	if _active:
		if _level_id == level_id:
			return {"ok": true, "event": "already_active", "level_id": _level_id}
		return _failure("lighting_already_active_for_another_level")
	if (
		world_environment == null
		or not is_instance_valid(world_environment)
		or world_environment.environment == null
		or sun == null
		or not is_instance_valid(sun)
	):
		return _failure("surface_lighting_nodes_unavailable")
	var profile: Dictionary = ProfileScript.get_level_profile(level_id)
	if profile.is_empty():
		return _failure("backrooms_lighting_level_unsupported")
	var backrooms_environment_value: Resource = world_environment.environment.duplicate(true)
	if not (backrooms_environment_value is Environment):
		return _failure("backrooms_environment_clone_failed")
	var backrooms_environment: Environment = backrooms_environment_value as Environment
	backrooms_environment.background_mode = Environment.BG_COLOR
	backrooms_environment.background_color = profile.get("background_color", Color.BLACK)
	backrooms_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	backrooms_environment.ambient_light_color = profile.get("ambient_color", Color.WHITE)
	backrooms_environment.ambient_light_energy = float(profile.get("ambient_energy", 0.0))
	backrooms_environment.tonemap_exposure = float(profile.get("tonemap_exposure", 1.0))

	_world_environment = world_environment
	_surface_environment = world_environment.environment
	_backrooms_environment = backrooms_environment
	_sun = sun
	_surface_sun_energy = sun.light_energy
	_surface_sun_visible = sun.visible
	world_environment.environment = backrooms_environment
	sun.light_energy = 0.0
	_active = true
	_level_id = level_id
	return {
		"ok": true,
		"event": "backrooms_lighting_applied",
		"level_id": level_id,
		"ambient_energy": backrooms_environment.ambient_light_energy
	}

func restore_surface() -> bool:
	if not _active:
		return true
	if (
		_world_environment == null
		or not is_instance_valid(_world_environment)
		or _sun == null
		or not is_instance_valid(_sun)
		or _surface_environment == null
	):
		return false
	_world_environment.environment = _surface_environment
	_sun.light_energy = _surface_sun_energy
	_sun.visible = _surface_sun_visible
	_clear_snapshot()
	return true

func is_active() -> bool:
	return _active

func get_current_level() -> String:
	return _level_id

func get_current_profile() -> Dictionary:
	return ProfileScript.get_level_profile(_level_id) if _active else {}

func _clear_snapshot() -> void:
	_active = false
	_level_id = ""
	_world_environment = null
	_surface_environment = null
	_backrooms_environment = null
	_sun = null
	_surface_sun_energy = 1.0
	_surface_sun_visible = true

func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

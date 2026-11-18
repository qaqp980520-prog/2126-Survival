extends RefCounted
class_name BackroomsPerceptionDriver

## Bounded, world-owned sensor sampling for production Backrooms entities.
## The driver never creates a per-entity process loop; SurfaceWorld calls tick()
## from its existing physics callback.
const BrainScript = preload("res://systems/BackroomsEntityBrain.gd")
const LightingProfileScript = preload("res://systems/BackroomsLightingProfile.gd")

const SENSOR_INTERVAL_SECONDS: float = 0.2
const MAX_ENTITY_SAMPLES_PER_TICK: int = 12
const WORLD_GEOMETRY_COLLISION_MASK: int = 1
const SIGHT_RADIUS_FIELDS := [
	"sight_radius",
	"observe_radius",
	"activation_radius",
	"trigger_radius"
]

var _accumulator: float = 0.0
var _tick_index: int = 0
var _next_entity_key: String = ""
var _last_sample_tick_by_entity: Dictionary = {}

func reset() -> void:
	_accumulator = 0.0
	_tick_index = 0
	_next_entity_key = ""
	_last_sample_tick_by_entity.clear()

func tick(
	runtime: Node,
	player: CharacterBody3D,
	camera: Camera3D,
	world_3d: World3D,
	delta_seconds: float,
	is_dark: bool,
	movement_noise_strength: float
) -> Dictionary:
	if not is_finite(delta_seconds) or delta_seconds < 0.0:
		return _failure("delta_seconds_invalid")
	if not is_finite(movement_noise_strength) or movement_noise_strength < 0.0 or movement_noise_strength > 1.0:
		return _failure("movement_noise_strength_invalid")
	if runtime == null or not is_instance_valid(runtime) or not runtime.has_method("is_active"):
		reset()
		return _failure("runtime_unavailable")
	if not bool(runtime.call("is_active")):
		reset()
		return _failure("runtime_inactive")
	if (
		not runtime.has_method("get_loaded_cell_keys")
		or not runtime.has_method("get_cell_root")
		or not runtime.has_method("submit_entity_perception")
	):
		return _failure("runtime_sensor_contract_unavailable")
	if player == null or not is_instance_valid(player) or camera == null or not is_instance_valid(camera):
		return _failure("player_or_camera_unavailable")
	if not _is_finite_vector3(player.global_position) or not _is_finite_vector3(camera.global_position):
		return _failure("player_or_camera_position_invalid")

	_accumulator += delta_seconds
	if _accumulator + 0.000001 < SENSOR_INTERVAL_SECONDS:
		return {
			"ok": true,
			"sampled_count": 0,
			"accepted_count": 0,
			"pending_count": 0,
			"tick_index": _tick_index
		}

	var elapsed_periods: int = maxi(1, int(floor(_accumulator / SENSOR_INTERVAL_SECONDS)))
	_tick_index += elapsed_periods
	_accumulator = fmod(_accumulator, SENSOR_INTERVAL_SECONDS)

	var records: Array[Dictionary] = _collect_entity_records(runtime)
	if records.is_empty():
		_next_entity_key = ""
		_last_sample_tick_by_entity.clear()
		return {
			"ok": true,
			"sampled_count": 0,
			"accepted_count": 0,
			"pending_count": 0,
			"tick_index": _tick_index
		}

	var live_keys: Dictionary = {}
	for record in records:
		live_keys[str(record.get("key", ""))] = true
	for previous_key in _last_sample_tick_by_entity.keys():
		if not live_keys.has(previous_key):
			_last_sample_tick_by_entity.erase(previous_key)

	var start_index: int = _find_start_index(records, _next_entity_key)
	var sample_count: int = mini(MAX_ENTITY_SAMPLES_PER_TICK, records.size())
	var accepted_count: int = 0
	for offset in range(sample_count):
		var record_index: int = (start_index + offset) % records.size()
		var record: Dictionary = records[record_index]
		var entity_key: String = str(record.get("key", ""))
		var previous_tick: int = int(_last_sample_tick_by_entity.get(entity_key, _tick_index - 1))
		var sample_delta: float = float(maxi(1, _tick_index - previous_tick)) * SENSOR_INTERVAL_SECONDS
		_last_sample_tick_by_entity[entity_key] = _tick_index

		var perception: Dictionary = _build_perception(
			record,
			player,
			camera,
			world_3d,
			is_dark,
			movement_noise_strength
		)
		var result_value: Variant = runtime.call(
			"submit_entity_perception",
			str(record.get("cell_key", "")),
			str(record.get("entity_id", "")),
			perception,
			sample_delta,
			str(record.get("spawn_cell_key", ""))
		)
		if result_value is Dictionary and bool(result_value.get("ok", false)):
			accepted_count += 1

	var next_index: int = (start_index + sample_count) % records.size()
	_next_entity_key = str(records[next_index].get("key", ""))
	return {
		"ok": true,
		"sampled_count": sample_count,
		"accepted_count": accepted_count,
		"pending_count": records.size() - sample_count,
		"total_count": records.size(),
		"tick_index": _tick_index,
		"next_entity_key": _next_entity_key
	}

func _collect_entity_records(runtime: Node) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var cell_keys_value: Variant = runtime.call("get_loaded_cell_keys")
	if not (cell_keys_value is Array):
		return records
	var cell_keys: Array = cell_keys_value.duplicate()
	cell_keys.sort()
	for cell_key_value in cell_keys:
		var cell_key: String = str(cell_key_value)
		if cell_key.is_empty():
			continue
		var cell_root_value: Variant = runtime.call("get_cell_root", cell_key)
		if not (cell_root_value is Node3D) or not is_instance_valid(cell_root_value):
			continue
		var cell_root: Node3D = cell_root_value as Node3D
		for child in cell_root.get_children():
			if not (child is Node3D):
				continue
			var entity_root: Node3D = child as Node3D
			if not entity_root.has_meta("backrooms_entity_id"):
				continue
			var entity_id: String = str(entity_root.get_meta("backrooms_entity_id", ""))
			if entity_id.is_empty() or entity_root.get_node_or_null("AI") == null:
				continue
			var spawn_cell_value: Variant = entity_root.get_meta("spawn_cell", null)
			if not (spawn_cell_value is Vector2i):
				continue
			var spawn_cell: Vector2i = spawn_cell_value
			var spawn_cell_key: String = "%d,%d" % [spawn_cell.x, spawn_cell.y]
			var identity_key: String = spawn_cell_key + "|" + entity_id
			records.append({
				"key": identity_key,
				"cell_key": cell_key,
				"spawn_cell_key": spawn_cell_key,
				"entity_id": entity_id,
				"entity_root": entity_root,
				"cell_root": cell_root
			})
	records.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("key", "")) < str(right.get("key", ""))
	)
	return records

func _build_perception(
	record: Dictionary,
	player: CharacterBody3D,
	camera: Camera3D,
	world_3d: World3D,
	is_dark: bool,
	movement_noise_strength: float
) -> Dictionary:
	var entity_root_value: Variant = record.get("entity_root", null)
	if not (entity_root_value is Node3D) or not is_instance_valid(entity_root_value):
		return {}
	var entity_root: Node3D = entity_root_value as Node3D
	var entity_id: String = str(record.get("entity_id", ""))
	var profile: Dictionary = BrainScript.get_behavior_profile(entity_id)
	var distance_to_player: float = entity_root.global_position.distance_to(player.global_position)
	var sight_radius: float = _get_sight_radius(profile)
	var target_point: Vector3 = _get_entity_aim_point(entity_root, entity_id)
	var has_line_of_sight: bool = false
	var player_looking_at_entity: bool = false
	if distance_to_player <= sight_radius and world_3d != null:
		var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
		has_line_of_sight = _has_clear_ray(
			space_state,
			target_point,
			camera.global_position,
			player.get_rid()
		)
		if has_line_of_sight:
			player_looking_at_entity = _is_inside_player_view_cone(camera, target_point)

	var noise_radius: float = maxf(
		float(profile.get("noise_radius", 0.0)),
		float(profile.get("close_noise_radius", 0.0))
	)
	var effective_noise: float = movement_noise_strength
	if noise_radius <= 0.0 or distance_to_player > noise_radius:
		effective_noise = 0.0

	var cell_root_value: Variant = record.get("cell_root", null)
	var resolved_is_dark: bool = is_dark
	if cell_root_value is Node3D:
		resolved_is_dark = LightingProfileScript.is_position_dark(cell_root_value as Node3D, target_point, is_dark)
	var perception: Dictionary = {
		"distance_to_player": distance_to_player,
		"has_line_of_sight": has_line_of_sight,
		"player_looking_at_entity": player_looking_at_entity,
		"noise_strength": effective_noise,
		"noise_distance": distance_to_player,
		"is_dark": resolved_is_dark
	}
	# Movement intents such as Smiler approach and Faceling/Duller avoidance
	# need a player target even when the physics ray reports no line of sight.
	perception["player_position"] = player.global_position
	if effective_noise > 0.0:
		perception["noise_position"] = player.global_position
	return perception

func _get_sight_radius(profile: Dictionary) -> float:
	var result: float = 0.0
	for field_name in SIGHT_RADIUS_FIELDS:
		result = maxf(result, float(profile.get(field_name, 0.0)))
	return result

func _get_entity_aim_point(entity_root: Node3D, entity_id: String) -> Vector3:
	if entity_id == "window":
		var wall_value: Variant = entity_root.get_meta("backrooms_wall_direction", Vector2i.ZERO)
		if wall_value is Vector2i:
			var wall_direction: Vector2i = wall_value
			if wall_direction == Vector2i(0, -1):
				return entity_root.to_global(Vector3(0.0, 0.15, 0.35))
			if wall_direction == Vector2i(-1, 0):
				return entity_root.to_global(Vector3(0.35, 0.15, 0.0))
	return entity_root.global_position + Vector3.UP * 0.6

func _is_inside_player_view_cone(camera: Camera3D, target_position: Vector3) -> bool:
	var to_target: Vector3 = target_position - camera.global_position
	if to_target.length_squared() <= 0.0001:
		return true
	var direction: Vector3 = to_target.normalized()
	var forward: Vector3 = -camera.global_basis.z.normalized()
	var half_fov_radians: float = deg_to_rad(clampf(camera.fov, 1.0, 179.0) * 0.5)
	return forward.dot(direction) >= cos(half_fov_radians)

func _has_clear_ray(
	space_state: PhysicsDirectSpaceState3D,
	from_position: Vector3,
	to_position: Vector3,
	excluded_body: RID
) -> bool:
	if space_state == null or not _is_finite_vector3(from_position) or not _is_finite_vector3(to_position):
		return false
	if from_position.distance_squared_to(to_position) <= 0.0001:
		return true
	var excluded: Array[RID] = [excluded_body]
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from_position,
		to_position,
		WORLD_GEOMETRY_COLLISION_MASK,
		excluded
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query).is_empty()

func _find_start_index(records: Array[Dictionary], requested_key: String) -> int:
	if requested_key.is_empty():
		return 0
	for index in range(records.size()):
		if str(records[index].get("key", "")) == requested_key:
			return index
	return 0

func _is_finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

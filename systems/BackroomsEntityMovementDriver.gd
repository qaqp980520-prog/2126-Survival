extends RefCounted
class_name BackroomsEntityMovementDriver

const NavigationFactoryScript = preload("res://systems/BackroomsCellNavigationFactory.gd")

## Bounded, cell-local locomotion for perception-driven Backrooms entities.
## The owning SurfaceWorld calls tick(); entities never create their own process loop.
## Movement is constrained to the entity's owning cell until roaming-entity persistence
## and cross-cell ownership migration are implemented.
const MOVEMENT_INTERVAL_SECONDS: float = 0.1
const MAX_ENTITY_MOVES_PER_TICK: int = 12
const MAX_FRAME_DELTA_SECONDS: float = 0.5
const MAX_CATCHUP_SECONDS: float = 0.25
const SAFE_CELL_MARGIN: float = 0.65
const COLLISION_SAFE_MARGIN: float = 0.02
const PATROL_RADIUS: float = 1.45
const MOVABLE_ENTITY_IDS := [
	"smiler",
	"hound",
	"skin_stealer",
	"faceling",
	"duller",
	"deathmoth"
]
const SPEED_BY_ENTITY := {
	"smiler": 1.8,
	"hound": 3.8,
	"skin_stealer": 2.8,
	"faceling": 1.6,
	"duller": 2.0,
	"deathmoth": 3.2
}

var _accumulator: float = 0.0
var _tick_index: int = 0
var _next_entity_key: String = ""
var _last_move_tick_by_entity: Dictionary = {}
var _patrol_index_by_entity: Dictionary = {}

func get_diagnostics() -> Dictionary:
	return {
		"tick_index": _tick_index,
		"tracked_entities": _last_move_tick_by_entity.size(),
		"next_entity_key": _next_entity_key,
		"movement_interval_seconds": MOVEMENT_INTERVAL_SECONDS,
		"max_entities_per_tick": MAX_ENTITY_MOVES_PER_TICK
	}

func reset() -> void:
	_accumulator = 0.0
	_tick_index = 0
	_next_entity_key = ""
	_last_move_tick_by_entity.clear()
	_patrol_index_by_entity.clear()

func tick(runtime: Node, delta_seconds: float) -> Dictionary:
	if not is_finite(delta_seconds) or delta_seconds < 0.0:
		return _failure("delta_seconds_invalid")
	if runtime == null or not is_instance_valid(runtime) or not runtime.has_method("is_active"):
		reset()
		return _failure("runtime_unavailable")
	if not bool(runtime.call("is_active")):
		reset()
		return _failure("runtime_inactive")
	if not runtime.has_method("get_loaded_cell_keys") or not runtime.has_method("get_cell_root"):
		return _failure("runtime_movement_contract_unavailable")

	var safe_delta_seconds: float = minf(delta_seconds, MAX_FRAME_DELTA_SECONDS)
	_accumulator += safe_delta_seconds
	if _accumulator + 0.000001 < MOVEMENT_INTERVAL_SECONDS:
		return {
			"ok": true,
			"moved_count": 0,
			"blocked_count": 0,
			"pending_count": 0,
			"tick_index": _tick_index
		}

	var elapsed_periods: int = maxi(1, int(floor(_accumulator / MOVEMENT_INTERVAL_SECONDS)))
	_tick_index += elapsed_periods
	_accumulator = fmod(_accumulator, MOVEMENT_INTERVAL_SECONDS)

	var records: Array[Dictionary] = _collect_entity_records(runtime)
	if records.is_empty():
		_next_entity_key = ""
		_last_move_tick_by_entity.clear()
		_patrol_index_by_entity.clear()
		return {
			"ok": true,
			"moved_count": 0,
			"blocked_count": 0,
			"pending_count": 0,
			"tick_index": _tick_index
		}

	var live_keys: Dictionary = {}
	for record in records:
		live_keys[str(record.get("key", ""))] = true
	for previous_key in _last_move_tick_by_entity.keys():
		if not live_keys.has(previous_key):
			_last_move_tick_by_entity.erase(previous_key)
			_patrol_index_by_entity.erase(previous_key)

	var start_index: int = _find_start_index(records, _next_entity_key)
	var move_count: int = mini(MAX_ENTITY_MOVES_PER_TICK, records.size())
	var moved_count: int = 0
	var blocked_count: int = 0
	for offset in range(move_count):
		var record_index: int = (start_index + offset) % records.size()
		var record: Dictionary = records[record_index]
		var entity_key: String = str(record.get("key", ""))
		var previous_tick: int = int(_last_move_tick_by_entity.get(entity_key, _tick_index - 1))
		var move_delta: float = minf(
			float(maxi(1, _tick_index - previous_tick)) * MOVEMENT_INTERVAL_SECONDS,
			MAX_CATCHUP_SECONDS
		)
		_last_move_tick_by_entity[entity_key] = _tick_index
		var result: Dictionary = _move_entity(record, move_delta)
		if bool(result.get("moved", false)):
			moved_count += 1
		if bool(result.get("blocked", false)):
			blocked_count += 1

	var next_index: int = (start_index + move_count) % records.size()
	_next_entity_key = str(records[next_index].get("key", ""))
	return {
		"ok": true,
		"moved_count": moved_count,
		"blocked_count": blocked_count,
		"sampled_count": move_count,
		"pending_count": records.size() - move_count,
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
			var entity_id: String = str(entity_root.get_meta("backrooms_entity_id", ""))
			if not MOVABLE_ENTITY_IDS.has(entity_id):
				continue
			var brain: Node = entity_root.get_node_or_null("AI")
			if brain == null or not brain.has_method("get_behavior_snapshot"):
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
				"cell_root": cell_root,
				"brain": brain
			})
	records.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("key", "")) < str(right.get("key", ""))
	)
	return records

func _move_entity(record: Dictionary, delta_seconds: float) -> Dictionary:
	var entity_root_value: Variant = record.get("entity_root", null)
	var cell_root_value: Variant = record.get("cell_root", null)
	var brain_value: Variant = record.get("brain", null)
	if not (entity_root_value is Node3D) or not is_instance_valid(entity_root_value):
		return {"moved": false, "blocked": true, "reason": "entity_unavailable"}
	if not (cell_root_value is Node3D) or not is_instance_valid(cell_root_value):
		return {"moved": false, "blocked": true, "reason": "cell_unavailable"}
	if not (brain_value is Node) or not is_instance_valid(brain_value):
		return {"moved": false, "blocked": true, "reason": "brain_unavailable"}

	var entity_root: Node3D = entity_root_value as Node3D
	if not (entity_root is CharacterBody3D):
		return {"moved": false, "blocked": true, "reason": "entity_physics_body_unavailable"}
	var entity_body: CharacterBody3D = entity_root as CharacterBody3D
	if not entity_body.is_inside_tree():
		return {"moved": false, "blocked": true, "reason": "entity_physics_body_outside_tree"}
	var collision_shape: CollisionShape3D = entity_body.get_node_or_null("EntityCollision") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null or collision_shape.disabled or entity_body.collision_mask == 0:
		return {"moved": false, "blocked": true, "reason": "entity_collision_proxy_unavailable"}
	var cell_root: Node3D = cell_root_value as Node3D
	var brain: Node = brain_value as Node
	var snapshot_value: Variant = brain.call("get_behavior_snapshot")
	if not (snapshot_value is Dictionary):
		return {"moved": false, "blocked": true, "reason": "brain_snapshot_invalid"}
	var snapshot: Dictionary = snapshot_value
	if not bool(snapshot.get("configured", false)) or not bool(snapshot.get("has_evaluated_perception", false)):
		return {"moved": false, "blocked": false, "reason": "brain_not_ready"}

	var entity_id: String = str(record.get("entity_id", ""))
	var entity_key: String = str(record.get("key", ""))
	var state_name: String = str(snapshot.get("state", ""))
	var cell_size: float = float(cell_root.get_meta("backrooms_cell_size", 0.0))
	if not is_finite(cell_size) or cell_size <= SAFE_CELL_MARGIN * 2.0:
		return {"moved": false, "blocked": true, "reason": "cell_size_invalid"}
	var half_extent: float = cell_size * 0.5 - SAFE_CELL_MARGIN
	var current_local: Vector3 = cell_root.to_local(entity_root.global_position)
	if not _is_finite_vector3(current_local):
		return {"moved": false, "blocked": true, "reason": "entity_position_invalid"}
	var target_local: Vector3 = current_local
	var stop_distance: float = 0.0
	var speed: float = float(SPEED_BY_ENTITY.get(entity_id, 0.0))
	if speed <= 0.0:
		return {"moved": false, "blocked": true, "reason": "entity_speed_unavailable"}

	match state_name:
		"approach", "pursue", "investigate", "observe":
			if not bool(snapshot.get("has_target_position", false)):
				return {"moved": false, "blocked": false, "reason": "target_unavailable"}
			var target_value: Variant = snapshot.get("target_position", null)
			if not (target_value is Vector3) or not _is_finite_vector3(target_value):
				return {"moved": false, "blocked": true, "reason": "target_position_invalid"}
			target_local = cell_root.to_local(target_value)
			if not _is_inside_cell(target_local, cell_size * 0.5 - 0.1):
				return {"moved": false, "blocked": true, "reason": "target_outside_owning_cell"}
			match state_name:
				"approach":
					stop_distance = 2.0
				"pursue":
					stop_distance = 1.1
				"investigate":
					stop_distance = 1.35
				"observe":
					stop_distance = 5.0
			target_local.y = current_local.y
		"avoid", "retreat":
			if not bool(snapshot.get("has_target_position", false)):
				return {"moved": false, "blocked": false, "reason": "avoidance_target_unavailable"}
			var player_value: Variant = snapshot.get("target_position", null)
			if not (player_value is Vector3) or not _is_finite_vector3(player_value):
				return {"moved": false, "blocked": true, "reason": "avoidance_target_invalid"}
			var player_local: Vector3 = cell_root.to_local(player_value)
			if not _is_inside_cell(player_local, cell_size * 0.5 - 0.1):
				return {"moved": false, "blocked": true, "reason": "avoidance_target_outside_owning_cell"}
			var away := Vector2(current_local.x - player_local.x, current_local.z - player_local.z)
			if away.length_squared() <= 0.0001:
				away = _deterministic_fallback_direction(entity_root)
			var retreat_distance: float = 2.2 if state_name == "retreat" else 1.7
			target_local.x = clampf(current_local.x + away.normalized().x * retreat_distance, -half_extent, half_extent)
			target_local.z = clampf(current_local.z + away.normalized().y * retreat_distance, -half_extent, half_extent)
			target_local.y = current_local.y
		"patrol", "fly_patrol":
			target_local = _get_patrol_target(entity_root, entity_key, current_local, state_name)
		_:
			return {"moved": false, "blocked": false, "reason": "state_is_stationary"}

	var next_local := current_local
	if state_name == "fly_patrol":
		var current_horizontal := Vector2(current_local.x, current_local.z)
		var target_horizontal := Vector2(target_local.x, target_local.z)
		var fly_offset: Vector2 = target_horizontal - current_horizontal
		var fly_distance: float = fly_offset.length()
		if fly_distance <= stop_distance + 0.0001:
			_advance_patrol(entity_key, entity_root)
			return {"moved": false, "blocked": false, "reason": "within_stop_distance"}
		var fly_travel_distance: float = minf(
			speed * maxf(delta_seconds, 0.0),
			maxf(0.0, fly_distance - stop_distance)
		)
		if fly_travel_distance <= 0.0001:
			return {"moved": false, "blocked": false, "reason": "movement_below_epsilon"}
		var fly_direction: Vector2 = fly_offset / fly_distance
		next_local.x = clampf(current_local.x + fly_direction.x * fly_travel_distance, -half_extent, half_extent)
		next_local.z = clampf(current_local.z + fly_direction.y * fly_travel_distance, -half_extent, half_extent)
		var vertical_offset: float = target_local.y - current_local.y
		next_local.y = current_local.y + clampf(
			vertical_offset,
			-speed * maxf(delta_seconds, 0.0),
			speed * maxf(delta_seconds, 0.0)
		)
	else:
		var navigation_agent := NavigationFactoryScript.get_agent(entity_body)
		if navigation_agent == null:
			return {"moved": false, "blocked": true, "reason": "navigation_agent_unavailable"}
		var navigation_target_local: Vector3 = target_local
		navigation_target_local.y = NavigationFactoryScript.NAVIGATION_SURFACE_Y
		var navigation_target_world: Vector3 = cell_root.to_global(navigation_target_local)
		if not NavigationFactoryScript.set_agent_target(
			navigation_agent, navigation_target_world, stop_distance
		):
			return {"moved": false, "blocked": true, "reason": "navigation_target_rejected"}
		var navigation_result: Dictionary = NavigationFactoryScript.get_next_waypoint(navigation_agent)
		if not bool(navigation_result.get("ok", false)):
			var navigation_reason: String = str(navigation_result.get("reason", "navigation_unavailable"))
			return {
				"moved": false,
				"blocked": navigation_reason != "navigation_path_unavailable",
				"reason": navigation_reason
			}
		if bool(navigation_result.get("finished", false)):
			if not bool(navigation_result.get("target_reachable", false)):
				return {"moved": false, "blocked": true, "reason": "navigation_target_unreachable"}
			if state_name == "patrol":
				_advance_patrol(entity_key, entity_root)
			return {"moved": false, "blocked": false, "reason": "within_stop_distance"}
		var waypoint_value: Variant = navigation_result.get("next_path_position", null)
		if not (waypoint_value is Vector3) or not _is_finite_vector3(waypoint_value):
			return {"moved": false, "blocked": true, "reason": "navigation_waypoint_invalid"}
		var waypoint_local: Vector3 = cell_root.to_local(waypoint_value)
		var waypoint_offset := Vector2(
			waypoint_local.x - current_local.x,
			waypoint_local.z - current_local.z
		)
		var waypoint_distance: float = waypoint_offset.length()
		if waypoint_distance <= 0.0001:
			return {"moved": false, "blocked": false, "reason": "navigation_waypoint_pending"}
		var waypoint_travel_distance: float = minf(
			speed * maxf(delta_seconds, 0.0),
			waypoint_distance
		)
		var waypoint_direction: Vector2 = waypoint_offset / waypoint_distance
		next_local.x = current_local.x + waypoint_direction.x * waypoint_travel_distance
		next_local.z = current_local.z + waypoint_direction.y * waypoint_travel_distance
		next_local.y = current_local.y
	var previous_world_position: Vector3 = entity_body.global_position
	var desired_world_position: Vector3 = cell_root.to_global(next_local)
	var motion: Vector3 = desired_world_position - previous_world_position
	if motion.length_squared() <= 0.000001:
		return {"moved": false, "blocked": false, "reason": "movement_below_epsilon"}
	var collision: KinematicCollision3D = entity_body.move_and_collide(
		motion,
		false,
		COLLISION_SAFE_MARGIN,
		false
	)
	var actual_local: Vector3 = cell_root.to_local(entity_body.global_position)
	if not _is_inside_cell(actual_local, half_extent):
		entity_body.global_position = previous_world_position
		return {"moved": false, "blocked": true, "reason": "physics_motion_exceeded_safe_cell_bounds"}
	var did_move: bool = entity_body.global_position.distance_squared_to(previous_world_position) > 0.000001
	entity_body.set_meta("backrooms_movement_mode", "cell_local_physics_v1")
	if collision != null:
		entity_body.set_meta("backrooms_last_collision_normal", collision.get_normal())
		if state_name in ["patrol", "fly_patrol"]:
			_advance_patrol(entity_key, entity_root)
		return {"moved": did_move, "blocked": true, "reason": "world_collision"}
	if entity_body.has_meta("backrooms_last_collision_normal"):
		entity_body.remove_meta("backrooms_last_collision_normal")
	return {"moved": did_move, "blocked": false, "reason": "moved"}

func _get_patrol_target(
	entity_root: Node3D,
	entity_key: String,
	current_local: Vector3,
	state_name: String
) -> Vector3:
	var index: int = posmod(
		int(entity_root.get_meta("backrooms_patrol_index", _initial_patrol_index(entity_root))),
		4
	)
	_patrol_index_by_entity[entity_key] = index
	entity_root.set_meta("backrooms_patrol_index", index)
	var y_values: Array[float] = [current_local.y, current_local.y, current_local.y, current_local.y]
	if state_name == "fly_patrol":
		y_values = [1.9, 2.25, 2.05, 1.8]
	var points: Array[Vector3] = [
		Vector3(-PATROL_RADIUS, y_values[0], -PATROL_RADIUS),
		Vector3(PATROL_RADIUS, y_values[1], -PATROL_RADIUS),
		Vector3(PATROL_RADIUS, y_values[2], PATROL_RADIUS),
		Vector3(-PATROL_RADIUS, y_values[3], PATROL_RADIUS)
	]
	return points[posmod(index, points.size())]

func _initial_patrol_index(entity_root: Node3D) -> int:
	var cell_value: Variant = entity_root.get_meta("spawn_cell", Vector2i.ZERO)
	var seed_value: int = int(entity_root.get_meta("spawn_world_seed", 0))
	var cell: Vector2i = Vector2i.ZERO
	if cell_value is Vector2i:
		cell = cell_value
	var value: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ seed_value
	return posmod(value, 4)

func _advance_patrol(entity_key: String, entity_root: Node3D) -> void:
	var next_index: int = posmod(int(_patrol_index_by_entity.get(entity_key, 0)) + 1, 4)
	_patrol_index_by_entity[entity_key] = next_index
	entity_root.set_meta("backrooms_patrol_index", next_index)

func _deterministic_fallback_direction(entity_root: Node3D) -> Vector2:
	var cell_value: Variant = entity_root.get_meta("spawn_cell", Vector2i.ZERO)
	var seed_value: int = int(entity_root.get_meta("spawn_world_seed", 0))
	var cell: Vector2i = Vector2i.ZERO
	if cell_value is Vector2i:
		cell = cell_value
	var value: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ seed_value
	if posmod(value, 2) == 0:
		return Vector2(1.0, 0.0)
	return Vector2(-1.0, 0.0)

func _is_inside_cell(local_position: Vector3, half_extent: float) -> bool:
	return (
		_is_finite_vector3(local_position)
		and absf(local_position.x) <= half_extent
		and absf(local_position.z) <= half_extent
	)

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

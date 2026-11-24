extends RefCounted
class_name BackroomsEntityCombatDriver

## World-owned, bounded contact attacks for active Backrooms entities.
## Cooldowns are keyed by immutable spawn identity so cell transfers do not reset them.
const ATTACK_INTERVAL_SECONDS: float = 0.1
const MAX_ENTITY_ATTACKS_PER_TICK: int = 12
const MAX_FRAME_DELTA_SECONDS: float = 0.5
const MAX_TRACKED_COOLDOWNS: int = 4096
const HOUND_ATTACK_RANGE: float = 1.35
const HOUND_ATTACK_DAMAGE: float = 12.0
const HOUND_ATTACK_COOLDOWN_SECONDS: float = 1.25
const WORLD_GEOMETRY_COLLISION_MASK: int = 1

var _accumulator: float = 0.0
var _tick_index: int = 0
var _next_entity_key: String = ""
var _cooldown_remaining_by_entity: Dictionary = {}

func reset() -> void:
	_accumulator = 0.0
	_tick_index = 0
	_next_entity_key = ""
	_cooldown_remaining_by_entity.clear()

func get_diagnostics() -> Dictionary:
	return {
		"tick_index": _tick_index,
		"tracked_cooldowns": _cooldown_remaining_by_entity.size(),
		"next_entity_key": _next_entity_key,
		"attack_interval_seconds": ATTACK_INTERVAL_SECONDS,
		"max_entities_per_tick": MAX_ENTITY_ATTACKS_PER_TICK
	}

func tick(
	runtime: Node,
	player: CharacterBody3D,
	world_3d: World3D,
	health: RefCounted,
	delta_seconds: float
) -> Dictionary:
	if not is_finite(delta_seconds) or delta_seconds < 0.0:
		return _failure("delta_seconds_invalid")
	if runtime == null or not is_instance_valid(runtime) or not runtime.has_method("is_active"):
		reset()
		return _failure("runtime_unavailable")
	if not bool(runtime.call("is_active")):
		reset()
		return _failure("runtime_inactive")
	if not runtime.has_method("get_loaded_cell_keys") or not runtime.has_method("get_cell_root"):
		return _failure("runtime_combat_contract_unavailable")
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return _failure("player_unavailable")
	if world_3d == null:
		return _failure("world_3d_unavailable")
	if health == null or not health.has_method("is_alive") or not health.has_method("apply_damage"):
		return _failure("health_contract_unavailable")
	if not bool(health.call("is_alive")):
		return {
			"ok": true,
			"attacked_count": 0,
			"damage_applied": 0.0,
			"sampled_count": 0,
			"pending_count": 0,
			"tick_index": _tick_index,
			"reason": "player_defeated"
		}

	_accumulator += minf(delta_seconds, MAX_FRAME_DELTA_SECONDS)
	if _accumulator + 0.000001 < ATTACK_INTERVAL_SECONDS:
		return {
			"ok": true,
			"attacked_count": 0,
			"damage_applied": 0.0,
			"sampled_count": 0,
			"pending_count": 0,
			"tick_index": _tick_index
		}

	var elapsed_periods: int = maxi(1, int(floor(_accumulator / ATTACK_INTERVAL_SECONDS)))
	var elapsed_seconds: float = float(elapsed_periods) * ATTACK_INTERVAL_SECONDS
	_tick_index += elapsed_periods
	_accumulator = fmod(_accumulator, ATTACK_INTERVAL_SECONDS)
	_decay_cooldowns(elapsed_seconds)

	var records: Array[Dictionary] = _collect_entity_records(runtime)
	if records.is_empty():
		return {
			"ok": true,
			"attacked_count": 0,
			"damage_applied": 0.0,
			"sampled_count": 0,
			"pending_count": 0,
			"tick_index": _tick_index
		}

	var start_index: int = _find_start_index(records, _next_entity_key)
	var sample_count: int = mini(MAX_ENTITY_ATTACKS_PER_TICK, records.size())
	var processed_count: int = 0
	var attacked_count: int = 0
	var blocked_count: int = 0
	var damage_applied: float = 0.0
	var attack_events: Array[Dictionary] = []
	for offset in range(sample_count):
		if not bool(health.call("is_alive")):
			break
		var record: Dictionary = records[(start_index + offset) % records.size()]
		processed_count += 1
		var entity_key: String = str(record.get("key", ""))
		if float(_cooldown_remaining_by_entity.get(entity_key, 0.0)) > 0.000001:
			continue
		if _cooldown_remaining_by_entity.size() >= MAX_TRACKED_COOLDOWNS:
			continue
		var entity_root_value: Variant = record.get("entity_root", null)
		var brain_value: Variant = record.get("brain", null)
		if not (entity_root_value is CharacterBody3D) or not is_instance_valid(entity_root_value):
			continue
		if not (brain_value is Node) or not is_instance_valid(brain_value):
			continue
		var entity_root: CharacterBody3D = entity_root_value as CharacterBody3D
		var brain: Node = brain_value as Node
		var snapshot_value: Variant = brain.call("get_behavior_snapshot")
		if not (snapshot_value is Dictionary):
			continue
		var snapshot: Dictionary = snapshot_value
		if not bool(snapshot.get("configured", false)) or str(snapshot.get("state", "")) != "pursue":
			continue
		var distance: float = entity_root.global_position.distance_to(player.global_position)
		if not is_finite(distance) or distance > HOUND_ATTACK_RANGE:
			continue
		if not _has_clear_attack_path(world_3d, entity_root, player):
			blocked_count += 1
			continue
		var damage_value: Variant = health.call("apply_damage", HOUND_ATTACK_DAMAGE, "hound")
		if not (damage_value is Dictionary) or not bool(damage_value.get("ok", false)):
			continue
		var applied: float = float(damage_value.get("applied", 0.0))
		_cooldown_remaining_by_entity[entity_key] = HOUND_ATTACK_COOLDOWN_SECONDS
		attacked_count += 1
		damage_applied += applied
		attack_events.append({
			"entity_key": entity_key,
			"distance": distance,
			"damage": applied,
			"defeated": bool(damage_value.get("defeated", false))
		})

	var next_index: int = (start_index + processed_count) % records.size()
	_next_entity_key = str(records[next_index].get("key", ""))
	return {
		"ok": true,
		"attacked_count": attacked_count,
		"blocked_count": blocked_count,
		"damage_applied": damage_applied,
		"sampled_count": processed_count,
		"pending_count": records.size() - processed_count,
		"total_count": records.size(),
		"tick_index": _tick_index,
		"next_entity_key": _next_entity_key,
		"attack_events": attack_events
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
		var level_id: String = str(cell_root.get_meta("backrooms_level_id")) if cell_root.has_meta("backrooms_level_id") else ""
		var world_seed: int = int(cell_root.get_meta("backrooms_world_seed")) if cell_root.has_meta("backrooms_world_seed") else 0
		for child in cell_root.get_children():
			if not (child is CharacterBody3D):
				continue
			var entity_root: CharacterBody3D = child as CharacterBody3D
			if not entity_root.has_meta("backrooms_entity_id") or str(entity_root.get_meta("backrooms_entity_id", "")) != "hound":
				continue
			if not entity_root.has_meta("spawn_cell"):
				continue
			var spawn_cell_value: Variant = entity_root.get_meta("spawn_cell")
			if not (spawn_cell_value is Vector2i):
				continue
			var owner_cell_key: String = str(entity_root.get_meta("backrooms_owner_cell_key")) if entity_root.has_meta("backrooms_owner_cell_key") else cell_key
			if owner_cell_key != cell_key:
				continue
			var brain: Node = entity_root.get_node_or_null("AI")
			if brain == null or not brain.has_method("get_behavior_snapshot"):
				continue
			var spawn_cell: Vector2i = spawn_cell_value
			var spawn_cell_key: String = "%d,%d" % [spawn_cell.x, spawn_cell.y]
			records.append({
				"key": "%s|%d|%s|hound" % [level_id, world_seed, spawn_cell_key],
				"cell_key": cell_key,
				"entity_root": entity_root,
				"brain": brain
			})
	records.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("key", "")) < str(right.get("key", ""))
	)
	return records

func _has_clear_attack_path(world_3d: World3D, entity_root: CharacterBody3D, player: CharacterBody3D) -> bool:
	if not entity_root.is_inside_tree() or not player.is_inside_tree():
		return false
	var from_position: Vector3 = entity_root.global_position + Vector3.UP * 0.6
	var to_position: Vector3 = player.global_position + Vector3.UP * 0.9
	if not _is_finite_vector3(from_position) or not _is_finite_vector3(to_position):
		return false
	if from_position.distance_squared_to(to_position) <= 0.0001:
		return true
	var excluded: Array[RID] = [entity_root.get_rid(), player.get_rid()]
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from_position,
		to_position,
		WORLD_GEOMETRY_COLLISION_MASK,
		excluded
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world_3d.direct_space_state.intersect_ray(query).is_empty()

func _decay_cooldowns(elapsed_seconds: float) -> void:
	for entity_key_value in _cooldown_remaining_by_entity.keys():
		var entity_key: String = str(entity_key_value)
		var remaining: float = maxf(
			0.0,
			float(_cooldown_remaining_by_entity.get(entity_key, 0.0)) - elapsed_seconds
		)
		if remaining <= 0.000001:
			_cooldown_remaining_by_entity.erase(entity_key)
		else:
			_cooldown_remaining_by_entity[entity_key] = remaining

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

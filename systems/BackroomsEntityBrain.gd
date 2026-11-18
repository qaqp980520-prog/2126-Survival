extends Node
class_name BackroomsEntityBrain

## Deterministic, perception-driven decision controller for production Backrooms entities.
## This layer emits behavior intents; navigation, movement, animation and combat are separate systems.
const EntityDirectorScript = preload("res://systems/BackroomsEntityDirector.gd")

const BEHAVIOR_VERSION: int = 2
const SAVE_SCHEMA_VERSION: int = 1
const SUPPORTED_ENTITY_IDS := [
	"window",
	"smiler",
	"hound",
	"skin_stealer",
	"clump",
	"faceling",
	"duller",
	"deathmoth"
]

const BEHAVIOR_PROFILES := {
	"window": {
		"role": "anchored_observer",
		"sight_radius": 14.0
	},
	"smiler": {
		"role": "darkness_stalker",
		"activation_radius": 14.0
	},
	"hound": {
		"role": "sound_tracker",
		"sight_radius": 18.0,
		"noise_radius": 24.0,
		"investigate_noise": 0.25,
		"pursue_noise": 0.65,
		"close_noise_radius": 12.0
	},
	"skin_stealer": {
		"role": "ambush_hunter",
		"sight_radius": 10.0,
		"observe_radius": 20.0,
		"noise_radius": 18.0,
		"investigate_noise": 0.4
	},
	"clump": {
		"role": "anchored_ambusher",
		"trigger_radius": 6.0
	},
	"faceling": {
		"role": "passive_avoidant",
		"avoid_radius": 4.0
	},
	"duller": {
		"role": "passive_retreat",
		"retreat_radius": 7.0
	},
	"deathmoth": {
		"role": "aerial_hunter",
		"sight_radius": 16.0,
		"noise_radius": 22.0,
		"investigate_noise": 0.45
	}
}

var configured: bool = false
var entity_id: String = ""
var level_id: String = ""
var spawn_cell: Vector2i = Vector2i.ZERO
var world_seed: int = 0
var current_state: String = "unconfigured"
var current_intent: String = "none"
var state_elapsed_seconds: float = 0.0
var has_evaluated_perception: bool = false
var has_target_position: bool = false
var target_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Perception is submitted by the owning world/runtime. The controller never
	# polls global nodes or runs an unbounded per-entity process loop.
	set_process(false)
	set_physics_process(false)

static func is_behavior_version_supported(version: int) -> bool:
	return version == BEHAVIOR_VERSION

static func get_supported_entity_ids() -> Array[String]:
	var result: Array[String] = []
	for requested_entity_id in SUPPORTED_ENTITY_IDS:
		result.append(str(requested_entity_id))
	return result

static func get_behavior_profile(requested_entity_id: String) -> Dictionary:
	var value: Variant = BEHAVIOR_PROFILES.get(requested_entity_id, null)
	if not (value is Dictionary):
		return {}
	return value.duplicate(true)

func configure(
	requested_entity_id: String,
	requested_level_id: String,
	requested_spawn_cell: Vector2i,
	requested_world_seed: int
) -> bool:
	if configured:
		return false
	if not SUPPORTED_ENTITY_IDS.has(requested_entity_id):
		return false
	if not EntityDirectorScript.get_allowed_entities(requested_level_id).has(requested_entity_id):
		return false
	if get_behavior_profile(requested_entity_id).is_empty():
		return false

	entity_id = requested_entity_id
	level_id = requested_level_id
	spawn_cell = requested_spawn_cell
	world_seed = requested_world_seed
	current_state = _initial_state(entity_id)
	current_intent = _intent_for_state(current_state)
	state_elapsed_seconds = 0.0
	has_evaluated_perception = false
	has_target_position = false
	target_position = Vector3.ZERO
	configured = true
	set_process(false)
	set_physics_process(false)
	return true

## Evaluate one externally supplied perception snapshot.
## Required: distance_to_player. Optional: has_line_of_sight, noise_strength,
## noise_distance, is_dark, player_position and noise_position.
func evaluate_perception(perception: Dictionary, delta_seconds: float = 0.0) -> Dictionary:
	if not configured:
		return _reject("brain_not_configured")
	if not is_finite(delta_seconds) or delta_seconds < 0.0:
		return _reject("delta_seconds_invalid")

	var distance_value: Variant = perception.get("distance_to_player", null)
	if not _is_number(distance_value):
		return _reject("distance_to_player_invalid")
	var distance_to_player: float = float(distance_value)
	if not is_finite(distance_to_player) or distance_to_player < 0.0:
		return _reject("distance_to_player_invalid")

	var line_of_sight_value: Variant = perception.get("has_line_of_sight", false)
	if typeof(line_of_sight_value) != TYPE_BOOL:
		return _reject("line_of_sight_invalid")
	var has_line_of_sight: bool = bool(line_of_sight_value)
	var player_looking_value: Variant = perception.get("player_looking_at_entity", has_line_of_sight)
	if typeof(player_looking_value) != TYPE_BOOL:
		return _reject("player_looking_at_entity_invalid")
	var player_looking_at_entity: bool = bool(player_looking_value)

	var noise_value: Variant = perception.get("noise_strength", 0.0)
	if not _is_number(noise_value):
		return _reject("noise_strength_invalid")
	var noise_strength: float = float(noise_value)
	if not is_finite(noise_strength) or noise_strength < 0.0 or noise_strength > 1.0:
		return _reject("noise_strength_invalid")

	var noise_distance_value: Variant = perception.get("noise_distance", distance_to_player)
	if not _is_number(noise_distance_value):
		return _reject("noise_distance_invalid")
	var noise_distance: float = float(noise_distance_value)
	if not is_finite(noise_distance) or noise_distance < 0.0:
		return _reject("noise_distance_invalid")

	var dark_value: Variant = perception.get("is_dark", false)
	if typeof(dark_value) != TYPE_BOOL:
		return _reject("darkness_state_invalid")
	var is_dark: bool = bool(dark_value)

	var player_position_value: Variant = perception.get("player_position", null)
	var has_player_position: bool = perception.has("player_position")
	if has_player_position and not _is_finite_vector3_value(player_position_value):
		return _reject("player_position_invalid")

	var noise_position_value: Variant = perception.get("noise_position", null)
	var has_noise_position: bool = perception.has("noise_position")
	if has_noise_position and not _is_finite_vector3_value(noise_position_value):
		return _reject("noise_position_invalid")

	var next_state: String = _decide_state(
		distance_to_player,
		has_line_of_sight,
		player_looking_at_entity,
		noise_strength,
		noise_distance,
		is_dark
	)
	if not has_evaluated_perception or next_state != current_state:
		state_elapsed_seconds = 0.0
	else:
		state_elapsed_seconds += delta_seconds
	current_state = next_state
	current_intent = _intent_for_state(next_state)
	has_evaluated_perception = true

	if next_state in ["avoid", "retreat"] and has_player_position:
		target_position = player_position_value
		has_target_position = true
	elif next_state in ["investigate", "pursue"] and noise_strength > 0.0 and has_noise_position:
		target_position = noise_position_value
		has_target_position = true
	elif has_player_position and (has_line_of_sight or next_state in ["approach", "pursue", "observe"]):
		target_position = player_position_value
		has_target_position = true
	elif next_state in ["avoid", "retreat"]:
		target_position = Vector3.ZERO
		has_target_position = false
	elif not _state_retains_target(next_state):
		target_position = Vector3.ZERO
		has_target_position = false

	var result: Dictionary = get_behavior_snapshot()
	result["ok"] = true
	return result

func get_behavior_snapshot() -> Dictionary:
	return {
		"behavior_version": BEHAVIOR_VERSION,
		"configured": configured,
		"entity_id": entity_id,
		"level_id": level_id,
		"spawn_cell": spawn_cell,
		"world_seed": world_seed,
		"state": current_state,
		"intent": current_intent,
		"state_elapsed_seconds": state_elapsed_seconds,
		"has_evaluated_perception": has_evaluated_perception,
		"has_target_position": has_target_position,
		"target_position": target_position if has_target_position else Vector3.ZERO
	}

func to_save_dict() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"behavior_version": BEHAVIOR_VERSION,
		"entity_id": entity_id,
		"level_id": level_id,
		"spawn_cell": [spawn_cell.x, spawn_cell.y],
		"world_seed": world_seed,
		"state": current_state,
		"intent": current_intent,
		"state_elapsed_seconds": state_elapsed_seconds,
		"has_evaluated_perception": has_evaluated_perception,
		"has_target_position": has_target_position,
		"target_position": [
			target_position.x if has_target_position else 0.0,
			target_position.y if has_target_position else 0.0,
			target_position.z if has_target_position else 0.0
		]
	}

static func validate_save_dict(payload: Dictionary, expected_entity_id: String, expected_level_id: String, expected_spawn_cell: Vector2i, expected_world_seed: int) -> bool:
	var schema_value: Variant = payload.get("schema_version", null)
	var behavior_value: Variant = payload.get("behavior_version", null)
	var seed_value: Variant = payload.get("world_seed", null)
	if not _is_integer_value(schema_value) or int(schema_value) != SAVE_SCHEMA_VERSION:
		return false
	if not _is_integer_value(behavior_value) or int(behavior_value) != BEHAVIOR_VERSION:
		return false
	if not _is_integer_value(seed_value) or int(seed_value) != expected_world_seed:
		return false
	if str(payload.get("entity_id", "")) != expected_entity_id or str(payload.get("level_id", "")) != expected_level_id:
		return false
	var spawn_value: Variant = payload.get("spawn_cell", null)
	if not (spawn_value is Array) or spawn_value.size() != 2:
		return false
	if not _is_integer_value(spawn_value[0]) or not _is_integer_value(spawn_value[1]):
		return false
	if int(spawn_value[0]) != expected_spawn_cell.x or int(spawn_value[1]) != expected_spawn_cell.y:
		return false
	var state_value: Variant = payload.get("state", null)
	var intent_value: Variant = payload.get("intent", null)
	var elapsed_value: Variant = payload.get("state_elapsed_seconds", null)
	var evaluated_value: Variant = payload.get("has_evaluated_perception", null)
	var target_flag_value: Variant = payload.get("has_target_position", null)
	var target_value: Variant = payload.get("target_position", null)
	if not (state_value is String) or not (intent_value is String):
		return false
	if not (elapsed_value is int or elapsed_value is float):
		return false
	var elapsed: float = float(elapsed_value)
	if not is_finite(elapsed) or elapsed < 0.0 or elapsed > 1000000000.0:
		return false
	if not (evaluated_value is bool) or not (target_flag_value is bool):
		return false
	if not _is_state_allowed_for_entity(expected_entity_id, str(state_value)):
		return false
	if str(intent_value) != _intent_for_state_value(str(state_value)):
		return false
	if not (target_value is Array) or target_value.size() != 3:
		return false
	for component in target_value:
		if not (component is int or component is float) or not is_finite(float(component)):
			return false
	if not bool(target_flag_value) and (
		float(target_value[0]) != 0.0 or float(target_value[1]) != 0.0 or float(target_value[2]) != 0.0
	):
		return false
	if not bool(evaluated_value) and (
		str(state_value) != _initial_state_for_entity(expected_entity_id)
		or elapsed != 0.0
		or bool(target_flag_value)
	):
		return false
	return true

func load_save_dict(payload: Dictionary) -> bool:
	if not configured or not validate_save_dict(payload, entity_id, level_id, spawn_cell, world_seed):
		return false
	current_state = str(payload["state"])
	current_intent = str(payload["intent"])
	state_elapsed_seconds = float(payload["state_elapsed_seconds"])
	has_evaluated_perception = bool(payload["has_evaluated_perception"])
	has_target_position = bool(payload["has_target_position"])
	var target: Array = payload["target_position"]
	target_position = Vector3(float(target[0]), float(target[1]), float(target[2]))
	return true

func reset_behavior() -> bool:
	if not configured:
		return false
	current_state = _initial_state(entity_id)
	current_intent = _intent_for_state(current_state)
	state_elapsed_seconds = 0.0
	has_evaluated_perception = false
	has_target_position = false
	target_position = Vector3.ZERO
	return true

func _decide_state(
	distance_to_player: float,
	has_line_of_sight: bool,
	player_looking_at_entity: bool,
	noise_strength: float,
	noise_distance: float,
	is_dark: bool
) -> String:
	var profile: Dictionary = get_behavior_profile(entity_id)
	match entity_id:
		"window":
			if player_looking_at_entity and distance_to_player <= float(profile.get("sight_radius", 0.0)):
				return "watch"
			return "dormant"
		"smiler":
			if not is_dark:
				return "dormant"
			if player_looking_at_entity:
				return "freeze"
			if distance_to_player <= float(profile.get("activation_radius", 0.0)):
				return "approach"
			return "dormant"
		"hound":
			if noise_strength >= float(profile.get("pursue_noise", 1.0)) and noise_distance <= float(profile.get("close_noise_radius", 0.0)):
				return "pursue"
			if has_line_of_sight and distance_to_player <= float(profile.get("sight_radius", 0.0)):
				return "pursue"
			if noise_strength >= float(profile.get("investigate_noise", 1.0)) and noise_distance <= float(profile.get("noise_radius", 0.0)):
				return "investigate"
			return "patrol"
		"skin_stealer":
			if has_line_of_sight and distance_to_player <= float(profile.get("sight_radius", 0.0)):
				return "pursue"
			if noise_strength >= float(profile.get("investigate_noise", 1.0)) and noise_distance <= float(profile.get("noise_radius", 0.0)):
				return "investigate"
			if has_line_of_sight and distance_to_player <= float(profile.get("observe_radius", 0.0)):
				return "observe"
			return "patrol"
		"clump":
			if has_line_of_sight and distance_to_player <= float(profile.get("trigger_radius", 0.0)):
				return "ambush"
			return "anchored"
		"faceling":
			if distance_to_player <= float(profile.get("avoid_radius", 0.0)):
				return "avoid"
			return "passive"
		"duller":
			if distance_to_player <= float(profile.get("retreat_radius", 0.0)):
				return "retreat"
			return "passive"
		"deathmoth":
			if has_line_of_sight and distance_to_player <= float(profile.get("sight_radius", 0.0)):
				return "pursue"
			if noise_strength >= float(profile.get("investigate_noise", 1.0)) and noise_distance <= float(profile.get("noise_radius", 0.0)):
				return "investigate"
			return "fly_patrol"
	return "dormant"

func _initial_state(requested_entity_id: String) -> String:
	return _initial_state_for_entity(requested_entity_id)

static func _initial_state_for_entity(requested_entity_id: String) -> String:
	match requested_entity_id:
		"hound", "skin_stealer":
			return "patrol"
		"clump":
			return "anchored"
		"faceling", "duller":
			return "passive"
		"deathmoth":
			return "fly_patrol"
		_:
			return "dormant"

static func _is_state_allowed_for_entity(requested_entity_id: String, state_name: String) -> bool:
	match requested_entity_id:
		"window":
			return state_name in ["watch", "dormant"]
		"smiler":
			return state_name in ["dormant", "freeze", "approach"]
		"hound":
			return state_name in ["pursue", "investigate", "patrol"]
		"skin_stealer":
			return state_name in ["pursue", "investigate", "observe", "patrol"]
		"clump":
			return state_name in ["ambush", "anchored"]
		"faceling":
			return state_name in ["avoid", "passive"]
		"duller":
			return state_name in ["retreat", "passive"]
		"deathmoth":
			return state_name in ["pursue", "investigate", "fly_patrol"]
	return false

static func _is_integer_value(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var number: float = float(value)
		return is_finite(number) and floorf(number) == number
	return false

func _intent_for_state(state_name: String) -> String:
	return _intent_for_state_value(state_name)

static func _intent_for_state_value(state_name: String) -> String:
	match state_name:
		"watch":
			return "observe"
		"freeze":
			return "hold_when_seen"
		"approach":
			return "approach_unseen_player"
		"pursue":
			return "pursue_player"
		"investigate":
			return "investigate_sound"
		"patrol":
			return "patrol"
		"observe":
			return "shadow_player"
		"ambush":
			return "hold_ambush"
		"anchored":
			return "remain_anchored"
		"avoid":
			return "move_away"
		"passive":
			return "remain_passive"
		"retreat":
			return "withdraw"
		"fly_patrol":
			return "aerial_patrol"
		_:
			return "wait"

func _state_retains_target(state_name: String) -> bool:
	return state_name in ["watch", "freeze", "approach", "pursue", "investigate", "observe", "ambush", "avoid", "retreat"]

func _reject(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"snapshot": get_behavior_snapshot()
	}

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

static func _is_finite_vector3_value(value: Variant) -> bool:
	if not (value is Vector3):
		return false
	var vector: Vector3 = value
	return is_finite(vector.x) and is_finite(vector.y) and is_finite(vector.z)

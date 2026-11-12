extends RefCounted
class_name BackroomsMazeStreamState

## Transactional, renderer-independent state for a streamed Backrooms maze window.
## A caller stages every new cell root first, then commits the exact staged key set.
## Existing cells are not retired until that commit succeeds.
const Layout = preload("res://systems/BackroomsMazeLayout.gd")

const SAVE_SCHEMA_VERSION: int = 1
const MAX_WORLD_SEED: int = 2147483647
const MAX_STREAM_RADIUS: int = 8
const MAX_ABS_CELL_COORD: int = 1000000
const MAX_CELL_SIZE: float = 1024.0
const VALID_LEVEL_IDS: Array[String] = [
	"Level 0", "Level 1", "Level 2", "Level 3", "Level 4", "Level 5"
]

var configured: bool = false
var level_id: String = ""
var world_seed: int = 0
var cell_size: float = 8.0
var stream_radius: int = 1
var center_cell: Vector2i = Vector2i.ZERO
var last_load_error: String = ""

var _loaded_cells: Dictionary = {}
var _generation: int = 0
var _configuration_revision: int = 0

func configure(
	destination_level: String,
	seed_value: int,
	requested_cell_size: float = 8.0,
	requested_stream_radius: int = 1
) -> bool:
	if not VALID_LEVEL_IDS.has(destination_level):
		return false
	if seed_value < 0 or seed_value > MAX_WORLD_SEED:
		return false
	if not Layout.is_valid_cell_size(requested_cell_size) or requested_cell_size > MAX_CELL_SIZE:
		return false
	if requested_stream_radius < 0 or requested_stream_radius > MAX_STREAM_RADIUS:
		return false
	if configured and level_id == destination_level and world_seed == seed_value and is_equal_approx(cell_size, requested_cell_size) and stream_radius == requested_stream_radius:
		last_load_error = ""
		return true

	level_id = destination_level
	world_seed = seed_value
	cell_size = requested_cell_size
	stream_radius = requested_stream_radius
	center_cell = Vector2i.ZERO
	_loaded_cells.clear()
	configured = true
	_configuration_revision += 1
	_generation += 1
	last_load_error = ""
	return true

func plan_window_for_position(world_position: Vector3) -> Dictionary:
	if not configured:
		return {"ok": false, "reason": "not_configured"}
	var max_world_coordinate: float = (float(MAX_ABS_CELL_COORD) + 0.5) * cell_size
	if world_position.x <= -max_world_coordinate or world_position.x >= max_world_coordinate or world_position.z <= -max_world_coordinate or world_position.z >= max_world_coordinate:
		return {"ok": false, "reason": "world_position_out_of_range"}
	var mapping: Dictionary = Layout.try_cell_for_position(world_position, cell_size)
	if not bool(mapping.get("ok", false)):
		return {"ok": false, "reason": str(mapping.get("reason", "invalid_world_position"))}
	var mapped_cell: Variant = mapping.get("cell", null)
	if not (mapped_cell is Vector2i):
		return {"ok": false, "reason": "invalid_cell_mapping"}
	var center: Vector2i = mapped_cell
	return plan_window_at_cell(center)

func plan_window_at_cell(requested_center: Vector2i) -> Dictionary:
	if not configured:
		return {"ok": false, "reason": "not_configured"}
	if requested_center.x < -MAX_ABS_CELL_COORD or requested_center.x > MAX_ABS_CELL_COORD or requested_center.y < -MAX_ABS_CELL_COORD or requested_center.y > MAX_ABS_CELL_COORD:
		return {"ok": false, "reason": "cell_out_of_range"}

	var desired_keys: Array[String] = []
	var descriptors: Array[Dictionary] = []
	var desired_lookup: Dictionary = {}
	for z in range(requested_center.y - stream_radius, requested_center.y + stream_radius + 1):
		for x in range(requested_center.x - stream_radius, requested_center.x + stream_radius + 1):
			var cell := Vector2i(x, z)
			var descriptor: Dictionary = _build_cell_descriptor(cell)
			var key: String = str(descriptor["cell_key"])
			desired_keys.append(key)
			descriptors.append(descriptor)
			desired_lookup[key] = true

	var current_keys: Array[String] = _sorted_dictionary_keys(_loaded_cells)
	var load_keys: Array[String] = []
	var keep_keys: Array[String] = []
	var unload_keys: Array[String] = []
	for key in desired_keys:
		if _loaded_cells.has(key):
			keep_keys.append(key)
		else:
			load_keys.append(key)
	for key in current_keys:
		if not desired_lookup.has(key):
			unload_keys.append(key)

	return {
		"ok": true,
		"generation": _generation,
		"configuration_revision": _configuration_revision,
		"center_cell": requested_center,
		"expected_loaded_keys": current_keys,
		"desired_cell_keys": desired_keys,
		"load_cell_keys": load_keys,
		"keep_cell_keys": keep_keys,
		"unload_cell_keys": unload_keys,
		"cell_descriptors": descriptors
	}

## Commit only after the caller has successfully staged every newly required cell.
## A partial stage, duplicate key, stale plan, or changed live window leaves state untouched.
func commit_window(plan: Dictionary, staged_cell_keys: Array) -> bool:
	if not configured or not bool(plan.get("ok", false)):
		return false
	if plan.get("generation", -1) != _generation:
		return false
	if plan.get("configuration_revision", -1) != _configuration_revision:
		return false
	var center_value: Variant = plan.get("center_cell", null)
	if not (center_value is Vector2i):
		return false

	var requested_center: Vector2i = center_value
	var expected: Dictionary = plan_window_at_cell(requested_center)
	if not bool(expected.get("ok", false)):
		return false
	for field in [
		"expected_loaded_keys",
		"desired_cell_keys",
		"load_cell_keys",
		"keep_cell_keys",
		"unload_cell_keys"
	]:
		if plan.get(field, null) != expected.get(field, null):
			return false

	var staged_lookup: Dictionary = {}
	for value in staged_cell_keys:
		if not (value is String):
			return false
		if staged_lookup.has(value):
			return false
		staged_lookup[value] = true

	var expected_staged: Dictionary = {}
	for key in expected["load_cell_keys"]:
		expected_staged[key] = true
	if staged_lookup.size() != expected_staged.size():
		return false
	for key in expected_staged.keys():
		if not staged_lookup.has(key):
			return false

	var next_loaded: Dictionary = {}
	for descriptor in expected["cell_descriptors"]:
		var key: String = str(descriptor["cell_key"])
		next_loaded[key] = descriptor.duplicate(true)

	_loaded_cells = next_loaded
	center_cell = requested_center
	_generation += 1
	return true

func get_loaded_cell_keys() -> Array[String]:
	return _sorted_dictionary_keys(_loaded_cells)

func get_loaded_cell_descriptors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in get_loaded_cell_keys():
		var descriptor: Variant = _loaded_cells.get(key, {})
		if descriptor is Dictionary:
			result.append(descriptor.duplicate(true))
	return result

func get_cell_descriptor(cell: Vector2i) -> Dictionary:
	var descriptor: Variant = _loaded_cells.get(_cell_key(cell), {})
	if descriptor is Dictionary:
		return descriptor.duplicate(true)
	return {}

func is_cell_loaded(cell: Vector2i) -> bool:
	return _loaded_cells.has(_cell_key(cell))

func get_loaded_cell_count() -> int:
	return _loaded_cells.size()

func get_center_cell() -> Vector2i:
	return center_cell

## The saved center and layout version are sufficient to rebuild the loaded window.
## Loaded Node references are intentionally never serialized.
func to_save_dict() -> Dictionary:
	if not configured:
		return {}
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"layout_algorithm_version": Layout.ALGORITHM_VERSION,
		"level_id": level_id,
		"world_seed": world_seed,
		"cell_size": cell_size,
		"stream_radius": stream_radius,
		"center_cell": [center_cell.x, center_cell.y]
	}

## Validate every field into locals before mutating the current state.
## A version mismatch fails closed; it must not silently regenerate a different maze.
func load_save_dict(payload: Dictionary) -> bool:
	last_load_error = ""
	var schema_result: Dictionary = _read_integer(payload.get("schema_version", null), SAVE_SCHEMA_VERSION, SAVE_SCHEMA_VERSION)
	if not bool(schema_result.get("ok", false)):
		return _reject_load("invalid_schema_version")
	var layout_result: Dictionary = _read_integer(
		payload.get("layout_algorithm_version", null),
		Layout.ALGORITHM_VERSION,
		Layout.ALGORITHM_VERSION
	)
	if not bool(layout_result.get("ok", false)):
		return _reject_load("unsupported_layout_algorithm_version")

	var level_value: Variant = payload.get("level_id", null)
	if not (level_value is String) or not VALID_LEVEL_IDS.has(level_value):
		return _reject_load("invalid_level_id")
	var seed_result: Dictionary = _read_integer(payload.get("world_seed", null), 0, MAX_WORLD_SEED)
	if not bool(seed_result.get("ok", false)):
		return _reject_load("invalid_world_seed")
	var radius_result: Dictionary = _read_integer(payload.get("stream_radius", null), 0, MAX_STREAM_RADIUS)
	if not bool(radius_result.get("ok", false)):
		return _reject_load("invalid_stream_radius")
	var cell_size_result: Dictionary = _read_positive_finite_number(payload.get("cell_size", null))
	if not bool(cell_size_result.get("ok", false)) or float(cell_size_result.get("value", 0.0)) > MAX_CELL_SIZE:
		return _reject_load("invalid_cell_size")

	var center_value: Variant = payload.get("center_cell", null)
	if not (center_value is Array) or center_value.size() != 2:
		return _reject_load("invalid_center_cell")
	var x_result: Dictionary = _read_integer(center_value[0], -MAX_ABS_CELL_COORD, MAX_ABS_CELL_COORD)
	var z_result: Dictionary = _read_integer(center_value[1], -MAX_ABS_CELL_COORD, MAX_ABS_CELL_COORD)
	if not bool(x_result.get("ok", false)) or not bool(z_result.get("ok", false)):
		return _reject_load("invalid_center_cell")

	var candidate_level: String = str(level_value)
	var candidate_seed: int = int(seed_result["value"])
	var candidate_radius: int = int(radius_result["value"])
	var candidate_cell_size: float = float(cell_size_result["value"])
	var candidate_center := Vector2i(int(x_result["value"]), int(z_result["value"]))

	level_id = candidate_level
	world_seed = candidate_seed
	stream_radius = candidate_radius
	cell_size = candidate_cell_size
	center_cell = candidate_center
	configured = true
	_loaded_cells.clear()
	_configuration_revision += 1
	_generation += 1
	return true

func _build_cell_descriptor(cell: Vector2i) -> Dictionary:
	var north := Vector2i(0, -1)
	var east := Vector2i(1, 0)
	var south := Vector2i(0, 1)
	var west := Vector2i(-1, 0)
	return {
		"cell_key": _cell_key(cell),
		"cell": cell,
		"world_origin": Vector3(float(cell.x) * cell_size, 0.0, float(cell.y) * cell_size),
		"level_id": level_id,
		"world_seed": world_seed,
		"layout_algorithm_version": Layout.ALGORITHM_VERSION,
		"parent_direction": Layout.parent_toward_origin(cell),
		"open_edges": {
			"north": Layout.edge_is_open(cell, north, world_seed),
			"east": Layout.edge_is_open(cell, east, world_seed),
			"south": Layout.edge_is_open(cell, south, world_seed),
			"west": Layout.edge_is_open(cell, west, world_seed)
		}
	}

static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func _sorted_dictionary_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in source.keys():
		result.append(str(key))
	result.sort()
	return result

static func _read_integer(value: Variant, minimum: int, maximum: int) -> Dictionary:
	var parsed: int
	if value is int:
		parsed = int(value)
	elif value is float:
		var numeric: float = float(value)
		if not is_finite(numeric) or floor(numeric) != numeric:
			return {"ok": false}
		parsed = int(numeric)
	else:
		return {"ok": false}
	if parsed < minimum or parsed > maximum:
		return {"ok": false}
	return {"ok": true, "value": parsed}

static func _read_positive_finite_number(value: Variant) -> Dictionary:
	if not (value is int) and not (value is float):
		return {"ok": false}
	var numeric: float = float(value)
	if not is_finite(numeric) or numeric <= 0.0:
		return {"ok": false}
	return {"ok": true, "value": numeric}

func _reject_load(reason: String) -> bool:
	last_load_error = reason
	return false

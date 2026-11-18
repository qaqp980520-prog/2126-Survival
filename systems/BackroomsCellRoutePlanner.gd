extends RefCounted
class_name BackroomsCellRoutePlanner

## Deterministic BFS over the currently loaded maze-cell window.
## This plans topology only; it never transfers entity ownership or loads cells.
const LayoutScript = preload("res://systems/BackroomsMazeLayout.gd")

const MAX_LOADED_CELL_DESCRIPTORS: int = 289
const DEFAULT_MAX_EXPANSIONS: int = MAX_LOADED_CELL_DESCRIPTORS
const MAX_WORLD_SEED: int = 2147483647
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]
const EDGE_NAMES := {
	"0,-1": "north",
	"1,0": "east",
	"0,1": "south",
	"-1,0": "west"
}
const OPPOSITE_EDGE_NAMES := {
	"north": "south",
	"east": "west",
	"south": "north",
	"west": "east"
}

static func plan_route(
	start_cell: Vector2i,
	goal_cell: Vector2i,
	cell_descriptors: Array,
	expected_level_id: String,
	expected_world_seed: int,
	max_expansions: int = DEFAULT_MAX_EXPANSIONS
) -> Dictionary:
	if expected_level_id.is_empty():
		return _failure("level_id_invalid")
	if expected_world_seed < 0 or expected_world_seed > MAX_WORLD_SEED:
		return _failure("world_seed_invalid")
	if max_expansions < 1 or max_expansions > MAX_LOADED_CELL_DESCRIPTORS:
		return _failure("search_budget_invalid")
	if cell_descriptors.is_empty() or cell_descriptors.size() > MAX_LOADED_CELL_DESCRIPTORS:
		return _failure("loaded_cell_descriptor_count_invalid")
	if not _is_cell_in_range(start_cell) or not _is_cell_in_range(goal_cell):
		return _failure("route_endpoint_out_of_range")

	var descriptors_by_key: Dictionary = {}
	for descriptor_value in cell_descriptors:
		if not (descriptor_value is Dictionary):
			return _failure("cell_descriptor_invalid")
		var descriptor: Dictionary = descriptor_value
		var cell_value: Variant = descriptor.get("cell", null)
		var key_value: Variant = descriptor.get("cell_key", null)
		var level_value: Variant = descriptor.get("level_id", null)
		var seed_value: Variant = descriptor.get("world_seed", null)
		var layout_version_value: Variant = descriptor.get("layout_algorithm_version", null)
		var edges_value: Variant = descriptor.get("open_edges", null)
		if not (cell_value is Vector2i) or not (key_value is String):
			return _failure("cell_descriptor_identity_invalid")
		var cell: Vector2i = cell_value
		var cell_key: String = str(key_value)
		if not _is_cell_in_range(cell) or cell_key != _cell_key(cell):
			return _failure("cell_descriptor_identity_invalid")
		if descriptors_by_key.has(cell_key):
			return _failure("cell_descriptor_duplicate")
		if not (level_value is String) or str(level_value) != expected_level_id:
			return _failure("cell_descriptor_level_mismatch")
		if not (seed_value is int) or int(seed_value) != expected_world_seed:
			return _failure("cell_descriptor_world_seed_mismatch")
		if not (layout_version_value is int) or int(layout_version_value) != LayoutScript.ALGORITHM_VERSION:
			return _failure("cell_descriptor_layout_version_mismatch")
		if not (edges_value is Dictionary):
			return _failure("cell_descriptor_edges_invalid")
		var edges: Dictionary = edges_value
		for direction in DIRECTIONS:
			var edge_name: String = _edge_name(direction)
			var actual_open_value: Variant = edges.get(edge_name, null)
			if not (actual_open_value is bool):
				return _failure("cell_descriptor_edges_invalid")
			var expected_open: bool = LayoutScript.edge_is_open(cell, direction, expected_world_seed)
			if bool(actual_open_value) != expected_open:
				return _failure("cell_descriptor_topology_mismatch")
		descriptors_by_key[cell_key] = descriptor.duplicate(true)

	var start_key: String = _cell_key(start_cell)
	var goal_key: String = _cell_key(goal_cell)
	if not descriptors_by_key.has(start_key):
		return _failure("start_cell_not_loaded")
	if not descriptors_by_key.has(goal_key):
		return _failure("goal_cell_not_loaded")

	var queue: Array[Vector2i] = [start_cell]
	var queue_index: int = 0
	var visited: Dictionary = {start_key: true}
	var parent_by_key: Dictionary = {}
	var expanded_count: int = 0
	while queue_index < queue.size():
		if expanded_count >= max_expansions:
			return _failure("search_budget_exceeded")
		var current_cell: Vector2i = queue[queue_index]
		queue_index += 1
		expanded_count += 1
		if current_cell == goal_cell:
			break
		var current_key: String = _cell_key(current_cell)
		var current_descriptor: Dictionary = descriptors_by_key[current_key]
		var current_edges: Dictionary = current_descriptor["open_edges"]
		for direction in DIRECTIONS:
			var edge_name: String = _edge_name(direction)
			if not bool(current_edges.get(edge_name, false)):
				continue
			var neighbor_cell: Vector2i = current_cell + direction
			var neighbor_key: String = _cell_key(neighbor_cell)
			if visited.has(neighbor_key) or not descriptors_by_key.has(neighbor_key):
				continue
			var neighbor_descriptor: Dictionary = descriptors_by_key[neighbor_key]
			var neighbor_edges: Dictionary = neighbor_descriptor["open_edges"]
			var opposite_name: String = str(OPPOSITE_EDGE_NAMES[edge_name])
			if not bool(neighbor_edges.get(opposite_name, false)):
				return _failure("shared_edge_topology_mismatch")
			visited[neighbor_key] = true
			parent_by_key[neighbor_key] = {
				"previous_cell": current_cell,
				"direction": direction
			}
			queue.append(neighbor_cell)

	if not visited.has(goal_key):
		return _failure("no_route_in_loaded_window")

	var reversed_cells: Array[Vector2i] = [goal_cell]
	var reversed_directions: Array[Vector2i] = []
	var cursor: Vector2i = goal_cell
	while cursor != start_cell:
		var cursor_key: String = _cell_key(cursor)
		var parent_value: Variant = parent_by_key.get(cursor_key, null)
		if not (parent_value is Dictionary):
			return _failure("route_reconstruction_failed")
		var parent_record: Dictionary = parent_value
		var previous_value: Variant = parent_record.get("previous_cell", null)
		var direction_value: Variant = parent_record.get("direction", null)
		if not (previous_value is Vector2i) or not (direction_value is Vector2i):
			return _failure("route_reconstruction_failed")
		cursor = previous_value
		reversed_cells.append(cursor)
		reversed_directions.append(direction_value)
		if reversed_cells.size() > descriptors_by_key.size():
			return _failure("route_reconstruction_cycle")

	reversed_cells.reverse()
	reversed_directions.reverse()
	var cell_keys: Array[String] = []
	for cell in reversed_cells:
		cell_keys.append(_cell_key(cell))
	return {
		"ok": true,
		"cell_path": reversed_cells,
		"cell_keys": cell_keys,
		"edge_directions": reversed_directions,
		"route_cell_count": reversed_cells.size(),
		"expanded_count": expanded_count,
		"level_id": expected_level_id,
		"world_seed": expected_world_seed,
		"layout_algorithm_version": LayoutScript.ALGORITHM_VERSION
	}

static func _is_cell_in_range(cell: Vector2i) -> bool:
	return (
		cell.x >= -LayoutScript.MAX_ABS_CELL_COORD
		and cell.x <= LayoutScript.MAX_ABS_CELL_COORD
		and cell.y >= -LayoutScript.MAX_ABS_CELL_COORD
		and cell.y <= LayoutScript.MAX_ABS_CELL_COORD
	)

static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func _edge_name(direction: Vector2i) -> String:
	var direction_key: String = "%d,%d" % [direction.x, direction.y]
	return str(EDGE_NAMES.get(direction_key, ""))

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

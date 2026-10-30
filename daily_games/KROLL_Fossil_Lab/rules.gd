extends RefCounted

const BOARD_SIZE: int = 5
const PIECE_COUNT: int = 4

static func get_scenario_count() -> int:
	return 3

static func get_scenario(index: int) -> Dictionary:
	var scenarios: Array[Dictionary] = [
		{
			"name": "DOCKSIDE HADROSAUR",
			"solution": [
				{"piece_index": 0, "anchor": Vector2i(0, 0), "rotation": 0},
				{"piece_index": 1, "anchor": Vector2i(3, 0), "rotation": 0},
				{"piece_index": 2, "anchor": Vector2i(0, 3), "rotation": 0},
				{"piece_index": 3, "anchor": Vector2i(3, 3), "rotation": 0}
			]
		},
		{
			"name": "RIDGE RAPTOR",
			"solution": [
				{"piece_index": 0, "anchor": Vector2i(0, 0), "rotation": 1},
				{"piece_index": 1, "anchor": Vector2i(2, 0), "rotation": 1},
				{"piece_index": 2, "anchor": Vector2i(0, 3), "rotation": 2},
				{"piece_index": 3, "anchor": Vector2i(3, 3), "rotation": 3}
			]
		},
		{
			"name": "FLOODPLAIN TRICERATOPS",
			"solution": [
				{"piece_index": 0, "anchor": Vector2i(0, 0), "rotation": 2},
				{"piece_index": 1, "anchor": Vector2i(3, 0), "rotation": 3},
				{"piece_index": 2, "anchor": Vector2i(0, 3), "rotation": 1},
				{"piece_index": 3, "anchor": Vector2i(3, 3), "rotation": 2}
			]
		}
	]
	return scenarios[posmod(index, scenarios.size())].duplicate(true)

static func get_piece_name(piece_index: int) -> String:
	var names: Array[String] = ["RIB", "JAW", "HIP", "CLAW"]
	return names[posmod(piece_index, names.size())]

static func get_piece_shape(piece_index: int) -> Array[Vector2i]:
	match posmod(piece_index, PIECE_COUNT):
		0:
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
		1:
			return [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
		2:
			return [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
		_:
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]

static func get_piece_cells(piece_index: int, rotation: int, anchor: Vector2i) -> Array[Vector2i]:
	var shape: Array[Vector2i] = get_piece_shape(piece_index)
	var rotated: Array[Vector2i] = []
	for cell in shape:
		var point: Vector2i = cell
		for turn in range(posmod(rotation, 4)):
			point = Vector2i(-point.y, point.x)
		rotated.append(point)
	var min_x: int = rotated[0].x
	var min_y: int = rotated[0].y
	for point in rotated:
		min_x = mini(min_x, point.x)
		min_y = mini(min_y, point.y)
	for index in range(rotated.size()):
		rotated[index] = rotated[index] - Vector2i(min_x, min_y) + anchor
	return rotated

static func get_target_cells(scenario: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary = {}
	for entry in scenario.get("solution", []):
		var piece_index: int = int(entry.get("piece_index", -1))
		var anchor: Vector2i = entry.get("anchor", Vector2i(-1, -1))
		var rotation: int = int(entry.get("rotation", 0))
		for cell in get_piece_cells(piece_index, rotation, anchor):
			if not seen.has(cell):
				seen[cell] = true
				result.append(cell)
	return result

static func create_state(scenario_index: int) -> Dictionary:
	return {
		"scenario_index": posmod(scenario_index, get_scenario_count()),
		"placements": {},
		"rotations": [0, 0, 0, 0],
		"selected_piece": 0,
		"cursor": Vector2i(0, 0),
		"moves": 0,
		"status": "active"
	}

static func select_piece(state: Dictionary, piece_index: int) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if piece_index >= 0 and piece_index < PIECE_COUNT:
		next["selected_piece"] = piece_index
	return next

static func set_cursor(state: Dictionary, cursor: Vector2i) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	next["cursor"] = Vector2i(clampi(cursor.x, 0, BOARD_SIZE - 1), clampi(cursor.y, 0, BOARD_SIZE - 1))
	return next

static func move_cursor(state: Dictionary, delta: Vector2i) -> Dictionary:
	return set_cursor(state, state.get("cursor", Vector2i.ZERO) + delta)

static func rotate_selected(state: Dictionary, direction: int) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var selected: int = int(next.get("selected_piece", -1))
	if selected < 0 or selected >= PIECE_COUNT or next.get("placements", {}).has(selected):
		return next
	var rotations: Array = next.get("rotations", [0, 0, 0, 0]).duplicate()
	rotations[selected] = posmod(int(rotations[selected]) + direction, 4)
	next["rotations"] = rotations
	return next

static func get_occupied_cells(state: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary = {}
	var placements: Dictionary = state.get("placements", {})
	for key in placements.keys():
		var placement: Dictionary = placements[key]
		for cell in get_piece_cells(int(key), int(placement.get("rotation", 0)), placement.get("anchor", Vector2i.ZERO)):
			if not seen.has(cell):
				seen[cell] = true
				result.append(cell)
	return result

static func can_place(state: Dictionary, scenario: Dictionary, piece_index: int, anchor: Vector2i, rotation: int) -> bool:
	if str(state.get("status", "active")) != "active":
		return false
	if piece_index < 0 or piece_index >= PIECE_COUNT or state.get("placements", {}).has(piece_index):
		return false
	var target_lookup: Dictionary = {}
	for cell in get_target_cells(scenario):
		target_lookup[cell] = true
	var occupied_lookup: Dictionary = {}
	for cell in get_occupied_cells(state):
		occupied_lookup[cell] = true
	for cell in get_piece_cells(piece_index, rotation, anchor):
		if cell.x < 0 or cell.y < 0 or cell.x >= BOARD_SIZE or cell.y >= BOARD_SIZE:
			return false
		if not target_lookup.has(cell) or occupied_lookup.has(cell):
			return false
	return true

static func place_selected(state: Dictionary, scenario: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var selected: int = int(next.get("selected_piece", -1))
	var cursor: Vector2i = next.get("cursor", Vector2i.ZERO)
	var rotations: Array = next.get("rotations", [0, 0, 0, 0])
	var rotation: int = int(rotations[selected]) if selected >= 0 and selected < rotations.size() else 0
	if not can_place(next, scenario, selected, cursor, rotation):
		return next
	var placements: Dictionary = next.get("placements", {}).duplicate(true)
	placements[selected] = {"anchor": cursor, "rotation": rotation}
	next["placements"] = placements
	next["moves"] = int(next.get("moves", 0)) + 1
	if is_won(next, scenario):
		next["status"] = "won"
	return next

static func remove_selected(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var selected: int = int(next.get("selected_piece", -1))
	var placements: Dictionary = next.get("placements", {}).duplicate(true)
	if placements.erase(selected):
		next["placements"] = placements
		next["status"] = "active"
	return next

static func is_won(state: Dictionary, scenario: Dictionary) -> bool:
	var placements: Dictionary = state.get("placements", {})
	if placements.size() != PIECE_COUNT:
		return false
	var occupied: Array[Vector2i] = get_occupied_cells(state)
	var target: Array[Vector2i] = get_target_cells(scenario)
	if occupied.size() != target.size():
		return false
	for cell in target:
		if not occupied.has(cell):
			return false
	return true

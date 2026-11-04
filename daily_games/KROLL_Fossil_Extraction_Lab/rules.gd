extends RefCounted

const GRID_SIZE: int = 8
const STARTING_ACTIONS: int = 16
const STARTING_INTEGRITY: int = 100
const FOSSIL_CHISEL_DAMAGE: int = 20
const MISSIONS: Array = [
	{
		"name": "Triceratops Horn",
		"center": Vector2i(3, 3),
		"fossils": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3), Vector2i(3, 4)]
	},
	{
		"name": "Ammonite Coil",
		"center": Vector2i(5, 2),
		"fossils": [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 3), Vector2i(5, 3)]
	},
	{
		"name": "Raptor Claw",
		"center": Vector2i(3, 3),
		"fossils": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)]
	}
]

static func mission_count() -> int:
	return MISSIONS.size()

static func mission_at(index: int) -> Dictionary:
	var safe_index: int = clampi(index, 0, MISSIONS.size() - 1)
	return MISSIONS[safe_index].duplicate(true)

static func new_state(index: int = 0, score: int = 0, awarded: Array = []) -> Dictionary:
	var safe_index: int = clampi(index, 0, MISSIONS.size() - 1)
	var mission: Dictionary = mission_at(safe_index)
	var awards: Array = awarded.duplicate(true)
	if awards.size() != MISSIONS.size():
		awards = [false, false, false]
	return {
		"mission_index": safe_index,
		"mission_name": str(mission["name"]),
		"center": mission["center"],
		"fossil_cells": mission["fossils"].duplicate(true),
		"grid": _build_grid(mission, safe_index),
		"actions_left": STARTING_ACTIONS,
		"actions_used": 0,
		"integrity": STARTING_INTEGRITY,
		"air_charges": 1,
		"chisel_charges": 2,
		"scan_charges": 2,
		"last_scan": {},
		"exposed_count": 0,
		"mission_score": 0,
		"campaign_score": maxi(0, score),
		"awarded": awards,
		"status": "active"
	}

static func _build_grid(mission: Dictionary, mission_index: int) -> Array:
	var fossil_lookup: Dictionary = {}
	for fossil_cell in mission["fossils"]:
		fossil_lookup[fossil_cell] = true
	var grid: Array = []
	for y in range(GRID_SIZE):
		var row: Array = []
		for x in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			var depth: int = 1 + posmod(x * 3 + y * 5 + mission_index, 2)
			if fossil_lookup.has(cell):
				depth = 2
			row.append({
				"depth": depth,
				"fossil": fossil_lookup.has(cell),
				"exposed": false
			})
		grid.append(row)
	return grid

static func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_SIZE and cell.y >= 0 and cell.y < GRID_SIZE

static func cell_at(state: Dictionary, cell: Vector2i) -> Dictionary:
	if not is_inside(cell):
		return {}
	var grid: Array = state.get("grid", [])
	if grid.size() != GRID_SIZE:
		return {}
	var row: Array = grid[cell.y]
	if row.size() != GRID_SIZE:
		return {}
	return row[cell.x].duplicate(true)

static func exposed_count(state: Dictionary) -> int:
	var count: int = 0
	for cell in state.get("fossil_cells", []):
		var data: Dictionary = cell_at(state, cell)
		if bool(data.get("exposed", false)):
			count += 1
	return count

static func apply_tool(state: Dictionary, tool: String, cell: Vector2i) -> Dictionary:
	if str(state.get("status", "active")) != "active":
		return _rejected(state, "mission_not_active")
	if not is_inside(cell):
		return _rejected(state, "outside_grid")
	var next_state: Dictionary = state.duplicate(true)
	var grid: Array = next_state["grid"]
	var data: Dictionary = grid[cell.y][cell.x]
	var reason: String = ""

	match tool:
		"brush":
			if int(data["depth"]) <= 0:
				return _rejected(state, "no_sediment")
			data["depth"] = int(data["depth"]) - 1
			_update_exposed(data)
			reason = "brush_complete"
		"air":
			if int(next_state["air_charges"]) <= 0:
				return _rejected(state, "no_air_charges")
			var changed: int = 0
			var air_grid: Array = next_state["grid"]
			for y in range(maxi(0, cell.y - 1), mini(GRID_SIZE, cell.y + 2)):
				for x in range(maxi(0, cell.x - 1), mini(GRID_SIZE, cell.x + 2)):
					var nearby: Dictionary = air_grid[y][x]
					if int(nearby["depth"]) > 0:
						nearby["depth"] = int(nearby["depth"]) - 1
						_update_exposed(nearby)
						changed += 1
			if changed == 0:
				return _rejected(state, "no_sediment")
			next_state["air_charges"] = int(next_state["air_charges"]) - 1
			reason = "air_complete"
		"chisel":
			if int(next_state["chisel_charges"]) <= 0:
				return _rejected(state, "no_chisel_charges")
			if int(data["depth"]) <= 0:
				return _rejected(state, "no_sediment")
			if bool(data["fossil"]):
				next_state["integrity"] = maxi(0, int(next_state["integrity"]) - FOSSIL_CHISEL_DAMAGE)
			data["depth"] = maxi(0, int(data["depth"]) - 2)
			_update_exposed(data)
			next_state["chisel_charges"] = int(next_state["chisel_charges"]) - 1
			reason = "chisel_complete"
		"scan":
			if int(next_state["scan_charges"]) <= 0:
				return _rejected(state, "no_scan_charges")
			var nearby_fossils: int = 0
			for fossil_cell in next_state["fossil_cells"]:
				if absi(fossil_cell.x - cell.x) <= 1 and absi(fossil_cell.y - cell.y) <= 1:
					nearby_fossils += 1
			next_state["scan_charges"] = int(next_state["scan_charges"]) - 1
			next_state["last_scan"] = {"cell": cell, "fossil_count": nearby_fossils}
			reason = "scan_complete"
		_:
			return _rejected(state, "unknown_tool")

	next_state["actions_left"] = int(next_state["actions_left"]) - 1
	next_state["actions_used"] = int(next_state["actions_used"]) + 1
	next_state["exposed_count"] = exposed_count(next_state)
	_resolve_status(next_state)
	return {"state": next_state, "accepted": true, "reason": reason}

static func _update_exposed(data: Dictionary) -> void:
	data["exposed"] = bool(data["fossil"]) and int(data["depth"]) == 0

static func _resolve_status(state: Dictionary) -> void:
	if int(state["integrity"]) <= 0:
		state["status"] = "failed"
		state["mission_score"] = 0
		return
	if int(state["exposed_count"]) == state["fossil_cells"].size():
		state["status"] = "complete"
		var score: int = 0
		if int(state["integrity"]) >= 90 and int(state["actions_used"]) <= 8:
			score = 100
		elif int(state["integrity"]) >= 70:
			score = 75
		state["mission_score"] = score
		var awards: Array = state["awarded"]
		var mission_index: int = int(state["mission_index"])
		if not bool(awards[mission_index]):
			awards[mission_index] = true
			state["campaign_score"] = int(state["campaign_score"]) + score
		return
	if int(state["actions_left"]) <= 0:
		state["status"] = "failed"

static func next_mission(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "complete":
		return {"state": state, "accepted": false, "reason": "mission_not_complete"}
	var next_index: int = int(state["mission_index"]) + 1
	if next_index >= MISSIONS.size():
		var completed: Dictionary = state.duplicate(true)
		completed["status"] = "campaign_complete"
		return {"state": completed, "accepted": true, "reason": "campaign_complete"}
	return {
		"state": new_state(next_index, int(state["campaign_score"]), state["awarded"]),
		"accepted": true,
		"reason": "next_mission"
	}

static func restart_mission(state: Dictionary) -> Dictionary:
	return new_state(int(state.get("mission_index", 0)), int(state.get("campaign_score", 0)), state.get("awarded", []))

static func restart_campaign() -> Dictionary:
	return new_state(0, 0, [false, false, false])

static func _rejected(state: Dictionary, reason: String) -> Dictionary:
	return {"state": state, "accepted": false, "reason": reason}

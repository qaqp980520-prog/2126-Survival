extends RefCounted
class_name KROLLOrbitalSurveyorRules

const MISSIONS: Array[Dictionary] = [
	{
		"id":"ice_ridge",
		"name":"Ice Ridge Survey",
		"battery":25,
		"grid":[
			"S......",
			".##....",
			"...A...",
			"...~#..",
			"..B....",
			"....C..",
			"......."
		]
	},
	{
		"id":"crater_belt",
		"name":"Crater Belt Relay",
		"battery":30,
		"grid":[
			"S..#...",
			".~.#...",
			".~.#B..",
			".#.....",
			".#A.#..",
			"...#C..",
			"......."
		]
	},
	{
		"id":"basalt_shadow",
		"name":"Basalt Shadow",
		"battery":24,
		"grid":[
			"S......",
			".~##...",
			"...A...",
			".#..~..",
			".B~#...",
			"...C...",
			"......."
		]
	}
]

static func mission_count() -> int:
	return MISSIONS.size()

static func mission_at(index: int) -> Dictionary:
	if index < 0 or index >= MISSIONS.size():
		return {}
	return MISSIONS[index].duplicate(true)

static func new_state() -> Dictionary:
	return {
		"mission_index":0,
		"mission_state":_new_mission_state(0),
		"completed":[false,false,false],
		"score":0,
		"status":"active"
	}

static func perform_action(state: Dictionary, action: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "active")) != "active":
		return _rejected(next, "campaign_finished")

	var mission_index: int = int(next.get("mission_index", -1))
	if mission_index < 0 or mission_index >= MISSIONS.size():
		return _rejected(next, "invalid_mission")

	if action == "next":
		var current: Dictionary = next.get("mission_state", {}).duplicate(true)
		if str(current.get("status", "")) != "won":
			return _rejected(next, "mission_not_complete")
		if mission_index >= MISSIONS.size() - 1:
			return _rejected(next, "campaign_finished")
		next["mission_index"] = mission_index + 1
		next["mission_state"] = _new_mission_state(mission_index + 1)
		return {"accepted":true,"state":next,"reason":"next_mission"}

	var current_state: Dictionary = next.get("mission_state", {}).duplicate(true)
	var result: Dictionary = _perform_mission_action(current_state, mission_index, action)
	if not bool(result.get("accepted", false)):
		return _rejected(next, str(result.get("reason", "action_rejected")))

	current_state = result.get("state", current_state)
	next["mission_state"] = current_state
	var mission_status: String = str(current_state.get("status", "active"))
	if mission_status == "won":
		var completed: Array = next.get("completed", []).duplicate(true)
		if not bool(completed[mission_index]):
			completed[mission_index] = true
			next["completed"] = completed
			next["score"] = int(next.get("score", 0)) + 100
		if mission_index == MISSIONS.size() - 1:
			next["status"] = "won"
	elif mission_status == "lost":
		next["status"] = "lost"

	return {"accepted":true,"state":next,"reason":str(result.get("reason", "action_accepted"))}

static func _new_mission_state(index: int) -> Dictionary:
	var mission: Dictionary = mission_at(index)
	var battery: int = int(mission.get("battery", 0))
	return {
		"x":0,
		"y":0,
		"battery":battery,
		"initial_battery":battery,
		"scanned":{"A":false,"B":false,"C":false},
		"actions":0,
		"status":"active"
	}

static func _perform_mission_action(state: Dictionary, mission_index: int, action: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "active")) != "active":
		return {"accepted":false,"state":next,"reason":"mission_finished"}

	var mission: Dictionary = mission_at(mission_index)
	var grid: Array = mission.get("grid", [])
	var x: int = int(next.get("x", 0))
	var y: int = int(next.get("y", 0))
	var battery: int = int(next.get("battery", 0))

	if action == "scan":
		var tile: String = _tile_at(grid, x, y)
		if not ["A","B","C"].has(tile):
			return {"accepted":false,"state":next,"reason":"not_on_beacon"}
		var scanned: Dictionary = next.get("scanned", {}).duplicate(true)
		if bool(scanned.get(tile, false)):
			return {"accepted":false,"state":next,"reason":"already_scanned"}
		if battery < 1:
			next["battery"] = 0
			next["status"] = "lost"
			return {"accepted":true,"state":next,"reason":"battery_depleted"}
		next["battery"] = battery - 1
		next["actions"] = int(next.get("actions", 0)) + 1
		scanned[tile] = true
		next["scanned"] = scanned
		_update_mission_status(next)
		return {"accepted":true,"state":next,"reason":"beacon_scanned"}

	var dx: int = 0
	var dy: int = 0
	match action:
		"move_up":
			dy = -1
		"move_down":
			dy = 1
		"move_left":
			dx = -1
		"move_right":
			dx = 1
		_:
			return {"accepted":false,"state":next,"reason":"unknown_action"}

	var nx: int = x + dx
	var ny: int = y + dy
	if nx < 0 or ny < 0 or ny >= grid.size() or nx >= 7:
		return {"accepted":false,"state":next,"reason":"outside_map"}
	var target: String = _tile_at(grid, nx, ny)
	if target == "#":
		return {"accepted":false,"state":next,"reason":"blocked"}
	var energy_cost: int = 2 if target == "~" else 1
	if battery < energy_cost:
		next["battery"] = 0
		next["status"] = "lost"
		return {"accepted":true,"state":next,"reason":"battery_depleted"}

	next["x"] = nx
	next["y"] = ny
	next["battery"] = battery - energy_cost
	next["actions"] = int(next.get("actions", 0)) + 1
	_update_mission_status(next)
	return {"accepted":true,"state":next,"reason":"moved"}

static func _update_mission_status(state: Dictionary) -> void:
	var scanned: Dictionary = state.get("scanned", {})
	var all_scanned: bool = bool(scanned.get("A", false)) and bool(scanned.get("B", false)) and bool(scanned.get("C", false))
	if int(state.get("x", -1)) == 0 and int(state.get("y", -1)) == 0 and all_scanned:
		state["status"] = "won"
	elif int(state.get("battery", 0)) <= 0:
		state["status"] = "lost"

static func _tile_at(grid: Array, x: int, y: int) -> String:
	if y < 0 or y >= grid.size():
		return ""
	var row: String = str(grid[y])
	if x < 0 or x >= row.length():
		return ""
	return row.substr(x, 1)

static func _rejected(state: Dictionary, reason: String) -> Dictionary:
	return {"accepted":false,"state":state,"reason":reason}

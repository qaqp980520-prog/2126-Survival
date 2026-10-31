extends RefCounted
class_name EchoMapperRules

const GRID_SIZE: int = 9
const MAX_TURNS: int = 60
const MAX_SONAR_CHARGES: int = 6
const SONAR_RADIUS: int = 3
const SONAR_DURATION: int = 5

const LEVELS: Array[Dictionary] = [
	{
		"id": "dockside_echo",
		"title": "Dockside Echo",
		"rows": [
			"#########",
			"#S..#...#",
			"#.#.#.#.#",
			"#.#...#.#",
			"#.###.#.#",
			"#.....#.#",
			"###.#...#",
			"#...###E#",
			"#########"
		],
		"start": Vector2i(1, 1),
		"exit": Vector2i(7, 7),
		"beacons": [Vector2i(3, 1), Vector2i(5, 3), Vector2i(5, 5)]
	},
	{
		"id": "coolant_echo",
		"title": "Coolant Echo",
		"rows": [
			"#########",
			"#S..#...#",
			"#.#.#.#.#",
			"#...#...#",
			"###...#.#",
			"#...#...#",
			"#.#.#.#.#",
			"#......E#",
			"#########"
		],
		"start": Vector2i(1, 1),
		"exit": Vector2i(7, 7),
		"beacons": [Vector2i(3, 3), Vector2i(5, 4), Vector2i(7, 5)]
	},
	{
		"id": "archive_echo",
		"title": "Archive Echo",
		"rows": [
			"#########",
			"#S......#",
			"#.###.#.#",
			"#...#...#",
			"###.#.###",
			"#...#...#",
			"#.#...#.#",
			"#......E#",
			"#########"
		],
		"start": Vector2i(1, 1),
		"exit": Vector2i(7, 7),
		"beacons": [Vector2i(5, 1), Vector2i(3, 3), Vector2i(5, 5)]
	}
]

static func get_level_count() -> int:
	return LEVELS.size()

static func get_level_title(level_index: int) -> String:
	var index: int = clampi(level_index, 0, LEVELS.size() - 1)
	return str(LEVELS[index].get("title", "Unknown Sector"))

static func new_game(level_index: int = 0) -> Dictionary:
	var index: int = clampi(level_index, 0, LEVELS.size() - 1)
	var level: Dictionary = LEVELS[index]
	var start: Vector2i = level["start"]
	return {
		"level_index": index,
		"level_id": str(level["id"]),
		"rows": level["rows"].duplicate(),
		"player": start,
		"exit": level["exit"],
		"beacons": level["beacons"].duplicate(),
		"collected": [],
		"visited": [start],
		"revealed_until": {},
		"turns": 0,
		"sonar_charges": MAX_SONAR_CHARGES,
		"status": "playing",
		"message": "Find three signal beacons, then reach the extraction hatch."
	}

static func is_wall(state: Dictionary, cell: Vector2i) -> bool:
	var rows: Array = state.get("rows", [])
	if cell.x < 0 or cell.y < 0 or cell.y >= rows.size():
		return true
	var row_text: String = str(rows[cell.y])
	if cell.x >= row_text.length():
		return true
	return row_text.substr(cell.x, 1) == "#"

static func is_cell_visible(state: Dictionary, cell: Vector2i) -> bool:
	var visited: Array = state.get("visited", [])
	if visited.has(cell):
		return true
	var revealed_until: Dictionary = state.get("revealed_until", {})
	return int(revealed_until.get(cell, -1)) >= int(state.get("turns", 0))

static func apply_action(state: Dictionary, action: String) -> Dictionary:
	if state.is_empty() or not state.has("player") or not state.has("rows"):
		return _result(false, "invalid_state", state)
	if str(state.get("status", "")) != "playing":
		return _result(false, "terminal", state)

	var next: Dictionary = state.duplicate(true)
	if action == "ping":
		var charges: int = int(next.get("sonar_charges", 0))
		if charges <= 0:
			return _result(false, "no_sonar_charge", state)
		next["turns"] = int(next.get("turns", 0)) + 1
		next["sonar_charges"] = charges - 1
		var revealed_until: Dictionary = next.get("revealed_until", {})
		var player: Vector2i = next.get("player", Vector2i.ZERO)
		for y in range(maxi(0, player.y - SONAR_RADIUS), mini(GRID_SIZE - 1, player.y + SONAR_RADIUS) + 1):
			for x in range(maxi(0, player.x - SONAR_RADIUS), mini(GRID_SIZE - 1, player.x + SONAR_RADIUS) + 1):
				var cell := Vector2i(x, y)
				if absi(cell.x - player.x) + absi(cell.y - player.y) <= SONAR_RADIUS:
					revealed_until[cell] = int(next["turns"]) + SONAR_DURATION
		next["revealed_until"] = revealed_until
		next["message"] = "SONAR PING: nearby walls and signal beacons are mapped."
		_resolve_terminal(next)
		return _result(true, "ping", next)

	var direction := Vector2i.ZERO
	match action:
		"up":
			direction = Vector2i(0, -1)
		"right":
			direction = Vector2i(1, 0)
		"down":
			direction = Vector2i(0, 1)
		"left":
			direction = Vector2i(-1, 0)
		_:
			return _result(false, "invalid_action", state)

	var destination: Vector2i = Vector2i(state["player"]) + direction
	next["turns"] = int(next.get("turns", 0)) + 1
	if is_wall(state, destination):
		var revealed_until: Dictionary = next.get("revealed_until", {})
		revealed_until[destination] = int(next["turns"]) + 2
		next["revealed_until"] = revealed_until
		next["message"] = "ECHO BLOCKED: a solid wall is directly ahead."
		_resolve_terminal(next)
		return _result(true, "blocked", next)

	next["player"] = destination
	var visited: Array = next.get("visited", [])
	if not visited.has(destination):
		visited.append(destination)
	next["visited"] = visited
	var collected: Array = next.get("collected", [])
	var beacons: Array = next.get("beacons", [])
	if beacons.has(destination) and not collected.has(destination):
		collected.append(destination)
		next["message"] = "SIGNAL BEACON RECOVERED: %d / %d." % [collected.size(), beacons.size()]
	else:
		next["message"] = "Movement confirmed. Use sonar to reveal nearby routes."
	next["collected"] = collected
	_resolve_terminal(next)
	return _result(true, "moved", next)

static func _resolve_terminal(state: Dictionary) -> void:
	var collected: Array = state.get("collected", [])
	var beacons: Array = state.get("beacons", [])
	if state.get("player", Vector2i(-1, -1)) == state.get("exit", Vector2i(-2, -2)) and collected.size() == beacons.size():
		state["status"] = "won"
		state["message"] = "EXTRACTION COMPLETE. All three signal beacons recovered."
	elif int(state.get("turns", 0)) >= MAX_TURNS:
		state["status"] = "failed"
		state["message"] = "MAPPING WINDOW EXPIRED. Restart and plan a shorter route."
	else:
		state["status"] = "playing"

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "state": state.duplicate(true)}

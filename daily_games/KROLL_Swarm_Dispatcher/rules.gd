extends RefCounted
class_name KROLLSwarmDispatcherRules

const GRID_SIZE: int = 8
const DRONE_COUNT: int = 3
const MAX_COMMANDS: int = 24
const ACTIONS: Array[String] = ["up", "down", "left", "right", "wait"]
const OFFSETS: Dictionary = {
	"up": Vector2i(0, -1),
	"down": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
	"wait": Vector2i.ZERO
}
const LEVELS: Array[Dictionary] = [
	{
		"id": "dockside_weave",
		"title": "DOCKSIDE WEAVE",
		"starts": [Vector2i(1, 1), Vector2i(6, 1), Vector2i(1, 6)],
		"goals": [Vector2i(6, 6), Vector2i(1, 6), Vector2i(6, 1)],
		"walls": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)]
	},
	{
		"id": "relay_split",
		"title": "RELAY SPLIT",
		"starts": [Vector2i(1, 1), Vector2i(6, 1), Vector2i(3, 6)],
		"goals": [Vector2i(6, 1), Vector2i(1, 6), Vector2i(6, 6)],
		"walls": [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(5, 4), Vector2i(5, 5)]
	},
	{
		"id": "core_exchange",
		"title": "CORE EXCHANGE",
		"starts": [Vector2i(1, 6), Vector2i(6, 6), Vector2i(3, 1)],
		"goals": [Vector2i(6, 1), Vector2i(1, 1), Vector2i(3, 6)],
		"walls": [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 4)]
	}
]

func get_level_count() -> int:
	return LEVELS.size()

func get_drone_count() -> int:
	return DRONE_COUNT

func get_max_commands() -> int:
	return MAX_COMMANDS

func get_title_text() -> String:
	return "KROLL // SWARM DISPATCHER"

func get_level_definition(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return LEVELS[index].duplicate(true)

func create_state(index: int, campaign_score: int = 0, completed: Array = []) -> Dictionary:
	var level: Dictionary = get_level_definition(index)
	if level.is_empty() or campaign_score < 0:
		return {}
	var completed_levels: Array[int] = []
	for value in completed:
		if value is int and int(value) >= 0 and int(value) < LEVELS.size() and not completed_levels.has(int(value)):
			completed_levels.append(int(value))
	var programs: Array = [[], [], []]
	var cursors: Array[int] = [0, 0, 0]
	return {
		"level_index": index,
		"level_id": str(level["id"]),
		"status": "playing",
		"campaign_score": campaign_score,
		"score": 0,
		"completed_levels": completed_levels,
		"positions": level["starts"].duplicate(true),
		"programs": programs,
		"cursors": cursors,
		"tick": 0
	}

func append_action(state: Dictionary, drone_index: int, action: String) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "level_not_playing"}
	if drone_index < 0 or drone_index >= DRONE_COUNT:
		return {"ok": false, "reason": "invalid_drone"}
	if not ACTIONS.has(action):
		return {"ok": false, "reason": "invalid_action"}
	var next: Dictionary = state.duplicate(true)
	var programs: Array = next.get("programs", [])
	var program: Array = programs[drone_index].duplicate(true)
	if program.size() >= MAX_COMMANDS:
		return {"ok": false, "reason": "program_limit"}
	program.append(action)
	programs[drone_index] = program
	next["programs"] = programs
	return {"ok": true, "state": next}

func undo_action(state: Dictionary, drone_index: int) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "level_not_playing"}
	if drone_index < 0 or drone_index >= DRONE_COUNT:
		return {"ok": false, "reason": "invalid_drone"}
	var next: Dictionary = state.duplicate(true)
	var programs: Array = next.get("programs", [])
	var cursors: Array = next.get("cursors", [])
	var program: Array = programs[drone_index].duplicate(true)
	if program.size() <= int(cursors[drone_index]):
		return {"ok": false, "reason": "no_pending_command"}
	program.pop_back()
	programs[drone_index] = program
	next["programs"] = programs
	return {"ok": true, "state": next}

func clear_program(state: Dictionary, drone_index: int) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "level_not_playing"}
	if drone_index < 0 or drone_index >= DRONE_COUNT:
		return {"ok": false, "reason": "invalid_drone"}
	var next: Dictionary = state.duplicate(true)
	var programs: Array = next.get("programs", [])
	var cursors: Array = next.get("cursors", [])
	var program: Array = programs[drone_index]
	var retained: Array = []
	for index in range(mini(int(cursors[drone_index]), program.size())):
		retained.append(program[index])
	programs[drone_index] = retained
	next["programs"] = programs
	return {"ok": true, "state": next}

func step_tick(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "level_not_playing"}
	var level: Dictionary = get_level_definition(int(state.get("level_index", -1)))
	if level.is_empty():
		return {"ok": false, "reason": "invalid_level"}
	var positions: Array = state.get("positions", [])
	var programs: Array = state.get("programs", [])
	var cursors: Array = state.get("cursors", [])
	var walls: Array = level.get("walls", [])
	var targets: Array = []
	var consumed: Array = [false, false, false]
	var has_command: bool = false
	for index in range(DRONE_COUNT):
		var target: Vector2i = positions[index]
		var cursor: int = int(cursors[index])
		var program: Array = programs[index]
		if cursor < program.size():
			has_command = true
			var action: String = str(program[cursor])
			if not ACTIONS.has(action):
				return {"ok": false, "reason": "invalid_action", "drone": index}
			target = target + OFFSETS[action]
			if action != "wait" and (
				target.x <= 0 or target.y <= 0
				or target.x >= GRID_SIZE - 1 or target.y >= GRID_SIZE - 1
				or walls.has(target)
			):
				return {"ok": false, "reason": "blocked_by_obstacle", "drone": index}
			consumed[index] = true
		targets.append(target)
	if not has_command:
		return {"ok": false, "reason": "no_commands"}
	for first_index in range(DRONE_COUNT):
		for second_index in range(first_index + 1, DRONE_COUNT):
			if targets[first_index] == targets[second_index]:
				return {"ok": false, "reason": "collision_same_target", "first_drone": first_index, "second_drone": second_index}
			if (
				bool(consumed[first_index]) and bool(consumed[second_index])
				and targets[first_index] == positions[second_index]
				and targets[second_index] == positions[first_index]
				and targets[first_index] != positions[first_index]
			):
				return {"ok": false, "reason": "head_on_swap", "first_drone": first_index, "second_drone": second_index}
	var next: Dictionary = state.duplicate(true)
	next["positions"] = targets.duplicate(true)
	var next_cursors: Array = cursors.duplicate(true)
	for index in range(DRONE_COUNT):
		if bool(consumed[index]):
			next_cursors[index] = int(next_cursors[index]) + 1
	next["cursors"] = next_cursors
	next["tick"] = int(next.get("tick", 0)) + 1
	var goals: Array = level.get("goals", [])
	var all_at_goals: bool = true
	var all_commands_consumed: bool = true
	for index in range(DRONE_COUNT):
		if next["positions"][index] != goals[index]:
			all_at_goals = false
		if int(next_cursors[index]) < (next["programs"][index] as Array).size():
			all_commands_consumed = false
	if all_at_goals and all_commands_consumed:
		next["status"] = "passed"
		next["score"] = 100
		var completed_levels: Array = next.get("completed_levels", []).duplicate(true)
		var level_index: int = int(next.get("level_index", -1))
		if not completed_levels.has(level_index):
			completed_levels.append(level_index)
		next["completed_levels"] = completed_levels
	return {"ok": true, "state": next, "tick": int(next["tick"])}

func run_all(state: Dictionary) -> Dictionary:
	var current: Dictionary = state.duplicate(true)
	for _index in range(MAX_COMMANDS + 1):
		if str(current.get("status", "")) != "playing":
			return {"ok": true, "state": current}
		var result: Dictionary = step_tick(current)
		if not bool(result.get("ok", false)):
			if str(result.get("reason", "")) == "no_commands":
				return {"ok": true, "state": current, "reason": "programs_exhausted"}
			return result
		current = result["state"]
		if str(current.get("status", "")) == "passed":
			return {"ok": true, "state": current}
	return {"ok": false, "reason": "execution_limit"}

func restart_level(state: Dictionary) -> Dictionary:
	var status: String = str(state.get("status", ""))
	if status == "passed" or status == "campaign_complete":
		return {"ok": false, "reason": "completed_level_locked"}
	var level_index: int = int(state.get("level_index", -1))
	var next: Dictionary = create_state(level_index, int(state.get("campaign_score", 0)), state.get("completed_levels", []))
	if next.is_empty():
		return {"ok": false, "reason": "invalid_level"}
	return {"ok": true, "state": next}

func advance_level(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "passed":
		return {"ok": false, "reason": "level_not_passed"}
	var index: int = int(state.get("level_index", -1))
	if index < 0 or index >= LEVELS.size():
		return {"ok": false, "reason": "invalid_level"}
	var completed: Array = state.get("completed_levels", []).duplicate(true)
	if not completed.has(index):
		completed.append(index)
	var total: int = int(state.get("campaign_score", 0)) + int(state.get("score", 0))
	if index + 1 >= LEVELS.size():
		return {
			"ok": true,
			"state": {
				"level_index": index,
				"level_id": "campaign",
				"status": "campaign_complete",
				"campaign_score": total,
				"total_score": total,
				"score": int(state.get("score", 0)),
				"completed_levels": completed,
				"positions": [],
				"programs": [[], [], []],
				"cursors": [0, 0, 0],
				"tick": 0
			}
		}
	return {"ok": true, "state": create_state(index + 1, total, completed)}

func restart_campaign() -> Dictionary:
	return {"ok": true, "state": create_state(0)}

func get_remaining_commands(state: Dictionary) -> int:
	var total: int = 0
	var programs: Array = state.get("programs", [])
	var cursors: Array = state.get("cursors", [])
	for index in range(mini(programs.size(), cursors.size())):
		total += maxi(0, (programs[index] as Array).size() - int(cursors[index]))
	return total

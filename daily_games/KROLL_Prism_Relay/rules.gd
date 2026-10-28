extends RefCounted
class_name PrismRelayRules

const WIDTH := 7
const HEIGHT := 7
const MIRROR_SLASH := 1
const MIRROR_BACKSLASH := 2
const MAX_TURNS := 18

static func create_puzzle(index: int) -> Dictionary:
	var puzzle_index := posmod(index, 3)
	var mirror_b := MIRROR_SLASH
	var mirror_c := MIRROR_BACKSLASH
	if puzzle_index == 1:
		mirror_b = MIRROR_BACKSLASH
	elif puzzle_index == 2:
		mirror_c = MIRROR_SLASH
	return {
		"puzzle_index": puzzle_index,
		"source": Vector2i(0, 3),
		"target": Vector2i(5, 1),
		"walls": {"4,2": true, "4,4": true, "6,4": true, "3,1": true, "3,6": true},
		"mirrors": {"2,3": MIRROR_BACKSLASH, "2,5": mirror_b, "5,5": mirror_c},
		"turns_left": MAX_TURNS,
		"moves": 0,
		"status": "playing",
		"message": "Rotate the mirrors to guide the beam into the receiver."
	}

static func trace_beam(state: Dictionary) -> Dictionary:
	var source: Vector2i = state.get("source", Vector2i.ZERO)
	var target: Vector2i = state.get("target", Vector2i(-1, -1))
	var walls: Dictionary = state.get("walls", {})
	var mirrors: Dictionary = state.get("mirrors", {})
	var position := source
	var direction := Vector2i.RIGHT
	var path: Array[Vector2i] = []
	var visited_states: Dictionary = {}
	var hit_target := false
	var looped := false
	var stopped_by_wall := false
	for _step in range(WIDTH * HEIGHT * 4):
		position += direction
		if not _inside(position):
			break
		path.append(position)
		if position == target:
			hit_target = true
			break
		var key := _key(position.x, position.y)
		if walls.has(key):
			stopped_by_wall = true
			break
		if mirrors.has(key):
			var state_key := key + ":" + str(direction.x) + ":" + str(direction.y)
			if visited_states.has(state_key):
				looped = true
				break
			visited_states[state_key] = true
			direction = _reflect(direction, int(mirrors[key]))
	return {"path": path, "hit_target": hit_target, "looped": looped, "stopped_by_wall": stopped_by_wall}

static func apply_rotation(state: Dictionary, mirror_key: String) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	if str(next_state.get("status", "playing")) != "playing":
		return {"ok": false, "reason": "terminal", "state": next_state}
	var turns_left := int(next_state.get("turns_left", 0))
	if turns_left <= 0:
		next_state["status"] = "failed"
		next_state["message"] = "Power budget exhausted. Reset or choose another relay."
		return {"ok": false, "reason": "no_turns", "state": next_state}
	var mirrors: Dictionary = next_state.get("mirrors", {})
	if not mirrors.has(mirror_key):
		return {"ok": false, "reason": "not_a_mirror", "state": next_state}
	var orientation := int(mirrors[mirror_key])
	if orientation == MIRROR_SLASH:
		mirrors[mirror_key] = MIRROR_BACKSLASH
	elif orientation == MIRROR_BACKSLASH:
		mirrors[mirror_key] = MIRROR_SLASH
	else:
		return {"ok": false, "reason": "invalid_mirror", "state": next_state}
	next_state["mirrors"] = mirrors
	next_state["turns_left"] = turns_left - 1
	next_state["moves"] = int(next_state.get("moves", 0)) + 1
	var trace := trace_beam(next_state)
	if bool(trace.get("hit_target", false)):
		next_state["status"] = "won"
		next_state["message"] = "Receiver powered. Relay restored!"
	elif int(next_state["turns_left"]) <= 0:
		next_state["status"] = "failed"
		next_state["message"] = "Power budget exhausted. Reset or choose another relay."
	else:
		next_state["message"] = "Beam traced. Adjust a mirror and try again."
	return {"ok": true, "reason": "rotated", "state": next_state, "trace": trace}

static func _reflect(direction: Vector2i, orientation: int) -> Vector2i:
	if orientation == MIRROR_SLASH:
		return Vector2i(-direction.y, -direction.x)
	return Vector2i(direction.y, direction.x)

static func _inside(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < WIDTH and position.y >= 0 and position.y < HEIGHT

static func _key(x: int, y: int) -> String:
	return str(x) + "," + str(y)

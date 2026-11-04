extends RefCounted

const GRID_SIZE: int = 9
const MOVE_COST: int = 1
const PING_COST: int = 2
const MAX_PINGS: int = 3
const DIRECTIONS: Array[Vector2i] = [
    Vector2i(0, -1),
    Vector2i(1, 0),
    Vector2i(0, 1),
    Vector2i(-1, 0)
]
const MISSION_DATA: Array = [
    {
        "name": "Trench Alpha",
        "start": [1, 7],
        "target": [7, 1],
        "walls": [[2, 6], [2, 5], [3, 5], [4, 5], [5, 5], [6, 3], [6, 2], [4, 2]],
        "battery": 48,
        "par_battery": 12
    },
    {
        "name": "Abyssal Relay",
        "start": [1, 1],
        "target": [7, 7],
        "walls": [[2, 1], [2, 2], [2, 3], [4, 3], [5, 3], [6, 3], [6, 4], [3, 6], [4, 6]],
        "battery": 52,
        "par_battery": 14
    },
    {
        "name": "Blackwater Vault",
        "start": [4, 8],
        "target": [4, 0],
        "walls": [[3, 6], [4, 6], [5, 6], [3, 4], [4, 4], [5, 4], [2, 2], [6, 2]],
        "battery": 48,
        "par_battery": 12
    }
]

static func mission_count() -> int:
    return MISSION_DATA.size()

static func mission_at(index: int) -> Dictionary:
    var safe_index: int = clampi(index, 0, MISSION_DATA.size() - 1)
    var raw: Dictionary = MISSION_DATA[safe_index]
    var result: Dictionary = raw.duplicate(true)
    var start_values: Array = raw["start"]
    var target_values: Array = raw["target"]
    result["start_cell"] = Vector2i(int(start_values[0]), int(start_values[1]))
    result["target_cell"] = Vector2i(int(target_values[0]), int(target_values[1]))
    var walls: Array[Vector2i] = []
    for entry in raw["walls"]:
        var values: Array = entry
        walls.append(Vector2i(int(values[0]), int(values[1])))
    result["walls"] = walls
    return result

static func new_state(index: int = 0, score: int = 0, awarded: Array = []) -> Dictionary:
    var safe_index: int = clampi(index, 0, MISSION_DATA.size() - 1)
    var mission: Dictionary = mission_at(safe_index)
    var awards: Array = awarded.duplicate(true)
    if awards.size() != MISSION_DATA.size():
        awards = [false, false, false]
    return {
        "mission_index": safe_index,
        "mission_name": str(mission["name"]),
        "start": mission["start_cell"],
        "player": mission["start_cell"],
        "target": mission["target_cell"],
        "walls": mission["walls"].duplicate(true),
        "battery": int(mission["battery"]),
        "battery_limit": int(mission["battery"]),
        "par_battery": int(mission["par_battery"]),
        "pings_left": MAX_PINGS,
        "ping_log": [],
        "moves": 0,
        "sonar_used": 0,
        "carrying": false,
        "status": "active",
        "campaign_score": maxi(0, score),
        "awarded": awards
    }

static func is_inside(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.x < GRID_SIZE and cell.y >= 0 and cell.y < GRID_SIZE

static func is_passable(mission: Dictionary, cell: Vector2i) -> bool:
    if not is_inside(cell):
        return false
    var walls: Array = mission.get("walls", [])
    return not walls.has(cell)

static func find_path(mission: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
    var path: Array[Vector2i] = []
    if not is_passable(mission, start) or not is_passable(mission, goal):
        return path
    var queue: Array[Vector2i] = [start]
    var parents: Dictionary = {}
    var visited: Dictionary = {start: true}
    var head: int = 0
    while head < queue.size():
        var current: Vector2i = queue[head]
        head += 1
        if current == goal:
            break
        for direction in DIRECTIONS:
            var next_cell: Vector2i = current + direction
            if not is_passable(mission, next_cell) or visited.has(next_cell):
                continue
            visited[next_cell] = true
            parents[next_cell] = current
            queue.append(next_cell)
    if not visited.has(goal):
        return path
    var cursor: Vector2i = goal
    path.push_front(cursor)
    while cursor != start:
        if not parents.has(cursor):
            return []
        cursor = parents[cursor]
        path.push_front(cursor)
    return path

static func direction_for_delta(delta: Vector2i) -> String:
    if delta == Vector2i(0, -1):
        return "up"
    if delta == Vector2i(1, 0):
        return "right"
    if delta == Vector2i(0, 1):
        return "down"
    if delta == Vector2i(-1, 0):
        return "left"
    return ""

static func bearing(from_cell: Vector2i, target_cell: Vector2i) -> String:
    var dx: int = target_cell.x - from_cell.x
    var dy: int = target_cell.y - from_cell.y
    if dx == 0 and dy < 0:
        return "N"
    if dx > 0 and dy < 0:
        return "NE"
    if dx > 0 and dy == 0:
        return "E"
    if dx > 0 and dy > 0:
        return "SE"
    if dx == 0 and dy > 0:
        return "S"
    if dx < 0 and dy > 0:
        return "SW"
    if dx < 0 and dy == 0:
        return "W"
    if dx < 0 and dy < 0:
        return "NW"
    return "OVERLAP"

static func distance_band(from_cell: Vector2i, target_cell: Vector2i) -> String:
    var distance: int = absi(target_cell.x - from_cell.x) + absi(target_cell.y - from_cell.y)
    if distance <= 2:
        return "NEAR"
    if distance <= 5:
        return "MID"
    return "FAINT"

static func move(state: Dictionary, direction: String) -> Dictionary:
    var next_state: Dictionary = state.duplicate(true)
    if str(next_state.get("status", "")) != "active":
        return {"accepted": false, "reason": "mission_not_active", "state": next_state}
    var delta := Vector2i.ZERO
    match direction:
        "up":
            delta = Vector2i(0, -1)
        "right":
            delta = Vector2i(1, 0)
        "down":
            delta = Vector2i(0, 1)
        "left":
            delta = Vector2i(-1, 0)
        _:
            return {"accepted": false, "reason": "invalid_direction", "state": next_state}
    var next_cell: Vector2i = next_state["player"] + delta
    var mission: Dictionary = mission_at(int(next_state["mission_index"]))
    if not is_passable(mission, next_cell):
        return {"accepted": false, "reason": "blocked", "state": next_state}
    if int(next_state["battery"]) < MOVE_COST:
        next_state["status"] = "failed"
        return {"accepted": false, "reason": "battery_depleted", "state": next_state}
    next_state["battery"] = int(next_state["battery"]) - MOVE_COST
    next_state["moves"] = int(next_state["moves"]) + 1
    next_state["player"] = next_cell
    return {"accepted": true, "reason": "moved", "state": next_state}

static func ping(state: Dictionary) -> Dictionary:
    var next_state: Dictionary = state.duplicate(true)
    if str(next_state.get("status", "")) != "active":
        return {"accepted": false, "reason": "mission_not_active", "state": next_state}
    if int(next_state["pings_left"]) <= 0:
        return {"accepted": false, "reason": "no_pings_left", "state": next_state}
    if int(next_state["battery"]) < PING_COST:
        return {"accepted": false, "reason": "insufficient_battery", "state": next_state}
    var player: Vector2i = next_state["player"]
    var target: Vector2i = next_state["target"]
    var clue := {
        "origin": player,
        "bearing": bearing(player, target),
        "band": distance_band(player, target),
        "ping_number": int(next_state["sonar_used"]) + 1
    }
    next_state["battery"] = int(next_state["battery"]) - PING_COST
    next_state["pings_left"] = int(next_state["pings_left"]) - 1
    next_state["sonar_used"] = int(next_state["sonar_used"]) + 1
    var log: Array = next_state["ping_log"].duplicate(true)
    log.append(clue)
    next_state["ping_log"] = log
    return {"accepted": true, "reason": "echo_received", "clue": clue, "state": next_state}

static func interact(state: Dictionary) -> Dictionary:
    var next_state: Dictionary = state.duplicate(true)
    if str(next_state.get("status", "")) != "active":
        return {"accepted": false, "reason": "mission_not_active", "state": next_state}
    var player: Vector2i = next_state["player"]
    if not bool(next_state["carrying"]):
        if player != next_state["target"]:
            return {"accepted": false, "reason": "beacon_not_here", "state": next_state}
        next_state["carrying"] = true
        return {"accepted": true, "reason": "beacon_secured", "state": next_state}
    if player != next_state["start"]:
        return {"accepted": false, "reason": "return_to_sub", "state": next_state}
    var index: int = int(next_state["mission_index"])
    var awards: Array = next_state["awarded"].duplicate(true)
    if not bool(awards[index]):
        var points: int = 100 if int(next_state["battery"]) >= int(next_state["par_battery"]) else 75
        next_state["campaign_score"] = int(next_state["campaign_score"]) + points
        awards[index] = true
    next_state["awarded"] = awards
    next_state["status"] = "complete"
    return {"accepted": true, "reason": "mission_complete", "state": next_state}

static func next_mission(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "complete":
        return {"accepted": false, "reason": "mission_not_complete", "state": state.duplicate(true)}
    var index: int = int(state["mission_index"])
    if index >= MISSION_DATA.size() - 1:
        var victory_state: Dictionary = state.duplicate(true)
        victory_state["status"] = "victory"
        return {"accepted": true, "reason": "campaign_complete", "state": victory_state}
    return {"accepted": true, "reason": "next_mission", "state": new_state(index + 1, int(state["campaign_score"]), state["awarded"])}

static func restart_mission(state: Dictionary) -> Dictionary:
    return new_state(int(state.get("mission_index", 0)), int(state.get("campaign_score", 0)), state.get("awarded", []))

static func restart_campaign() -> Dictionary:
    return new_state()

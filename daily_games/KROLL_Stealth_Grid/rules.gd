extends RefCounted
class_name KROLLStealthGridRules

const LEVELS = [
    {
        "name": "Service Spine",
        "rows": [
            "#########",
            "#S....K##",
            "#.###...#",
            "#..G.#.E#",
            "#.###...#",
            "#.......#",
            "#########",
            "#########",
            "#########"
        ],
        "start": Vector2i(1, 1),
        "keys": [Vector2i(6, 1)],
        "exit": Vector2i(7, 3),
        "guards": [
            {"path": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 3), Vector2i(2, 3)]}
        ]
    },
    {
        "name": "Split Relay",
        "rows": [
            "#########",
            "#S..#..K#",
            "#.#.#.#.#",
            "#.....#.#",
            "#.G#G...#",
            "#.....#E#",
            "#.#.#.#.#",
            "#.......#",
            "#########"
        ],
        "start": Vector2i(1, 1),
        "keys": [Vector2i(7, 1)],
        "exit": Vector2i(7, 5),
        "guards": [
            {"path": [Vector2i(2, 4), Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5)]},
            {"path": [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(5, 4)]}
        ]
    },
    {
        "name": "Black Archive",
        "rows": [
            "#########",
            "#S...#..#",
            "#.#..#K.#",
            "#.#.....#",
            "#.G#G...#",
            "#...#...#",
            "#...#.#E#",
            "#K......#",
            "#########"
        ],
        "start": Vector2i(1, 1),
        "keys": [Vector2i(6, 2), Vector2i(1, 7)],
        "exit": Vector2i(7, 6),
        "guards": [
            {"path": [Vector2i(2, 4), Vector2i(2, 5), Vector2i(3, 5), Vector2i(2, 5)]},
            {"path": [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(5, 4)]}
        ]
    }
]

func get_level_count() -> int:
    return LEVELS.size()

func get_level_data(level_index: int) -> Dictionary:
    if level_index < 0 or level_index >= LEVELS.size():
        return {}
    return LEVELS[level_index].duplicate(true)

func create_state(level_index: int = 0, prior_score: int = 0, rewarded_levels: Array = []) -> Dictionary:
    var safe_index: int = clampi(level_index, 0, LEVELS.size() - 1)
    var level: Dictionary = get_level_data(safe_index)
    var guard_states: Array = []
    for guard_data_value in level["guards"]:
        var guard_data: Dictionary = guard_data_value
        var path: Array = guard_data["path"].duplicate()
        guard_states.append({
            "path": path,
            "index": 0,
            "position": path[0],
            "facing": Vector2i.ZERO
        })
    return {
        "level_index": safe_index,
        "level": level,
        "player": level["start"],
        "keys_collected": [],
        "guard_states": guard_states,
        "turn": 0,
        "score": prior_score,
        "rewarded_levels": rewarded_levels.duplicate(),
        "failed": false,
        "complete": false,
        "campaign_complete": false,
        "message": "Collect every access key, then reach the exit."
    }

func attempt_move(state: Dictionary, direction: Vector2i) -> Dictionary:
    if state.is_empty() or bool(state.get("failed", false)) or bool(state.get("complete", false)):
        return {"ok": false, "reason": "terminal"}
    if abs(direction.x) + abs(direction.y) > 1:
        return {"ok": false, "reason": "invalid_direction"}
    var level: Dictionary = state["level"]
    var rows: Array = level["rows"]
    var next_position: Vector2i = state["player"] + direction
    if _is_wall(rows, next_position):
        return {"ok": false, "reason": "blocked"}

    state["player"] = next_position
    var keys_collected: Array = state["keys_collected"].duplicate()
    var keys: Array = level["keys"]
    for key_index in range(keys.size()):
        if next_position == keys[key_index] and not keys_collected.has(key_index):
            keys_collected.append(key_index)
    state["keys_collected"] = keys_collected

    var guards: Array = state["guard_states"]
    for guard_index in range(guards.size()):
        var guard: Dictionary = guards[guard_index].duplicate(true)
        var path: Array = guard["path"]
        var old_position: Vector2i = guard["position"]
        var next_index: int = (int(guard["index"]) + 1) % path.size()
        var new_position: Vector2i = path[next_index]
        guard["index"] = next_index
        guard["position"] = new_position
        guard["facing"] = _unit_direction(new_position - old_position)
        guards[guard_index] = guard
    state["guard_states"] = guards
    state["turn"] = int(state["turn"]) + 1

    if _is_player_detected(state):
        state["failed"] = true
        state["message"] = "ALARM: a patrol has detected you. Restart the file."
        return {"ok": true, "detected": true, "complete": false}

    if next_position == level["exit"] and keys_collected.size() == keys.size():
        var level_index: int = int(state["level_index"])
        var rewarded: Array = state["rewarded_levels"].duplicate()
        if not rewarded.has(level_index):
            rewarded.append(level_index)
            state["score"] = int(state["score"]) + 100
        state["rewarded_levels"] = rewarded
        state["complete"] = true
        state["campaign_complete"] = level_index == LEVELS.size() - 1
        state["message"] = "FILE CLEARED. " + ("CAMPAIGN COMPLETE." if state["campaign_complete"] else "Proceed to the next sector.")
        return {"ok": true, "detected": false, "complete": true}

    if next_position == level["exit"] and keys_collected.size() < keys.size():
        state["message"] = "Exit locked: collect all access keys."
    else:
        state["message"] = "Move quietly. Patrols advance after every action."
    return {"ok": true, "detected": false, "complete": false}

func _is_player_detected(state: Dictionary) -> bool:
    var level: Dictionary = state["level"]
    var rows: Array = level["rows"]
    var player: Vector2i = state["player"]
    for guard_value in state["guard_states"]:
        var guard: Dictionary = guard_value
        var guard_position: Vector2i = guard["position"]
        if guard_position == player:
            return true
        var facing: Vector2i = guard["facing"]
        if facing == Vector2i.ZERO:
            continue
        for distance in range(1, 5):
            var sight_position: Vector2i = guard_position + facing * distance
            if _is_wall(rows, sight_position):
                break
            if sight_position == player:
                return true
    return false

func _is_wall(rows: Array, position: Vector2i) -> bool:
    if position.y < 0 or position.y >= rows.size():
        return true
    var row: String = str(rows[position.y])
    if position.x < 0 or position.x >= row.length():
        return true
    return row.substr(position.x, 1) == "#"

func _unit_direction(delta: Vector2i) -> Vector2i:
    return Vector2i(signi(delta.x), signi(delta.y))

func render_tile(state: Dictionary, position: Vector2i) -> String:
    var level: Dictionary = state["level"]
    var rows: Array = level["rows"]
    if _is_wall(rows, position):
        return "#"
    if position == state["player"]:
        return "P"
    for guard_value in state["guard_states"]:
        var guard: Dictionary = guard_value
        if position == guard["position"]:
            return "G"
    var keys: Array = level["keys"]
    var collected: Array = state["keys_collected"]
    for key_index in range(keys.size()):
        if position == keys[key_index] and not collected.has(key_index):
            return "K"
    if position == level["exit"]:
        return "E"
    var tile: String = str(rows[position.y]).substr(position.x, 1)
    return "." if tile == "S" or tile == "G" else tile

func get_collected_key_count(state: Dictionary) -> int:
    return state.get("keys_collected", []).size()

func can_advance(state: Dictionary) -> bool:
    return bool(state.get("complete", false)) and int(state.get("level_index", 0)) < LEVELS.size() - 1

func next_level(state: Dictionary) -> Dictionary:
    if not can_advance(state):
        return state.duplicate(true)
    return create_state(
        int(state["level_index"]) + 1,
        int(state["score"]),
        state["rewarded_levels"]
    )

func restart_level(state: Dictionary) -> Dictionary:
    if state.is_empty():
        return create_state()
    return create_state(
        int(state["level_index"]),
        int(state["score"]),
        state["rewarded_levels"]
    )

func restart_campaign() -> Dictionary:
    return create_state(0, 0, [])

func get_level_name(state: Dictionary) -> String:
    return str(state.get("level", {}).get("name", "Unknown Sector"))

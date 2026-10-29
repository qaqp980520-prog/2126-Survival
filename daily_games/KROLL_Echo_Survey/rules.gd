extends RefCounted
class_name KrollEchoSurveyRules

const GRID_SIZE := 8
const TARGET_CACHES := 3
const STARTING_BATTERY := 16
const STARTING_OXYGEN := 56
const PING_BATTERY_COST := 2
const LAYOUTS := [
    [
        "S.......",
        ".##.#...",
        "...#..C.",
        "#....#..",
        "..C.....",
        "....##..",
        "..#..C..",
        "........"
    ],
    [
        "S..#....",
        "...#..C.",
        "##......",
        "...C.#..",
        "......#.",
        ".#....C.",
        "........",
        "...#...."
    ],
    [
        "S.......",
        "..##....",
        "...#..C.",
        "...#....",
        "C.......",
        "...##...",
        "......C.",
        "........"
    ]
]

static func new_game(seed_value: int = 11) -> Dictionary:
    var layout_index: int = _layout_index(seed_value)
    return {
        "seed": seed_value,
        "map": LAYOUTS[layout_index].duplicate(true),
        "x": 0,
        "y": 0,
        "battery": STARTING_BATTERY,
        "oxygen": STARTING_OXYGEN,
        "caches_found": 0,
        "moves": 0,
        "status": "playing",
        "message": "Scan the seabed, recover three caches, then return to extraction.",
        "revealed": {"0,0": true},
        "collected": {}
    }

static func next_seed(seed_value: int) -> int:
    if seed_value == 11:
        return 23
    if seed_value == 23:
        return 37
    return 11

static func move(state: Dictionary, dx: int, dy: int) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    if abs(dx) + abs(dy) != 1:
        return _result(false, "invalid_direction", state)
    var nx: int = int(state.get("x", -1)) + dx
    var ny: int = int(state.get("y", -1)) + dy
    if not _in_bounds(nx, ny):
        return _result(false, "out_of_bounds", state)
    var next: Dictionary = state.duplicate(true)
    next["oxygen"] = maxi(0, int(next.get("oxygen", 0)) - 1)
    next["moves"] = int(next.get("moves", 0)) + 1
    var tile: String = _tile_at(next, nx, ny)
    if tile == "#":
        _reveal(next, nx, ny)
        next["message"] = "ROCK WALL. The ping maps the obstruction; route around it."
        _resolve_terminal(next)
        return _result(true, "blocked", next)
    next["x"] = nx
    next["y"] = ny
    _reveal_neighborhood(next, nx, ny, 1)
    if tile == "C":
        var key: String = _key(nx, ny)
        var collected: Dictionary = next.get("collected", {}).duplicate(true)
        if not collected.has(key):
            collected[key] = true
            next["collected"] = collected
            next["caches_found"] = int(next.get("caches_found", 0)) + 1
            next["message"] = "SALVAGE SECURED: %d/%d" % [int(next["caches_found"]), TARGET_CACHES]
        else:
            next["message"] = "Already recovered. Return to the extraction beacon."
    else:
        next["message"] = "Sector mapped. Keep an eye on oxygen."
    _resolve_terminal(next)
    return _result(true, "moved", next)

static func ping(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    if int(state.get("battery", 0)) < PING_BATTERY_COST:
        return _result(false, "battery_empty", state)
    if int(state.get("oxygen", 0)) <= 0:
        return _result(false, "oxygen_empty", state)
    var next: Dictionary = state.duplicate(true)
    next["battery"] = int(next.get("battery", 0)) - PING_BATTERY_COST
    next["oxygen"] = maxi(0, int(next.get("oxygen", 0)) - 1)
    next["moves"] = int(next.get("moves", 0)) + 1
    _reveal_neighborhood(next, int(next.get("x", 0)), int(next.get("y", 0)), 2)
    next["message"] = "SONAR PING. Two battery units spent; nearby terrain revealed."
    _resolve_terminal(next)
    return _result(true, "pinged", next)

static func display_tile(state: Dictionary, x: int, y: int) -> String:
    if not _in_bounds(x, y):
        return ""
    if not is_revealed(state, x, y):
        return "?"
    var tile: String = _tile_at(state, x, y)
    var collected: Dictionary = state.get("collected", {})
    if tile == "C" and bool(collected.get(_key(x, y), false)):
        return "✓"
    return tile

static func is_revealed(state: Dictionary, x: int, y: int) -> bool:
    return bool(state.get("revealed", {}).get(_key(x, y), false))

static func _resolve_terminal(state: Dictionary) -> void:
    if int(state.get("oxygen", 0)) <= 0:
        state["status"] = "failed"
        state["message"] = "OXYGEN DEPLETED. Survey aborted."
    elif int(state.get("caches_found", 0)) >= TARGET_CACHES and int(state.get("x", -1)) == 0 and int(state.get("y", -1)) == 0:
        state["status"] = "won"
        state["message"] = "EXTRACTION COMPLETE. All three caches recovered."

static func _reveal_neighborhood(state: Dictionary, center_x: int, center_y: int, radius: int) -> void:
    for y in range(maxi(0, center_y - radius), mini(GRID_SIZE - 1, center_y + radius) + 1):
        for x in range(maxi(0, center_x - radius), mini(GRID_SIZE - 1, center_x + radius) + 1):
            if absi(x - center_x) + absi(y - center_y) <= radius:
                _reveal(state, x, y)

static func _reveal(state: Dictionary, x: int, y: int) -> void:
    var revealed: Dictionary = state.get("revealed", {}).duplicate(true)
    revealed[_key(x, y)] = true
    state["revealed"] = revealed

static func _tile_at(state: Dictionary, x: int, y: int) -> String:
    var rows_value: Variant = state.get("map", null)
    if not (rows_value is Array) or y < 0 or y >= rows_value.size():
        return "?"
    var row: String = str(rows_value[y])
    if x < 0 or x >= row.length():
        return "?"
    return row.substr(x, 1)

static func _layout_index(seed_value: int) -> int:
    if seed_value == 11:
        return 0
    if seed_value == 23:
        return 1
    if seed_value == 37:
        return 2
    return posmod(seed_value, LAYOUTS.size())

static func _in_bounds(x: int, y: int) -> bool:
    return x >= 0 and y >= 0 and x < GRID_SIZE and y < GRID_SIZE

static func _key(x: int, y: int) -> String:
    return "%d,%d" % [x, y]

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
    return {"ok": ok, "reason": reason, "state": state.duplicate(true)}

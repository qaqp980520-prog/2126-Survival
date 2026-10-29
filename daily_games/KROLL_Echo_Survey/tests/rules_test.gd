extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
    var first := Rules.new_game(11)
    var repeated := Rules.new_game(11)
    assert(first["map"] == repeated["map"], "A fixed seed must reproduce the same layout")
    assert(first["x"] == 0 and first["y"] == 0)
    assert(first["battery"] == Rules.STARTING_BATTERY)
    assert(first["oxygen"] == Rules.STARTING_OXYGEN)
    assert(Rules.next_seed(11) == 23 and Rules.next_seed(23) == 37 and Rules.next_seed(37) == 11)

    for seed_value in [11, 23, 37]:
        var state: Dictionary = Rules.new_game(seed_value)
        var rows: Array = state["map"]
        var caches: Array[Vector2i] = []
        for y in range(Rules.GRID_SIZE):
            assert(str(rows[y]).length() == Rules.GRID_SIZE)
            for x in range(Rules.GRID_SIZE):
                if str(rows[y]).substr(x, 1) == "C":
                    caches.append(Vector2i(x, y))
        assert(caches.size() == Rules.TARGET_CACHES, "Each layout must contain exactly three caches")
        for cache in caches:
            var route_from_start: Array[Vector2i] = _find_path(rows, Vector2i(0, 0), cache)
            assert(not route_from_start.is_empty(), "Every cache must be reachable in every layout")

        var route_state: Dictionary = state
        for cache in caches:
            var travel_path: Array[Vector2i] = _find_path(rows, Vector2i(int(route_state["x"]), int(route_state["y"])), cache)
            for step in travel_path:
                var delta: Vector2i = step - Vector2i(int(route_state["x"]), int(route_state["y"]))
                var moved: Dictionary = Rules.move(route_state, delta.x, delta.y)
                assert(bool(moved["ok"]), "A computed open-cell route must be traversable")
                route_state = moved["state"]
                assert(str(route_state["status"]) == "playing", "Oxygen budget must support the cache route")
        var return_route: Array[Vector2i] = _find_path(rows, Vector2i(int(route_state["x"]), int(route_state["y"])), Vector2i(0, 0))
        for step in return_route:
            var delta: Vector2i = step - Vector2i(int(route_state["x"]), int(route_state["y"]))
            route_state = Rules.move(route_state, delta.x, delta.y)["state"]
        assert(int(route_state["caches_found"]) == Rules.TARGET_CACHES)
        assert(str(route_state["status"]) == "won", "All caches plus a return to extraction must win")

    var ping := Rules.ping(first)
    assert(bool(ping["ok"]) and str(ping["reason"]) == "pinged")
    assert(int(ping["state"]["battery"]) == Rules.STARTING_BATTERY - Rules.PING_BATTERY_COST)
    assert(int(ping["state"]["oxygen"]) == Rules.STARTING_OXYGEN - 1)
    assert(Rules.is_revealed(ping["state"], 2, 0), "Ping reveals cells at Manhattan distance two")
    assert(not Rules.is_revealed(ping["state"], 3, 0), "Ping does not reveal beyond its radius")

    var collision_state: Dictionary = Rules.new_game(11)
    var moved := Rules.move(collision_state, 1, 0)
    assert(bool(moved["ok"]) and int(moved["state"]["x"]) == 1)
    var oxygen_before: int = int(moved["state"]["oxygen"])
    var blocked := Rules.move(moved["state"], 0, 1)
    assert(bool(blocked["ok"]) and str(blocked["reason"]) == "blocked")
    assert(int(blocked["state"]["x"]) == 1 and int(blocked["state"]["y"]) == 0, "Rock must block movement")
    assert(int(blocked["state"]["oxygen"]) == oxygen_before - 1, "Attempting an unknown rock still costs oxygen")
    assert(Rules.is_revealed(blocked["state"], 1, 1), "Collision reveals the rock")
    var invalid_move := Rules.move(collision_state, 1, 1)
    assert(not bool(invalid_move["ok"]) and invalid_move["state"] == collision_state, "Diagonal movement must not mutate state")
    var low_battery: Dictionary = collision_state.duplicate(true)
    low_battery["battery"] = 1
    var rejected_ping := Rules.ping(low_battery)
    assert(not bool(rejected_ping["ok"]) and rejected_ping["state"] == low_battery, "Insufficient battery must be a no-op")
    var oxygen_empty: Dictionary = Rules.new_game(11)
    oxygen_empty["oxygen"] = 1
    var exhausted := Rules.ping(oxygen_empty)
    assert(str(exhausted["state"]["status"]) == "failed", "The last oxygen unit must end the run")
    var terminal := Rules.move(exhausted["state"], 1, 0)
    assert(not bool(terminal["ok"]), "Terminal states reject further moves")

    print("KROLL Echo Survey rules tests passed.")
    quit(0)

func _find_path(rows: Array, start: Vector2i, target: Vector2i) -> Array[Vector2i]:
    if start == target:
        return []
    var queue: Array[Vector2i] = [start]
    var parent: Dictionary = {}
    parent[_key(start)] = ""
    var position_by_key: Dictionary = {}
    var cursor_index: int = 0
    while cursor_index < queue.size():
        var current: Vector2i = queue[cursor_index]
        cursor_index += 1
        if current == target:
            break
        for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var candidate: Vector2i = current + direction
            if candidate.x < 0 or candidate.y < 0 or candidate.x >= Rules.GRID_SIZE or candidate.y >= Rules.GRID_SIZE:
                continue
            if str(rows[candidate.y]).substr(candidate.x, 1) == "#":
                continue
            var key: String = _key(candidate)
            if parent.has(key):
                continue
            parent[key] = _key(current)
            position_by_key[key] = candidate
            queue.append(candidate)
    var target_key: String = _key(target)
    if not parent.has(target_key):
        return []
    var path: Array[Vector2i] = []
    var cursor: String = target_key
    while cursor != _key(start):
        path.push_front(position_by_key[cursor])
        cursor = str(parent[cursor])
    return path

func _key(point: Vector2i) -> String:
    return "%d,%d" % [point.x, point.y]

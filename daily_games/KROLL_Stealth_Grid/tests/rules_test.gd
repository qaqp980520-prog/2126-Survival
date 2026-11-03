extends SceneTree

const RulesScript = preload("res://rules.gd")

var rules: Variant

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    rules = RulesScript.new()
    _test_authored_routes()
    _test_level_layout_contract()
    _test_blocked_move_and_wait()
    _test_detection_and_retry()
    _test_reward_cannot_be_farmed()
    _test_level_data_is_defensive()
    if failures.is_empty():
        print("KROLL Stealth Grid rules tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _test_authored_routes() -> void:
    var routes: Array[String] = [
        "RRRRRDDR",
        "DURRDDRRUURRDDDD",
        "DDDDDDRRRRUURWUUUDDDRD"
    ]
    var state: Dictionary = rules.create_state()
    for level_index in range(rules.get_level_count()):
        state = _play_route(state, routes[level_index])
        _expect(bool(state.get("complete", false)), "authored safe route clears " + rules.get_level_name(state))
        _expect(not bool(state.get("failed", false)), "authored safe route avoids detection")
        if level_index < rules.get_level_count() - 1:
            state = rules.next_level(state)
    _expect(bool(state.get("campaign_complete", false)), "third sector completes the campaign")
    _expect(int(state.get("score", 0)) == 300, "three unique sector rewards total 300 points")

func _test_level_layout_contract() -> void:
    for level_index in range(rules.get_level_count()):
        var level: Dictionary = rules.get_level_data(level_index)
        var rows: Array = level["rows"]
        _expect(rows.size() == 9, "sector %d has nine rows" % (level_index + 1))
        for row in rows:
            _expect(str(row).length() == 9, "sector %d row has nine columns" % (level_index + 1))
        var state: Dictionary = rules.create_state(level_index)
        var start: Vector2i = level["start"]
        var exit_position: Vector2i = level["exit"]
        _expect(rules.render_tile(state, start) != "#", "sector %d start is walkable" % (level_index + 1))
        _expect(rules.render_tile(state, exit_position) != "#", "sector %d exit is walkable" % (level_index + 1))
        for key_position in level["keys"]:
            _expect(rules.render_tile(state, key_position) != "#", "sector %d access key is walkable" % (level_index + 1))
        for guard_data in level["guards"]:
            var path: Array = guard_data["path"]
            _expect(not path.is_empty(), "sector %d patrol path is not empty" % (level_index + 1))
            for path_index in range(path.size()):
                var point: Vector2i = path[path_index]
                _expect(rules.render_tile(state, point) != "#", "sector %d patrol node is walkable" % (level_index + 1))
                var next_point: Vector2i = path[(path_index + 1) % path.size()]
                _expect(abs(next_point.x - point.x) + abs(next_point.y - point.y) == 1, "sector %d patrol step is cardinal" % (level_index + 1))

func _test_blocked_move_and_wait() -> void:
    var state: Dictionary = rules.create_state()
    var blocked: Dictionary = rules.attempt_move(state, Vector2i(-1, 0))
    _expect(not bool(blocked.get("ok", false)), "wall movement is rejected")
    _expect(int(state["turn"]) == 0, "blocked movement does not consume a turn")
    _expect(int(state["guard_states"][0]["index"]) == 0, "blocked movement does not advance patrols")
    var waited: Dictionary = rules.attempt_move(state, Vector2i.ZERO)
    _expect(bool(waited.get("ok", false)), "wait is a legal turn")
    _expect(int(state["turn"]) == 1, "wait consumes one turn")
    _expect(int(state["guard_states"][0]["index"]) == 1, "wait advances the patrol")

func _test_detection_and_retry() -> void:
    var state: Dictionary = rules.create_state()
    _expect(bool(rules.attempt_move(state, Vector2i(0, 1)).get("ok", false)), "first approach step is legal")
    var detected: Dictionary = rules.attempt_move(state, Vector2i(0, 1))
    _expect(bool(detected.get("detected", false)), "forward patrol sight detects the player")
    _expect(bool(state.get("failed", false)), "detection fails the current sector")
    var retried: Dictionary = rules.restart_level(state)
    _expect(not bool(retried.get("failed", true)), "retry clears the failure state")
    _expect(int(retried["turn"]) == 0, "retry resets the turn counter")
    _expect(retried["player"] == Vector2i(1, 1), "retry restores the start position")
    _expect(rules.get_collected_key_count(retried) == 0, "retry clears current-sector keys")

func _test_reward_cannot_be_farmed() -> void:
    var route := "RRRRRDDR"
    var state: Dictionary = _play_route(rules.create_state(), route)
    _expect(int(state["score"]) == 100, "first completion awards 100 points")
    var replay: Dictionary = _play_route(rules.restart_level(state), route)
    _expect(int(replay["score"]) == 100, "replaying a cleared sector cannot award points twice")

func _test_level_data_is_defensive() -> void:
    var first: Dictionary = rules.get_level_data(0)
    first["rows"][0] = "........."
    var second: Dictionary = rules.get_level_data(0)
    _expect(str(second["rows"][0]) == "#########", "mutating a level snapshot cannot change authored data")

func _play_route(initial_state: Dictionary, route: String) -> Dictionary:
    var state: Dictionary = initial_state
    for index in range(route.length()):
        var direction := Vector2i.ZERO
        match route.substr(index, 1):
            "U":
                direction = Vector2i(0, -1)
            "D":
                direction = Vector2i(0, 1)
            "L":
                direction = Vector2i(-1, 0)
            "R":
                direction = Vector2i(1, 0)
            "W":
                direction = Vector2i.ZERO
            _:
                _expect(false, "route contains a known action")
        var result: Dictionary = rules.attempt_move(state, direction)
        _expect(bool(result.get("ok", false)), "route action " + str(index + 1) + " is legal")
        if bool(state.get("failed", false)) or bool(state.get("complete", false)):
            break
    return state

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)

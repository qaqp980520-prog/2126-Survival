extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _expect(Rules.mission_count() == 3, "campaign contains three authored trench missions")
    for index in range(Rules.mission_count()):
        var mission: Dictionary = Rules.mission_at(index)
        var start: Vector2i = mission["start_cell"]
        var target: Vector2i = mission["target_cell"]
        var outward: Array[Vector2i] = Rules.find_path(mission, start, target)
        var inward: Array[Vector2i] = Rules.find_path(mission, target, start)
        _expect(outward.size() > 1, "mission %d has a reachable hidden beacon" % (index + 1))
        _expect(inward.size() > 1, "mission %d has a return route to the submersible" % (index + 1))
        _expect(not mission["walls"].has(start) and not mission["walls"].has(target), "mission %d start and target are passable" % (index + 1))

        var state: Dictionary = Rules.new_state(index)
        var ping_result: Dictionary = Rules.ping(state)
        _expect(bool(ping_result["accepted"]), "mission %d can send an initial sonar ping" % (index + 1))
        state = ping_result["state"]
        var clue: Dictionary = ping_result["clue"]
        _expect(str(clue["bearing"]) == Rules.bearing(start, target), "mission %d sonar bearing is correct" % (index + 1))
        _expect(str(clue["band"]) == Rules.distance_band(start, target), "mission %d sonar distance band is correct" % (index + 1))
        _expect(int(state["battery"]) == int(mission["battery"]) - Rules.PING_COST, "mission %d ping consumes the correct battery" % (index + 1))

        var blocked_state: Dictionary = state.duplicate(true)
        blocked_state["battery"] = 1
        var no_battery_ping: Dictionary = Rules.ping(blocked_state)
        _expect(not bool(no_battery_ping["accepted"]) and int(no_battery_ping["state"]["pings_left"]) == Rules.MAX_PINGS, "mission %d refuses sonar without sufficient battery" % (index + 1))

        var invalid_move: Dictionary = Rules.move(state, "diagonal")
        _expect(not bool(invalid_move["accepted"]), "mission %d rejects invalid movement directions" % (index + 1))

        for step in range(1, outward.size()):
            var delta: Vector2i = outward[step] - outward[step - 1]
            var move_result: Dictionary = Rules.move(state, Rules.direction_for_delta(delta))
            _expect(bool(move_result["accepted"]), "mission %d outward path step %d is legal" % [index + 1, step])
            state = move_result["state"]
            if step == maxi(1, outward.size() / 2):
                var second_ping: Dictionary = Rules.ping(state)
                _expect(bool(second_ping["accepted"]), "mission %d can triangulate from a second position" % (index + 1))
                state = second_ping["state"]

        var collect_result: Dictionary = Rules.interact(state)
        _expect(bool(collect_result["accepted"]) and bool(collect_result["state"]["carrying"]), "mission %d beacon can be collected at its hidden cell" % (index + 1))
        state = collect_result["state"]
        for step in range(1, inward.size()):
            var delta: Vector2i = inward[step] - inward[step - 1]
            var move_result: Dictionary = Rules.move(state, Rules.direction_for_delta(delta))
            _expect(bool(move_result["accepted"]), "mission %d return path step %d is legal" % [index + 1, step])
            state = move_result["state"]
        var extract_result: Dictionary = Rules.interact(state)
        _expect(bool(extract_result["accepted"]) and str(extract_result["state"]["status"]) == "complete", "mission %d extracts the beacon at the submersible" % (index + 1))
        state = extract_result["state"]
        var first_score: int = int(state["campaign_score"])
        _expect(first_score == 100 or first_score == 75, "mission %d awards a valid one-time completion score" % (index + 1))

        var replay: Dictionary = Rules.restart_mission(state)
        var replay_out: Array[Vector2i] = Rules.find_path(mission, start, target)
        for step in range(1, replay_out.size()):
            var delta: Vector2i = replay_out[step] - replay_out[step - 1]
            var replay_move: Dictionary = Rules.move(replay, Rules.direction_for_delta(delta))
            replay = replay_move["state"]
        var replay_collect: Dictionary = Rules.interact(replay)
        replay = replay_collect["state"]
        var replay_back: Array[Vector2i] = Rules.find_path(mission, target, start)
        for step in range(1, replay_back.size()):
            var delta: Vector2i = replay_back[step] - replay_back[step - 1]
            var replay_return: Dictionary = Rules.move(replay, Rules.direction_for_delta(delta))
            replay = replay_return["state"]
        var replay_extract: Dictionary = Rules.interact(replay)
        replay = replay_extract["state"]
        _expect(int(replay["campaign_score"]) == first_score, "mission %d cannot award the same beacon twice" % (index + 1))

        var advance_result: Dictionary = Rules.next_mission(state)
        _expect(bool(advance_result["accepted"]), "mission %d can advance after extraction" % (index + 1))
        if index < Rules.mission_count() - 1:
            _expect(int(advance_result["state"]["mission_index"]) == index + 1, "mission %d loads the next trench" % (index + 1))
        else:
            _expect(str(advance_result["state"]["status"]) == "victory", "final mission completes the campaign")

    if failures.is_empty():
        print("KROLL Abyssal Sonar rules tests passed.")
        quit(0)
    else:
        push_error("KROLL Abyssal Sonar rules failures: " + str(failures))
        quit(1)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures.append(message)
        push_error("FAIL: " + message)

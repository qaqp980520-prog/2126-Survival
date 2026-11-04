extends SceneTree

const Rules = preload("res://rules.gd")
const PING_PATH_INDICES: Array = [[6, 7], [6, 10], [0, 6]]
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for mission_index in range(Rules.mission_count()):
        var scene: Node = load("res://main.tscn").instantiate()
        root.add_child(scene)
        await process_frame
        scene.set("_state", Rules.new_state(mission_index))
        var mission: Dictionary = Rules.mission_at(mission_index)
        var start: Vector2i = mission["start_cell"]
        var target: Vector2i = mission["target_cell"]
        var outward: Array[Vector2i] = Rules.find_path(mission, start, target)
        var inward: Array[Vector2i] = Rules.find_path(mission, target, start)

        for step in range(outward.size()):
            if PING_PATH_INDICES[mission_index].has(step):
                _expect(bool(scene.call("apply_action", "ping")), "mission %d records sonar echo at route cell %d" % [mission_index + 1, step])
            if step < outward.size() - 1:
                var delta: Vector2i = outward[step + 1] - outward[step]
                var direction: String = Rules.direction_for_delta(delta)
                _expect(bool(scene.call("apply_action", "move_" + direction)), "mission %d outward movement %d is accepted" % [mission_index + 1, step + 1])

        _expect(bool(scene.call("apply_action", "interact")), "mission %d secures the hidden beacon" % (mission_index + 1))
        for step in range(1, inward.size()):
            var delta: Vector2i = inward[step] - inward[step - 1]
            var direction: String = Rules.direction_for_delta(delta)
            _expect(bool(scene.call("apply_action", "move_" + direction)), "mission %d return movement %d is accepted" % [mission_index + 1, step])
        _expect(bool(scene.call("apply_action", "interact")), "mission %d extracts the beacon at the SUB tile" % (mission_index + 1))

        var final_state: Dictionary = scene.call("get_game_state")
        _expect(str(final_state["status"]) == "complete", "mission %d reaches completed state through actual grid movement" % (mission_index + 1))
        _expect(int(final_state["battery"]) >= int(final_state["par_battery"]), "mission %d preserves the par battery reserve" % (mission_index + 1))
        _expect(int(final_state["campaign_score"]) == 100, "mission %d earns the full on-time score" % (mission_index + 1))
        _expect(final_state["ping_log"].size() == 2, "mission %d keeps both sonar bearings in the log" % (mission_index + 1))
        var candidates: Array[Vector2i] = Rules.triangulation_candidates(mission, final_state["ping_log"])
        _expect(candidates.size() == 1 and candidates[0] == target, "mission %d route sonar echoes uniquely triangulate the hidden beacon" % (mission_index + 1))
        scene.queue_free()
        await process_frame

    if failures.is_empty():
        print("KROLL Abyssal Sonar route simulation passed.")
        quit(0)
    else:
        push_error("KROLL Abyssal Sonar route simulation failures: " + str(failures))
        quit(1)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures.append(message)
        push_error("FAIL: " + message)

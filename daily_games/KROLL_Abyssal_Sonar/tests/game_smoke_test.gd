extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: Node = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame

    var initial: Dictionary = scene.call("get_game_state")
    _expect(str(initial["status"]) == "active", "new game starts with an active mission")
    _expect(int(initial["battery"]) > 0 and int(initial["pings_left"]) == Rules.MAX_PINGS, "new mission initializes battery and sonar budget")
    _expect(str(scene.call("touch_action_at", Vector2(640.0, 450.0))) == "ping", "touch hit-testing identifies the PING button")
    _expect(str(scene.call("touch_action_at", Vector2(760.0, 450.0))) == "interact", "touch hit-testing identifies the INTERACT button")
    _expect(bool(scene.call("apply_action", "ping")), "game accepts the sonar action")
    var after_ping: Dictionary = scene.call("get_game_state")
    _expect(after_ping["ping_log"].size() == 1, "sonar clue is added to the visible contact log")
    _expect(int(after_ping["battery"]) == int(initial["battery"]) - Rules.PING_COST, "game UI state reflects sonar battery cost")

    var mission: Dictionary = Rules.mission_at(0)
    var path: Array[Vector2i] = Rules.find_path(mission, initial["start"], initial["target"])
    if path.size() > 1:
        var delta: Vector2i = path[1] - path[0]
        var direction: String = Rules.direction_for_delta(delta)
        _expect(bool(scene.call("apply_action", "move_" + direction)), "game accepts a legal directional move")
        var moved: Dictionary = scene.call("get_game_state")
        _expect(moved["player"] == path[1], "game updates the player cell after movement")

    scene.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Abyssal Sonar runtime smoke test passed.")
        quit(0)
    else:
        push_error("KROLL Abyssal Sonar runtime smoke failures: " + str(failures))
        quit(1)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures.append(message)
        push_error("FAIL: " + message)

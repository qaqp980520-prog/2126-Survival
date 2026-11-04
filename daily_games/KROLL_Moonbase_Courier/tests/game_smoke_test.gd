extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: Node = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    _expect(scene.call("get_game_state").size() > 0, "main scene initializes a playable campaign")

    for index in range(Rules.level_count()):
        var state: Dictionary = scene.call("get_game_state")
        var package_rect: Rect2 = state["package_rect"]
        state["player_position"] = package_rect.position
        scene.set("_state", state)
        _expect(bool(scene.call("_try_interact")), "route %d parcel can be collected" % (index + 1))
        state = scene.call("get_game_state")
        _expect(bool(state["carrying"]), "route %d records the carried parcel" % (index + 1))
        var exit_rect: Rect2 = state["exit_rect"]
        state["player_position"] = exit_rect.position
        scene.set("_state", state)
        _expect(bool(scene.call("_try_interact")), "route %d parcel can be delivered" % (index + 1))
        state = scene.call("get_game_state")
        _expect(str(state["status"]) == "complete", "route %d completes after delivery" % (index + 1))
        _expect(bool(scene.call("_advance_level")), "route %d can advance or finish the campaign" % (index + 1))

    var completed: Dictionary = scene.call("get_game_state")
    _expect(str(completed["status"]) == "victory", "third delivery ends the campaign")
    _expect(int(completed["campaign_score"]) == 300, "three on-time deliveries award the 300-point maximum")
    _expect(completed["awarded"] == [true, true, true], "each route is recorded exactly once")

    scene.call("_restart_level")
    var restarted_level: Dictionary = scene.call("get_game_state")
    _expect(int(restarted_level["campaign_score"]) == 300, "restarting a route preserves already awarded campaign points")
    scene.call("_restart_campaign")
    var restarted_campaign: Dictionary = scene.call("get_game_state")
    _expect(int(restarted_campaign["campaign_score"]) == 0 and restarted_campaign["awarded"] == [false, false, false], "new campaign resets the reward ledger")

    scene.call("_handle_touch_action", "left", true)
    _expect(bool(scene.get("_touch_left")), "touch left control can be held")
    scene.call("_handle_touch_action", "left", false)
    _expect(not bool(scene.get("_touch_left")), "touch left control releases cleanly")
    _expect(str(scene.call("_touch_action_at", Vector2(750.0, 480.0))) == "jump", "pointer and touch hit testing finds the jump control")

    var start_position: Vector2 = restarted_campaign["player_position"]
    scene.call("_simulate_step", 0.016, 1, false, false)
    var moved_state: Dictionary = scene.call("get_game_state")
    _expect(moved_state["player_position"].x > start_position.x, "horizontal movement advances the courier")
    scene.call("_simulate_step", 0.016, 0, false, false)
    scene.call("_simulate_step", 0.016, 0, true, false)
    var jump_state: Dictionary = scene.call("get_game_state")
    _expect(float(jump_state["velocity"].y) < 0.0, "grounded courier can jump")

    scene.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Moonbase Courier runtime smoke test passed.")
        quit(0)
    else:
        push_error("KROLL Moonbase Courier runtime smoke failures: " + str(failures))
        quit(1)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures.append(message)
        push_error("FAIL: " + message)

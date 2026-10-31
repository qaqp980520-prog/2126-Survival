extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Node2D = MainScene.instantiate() as Node2D
    _expect(game != null, "Core Drill main scene instantiates")
    if game == null:
        quit(1)
        return
    root.add_child(game)
    await process_frame
    _expect(game.has_method("get_current_mission"), "scene exposes its current drilling site")
    _expect(game.has_method("_drill_selected") and game.has_method("_vent"), "scene exposes drill and coolant actions")
    var mission: Dictionary = game.call("get_current_mission")
    _expect(str(mission.get("id", "")) == "copper_spine", "first site loads from the standalone rules module")
    _expect((mission.get("layout", []) as Array).size() == 8, "first site exposes eight rows")
    game.call("_drill_selected")
    var state: Dictionary = game.call("get_state")
    _expect(int(state.get("row", 0)) == 1 and int(state.get("ore", 0)) == 1, "first drill action extracts the center copper seam")
    var vent_ok: bool = bool(game.call("_vent"))
    state = game.call("get_state")
    _expect(vent_ok and int(state.get("heat", 100)) == 0, "coolant action updates the live scene state")
    _expect(not bool(game.call("_vent")), "scene prevents a second vent in the same row")

    game.call("restart_sector")
    var touch_drill := InputEventScreenTouch.new()
    touch_drill.pressed = true
    touch_drill.position = (game.call("_button_rect", "drill") as Rect2).get_center()
    game.call("_unhandled_input", touch_drill)
    state = game.call("get_state")
    _expect(int(state.get("row", 0)) == 1, "touch DRILL button advances the live scene")

    game.call("restart_sector")
    var routes: Array = [
        [2, 1, 2, 3, 2, 1, 2, 3]
    ]
    for lane in routes[0]:
        game.call("_set_selected_lane", int(lane))
        _expect(bool(game.call("_drill_selected")), "runtime route accepts each adjacent lane")
    state = game.call("get_state")
    _expect(bool(state.get("complete", false)), "runtime route completes the first site")
    _expect(bool(game.call("next_sector")), "completed site advances to the next sector")
    _expect(int(game.get("mission_index")) == 1, "next sector loads the second authored site")

    game.call("restart_sector")
    var touch_restart := InputEventScreenTouch.new()
    touch_restart.pressed = true
    touch_restart.position = (game.call("_button_rect", "restart") as Rect2).get_center()
    game.call("_unhandled_input", touch_restart)
    state = game.call("get_state")
    _expect(int(state.get("row", -1)) == 0, "touch RESTART button resets the current site")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Core Drill runtime smoke test passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)

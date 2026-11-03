extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(game.call("get_title_text") == "KROLL // SONAR TRIANGULATOR", "game displays its title")
    _expect(game.call("get_mission_count") == 3, "game provides three survey missions")
    _expect(game.call("get_sensor_button_count") == 4, "game builds four sensor ping buttons")
    _expect(game.call("get_cell_button_count") == 64, "game builds the 8x8 target grid")
    var phone_profile: Dictionary = game.call("get_layout_profile", 375.0)
    _expect(str(phone_profile.get("controls_layout", "")) == "stacked", "375px phone profile stacks the action controls")
    _expect(float(phone_profile.get("board_total_width", 999.0)) <= 375.0, "375px phone profile keeps the full 8x8 board inside the viewport")
    var compact_profile: Dictionary = game.call("get_layout_profile", 320.0)
    _expect(float(compact_profile.get("board_total_width", 999.0)) <= 320.0, "320px compact profile keeps the full 8x8 board inside the viewport")
    _expect(str(game.call("get_current_state").get("status", "")) == "playing", "game starts in the playing state")
    for sensor_index in range(3):
        _expect(bool(game.call("scan_sensor", sensor_index)), "runtime accepts sensor %d" % sensor_index)
    var state: Dictionary = game.call("get_current_state")
    var candidates: Array = state.get("candidates", [])
    _expect(candidates.size() == 1, "runtime triangulates the first beacon from three pings")
    if candidates.size() == 1:
        var target: Vector2i = candidates[0]
        _expect(bool(game.call("select_cell", target.x, target.y)), "runtime allows selection of the unique target cell")
        _expect(bool(game.call("submit_target")), "runtime accepts the correct target lock")
    state = game.call("get_current_state")
    _expect(str(state.get("status", "")) == "passed", "runtime completes the first survey")
    _expect(bool(game.call("advance_mission")), "runtime advances to the second survey")
    state = game.call("get_current_state")
    _expect(int(state.get("mission_index", -1)) == 1, "second survey becomes active")
    for sensor_index in range(3):
        _expect(bool(game.call("scan_sensor", sensor_index)), "second survey accepts sensor %d" % sensor_index)
    state = game.call("get_current_state")
    candidates = state.get("candidates", [])
    _expect(candidates.size() == 2, "second survey exposes the intentional ambiguous pair")
    _expect(str(game.call("get_status_text")).contains("USE UNUSED BUOY D"), "ambiguous survey guidance names the remaining south-edge buoy")
    if candidates.size() == 2:
        var wrong_cell: Vector2i = candidates[1]
        _expect(bool(game.call("select_cell", wrong_cell.x, wrong_cell.y)), "runtime allows a plausible false return to be selected")
        _expect(bool(game.call("submit_target")), "runtime records the false-return elimination")
    state = game.call("get_current_state")
    candidates = state.get("candidates", [])
    _expect(candidates.size() == 1, "false-return elimination leaves one target candidate")
    if candidates.size() == 1:
        var remaining: Vector2i = candidates[0]
        _expect(bool(game.call("select_cell", remaining.x, remaining.y)), "runtime allows the remaining beacon to be selected")
        _expect(bool(game.call("submit_target")), "runtime accepts the remaining beacon")
    state = game.call("get_current_state")
    _expect(str(state.get("status", "")) == "passed", "runtime completes the ambiguous survey")
    _expect(bool(game.call("restart_campaign")), "runtime can restart the complete campaign")
    state = game.call("get_current_state")
    _expect(int(state.get("campaign_score", -1)) == 0 and int(state.get("mission_index", -1)) == 0, "campaign restart clears score and returns to the first mission")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Sonar Triangulator runtime smoke test passed.")
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

extends SceneTree
const GameScene = preload("res://main_root.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(game.call("get_title_text") == "KROLL // STRATOSPHERE BALLOONIST", "game scene displays the Stratosphere Balloonist title")
    _expect(int(game.call("get_mission_count")) == 3, "game exposes three atmospheric missions")
    _expect(int(game.call("get_action_button_count")) == 3, "game builds ascend, hold and descend controls")
    _expect(int(game.call("get_control_button_count")) == 5, "game exposes three actions and two navigation controls")
    for step in range(5):
        var result: Dictionary = game.call("perform_action", "ascend")
        _expect(bool(result.get("ok", false)), "runtime accepts a controlled ascent")
    for step in range(3):
        var result: Dictionary = game.call("perform_action", "hold")
        _expect(bool(result.get("ok", false)), "runtime accepts a stable sampling hold")
    var state: Dictionary = game.call("get_state_snapshot")
    _expect(str(state.get("status", "")) == "passed", "runtime captures the first stable atmosphere sample")
    _expect(int(state.get("mission_score", 0)) > 0, "runtime records the first mission score")
    var advance: Dictionary = game.call("advance_mission")
    _expect(bool(advance.get("ok", false)), "runtime advances to Jet Stream")
    state = game.call("get_state_snapshot")
    _expect(int(state.get("mission_index", -1)) == 1, "runtime enters the second mission")
    game.call("restart_campaign")
    state = game.call("get_state_snapshot")
    _expect(int(state.get("mission_index", -1)) == 0 and int(state.get("campaign_score", -1)) == 0, "runtime restart resets mission and campaign score")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Stratosphere Balloonist runtime smoke test passed.")
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

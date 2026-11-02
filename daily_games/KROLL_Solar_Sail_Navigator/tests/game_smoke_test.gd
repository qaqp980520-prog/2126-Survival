extends SceneTree

const GameScene = preload("res://main.tscn")
const PlansScript = preload("res://tests/flight_plans.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(game.call("get_title_text") == "KROLL // SOLAR SAIL NAVIGATOR","game title")
    _expect(game.call("get_mission_count") == 3,"three relay missions")
    _expect(game.call("get_control_button_count") == 7,"seven flight controls")
    var state: Dictionary = game.call("get_current_state")
    _expect(str(state.get("mission_id","")) == "solar_wake","first relay loads")
    for mission_index in range(3):
        for action_value in PlansScript.PLANS[mission_index]:
            var action: Vector2i = action_value
            _expect(bool(game.call("set_sail",action.x,action.y)),"mission %d accepts sail trim" % mission_index)
            _expect(bool(game.call("advance_turn")),"mission %d advances one turn" % mission_index)
            state = game.call("get_current_state")
            if str(state.get("status","")) != "flight":
                break
        state = game.call("get_current_state")
        _expect(bool(state.get("mission_awarded",false)),"mission %d captures relay" % mission_index)
        _expect(int(state.get("score",0)) == (mission_index + 1) * 100,"mission %d awards 100 points" % mission_index)
        _expect(not bool(game.call("advance_turn")),"captured relay rejects another turn")
        if mission_index < 2:
            _expect(not bool(game.call("reset_mission")),"captured intermediate relay cannot be reset to farm score")
            _expect(bool(game.call("advance_mission")),"mission %d advances to next relay" % mission_index)
    state = game.call("get_current_state")
    _expect(bool(state.get("campaign_complete",false)),"third relay completes expedition")
    _expect(not bool(game.call("advance_mission")),"completed expedition rejects repeated advancement")
    _expect(bool(game.call("reset_mission")),"reset after final relay restarts campaign")
    state = game.call("get_current_state")
    _expect(int(state.get("mission_index",-1)) == 0 and int(state.get("score",-1)) == 0,"campaign restart clears score")
    _expect(not bool(game.call("set_sail",99,3)),"invalid sail trim is rejected")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Solar Sail Navigator runtime smoke test passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _expect(condition: bool,message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures.append(message)

extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(game.call("get_title_text") == "KROLL // EMBERLINE COMMAND","game exposes its title")
    _expect(game.call("get_mission_count") == 3,"game exposes three wildfire missions")
    _expect(game.call("get_cell_button_count") == 64,"game builds an 8x8 response grid")
    _expect(game.call("get_action_button_count") == 2,"game builds firebreak and water actions")
    _expect(game.call("get_control_button_count") == 5,"game builds five action/navigation controls")
    var state: Dictionary = game.call("get_current_state")
    var fire_index: int = -1
    for index in range(state.get("cells",[]).size()):
        if bool(state["cells"][index].get("burning",false)):
            fire_index = index
            break
    _expect(fire_index >= 0,"initial mission displays an active fire front")
    if fire_index >= 0:
        game.call("select_cell",fire_index)
        var result: Dictionary = game.call("perform_action","water")
        _expect(bool(result.get("ok",false)),"water button command is accepted")
        var updated: Dictionary = game.call("get_current_state")
        _expect(not bool(updated["cells"][fire_index].get("burning",true)),"water action updates the visible fire state")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Emberline Command runtime smoke test passed.")
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

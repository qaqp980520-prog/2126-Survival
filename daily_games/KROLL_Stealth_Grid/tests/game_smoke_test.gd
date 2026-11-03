extends SceneTree

const GameScene = preload("res://main.tscn")

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(game.call("get_title_text") == "KROLL // STEALTH GRID", "game displays its title")
    _expect(game.call("get_mission_count") == 3, "game exposes three sectors")
    _expect(game.call("get_board_cell_count") == 81, "game builds an 81-cell board")
    _expect(game.call("get_control_button_count") == 8, "game exposes eight touch and action controls")
    _expect(game.call("get_current_mission_index") == 0, "campaign begins at the first sector")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Stealth Grid runtime smoke test passed.")
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

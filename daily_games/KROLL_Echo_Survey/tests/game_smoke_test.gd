extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://main.tscn")
    assert(packed != null, "Echo Survey main scene must load")
    var game: Variant = packed.instantiate()
    root.add_child(game)
    await process_frame
    assert(str(game.state.get("status", "")) == "playing")
    assert(game.get_node_or_null("PingButton") != null)
    assert(game.get_node_or_null("UpButton") != null)
    var battery_before: int = int(game.state["battery"])
    game.ping_sonar()
    assert(int(game.state["battery"]) == battery_before - Rules.PING_BATTERY_COST, "Ping action should consume battery")
    var x_before: int = int(game.state["x"])
    game.move_player(1, 0)
    assert(int(game.state["x"]) == x_before + 1, "Movement API should move the player")
    game.restart_game()
    assert(int(game.state["x"]) == 0 and int(game.state["y"]) == 0)
    assert(int(game.state["battery"]) == Rules.STARTING_BATTERY and int(game.state["oxygen"]) == Rules.STARTING_OXYGEN)
    game.next_layout()
    assert(int(game.state["seed"]) == 23, "Next button should select the next deterministic layout")
    game.queue_free()
    await process_frame
    print("KROLL Echo Survey runtime smoke test passed.")
    quit(0)

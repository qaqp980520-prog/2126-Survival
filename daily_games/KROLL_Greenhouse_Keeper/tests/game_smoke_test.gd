extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(game.state.get("status") == "playing", "scene starts in a playable state")
    _expect(game.get_child_count() > 0, "scene builds its interface")
    _expect(game.select_plot(2), "third plot can be selected")
    _expect(game.water_selected(), "selected plot can be watered")
    _expect(game.state["water_left"] == 2, "water action updates the HUD state")
    _expect(game.advance_day(), "day can advance")
    _expect(game.state["day"] == 2, "day counter updates in the live scene")
    game.restart_game()
    _expect(game.state["day"] == 1 and game.state["water_left"] == 3, "restart resets the game")
    _expect(game.select_plot(2), "select the tomato plot for a full round")
    _expect(game.water_selected(), "water tomato before the first day")
    for i in range(3):
        _expect(game.advance_day(), "advance a day in the harvest route")
    _expect(game.harvest_selected(), "harvest mature tomato")
    _expect(game.select_plot(0), "select a second crop")
    _expect(game.water_selected(), "water the second crop")
    for i in range(3):
        _expect(game.advance_day(), "advance to the second harvest")
    _expect(game.harvest_selected(), "harvest a second mature crop")
    _expect(game.state["status"] == "won" and game.state["harvest_yield"] >= 5, "live scene can complete a full harvest victory")
    game.restart_game()
    game.next_layout()
    _expect(game.state["seed"] == 33, "next layout advances the deterministic seed")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Greenhouse Keeper runtime smoke test passed.")
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

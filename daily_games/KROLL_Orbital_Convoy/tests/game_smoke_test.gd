extends SceneTree

const MainScene = preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run_smoke_test")

func _run_smoke_test() -> void:
    var game = MainScene.instantiate()
    root.add_child(game)
    await process_frame
    assert(game.get("cargo_collected") == 0)
    assert(game.get("hull") == 3)
    assert(game.get("round_state") == "playing")
    assert(game.get("asteroids").size() == 8)
    assert(game.get("cargo").size() == 6)
    game.call("collect_cargo")
    assert(game.get("cargo_collected") == 1)
    game.call("take_hit")
    assert(game.get("hull") == 2)
    for i in range(5):
        game.call("collect_cargo")
    assert(game.get("cargo_collected") == 6)
    assert(game.call("get_round_state") == "won")
    print("KROLL Orbital Convoy runtime smoke test passed.")
    quit()

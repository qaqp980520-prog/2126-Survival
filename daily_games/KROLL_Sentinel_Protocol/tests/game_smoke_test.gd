extends SceneTree
const GameScene = preload("res://main.tscn")
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game: Node = GameScene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(str(game.get("_state")) == "playing", "game starts in playing state")
    _expect(int(game.get("_player_hp")) == 3, "game starts with three integrity")
    _expect(is_equal_approx(float(game.get("_time_left")), 45.0), "game starts with 45 seconds")
    var enemies: Array = game.get("_enemies")
    var before_enemies: int = enemies.size()
    game.call("debug_spawn_enemy_at", Vector2(90, 90))
    enemies = game.get("_enemies")
    _expect(enemies.size() == before_enemies + 1, "debug drone spawn reaches game state")
    var cells: Array = game.get("_cells")
    var before_cells: int = cells.size()
    game.call("debug_spawn_cell_at", Vector2(100, 100))
    cells = game.get("_cells")
    _expect(cells.size() == before_cells + 1, "energy cell spawn reaches game state")
    game.call("debug_dash", Vector2.RIGHT)
    _expect(float(game.get("_dash_timer")) > 0.0, "dash activates for a bounded duration")
    game.queue_free()
    await process_frame
    var exit_code := 0
    if failures.is_empty():
        print("KROLL Sentinel Escape runtime smoke test passed.")
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        exit_code = 1
    quit(exit_code)
func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)

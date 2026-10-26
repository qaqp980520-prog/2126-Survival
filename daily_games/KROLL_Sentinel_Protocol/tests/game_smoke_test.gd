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
    var initial_time: float = float(game.get("_time_left"))
    _expect(initial_time <= 45.0 and initial_time > 44.0, "game timer initializes near 45 seconds after first frame")
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
    var player_position: Vector2 = game.get("_player_position")
    cells.clear()
    game.call("debug_spawn_cell_at", player_position)
    game.call("_collect_cells")
    _expect(int(game.get("_score")) == 1, "touching an energy cell increments collection progress")
    enemies = game.get("_enemies")
    enemies.clear()
    game.call("debug_spawn_enemy_at", player_position)
    game.call("_move_enemies", 0.016)
    _expect(int(game.get("_player_hp")) == 2, "drone contact reduces integrity once")
    game.call("_restart")
    _expect(str(game.get("_state")) == "playing" and int(game.get("_player_hp")) == 3, "restart restores a playable round")
    var restarted_cells: Array = game.get("_cells")
    _expect(int(game.get("_score")) == 0 and restarted_cells.size() == 3, "restart resets collection progress and seeds three cells")
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

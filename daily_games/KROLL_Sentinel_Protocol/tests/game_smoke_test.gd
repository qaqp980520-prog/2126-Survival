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
    var before: int = (game.get("_enemies") as Array).size()
    game.call("debug_spawn_enemy_at", Vector2(90, 90))
    _expect((game.get("_enemies") as Array).size() == before + 1, "debug enemy spawn reaches game state")
    game.call("debug_fire_toward", Vector2.RIGHT)
    _expect((game.get("_bullets") as Array).size() == 1, "aim command creates projectile")
    game.queue_free()
    await process_frame
    var exit_code := 0
    if failures.is_empty():
        print("KROLL Sentinel Protocol runtime smoke test passed.")
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

extends SceneTree

const GameScene = preload("res://main.tscn")
const Rules = preload("res://scripts/rules.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Control = GameScene.instantiate()
    root.add_child(game)
    await process_frame
    assert(game.grid.size() == 25)
    assert(is_equal_approx(game.time_left, 45.0))
    assert(not game.finished)
    var before: int = int(game.grid[Rules.index_of(Vector2i(1, 2), 5)]["rotation"])
    game.call("_handle_point", Vector2(BOARD_POINT_X, BOARD_POINT_Y))
    var after: int = int(game.grid[Rules.index_of(Vector2i(1, 2), 5)]["rotation"])
    assert(after == (before + 1) % 4)
    game.call("_reset_game")
    assert(is_equal_approx(game.time_left, 45.0))
    assert(game.moves == 0)
    assert(not game.finished)
    game.queue_free()
    await process_frame
    print("KROLL Signal Siphon runtime smoke test passed.")
    quit(0)

const BOARD_POINT_X: float = 56.0 + (1 * (88.0 + 8.0)) + 44.0
const BOARD_POINT_Y: float = 132.0 + (2 * (88.0 + 8.0)) + 44.0

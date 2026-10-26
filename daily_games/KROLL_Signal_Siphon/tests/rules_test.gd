extends SceneTree

const Rules = preload("res://scripts/rules.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    assert(Rules.rotate_mask(Rules.PORT_N, 1) == Rules.PORT_E)
    assert(Rules.rotate_mask(Rules.PORT_E, 1) == Rules.PORT_S)
    assert(Rules.rotate_mask(Rules.PORT_S, 1) == Rules.PORT_W)
    assert(Rules.rotate_mask(Rules.PORT_W, 1) == Rules.PORT_N)
    assert(Rules.rotate_mask(Rules.PORT_N | Rules.PORT_W, 1) == (Rules.PORT_N | Rules.PORT_E))
    var grid: Array = Rules.make_puzzle()
    assert(grid.size() == 25)
    assert(not Rules.is_connected(grid, 5, 5, Vector2i(0, 2), Vector2i(4, 2)))
    var route: Array[Vector2i] = [
        Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2)
    ]
    for pos in route:
        var cell: Dictionary = grid[Rules.index_of(pos, 5)]
        cell["rotation"] = 0
        grid[Rules.index_of(pos, 5)] = cell
    assert(Rules.is_connected(grid, 5, 5, Vector2i(0, 2), Vector2i(4, 2)))
    assert(not Rules.is_connected(grid, 5, 5, Vector2i(-1, 2), Vector2i(4, 2)))
    assert(not Rules.is_connected(grid, 0, 5, Vector2i.ZERO, Vector2i(0, 0)))
    print("KROLL Signal Siphon rules tests passed.")
    quit(0)

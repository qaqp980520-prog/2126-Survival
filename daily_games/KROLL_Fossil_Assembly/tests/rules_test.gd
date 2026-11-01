extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _expect(Rules.level_count() == 3, "three authored fossil specimens are available")
    for level_index in range(Rules.level_count()):
        var state: Dictionary = Rules.create_state(level_index)
        _expect(not state.is_empty(), "specimen %d creates a valid state" % level_index)
        var definition: Dictionary = Rules.get_level_definition(level_index)
        _expect(definition.get("target_cells", []).size() == 12, "specimen %d has twelve target cells" % level_index)
        var solution: Array = Rules.get_reference_solution(level_index)
        _expect(solution.size() == 3, "specimen %d has three fragments" % level_index)
        for step in solution:
            var result: Dictionary = Rules.place_piece(
                state,
                str(step["piece_id"]),
                step["origin"],
                int(step["rotation"])
            )
            _expect(bool(result.get("ok", false)), "specimen %d reference fragment %s fits" % [level_index, str(step["piece_id"])])
            if bool(result.get("ok", false)):
                state = result["state"]
        _expect(str(state.get("status", "")) == "won", "specimen %d reference solution reconstructs the complete fossil" % level_index)
        _expect(Rules.is_complete(state), "specimen %d occupies every target cell exactly once" % level_index)

    var state: Dictionary = Rules.create_state(0)
    var invalid_outside: Dictionary = Rules.place_piece(state, "horn", Vector2i(4, 4), 0)
    _expect(not bool(invalid_outside.get("ok", true)) and str(invalid_outside.get("reason", "")) == "out_of_bounds", "out-of-bounds placement is rejected")
    _expect(state.get("occupied", {}).is_empty(), "failed placement leaves the caller state unchanged")
    var invalid_void: Dictionary = Rules.place_piece(state, "horn", Vector2i(0, 1), 0)
    _expect(not bool(invalid_void.get("ok", true)) and str(invalid_void.get("reason", "")) == "outside_specimen", "placement outside the fossil silhouette is rejected")
    var placed: Dictionary = Rules.place_piece(state, "horn", Vector2i(0, 0), 0)
    _expect(bool(placed.get("ok", false)), "valid horn fragment can be placed")
    state = placed["state"]
    var overlap: Dictionary = Rules.place_piece(state, "jaw", Vector2i(0, 0), 0)
    _expect(not bool(overlap.get("ok", true)) and str(overlap.get("reason", "")) == "overlap", "overlapping fragments are rejected")
    var removed: Dictionary = Rules.remove_piece(state, "horn")
    _expect(bool(removed.get("ok", false)), "placed fragment can be removed")
    state = removed["state"]
    _expect(state.get("occupied", {}).is_empty(), "removing a fragment frees all four cells")
    var rotated: Array[Vector2i] = Rules.transformed_cells(
        [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
        Vector2i.ZERO,
        1
    )
    _expect(rotated.size() == 4 and rotated.has(Vector2i(1, 0)) and rotated.has(Vector2i(1, 2)), "quarter-turn rotation normalizes a vertical T fragment")
    _expect(Rules.create_state(99).is_empty(), "unknown specimen index is rejected")

    if failures.is_empty():
        print("KROLL Fossil Assembly rules tests passed.")
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

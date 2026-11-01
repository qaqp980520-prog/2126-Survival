extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var rules: RefCounted = RulesScript.new() as RefCounted
    _expect(int(rules.call("level_count")) == 3, "three authored fossil specimens are available")
    for level_index in range(int(rules.call("level_count"))):
        var state: Dictionary = rules.call("create_state", level_index)
        _expect(not state.is_empty(), "specimen %d creates a valid state" % level_index)
        var definition: Dictionary = rules.call("get_level_definition", level_index)
        _expect(definition.get("target_cells", []).size() == 12, "specimen %d has twelve target cells" % level_index)
        var unique_targets: Dictionary = {}
        for target_cell in definition.get("target_cells", []):
            unique_targets[target_cell] = true
        _expect(unique_targets.size() == 12, "specimen %d target silhouette contains no duplicate cells" % level_index)
        var solution: Array = rules.call("get_reference_solution", level_index)
        _expect(solution.size() == 3, "specimen %d has three fragments" % level_index)
        for step in solution:
            var result: Dictionary = rules.call(
                "place_piece",
                state,
                str(step["piece_id"]),
                step["origin"],
                int(step["rotation"])
            )
            _expect(bool(result.get("ok", false)), "specimen %d reference fragment %s fits" % [level_index, str(step["piece_id"])])
            if bool(result.get("ok", false)):
                state = result["state"]
        _expect(str(state.get("status", "")) == "won", "specimen %d reference solution reconstructs the complete fossil" % level_index)
        _expect(bool(rules.call("is_complete", state)), "specimen %d occupies every target cell exactly once" % level_index)

    var state: Dictionary = rules.call("create_state", 0)
    var invalid_outside: Dictionary = rules.call("place_piece", state, "horn", Vector2i(4, 4), 0)
    _expect(not bool(invalid_outside.get("ok", true)) and str(invalid_outside.get("reason", "")) == "out_of_bounds", "out-of-bounds placement is rejected")
    _expect(state.get("occupied", {}).is_empty(), "failed placement leaves the caller state unchanged")
    var invalid_void: Dictionary = rules.call("place_piece", state, "horn", Vector2i(0, 1), 0)
    _expect(not bool(invalid_void.get("ok", true)) and str(invalid_void.get("reason", "")) == "outside_specimen", "placement outside the fossil silhouette is rejected")
    var placed: Dictionary = rules.call("place_piece", state, "horn", Vector2i(0, 0), 0)
    _expect(bool(placed.get("ok", false)), "valid horn fragment can be placed")
    state = placed["state"]
    var overlap: Dictionary = rules.call("place_piece", state, "jaw", Vector2i(0, 0), 0)
    _expect(not bool(overlap.get("ok", true)) and str(overlap.get("reason", "")) == "overlap", "overlapping fragments are rejected")
    var removed: Dictionary = rules.call("remove_piece", state, "horn")
    _expect(bool(removed.get("ok", false)), "placed fragment can be removed")
    state = removed["state"]
    _expect(state.get("occupied", {}).is_empty(), "removing a fragment frees all four cells")
    var first_placement: Dictionary = rules.call("place_piece", state, "horn", Vector2i(0, 0), 0)
    var second_placement: Dictionary = rules.call("place_piece", first_placement["state"], "jaw", Vector2i(0, 2), 0)
    var ordered_state: Dictionary = second_placement["state"]
    _expect(str(rules.call("get_last_placed_piece", ordered_state)) == "jaw", "placement history identifies the most recent fragment")
    var undo_result: Dictionary = rules.call("remove_piece", ordered_state, str(rules.call("get_last_placed_piece", ordered_state)))
    _expect(undo_result.get("state", {}).get("occupied", {}).size() == 4, "undo removes only the most recently placed fragment")
    var rotated: Array = rules.call(
        "transformed_cells",
        [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
        Vector2i.ZERO,
        1
    )
    _expect(rotated.size() == 4 and rotated.has(Vector2i(1, 0)) and rotated.has(Vector2i(1, 2)), "quarter-turn rotation normalizes a vertical T fragment")
    var unknown_state: Dictionary = rules.call("create_state", 99)
    _expect(unknown_state.is_empty(), "unknown specimen index is rejected")

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

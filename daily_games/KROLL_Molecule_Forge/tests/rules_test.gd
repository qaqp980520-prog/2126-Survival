extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _expect(Rules.LEVEL_COUNT == 3 and Rules.GRID_SIZE == 5, "three molecule challenges use a five-by-five board")
    var solutions: Array = [
        [
            {"element": "O", "cell": Vector2i(2, 2)},
            {"element": "H", "cell": Vector2i(2, 1)},
            {"element": "H", "cell": Vector2i(2, 3)}
        ],
        [
            {"element": "N", "cell": Vector2i(2, 2)},
            {"element": "H", "cell": Vector2i(1, 2)},
            {"element": "H", "cell": Vector2i(2, 1)},
            {"element": "H", "cell": Vector2i(3, 2)}
        ],
        [
            {"element": "C", "cell": Vector2i(2, 2)},
            {"element": "H", "cell": Vector2i(1, 2)},
            {"element": "H", "cell": Vector2i(2, 1)},
            {"element": "H", "cell": Vector2i(3, 2)},
            {"element": "H", "cell": Vector2i(2, 3)}
        ]
    ]
    for level_index in range(Rules.LEVEL_COUNT):
        var level: Dictionary = Rules.get_level(level_index)
        var state: Dictionary = Rules.new_state(level_index)
        for entry_value in solutions[level_index]:
            var entry: Dictionary = entry_value
            var result: Dictionary = Rules.place_atom(state, str(entry["element"]), entry["cell"])
            _expect(bool(result.get("ok", false)), "%s accepts a valid atom placement" % str(level.get("name", level_index)))
            state = result.get("state", state)
        var report: Dictionary = Rules.evaluate(state)
        _expect(bool(report.get("complete", false)), "%s solution satisfies formula, connectivity and valence" % str(level.get("name", level_index)))
        _expect(int(report.get("bond_count", -1)) == int(level.get("target_bonds", -2)), "%s reaches the exact target bond count" % str(level.get("name", level_index)))
        _expect(bool(report.get("saturated", false)), "%s uses every atom's available valence" % str(level.get("name", level_index)))

    var invalid_state: Dictionary = Rules.new_state(0)
    var invalid_element: Dictionary = Rules.place_atom(invalid_state, "X", Vector2i(2, 2))
    _expect(not bool(invalid_element.get("ok", false)) and str(invalid_element.get("reason", "")) == "invalid_element", "unknown elements are rejected")
    var out_of_bounds: Dictionary = Rules.place_atom(invalid_state, "O", Vector2i(5, 2))
    _expect(not bool(out_of_bounds.get("ok", false)) and str(out_of_bounds.get("reason", "")) == "invalid_cell", "cells outside the board are rejected")
    var occupied_state: Dictionary = Rules.place_atom(invalid_state, "O", Vector2i(2, 2)).get("state", invalid_state)
    var occupied_result: Dictionary = Rules.place_atom(occupied_state, "H", Vector2i(2, 2))
    _expect(not bool(occupied_result.get("ok", false)) and str(occupied_result.get("reason", "")) == "occupied_cell", "an occupied cell cannot receive a second atom")

    var over_limit: Dictionary = Rules.new_state(0)
    over_limit = Rules.place_atom(over_limit, "H", Vector2i(2, 1)).get("state", over_limit)
    over_limit = Rules.place_atom(over_limit, "H", Vector2i(2, 3)).get("state", over_limit)
    var third_hydrogen: Dictionary = Rules.place_atom(over_limit, "H", Vector2i(0, 0))
    _expect(not bool(third_hydrogen.get("ok", false)) and str(third_hydrogen.get("reason", "")) == "atom_limit", "the exact target formula limits available atom counts")

    var over_valence: Dictionary = Rules.new_state(0)
    over_valence = Rules.place_atom(over_valence, "H", Vector2i(1, 2)).get("state", over_valence)
    over_valence = Rules.place_atom(over_valence, "H", Vector2i(2, 2)).get("state", over_valence)
    var blocked_bond: Dictionary = Rules.place_atom(over_valence, "O", Vector2i(3, 2))
    _expect(not bool(blocked_bond.get("ok", false)) and str(blocked_bond.get("reason", "")) == "valence_exceeded", "a new bond cannot exceed an existing hydrogen's valence")
    var blocked_state: Dictionary = blocked_bond.get("state", {})
    var blocked_atoms: Array = blocked_state.get("atoms", [])
    _expect(blocked_atoms.size() == 2, "a rejected bond leaves the board unchanged")

    var disconnected: Dictionary = Rules.new_state(0)
    disconnected = Rules.place_atom(disconnected, "O", Vector2i(0, 0)).get("state", disconnected)
    disconnected = Rules.place_atom(disconnected, "H", Vector2i(0, 1)).get("state", disconnected)
    disconnected = Rules.place_atom(disconnected, "H", Vector2i(4, 4)).get("state", disconnected)
    var disconnected_report: Dictionary = Rules.evaluate(disconnected)
    _expect(bool(disconnected_report.get("formula_ok", false)), "disconnected test still has the correct H2O formula")
    _expect(not bool(disconnected_report.get("connected", true)) and not bool(disconnected_report.get("complete", false)), "a correct formula is not accepted while atoms remain disconnected")

    var removed: Dictionary = Rules.remove_atom(disconnected, Vector2i(4, 4))
    var removed_state: Dictionary = removed.get("state", {})
    var removed_atoms: Array = removed_state.get("atoms", [])
    _expect(bool(removed.get("ok", false)) and removed_atoms.size() == 2, "removing a selected atom updates the board")
    var empty_remove: Dictionary = Rules.remove_atom(removed_state, Vector2i(4, 4))
    _expect(not bool(empty_remove.get("ok", false)) and str(empty_remove.get("reason", "")) == "empty_cell", "removing an empty cell is a no-op")

    if failures.is_empty():
        print("KROLL Molecule Forge rules tests passed.")
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

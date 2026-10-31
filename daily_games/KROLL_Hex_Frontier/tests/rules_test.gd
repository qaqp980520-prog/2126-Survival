extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var rules: RefCounted = RulesScript.new()
    _expect(rules.call("get_cells").size() == 19, "radius-two axial board contains exactly nineteen hexes")
    _expect(rules.call("get_neighbors", Vector2i.ZERO).size() == 6, "central hex has six valid neighbors")
    _expect(rules.call("get_neighbors", Vector2i(-2, 0)).size() == 3, "corner base has three valid neighbors")

    var state: Dictionary = rules.call("new_game", 0)
    _expect(int(state.get("current_player", 0)) == 1, "human player starts the first turn")
    _expect(int(rules.call("territory_count", state, 1)) == 1 and int(rules.call("territory_count", state, 2)) == 1, "both factions begin with one headquarters")
    _expect(rules.call("get_legal_claims", state, 1).size() == 3, "player can claim one of three connected opening hexes")

    var disconnected: Dictionary = rules.call("apply_claim", state, Vector2i.ZERO)
    _expect(not bool(disconnected.get("ok", false)) and str(disconnected.get("reason", "")) == "not_connected", "a neutral hex outside the owned frontier cannot be claimed")
    _expect(int(rules.call("territory_count", state, 1)) == 1, "rejected claim leaves the original state unchanged")

    var first_claim: Vector2i = rules.call("get_legal_claims", state, 1)[0]
    var claim_result: Dictionary = rules.call("apply_claim", state, first_claim)
    _expect(bool(claim_result.get("ok", false)), "legal frontier claim succeeds")
    state = claim_result.get("state", state)
    _expect(int(rules.call("territory_count", state, 1)) == 2, "claim adds exactly one territory")
    _expect(int(rules.call("get_energy", state, 1)) == 3, "claim spends one energy")

    var base_upgrade: Dictionary = rules.call("apply_upgrade", state, Vector2i(-2, 0))
    _expect(bool(base_upgrade.get("ok", false)), "owned headquarters can be upgraded")
    var upgraded_state: Dictionary = base_upgrade.get("state", {})
    _expect(int(rules.call("get_energy", upgraded_state, 1)) == 1, "upgrade spends two energy")
    _expect(int(rules.call("get_tile", upgraded_state, Vector2i(-2, 0)).get("yield", 0)) == 2, "upgrade increases tile energy yield by one")

    var round_result: Dictionary = rules.call("advance_round", upgraded_state)
    _expect(bool(round_result.get("ok", false)), "player can end a valid turn")
    var round_state: Dictionary = round_result.get("state", {})
    _expect(int(round_state.get("current_player", 0)) == 1 and int(round_state.get("turn", 0)) == 2, "AI resolves and control returns to the player on the next round")
    _expect(int(rules.call("territory_count", round_state, 2)) == 2, "AI claims a connected resource hex deterministically")
    _expect(int(rules.call("get_energy", round_state, 1)) >= 1, "owned tile yields restore player energy at the next turn")

    var scenario_a: Dictionary = rules.call("new_game", 0)
    var scenario_b: Dictionary = rules.call("new_game", 1)
    _expect(scenario_a.get("tiles") != scenario_b.get("tiles"), "three authored maps use distinct deterministic resource layouts")

    var win_state: Dictionary = rules.call("new_game", 2)
    var safety: int = 0
    while int(rules.call("territory_count", win_state, 1)) < 10 and safety < 20:
        win_state["current_player"] = 1
        var energy: Dictionary = win_state.get("energy", {}).duplicate(true)
        energy["1"] = 9
        win_state["energy"] = energy
        var legal: Array = rules.call("get_legal_claims", win_state, 1)
        if legal.is_empty():
            break
        var result: Dictionary = rules.call("apply_claim", win_state, legal[0])
        if not bool(result.get("ok", false)):
            break
        win_state = result["state"]
        safety += 1
    _expect(int(rules.call("territory_count", win_state, 1)) == 10 and int(win_state.get("winner", 0)) == 1, "controlling ten connected hexes wins the campaign")

    var finished: Dictionary = rules.call("apply_claim", win_state, Vector2i.ZERO)
    _expect(not bool(finished.get("ok", false)) and str(finished.get("reason", "")) == "game_over", "actions are rejected after a winner is declared")

    if failures.is_empty():
        print("KROLL Hex Frontier rules tests passed.")
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

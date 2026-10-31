extends SceneTree

const GameScene = preload("res://main.tscn")
const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(game.has_method("get_current_state"), "scene exposes a read-only state snapshot for validation")
    _expect(game.has_method("perform_action_at") and game.has_method("end_player_turn"), "scene exposes the same action path used by mouse and keyboard input")
    var state: Dictionary = game.call("get_current_state")
    var rules: RefCounted = RulesScript.new()
    _expect(int(rules.call("territory_count", state, 1)) == 1, "new game displays the player headquarters")
    var legal: Array = rules.call("get_legal_claims", state, 1)
    _expect(not legal.is_empty(), "new game exposes at least one legal opening move")
    if not legal.is_empty():
        var action: Dictionary = game.call("perform_action_at", legal[0])
        _expect(bool(action.get("ok", false)), "the game scene accepts a legal board action")
        var updated: Dictionary = game.call("get_current_state")
        _expect(int(rules.call("territory_count", updated, 1)) == 2, "board redraw reflects the accepted claim")
    var turn: Dictionary = game.call("end_player_turn")
    _expect(bool(turn.get("ok", false)), "end-turn button resolves the AI response")
    var after_ai: Dictionary = game.call("get_current_state")
    _expect(int(after_ai.get("turn", 0)) == 2, "runtime scene advances to the next player turn")
    _expect(game.find_child("ActionBar", true, false) != null, "runtime scene creates the visible action bar")
    _expect(game.find_children("*", "Button", true, false).size() == 5, "runtime scene creates claim, upgrade, end, reset and map buttons")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Hex Frontier runtime smoke test passed.")
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

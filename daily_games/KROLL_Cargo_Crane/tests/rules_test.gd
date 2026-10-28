extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var first := Rules.new_game(7)
    var repeated := Rules.new_game(7)
    _expect(first == repeated, "same seed creates identical initial crane state")

    var invalid_direction: Dictionary = Rules.move_hook(first, 0, 24.0)
    _expect(not bool(invalid_direction.get("ok", true)), "invalid direction is rejected")
    _expect(float(first["hook_x"]) == 480.0, "invalid movement leaves source state unchanged")

    var clamped: Dictionary = Rules.move_hook(first, -1, 10000.0)
    _expect(bool(clamped.get("ok", false)) and float(clamped["state"]["hook_x"]) >= 20.0, "hook movement clamps inside the field")
    _expect(float(first["hook_x"]) == 480.0, "valid movement returns a detached candidate state")

    var win_state: Dictionary = Rules.new_game(7)
    for index in range(Rules.MAX_LOADS):
        win_state["hook_x"] = _top_center(win_state)
        var placed: Dictionary = Rules.drop_load(win_state)
        _expect(bool(placed.get("ok", false)), "aligned drop %d is accepted" % (index + 1))
        win_state = placed["state"]
    var stack: Array = win_state["placed"]
    _expect(str(win_state["status"]) == "won", "six stable loads win the contract")
    _expect(stack.size() == Rules.MAX_LOADS, "winning stack contains six loads")
    _expect(int(win_state["moves"]) == Rules.MAX_LOADS, "only successful placements count as moves")

    var locked: Dictionary = Rules.drop_load(win_state)
    _expect(not bool(locked.get("ok", true)) and str(locked.get("reason", "")) == "terminal", "terminal state rejects further drops")
    _expect(str(win_state["status"]) == "won" and stack.size() == Rules.MAX_LOADS, "terminal rejection does not mutate the winning state")

    var miss_state: Dictionary = Rules.new_game(3)
    miss_state["hook_x"] = 80.0
    var miss: Dictionary = Rules.drop_load(miss_state)
    _expect(bool(miss.get("ok", false)) and str(miss.get("reason", "")) == "missed", "non-overlapping load is recorded as a miss")
    _expect(str(miss["state"]["status"]) == "failed" and miss["state"]["placed"].is_empty(), "miss ends the run without adding a block")

    var drift_state: Dictionary = Rules.new_game(3)
    drift_state["hook_x"] = 430.0
    var drift: Dictionary = Rules.drop_load(drift_state)
    _expect(bool(drift.get("ok", false)) and str(drift.get("reason", "")) == "placed", "partial overlap is accepted when it remains stable")
    _expect(float(drift["state"]["placed"][0]["width"]) < float(drift_state["load_width"]), "off-center placement narrows the next support surface")

    if failures.is_empty():
        print("KROLL Cargo Crane rules tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _top_center(state: Dictionary) -> float:
    var placed: Array = state["placed"]
    if placed.is_empty():
        return float(state["base_left"]) + float(state["base_width"]) * 0.5
    var top: Dictionary = placed.back()
    return float(top["left"]) + float(top["width"]) * 0.5

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)

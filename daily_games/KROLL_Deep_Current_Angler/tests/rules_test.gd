extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var initial: Dictionary = Rules.new_game(33)
    _expect(initial == Rules.new_game(33), "same seed creates the same initial state")
    _expect(not bool(Rules.perform_action(initial, "wait").get("ok", false)), "waiting before casting is rejected")
    _expect(initial["turns"] == 0 and initial["mode"] == "idle", "rejected action does not mutate the source state")

    var cast := Rules.perform_action(initial, "cast")
    _expect(bool(cast["ok"]), "cast starts a fishing attempt")
    var state: Dictionary = cast["state"]
    while state["mode"] == "waiting":
        state = Rules.perform_action(state, "wait")["state"]
    _expect(state["mode"] == "bite", "deterministic wait reaches the bite window")
    state = Rules.perform_action(state, "hook")["state"]
    _expect(state["mode"] == "fight", "hook starts a fish fight")

    var broken: Dictionary = state.duplicate(true)
    for i in range(4):
        var result: Dictionary = Rules.perform_action(broken, "reel")
        if bool(result["ok"]):
            broken = result["state"]
    _expect(broken["status"] == "failed", "excessive reeling snaps the line")

    var win: Dictionary = Rules.new_game(33)
    var guard: int = 0
    while win["status"] == "playing" and guard < Rules.MAX_TURNS:
        guard += 1
        match str(win["mode"]):
            "idle":
                win = Rules.perform_action(win, "cast")["state"]
            "waiting":
                win = Rules.perform_action(win, "wait")["state"]
            "bite":
                win = Rules.perform_action(win, "hook")["state"]
            "fight":
                var action: String = "ease" if float(win["tension"]) >= 65.0 else "reel"
                win = Rules.perform_action(win, action)["state"]
    _expect(win["status"] == "won", "a controlled reel/ease rhythm catches three fish within the tide window")
    _expect(win["catches"] == Rules.TARGET_CATCHES, "victory requires exactly the target catch count")
    _expect(int(win["turns"]) <= Rules.MAX_TURNS, "winning route respects the action budget")

    var missed: Dictionary = Rules.new_game(34)
    missed = Rules.perform_action(missed, "cast")["state"]
    while missed["mode"] == "waiting":
        missed = Rules.perform_action(missed, "wait")["state"]
    missed = Rules.perform_action(missed, "wait")["state"]
    _expect(missed["mode"] == "idle" and missed["status"] == "playing", "ignoring a bite loses that fish but keeps the run playable")

    if failures.is_empty():
        print("KROLL Deep Current Angler rules tests passed.")
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

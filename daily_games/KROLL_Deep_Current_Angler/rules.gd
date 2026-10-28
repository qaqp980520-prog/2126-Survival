extends RefCounted

const TARGET_CATCHES := 3
const MAX_TURNS := 30
const MAX_TENSION := 100.0
const REEL_TENSION := 22.0
const EASE_AMOUNT := 35.0

static func new_game(seed_value: int = 33) -> Dictionary:
    return {
        "seed": seed_value,
        "mode": "idle",
        "status": "playing",
        "casts": 0,
        "catches": 0,
        "turns": 0,
        "wait_ticks": 0,
        "bite_after": 1,
        "fish_energy": 0,
        "tension": 20.0,
        "message": "Cast your line and watch for a bite."
    }

static func perform_action(state: Dictionary, action: String) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    var next: Dictionary = state.duplicate(true)
    var mode: String = str(next.get("mode", "idle"))
    match action:
        "cast":
            if mode != "idle":
                return _result(false, "line_busy", state)
            var cast_index: int = int(next.get("casts", 0))
            next["casts"] = cast_index + 1
            next["mode"] = "waiting"
            next["wait_ticks"] = 0
            next["bite_after"] = 1 + posmod(int(next.get("seed", 0)) + cast_index, 3)
            next["fish_energy"] = 3 + posmod(int(next.get("seed", 0)) + cast_index * 5, 3)
            next["tension"] = 20.0
            next["message"] = "Line cast. Wait for the bite signal."
        "wait":
            if mode == "waiting":
                next["wait_ticks"] = int(next.get("wait_ticks", 0)) + 1
                if int(next["wait_ticks"]) >= int(next["bite_after"]):
                    next["mode"] = "bite"
                    next["message"] = "BITE! Hook now."
                else:
                    next["message"] = "The current is quiet. Keep watching."
            elif mode == "bite":
                next["mode"] = "idle"
                next["message"] = "The fish escaped. Cast again."
            else:
                return _result(false, "cannot_wait", state)
        "hook":
            if mode != "bite":
                return _result(false, "no_bite", state)
            next["mode"] = "fight"
            next["tension"] = 20.0
            next["message"] = "Hook set. Reel carefully; ease the line before it snaps."
        "reel":
            if mode != "fight":
                return _result(false, "no_fish_on_line", state)
            next["tension"] = float(next.get("tension", 20.0)) + REEL_TENSION
            next["fish_energy"] = int(next.get("fish_energy", 1)) - 1
            if float(next["tension"]) >= MAX_TENSION:
                next["status"] = "failed"
                next["message"] = "The line snapped. Reset and try a gentler rhythm."
            elif int(next["fish_energy"]) <= 0:
                next["catches"] = int(next.get("catches", 0)) + 1
                next["mode"] = "idle"
                next["tension"] = 20.0
                if int(next["catches"]) >= TARGET_CATCHES:
                    next["status"] = "won"
                    next["message"] = "Three fish secured. The expedition is a success!"
                else:
                    next["message"] = "Fish landed! Cast for the next catch."
            else:
                next["message"] = "Reel in. Watch the line tension."
        "ease":
            if mode != "fight":
                return _result(false, "no_fish_on_line", state)
            next["tension"] = maxf(0.0, float(next.get("tension", 20.0)) - EASE_AMOUNT)
            next["message"] = "Line eased. The fish is tiring; resume reeling when safe."
        _:
            return _result(false, "unknown_action", state)
    next["turns"] = int(next.get("turns", 0)) + 1
    if str(next.get("status", "playing")) == "playing" and int(next["turns"]) >= MAX_TURNS:
        next["status"] = "failed"
        next["message"] = "The tide window closed. Reset to try another approach."
    return _result(true, "ok", next)

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
    return {"ok": ok, "reason": reason, "state": state.duplicate(true)}

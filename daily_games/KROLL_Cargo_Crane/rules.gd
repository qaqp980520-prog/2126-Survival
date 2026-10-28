extends RefCounted

const FIELD_WIDTH := 960.0
const BASE_LEFT := 370.0
const BASE_WIDTH := 220.0
const MAX_LOADS := 6
const BLOCK_HEIGHT := 34.0
const MIN_OVERLAP := 24.0
const MAX_CENTER_DRIFT := 74.0

static func new_game(seed_value: int = 7) -> Dictionary:
    return {
        "seed": seed_value,
        "base_left": BASE_LEFT,
        "base_width": BASE_WIDTH,
        "hook_x": BASE_LEFT + BASE_WIDTH * 0.5,
        "load_width": _load_width(seed_value, 0),
        "placed": [],
        "level": 0,
        "moves": 0,
        "status": "playing",
        "message": "Stack %d loads. Align the hook, then drop." % MAX_LOADS
    }

static func move_hook(state: Dictionary, direction: int, distance: float = 24.0) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    if direction != -1 and direction != 1:
        return _result(false, "invalid_direction", state)
    if not is_finite(distance) or distance <= 0.0:
        return _result(false, "invalid_distance", state)
    var width := float(state.get("load_width", 0.0))
    if not is_finite(width) or width <= 0.0:
        return _result(false, "invalid_state", state)
    var next: Dictionary = state.duplicate(true)
    var minimum_x := 20.0 + width * 0.5
    var maximum_x := FIELD_WIDTH - 20.0 - width * 0.5
    next["hook_x"] = clampf(float(next.get("hook_x", FIELD_WIDTH * 0.5)) + float(direction) * distance, minimum_x, maximum_x)
    return _result(true, "moved", next)

static func drop_load(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    var raw_placed: Variant = state.get("placed", null)
    if not (raw_placed is Array):
        return _result(false, "invalid_state", state)
    var load_width := float(state.get("load_width", 0.0))
    var hook_x := float(state.get("hook_x", -1.0))
    if not is_finite(load_width) or load_width <= 0.0 or not is_finite(hook_x):
        return _result(false, "invalid_state", state)

    var next: Dictionary = state.duplicate(true)
    var placed: Array = next["placed"]
    var top_left := float(next.get("base_left", BASE_LEFT))
    var top_width := float(next.get("base_width", BASE_WIDTH))
    if not placed.is_empty():
        var top: Variant = placed.back()
        if not (top is Dictionary):
            return _result(false, "invalid_state", state)
        top_left = float(top.get("left", top_left))
        top_width = float(top.get("width", top_width))
    if not is_finite(top_left) or not is_finite(top_width) or top_width <= 0.0:
        return _result(false, "invalid_state", state)

    var load_left := hook_x - load_width * 0.5
    var overlap_left := maxf(load_left, top_left)
    var overlap_right := minf(load_left + load_width, top_left + top_width)
    var overlap_width := maxf(0.0, overlap_right - overlap_left)
    var required_overlap := maxf(MIN_OVERLAP, load_width * 0.35)
    if overlap_width < required_overlap:
        next["status"] = "failed"
        next["message"] = "MISS. The load did not overlap enough; press R to retry."
        return _result(true, "missed", next)

    var new_center := overlap_left + overlap_width * 0.5
    var base_center := float(next.get("base_left", BASE_LEFT)) + float(next.get("base_width", BASE_WIDTH)) * 0.5
    if absf(new_center - base_center) > MAX_CENTER_DRIFT:
        next["status"] = "failed"
        next["message"] = "STACK COLLAPSED. Center the load closer to the base."
        return _result(true, "collapsed", next)

    var next_level := int(next.get("level", 0)) + 1
    placed.append({
        "left": overlap_left,
        "width": overlap_width,
        "level": next_level,
        "color_index": posmod(int(next.get("seed", 0)) + next_level * 2, 5)
    })
    next["placed"] = placed
    next["level"] = next_level
    next["moves"] = int(next.get("moves", 0)) + 1
    if next_level >= MAX_LOADS:
        next["status"] = "won"
        next["message"] = "LOAD SECURED. Six containers stacked safely!"
    else:
        next["load_width"] = _load_width(int(next.get("seed", 0)), next_level)
        next["message"] = "Load %d/%d secured. Keep the stack centered." % [next_level, MAX_LOADS]
    return _result(true, "placed", next)

static func _load_width(seed_value: int, level: int) -> float:
    var variation := posmod(seed_value + level * 5, 3) - 1
    return maxf(72.0, 190.0 - float(level) * 8.0 + float(variation) * 4.0)

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
    return {"ok": ok, "reason": reason, "state": state.duplicate(true)}

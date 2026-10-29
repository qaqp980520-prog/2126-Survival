extends RefCounted
class_name KrollSkylineCourierRules

const LANE_COUNT := 3
const STARTING_LIVES := 3
const TARGET_PACKETS := 6
const TIME_LIMIT := 45.0
const SPEED := 7.0
const MAX_FRAME_DELTA := 0.25

static func new_game(seed_value: int = 11) -> Dictionary:
    return {
        "seed": seed_value,
        "lane": 1,
        "distance": 0.0,
        "time_left": TIME_LIMIT,
        "lives": STARTING_LIVES,
        "packets": 0,
        "score": 0,
        "next_item": 0,
        "status": "playing",
        "message": "Deliver %d data packets. Dodge red barriers." % TARGET_PACKETS,
        "items": _build_items(seed_value)
    }

static func select_lane(state: Dictionary, lane: int) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    if lane < 0 or lane >= LANE_COUNT:
        return _result(false, "invalid_lane", state)
    var next: Dictionary = state.duplicate(true)
    next["lane"] = lane
    return _result(true, "lane_selected", next)

static func move_lane(state: Dictionary, direction: int) -> Dictionary:
    if direction != -1 and direction != 1:
        return _result(false, "invalid_direction", state)
    return select_lane(state, int(state.get("lane", 1)) + direction)

static func advance(state: Dictionary, delta: float) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    if not is_finite(delta) or delta <= 0.0 or delta > MAX_FRAME_DELTA:
        return _result(false, "invalid_delta", state)
    var items_value: Variant = state.get("items", null)
    if not (items_value is Array):
        return _result(false, "invalid_items", state)
    var next: Dictionary = state.duplicate(true)
    var previous_distance: float = float(next.get("distance", 0.0))
    var next_distance: float = previous_distance + SPEED * delta
    next["distance"] = next_distance
    next["time_left"] = maxf(0.0, float(next.get("time_left", 0.0)) - delta)
    var items: Array = next["items"]
    var next_item: int = int(next.get("next_item", 0))
    if next_item < 0 or next_item > items.size():
        return _result(false, "invalid_item_cursor", state)
    while next_item < items.size():
        var raw_item: Variant = items[next_item]
        if not (raw_item is Dictionary):
            return _result(false, "invalid_item", state)
        var item: Dictionary = raw_item
        var item_distance_value: Variant = item.get("distance", null)
        var item_lane_value: Variant = item.get("lane", null)
        var kind_value: Variant = item.get("kind", null)
        if not (item_distance_value is int or item_distance_value is float) or not is_finite(float(item_distance_value)):
            return _result(false, "invalid_item_distance", state)
        if not (item_lane_value is int) or int(item_lane_value) < 0 or int(item_lane_value) >= LANE_COUNT:
            return _result(false, "invalid_item_lane", state)
        if str(kind_value) != "hazard" and str(kind_value) != "packet":
            return _result(false, "invalid_item_kind", state)
        var item_distance: float = float(item_distance_value)
        if item_distance > next_distance:
            break
        if item_distance > previous_distance and int(item_lane_value) == int(next.get("lane", 1)):
            if str(kind_value) == "hazard":
                next["lives"] = maxi(0, int(next.get("lives", STARTING_LIVES)) - 1)
                next["message"] = "IMPACT. Switch lanes before the next barrier."
                if int(next["lives"]) <= 0:
                    next["status"] = "failed"
            else:
                next["packets"] = int(next.get("packets", 0)) + 1
                next["score"] = int(next.get("score", 0)) + 100
                next["message"] = "DATA SECURED: %d/%d" % [int(next["packets"]), TARGET_PACKETS]
                if int(next["packets"]) >= TARGET_PACKETS:
                    next["status"] = "won"
                    next["message"] = "DELIVERY COMPLETE. Six packets secured."
        next_item += 1
        if str(next.get("status", "")) != "playing":
            break
    next["next_item"] = next_item
    if str(next.get("status", "")) == "playing" and float(next.get("time_left", 0.0)) <= 0.0:
        next["status"] = "failed"
        next["message"] = "DELIVERY WINDOW EXPIRED."
    return _result(true, "advanced", next)

static func _build_items(seed_value: int) -> Array:
    var items: Array = []
    for index in range(18):
        var lane: int = posmod(seed_value + index * 2 + int(index / 3), LANE_COUNT)
        var kind: String = "packet" if index % 3 == 1 else "hazard"
        items.append({
            "id": index,
            "distance": 10.0 + float(index) * 6.5,
            "lane": lane,
            "kind": kind
        })
    return items

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
    return {"ok": ok, "reason": reason, "state": state.duplicate(true)}

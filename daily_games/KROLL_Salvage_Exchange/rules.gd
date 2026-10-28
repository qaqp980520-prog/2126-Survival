extends RefCounted

const ITEMS := ["copper", "polymer", "circuit", "alloy"]
const LABELS := {"copper": "Copper", "polymer": "Polymer", "circuit": "Circuit", "alloy": "Alloy"}
const BASE_PRICES := [12, 20, 30, 45]
const VOLATILITY := [2, 3, 5, 7]
const STARTING_CREDITS := 100
const CARGO_CAPACITY := 10
const FEE_PERCENT := 5
const MAX_DAYS := 8
const TARGET_NET_WORTH := 150

static func new_game(seed_value: int = 3) -> Dictionary:
    var cargo := {}
    for item in ITEMS:
        cargo[item] = 0
    return {
        "seed": seed_value,
        "day": 1,
        "credits": STARTING_CREDITS,
        "starting_credits": STARTING_CREDITS,
        "capacity": CARGO_CAPACITY,
        "cargo": cargo,
        "prices": _prices_for(seed_value, 1),
        "status": "playing",
        "actions": 0,
        "message": "Buy low, sell high. Reach net worth 150 before closing day 8."
    }

static func price_for(seed_value: int, day: int, item_index: int) -> int:
    if item_index < 0 or item_index >= ITEMS.size() or day < 1:
        return 0
    var wave: int = posmod(seed_value + day * (item_index + 2) * 3 + item_index * 5, 9) - 4
    return maxi(3, BASE_PRICES[item_index] + wave * VOLATILITY[item_index])

static func _prices_for(seed_value: int, day: int) -> Dictionary:
    var prices := {}
    for i in range(ITEMS.size()):
        prices[ITEMS[i]] = price_for(seed_value, day, i)
    return prices

static func trade(state: Dictionary, side: String, item: String, quantity: int = 1) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    var raw_cargo: Variant = state.get("cargo", {})
    if not (raw_cargo is Dictionary) or not ITEMS.has(item) or not raw_cargo.has(item):
        return _result(false, "unknown_item", state)
    if side != "buy" and side != "sell":
        return _result(false, "unknown_side", state)
    if quantity <= 0:
        return _result(false, "invalid_quantity", state)

    var next: Dictionary = state.duplicate(true)
    var cargo: Dictionary = next["cargo"]
    var current_units := _cargo_units(cargo)
    var price := int(next["prices"].get(item, 0))
    var gross := price * quantity
    var fee := int(ceil(float(gross * FEE_PERCENT) / 100.0))

    if side == "buy":
        if current_units + quantity > int(next["capacity"]):
            return _result(false, "cargo_capacity", state)
        if gross + fee > int(next["credits"]):
            return _result(false, "insufficient_credits", state)
        next["credits"] = int(next["credits"]) - gross - fee
        cargo[item] = int(cargo[item]) + quantity
        next["message"] = "Bought %d %s for %d credits including %d fee." % [quantity, item, gross + fee, fee]
    else:
        if quantity > int(cargo[item]):
            return _result(false, "insufficient_stock", state)
        var net := gross - fee
        cargo[item] = int(cargo[item]) - quantity
        next["credits"] = int(next["credits"]) + net
        next["message"] = "Sold %d %s for %d credits after %d fee." % [quantity, item, net, fee]

    next["cargo"] = cargo
    next["actions"] = int(next["actions"]) + 1
    return _result(true, "ok", next)

static func advance_day(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    var next: Dictionary = state.duplicate(true)
    if int(next["day"]) < MAX_DAYS:
        next["day"] = int(next["day"]) + 1
        next["prices"] = _prices_for(int(next["seed"]), int(next["day"]))
        next["actions"] = int(next["actions"]) + 1
        next["message"] = "Day %d market opened. Check prices before trading." % int(next["day"])
    else:
        var worth := net_worth(next)
        next["status"] = "won" if worth >= TARGET_NET_WORTH else "failed"
        next["message"] = "Contract complete: net worth %d." % worth if next["status"] == "won" else "Contract closed at net worth %d. Target was %d." % [worth, TARGET_NET_WORTH]
        next["actions"] = int(next["actions"]) + 1
    return _result(true, "ok", next)

static func net_worth(state: Dictionary) -> int:
    var worth := int(state.get("credits", 0))
    var cargo: Dictionary = state.get("cargo", {})
    var prices: Dictionary = state.get("prices", {})
    for item in ITEMS:
        worth += int(cargo.get(item, 0)) * int(prices.get(item, 0))
    return worth

static func _cargo_units(cargo: Dictionary) -> int:
    var units := 0
    for item in ITEMS:
        units += int(cargo.get(item, 0))
    return units

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
    return {"ok": ok, "reason": reason, "state": state.duplicate(true)}

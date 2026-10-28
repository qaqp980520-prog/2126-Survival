extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var initial: Dictionary = Rules.new_game(3)
    _expect(initial == Rules.new_game(3), "same seed creates identical starting state")
    _expect(int(initial["prices"]["copper"]) == 4, "seed 3 opens with copper at the deterministic low price")
    _expect(int(Rules.new_game(3)["prices"]["alloy"]) > 0, "all commodities receive valid prices")

    var rejected := Rules.trade(initial, "buy", "copper", 0)
    _expect(not bool(rejected["ok"]) and rejected["state"] == initial, "zero quantity is rejected without mutation")
    rejected = Rules.trade(initial, "buy", "unknown", 1)
    _expect(not bool(rejected["ok"]) and rejected["state"] == initial, "unknown commodities are rejected without mutation")
    rejected = Rules.trade(initial, "sell", "copper", 1)
    _expect(not bool(rejected["ok"]) and rejected["state"] == initial, "selling unavailable stock is rejected without mutation")
    var rounded_fee := Rules.trade(initial, "buy", "copper", 1)
    _expect(bool(rounded_fee["ok"]) and int(rounded_fee["state"]["credits"]) == 95, "small trade rounds the 5% fee up to one credit")
    var malformed := initial.duplicate(true)
    malformed["cargo"] = "not-a-dictionary"
    rejected = Rules.trade(malformed, "buy", "copper", 1)
    _expect(not bool(rejected["ok"]) and rejected["reason"] == "unknown_item", "malformed cargo payload is rejected before mutation")

    var bought := Rules.trade(initial, "buy", "copper", 10)
    _expect(bool(bought["ok"]), "buy ten low-priced units within the capacity")
    var state: Dictionary = bought["state"]
    _expect(int(state["credits"]) == 58 and int(state["cargo"]["copper"]) == 10, "purchase fee is charged and cargo updates atomically")
    rejected = Rules.trade(state, "buy", "polymer", 1)
    _expect(not bool(rejected["ok"]) and rejected["reason"] == "cargo_capacity", "cargo limit rejects overflow without mutation")
    _expect(rejected["state"] == state, "capacity rejection leaves the source state unchanged")

    var day_change := Rules.advance_day(state)
    _expect(bool(day_change["ok"]), "day advances while the contract is active")
    state = day_change["state"]
    _expect(int(state["day"]) == 2 and int(state["prices"]["copper"]) == 16, "deterministic day-two market raises copper price")
    var sold := Rules.trade(state, "sell", "copper", 10)
    _expect(bool(sold["ok"]) and int(sold["state"]["credits"]) == 210, "profitable sale deducts fees and increases credits")
    state = sold["state"]
    _expect(Rules.net_worth(state) == 210, "net worth includes cash and marked-to-market cargo")
    while int(state["day"]) < Rules.MAX_DAYS:
        state = Rules.advance_day(state)["state"]
    var closed := Rules.advance_day(state)
    _expect(bool(closed["ok"]) and closed["state"]["status"] == "won", "contract wins at or above the net-worth target")
    _expect(not bool(Rules.trade(closed["state"], "buy", "copper", 1)["ok"]), "terminal market rejects further trades")

    var loss: Dictionary = Rules.new_game(11)
    while int(loss["day"]) < Rules.MAX_DAYS:
        loss = Rules.advance_day(loss)["state"]
    loss = Rules.advance_day(loss)["state"]
    _expect(loss["status"] == "failed", "contract fails when net worth remains below target")

    if failures.is_empty():
        print("KROLL Salvage Exchange rules tests passed.")
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

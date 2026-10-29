extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
    var state: Dictionary = Rules.new_game(17)
    assert(state["lane"] == 1 and state["lives"] == 3 and state["packets"] == 0)
    assert(state["items"] == Rules.new_game(17)["items"], "Same seed must create the same route")
    assert(state["items"] != Rules.new_game(18)["items"], "Different seeds should vary the route")

    var left: Dictionary = Rules.move_lane(state, -1)
    assert(left["ok"] and left["state"]["lane"] == 0)
    var boundary: Dictionary = Rules.move_lane(left["state"], -1)
    assert(not boundary["ok"] and boundary["state"] == left["state"], "Lane boundary is a no-op")
    assert(not Rules.select_lane(state, 3)["ok"], "Invalid lane is rejected")

    var invalid_delta: Dictionary = Rules.advance(state, 0.0)
    assert(not invalid_delta["ok"] and invalid_delta["state"] == state, "Invalid delta cannot mutate the state")
    invalid_delta = Rules.advance(state, 0.5)
    assert(not invalid_delta["ok"] and invalid_delta["state"] == state, "Long frame delta is rejected")

    var hazard_state: Dictionary = Rules.new_game(1)
    hazard_state["items"] = [{"distance": 1.0, "lane": 1, "kind": "hazard"}]
    var hit: Dictionary = Rules.advance(hazard_state, 0.2)
    assert(hit["ok"] and hit["state"]["lives"] == 2 and hit["state"]["next_item"] == 1, "Matching a hazard costs one life")

    var packet_state: Dictionary = Rules.new_game(1)
    packet_state["items"] = [{"distance": 1.0, "lane": 1, "kind": "packet"}]
    packet_state["packets"] = 5
    var delivery: Dictionary = Rules.advance(packet_state, 0.2)
    assert(delivery["ok"] and delivery["state"]["packets"] == 6 and delivery["state"]["status"] == "won", "Sixth packet wins")
    var locked: Dictionary = Rules.advance(delivery["state"], 0.1)
    assert(not locked["ok"] and locked["state"] == delivery["state"], "Terminal state is locked")

    var timeout_state: Dictionary = Rules.new_game(2)
    timeout_state["items"] = []
    timeout_state["time_left"] = 0.1
    var timeout_result: Dictionary = Rules.advance(timeout_state, 0.2)
    assert(timeout_result["ok"] and timeout_result["state"]["status"] == "failed", "Expired delivery window fails")
    print("KROLL Skyline Courier rules tests passed.")
    quit(0)

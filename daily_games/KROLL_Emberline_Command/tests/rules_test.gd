extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var rules = RulesScript.new()
    _test_mission_contract(rules)
    _test_action_validation_and_water(rules)
    _test_firebreak_blocks_spread(rules)
    _test_relay_breach_fails(rules)
    _test_deterministic_replay(rules)
    _test_authored_mission_solutions(rules)
    _test_campaign_progression(rules)
    if failures.is_empty():
        print("KROLL Emberline Command rules tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _test_mission_contract(rules: Variant) -> void:
    _expect(rules.get_mission_count() == 3,"three authored wildfire missions exist")
    for mission_index in range(3):
        var state: Dictionary = rules.create_state(mission_index)
        _expect(not state.is_empty(),"mission %d creates a valid state" % mission_index)
        _expect(rules.get_cell_count() == 64,"mission uses an 8x8 grid")
        _expect(state.get("cells",[]).size() == 64,"mission contains 64 cells")
        _expect(rules.get_relay_count(state) == 3,"mission protects three relay stations")
        _expect(rules.get_active_fire_count(state) == 2,"mission begins with two ignition points")
        _expect(int(state.get("actions_left",0)) == 2,"mission starts with two response actions")

func _test_action_validation_and_water(rules: Variant) -> void:
    var state: Dictionary = rules.create_state(0)
    var invalid_cell: Dictionary = rules.apply_action(state,"water",-1)
    _expect(not bool(invalid_cell.get("ok",false)) and str(invalid_cell.get("reason","")) == "invalid_cell","out-of-range cell selection is rejected")
    var invalid_action: Dictionary = rules.apply_action(state,"burn",19)
    _expect(not bool(invalid_action.get("ok",false)) and str(invalid_action.get("reason","")) == "invalid_action","unknown response action is rejected")
    var fire_index: int = rules.get_cell_index(2,3)
    var water_result: Dictionary = rules.apply_action(state,"water",fire_index)
    _expect(bool(water_result.get("ok",false)),"water drop accepts an active ignition point")
    if not bool(water_result.get("ok",false)):
        return
    state = water_result["state"]
    _expect(not bool(rules.get_cell_state(state,fire_index).get("burning",true)),"water drop extinguishes its selected fire cell")
    _expect(int(state.get("water_drops",0)) == 2,"water stock decreases exactly once")
    _expect(int(state.get("actions_left",0)) == 1,"water drop consumes one action point")
    var wet_neighbor: Dictionary = rules.get_cell_state(state,rules.get_cell_index(2,2))
    _expect(int(wet_neighbor.get("wet",0)) == 2,"water drop wets adjacent flammable cells")
    var firebreak_index: int = rules.get_cell_index(1,4)
    var break_result: Dictionary = rules.apply_action(state,"firebreak",firebreak_index)
    _expect(bool(break_result.get("ok",false)),"frontline firebreak can be placed beside the remaining ignition")
    if bool(break_result.get("ok",false)):
        state = break_result["state"]
        _expect(bool(rules.get_cell_state(state,firebreak_index).get("firebreak",false)),"firebreak permanently removes target fuel")
        _expect(int(state.get("actions_left",0)) == 0,"second response consumes the remaining action point")
    var exhausted: Dictionary = rules.apply_action(state,"water",fire_index)
    _expect(not bool(exhausted.get("ok",false)) and str(exhausted.get("reason","")) == "actions_exhausted","response budget prevents a third action in the same turn")

func _test_firebreak_blocks_spread(rules: Variant) -> void:
    var state: Dictionary = rules.create_state(0)
    var cells: Array = []
    for index in range(64):
        cells.append({"terrain":"rock","fuel":0,"burning":false,"wet":0,"firebreak":false,"burned":false,"relay":false,"relay_hp":0})
    var source_index: int = rules.get_cell_index(2,3)
    var target_index: int = rules.get_cell_index(3,3)
    cells[source_index] = {"terrain":"grass","fuel":1,"burning":true,"wet":0,"firebreak":false,"burned":false,"relay":false,"relay_hp":0}
    cells[target_index] = {"terrain":"grass","fuel":2,"burning":false,"wet":0,"firebreak":true,"burned":false,"relay":false,"relay_hp":0}
    state["cells"] = cells
    var result: Dictionary = rules.end_turn(state)
    _expect(bool(result.get("ok",false)),"isolated firebreak scenario resolves a turn")
    if bool(result.get("ok",false)):
        var next_state: Dictionary = result["state"]
        _expect(not bool(rules.get_cell_state(next_state,target_index).get("burning",false)),"fire cannot cross a permanent firebreak")
        _expect(str(next_state.get("status","")) == "passed","isolated fire burns out without crossing the barrier")

func _test_relay_breach_fails(rules: Variant) -> void:
    var state: Dictionary = rules.create_state(0)
    var cells: Array = []
    for index in range(64):
        cells.append({"terrain":"rock","fuel":0,"burning":false,"wet":0,"firebreak":false,"burned":false,"relay":false,"relay_hp":0})
    var source_index: int = rules.get_cell_index(2,3)
    var relay_index: int = rules.get_cell_index(3,3)
    cells[source_index] = {"terrain":"grass","fuel":2,"burning":true,"wet":0,"firebreak":false,"burned":false,"relay":false,"relay_hp":0}
    cells[relay_index] = {"terrain":"relay","fuel":0,"burning":false,"wet":0,"firebreak":false,"burned":false,"relay":true,"relay_hp":1}
    state["cells"] = cells
    var result: Dictionary = rules.end_turn(state)
    _expect(bool(result.get("ok",false)),"relay breach scenario resolves a turn")
    if bool(result.get("ok",false)):
        _expect(str(result["state"].get("status","")) == "failed","fire entering a relay cell fails the mission")
        _expect(int(rules.get_cell_state(result["state"],relay_index).get("relay_hp",1)) == 0,"breached relay loses its integrity")

func _test_deterministic_replay(rules: Variant) -> void:
    var first: Dictionary = rules.create_state(0)
    var second: Dictionary = rules.create_state(0)
    for state_index in range(2):
        var state: Dictionary = first if state_index == 0 else second
        var water_result: Dictionary = rules.apply_action(state,"water",rules.get_cell_index(2,3))
        _expect(bool(water_result.get("ok",false)),"deterministic replay accepts the same water command")
        if not bool(water_result.get("ok",false)):
            return
        state = water_result["state"]
        var break_result: Dictionary = rules.apply_action(state,"firebreak",rules.get_cell_index(1,4))
        _expect(bool(break_result.get("ok",false)),"deterministic replay accepts the same firebreak command")
        if not bool(break_result.get("ok",false)):
            return
        var turn_result: Dictionary = rules.end_turn(state)
        _expect(bool(turn_result.get("ok",false)),"deterministic replay resolves the same turn")
        if state_index == 0:
            first = turn_result["state"]
        else:
            second = turn_result["state"]
    _expect(first == second,"identical commands and wind produce identical world states")

func _test_authored_mission_solutions(rules: Variant) -> void:
    var plans: Array[Dictionary] = [
        {"water":Vector2i(2,3),"break":Vector2i(1,4),"last":Vector2i(1,3)},
        {"water":Vector2i(4,3),"break":Vector2i(3,2),"last":Vector2i(3,3)},
        {"water":Vector2i(3,3),"break":Vector2i(4,2),"last":Vector2i(4,3)}
    ]
    for mission_index in range(3):
        var state: Dictionary = rules.create_state(mission_index)
        var plan: Dictionary = plans[mission_index]
        var water_cell: Vector2i = plan["water"]
        var break_cell: Vector2i = plan["break"]
        var last_cell: Vector2i = plan["last"]
        var water_result: Dictionary = rules.apply_action(state,"water",rules.get_cell_index(water_cell.x,water_cell.y))
        _expect(bool(water_result.get("ok",false)),"mission %d authored plan drops water" % mission_index)
        if not bool(water_result.get("ok",false)):
            continue
        state = water_result["state"]
        var break_result: Dictionary = rules.apply_action(state,"firebreak",rules.get_cell_index(break_cell.x,break_cell.y))
        _expect(bool(break_result.get("ok",false)),"mission %d authored plan builds a frontline" % mission_index)
        if not bool(break_result.get("ok",false)):
            continue
        state = break_result["state"]
        var placed_break: Dictionary = rules.get_cell_state(state,rules.get_cell_index(break_cell.x,break_cell.y))
        _expect(bool(placed_break.get("firebreak",false)),"mission %d carries the firebreak result into the next state" % mission_index)
        var first_turn: Dictionary = rules.end_turn(state)
        _expect(bool(first_turn.get("ok",false)),"mission %d resolves its first wind turn" % mission_index)
        if not bool(first_turn.get("ok",false)):
            continue
        state = first_turn["state"]
        var final_water: Dictionary = rules.apply_action(state,"water",rules.get_cell_index(last_cell.x,last_cell.y))
        _expect(bool(final_water.get("ok",false)),"mission %d plan extinguishes the remaining ignition" % mission_index)
        if not bool(final_water.get("ok",false)):
            continue
        var final_turn: Dictionary = rules.end_turn(final_water["state"])
        _expect(bool(final_turn.get("ok",false)) and str(final_turn["state"].get("status","")) == "passed","mission %d authored solution protects every relay" % mission_index)

func _test_campaign_progression(rules: Variant) -> void:
    var state: Dictionary = rules.create_state(0)
    state["status"] = "passed"
    state["mission_score"] = 50
    state["campaign_score"] = 50
    var rejected: Dictionary = rules.apply_action(state,"water",26)
    _expect(not bool(rejected.get("ok",false)) and str(rejected.get("reason","")) == "mission_not_active","completed mission cannot score repeated actions")
    var next_result: Dictionary = rules.advance_mission(state)
    _expect(bool(next_result.get("ok",false)),"passed mission advances to the next operation")
    if bool(next_result.get("ok",false)):
        _expect(int(next_result["state"].get("mission_index",-1)) == 1,"campaign advances in order")
        _expect(int(next_result["state"].get("campaign_score",0)) == 50,"campaign score carries into the next operation")
    var final_state: Dictionary = rules.create_state(2,150)
    final_state["status"] = "passed"
    var complete: Dictionary = rules.advance_mission(final_state)
    _expect(bool(complete.get("ok",false)) and str(complete["state"].get("status","")) == "campaign_complete","third mission ends the campaign")


func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)

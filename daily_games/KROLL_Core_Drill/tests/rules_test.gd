extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _expect(Rules.MISSION_COUNT == 3, "three authored core-drilling sites are available")
    _expect(Rules.ROW_COUNT == 8 and Rules.COLUMN_COUNT == 5, "each site has an eight-row, five-lane shaft")
    var routes: Array = [
        [2, 1, 2, 3, 2, 1, 2, 3],
        [2, 3, 2, 1, 2, 3, 2, 1],
        [2, 1, 2, 3, 2, 1, 2, 3]
    ]
    for mission_index in range(Rules.MISSION_COUNT):
        var mission: Dictionary = Rules.get_mission(mission_index)
        var layout: Array = mission.get("layout", [])
        _expect(layout.size() == Rules.ROW_COUNT, "site %d has eight depth rows" % mission_index)
        for row in range(layout.size()):
            _expect(str(layout[row]).length() == Rules.COLUMN_COUNT, "site %d row %d has five lanes" % [mission_index, row])
        var state: Dictionary = Rules.new_state(mission_index)
        for lane in routes[mission_index]:
            var result: Dictionary = Rules.apply_drill(state, int(lane))
            _expect(bool(result.get("ok", false)), "site %d route drills the next safe lane" % mission_index)
            state = result.get("state", state)
        _expect(bool(state.get("complete", false)), "site %d has a verified winning route" % mission_index)
        _expect(int(state.get("ore", 0)) >= int(mission.get("quota", 1)), "site %d route meets its mineral quota" % mission_index)
        _expect(int(state.get("energy", 0)) > 0, "site %d route retains power" % mission_index)
        _expect(int(state.get("heat", 0)) < Rules.MAX_HEAT, "site %d route stays below thermal shutdown" % mission_index)
        _expect(int(state.get("hull", 0)) > 0, "site %d route preserves the drill housing" % mission_index)

    var invalid_state: Dictionary = Rules.new_state(0)
    var invalid_result: Dictionary = Rules.apply_drill(invalid_state, 4)
    _expect(not bool(invalid_result.get("ok", false)) and str(invalid_result.get("reason", "")) == "lane_out_of_reach", "the drill cannot jump across multiple lanes")
    _expect(int(invalid_result.get("state", {}).get("row", -1)) == 0, "an invalid lane does not consume a depth row")

    var vent_state: Dictionary = Rules.new_state(0)
    var first_drill: Dictionary = Rules.apply_drill(vent_state, 2)
    vent_state = first_drill.get("state", vent_state)
    var vent_result: Dictionary = Rules.vent(vent_state)
    vent_state = vent_result.get("state", vent_state)
    _expect(bool(vent_result.get("ok", false)) and int(vent_state.get("heat", 100)) == 0, "a coolant purge reduces drill heat")
    var repeated_vent: Dictionary = Rules.vent(vent_state)
    _expect(not bool(repeated_vent.get("ok", false)) and str(repeated_vent.get("reason", "")) == "already_vented", "only one coolant purge is allowed per depth row")

    var hot_state: Dictionary = Rules.new_state(0)
    hot_state["heat"] = 95
    var hot_result: Dictionary = Rules.apply_drill(hot_state, 2)
    _expect(bool(hot_result.get("state", {}).get("failed", false)), "reaching the thermal limit shuts down the drill")
    _expect(str(hot_result.get("state", {}).get("status", "")) == "THERMAL LIMIT EXCEEDED", "thermal shutdown has an explicit diagnostic")

    var weak_state: Dictionary = Rules.new_state(0)
    weak_state["energy"] = 1
    var weak_result: Dictionary = Rules.apply_drill(weak_state, 2)
    _expect(not bool(weak_result.get("ok", false)) and bool(weak_result.get("state", {}).get("failed", false)), "insufficient drill power fails safely")
    if failures.is_empty():
        print("KROLL Core Drill rules tests passed.")
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

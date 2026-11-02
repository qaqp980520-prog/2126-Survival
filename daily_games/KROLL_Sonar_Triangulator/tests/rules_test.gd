extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _test_invalid_and_duplicate_scans()
    _test_three_ping_triangulation()
    _test_fourth_ping_breaks_the_abyssal_tie()
    _test_wrong_guess_elimination_and_score_penalty()
    _test_campaign_lock_and_restart()
    if failures.is_empty():
        print("KROLL Sonar Triangulator rules tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _test_invalid_and_duplicate_scans() -> void:
    var rules := RulesScript.new()
    _expect(rules.create_state(-1).is_empty(), "invalid mission cannot create a state")
    var state: Dictionary = rules.create_state(0)
    var invalid: Dictionary = rules.scan_sensor(state, 4)
    _expect(not bool(invalid.get("ok", true)) and str(invalid.get("reason", "")) == "invalid_sensor", "sensor indexes outside 0..3 are rejected")
    var first: Dictionary = rules.scan_sensor(state, 0)
    _expect(bool(first.get("ok", false)), "first sensor can be used")
    state = first["state"]
    var duplicate: Dictionary = rules.scan_sensor(state, 0)
    _expect(not bool(duplicate.get("ok", true)) and str(duplicate.get("reason", "")) == "sensor_already_used", "a sensor cannot be pinged twice")
    var early_selection: Dictionary = rules.select_cell(state, Vector2i(2, 2))
    _expect(not bool(early_selection.get("ok", true)) and str(early_selection.get("reason", "")) == "scans_incomplete", "target selection remains locked until three pings")

func _test_three_ping_triangulation() -> void:
    var rules := RulesScript.new()
    var state: Dictionary = rules.create_state(0)
    var expected_readings: Array[int] = [3, 5, 5]
    for sensor_index in range(3):
        var result: Dictionary = rules.scan_sensor(state, sensor_index)
        _expect(bool(result.get("ok", false)), "Nereid sensor %d scan succeeds" % sensor_index)
        _expect(int(result.get("reading", -1)) == expected_readings[sensor_index], "Nereid sensor %d returns the expected rounded range" % sensor_index)
        state = result["state"]
    var candidates: Array[Vector2i] = rules.get_candidate_positions(state)
    _expect(candidates.size() == 1, "three Nereid pings isolate exactly one cell")
    _expect(candidates.size() == 1 and candidates[0] == Vector2i(2, 2), "Nereid beacon resolves to grid coordinate (2, 2)")

func _test_fourth_ping_breaks_the_abyssal_tie() -> void:
    var rules := RulesScript.new()
    var state: Dictionary = rules.create_state(1)
    var expected_readings: Array[int] = [6, 4, 6, 4]
    _expect(rules.get_sensor_position(3) == Vector2i(4, 7), "fourth buoy is placed on the south edge rather than the symmetric corner")
    _expect(rules.get_sensor_name(3) == "SOUTH EDGE", "fourth buoy reports its correct station name")
    for sensor_index in range(3):
        var result: Dictionary = rules.scan_sensor(state, sensor_index)
        _expect(bool(result.get("ok", false)), "Abyssal sensor %d scan succeeds" % sensor_index)
        _expect(int(result.get("reading", -1)) == expected_readings[sensor_index], "Abyssal sensor %d returns the expected rounded range" % sensor_index)
        state = result["state"]
    var ambiguous: Array[Vector2i] = rules.get_candidate_positions(state)
    _expect(ambiguous.size() == 2, "first three Abyssal pings intentionally leave two cells")
    var final_ping: Dictionary = rules.scan_sensor(state, 3)
    _expect(bool(final_ping.get("ok", false)) and int(final_ping.get("reading", -1)) == expected_readings[3], "fourth buoy resolves the ambiguous return")
    state = final_ping["state"]
    var resolved: Array[Vector2i] = rules.get_candidate_positions(state)
    _expect(resolved.size() == 1 and resolved[0] == Vector2i(5, 3), "four pings isolate the Abyssal relay at (5, 3)")

func _test_wrong_guess_elimination_and_score_penalty() -> void:
    var rules := RulesScript.new()
    var state: Dictionary = rules.create_state(1)
    for sensor_index in range(3):
        state = rules.scan_sensor(state, sensor_index)["state"]
    var candidates: Array[Vector2i] = rules.get_candidate_positions(state)
    var target: Vector2i = rules.get_mission_target_for_test(1)
    _expect(candidates.size() == 2, "Abyssal survey begins with two plausible cells")
    var wrong_cell: Vector2i = candidates[0] if candidates[0] != target else candidates[1]
    var selected: Dictionary = rules.select_cell(state, wrong_cell)
    _expect(bool(selected.get("ok", false)), "one plausible return can be selected")
    state = selected["state"]
    var wrong: Dictionary = rules.submit_target(state)
    _expect(bool(wrong.get("ok", false)) and not bool(wrong.get("hit", true)), "a false return is accepted as a guess but not a solution")
    state = wrong["state"]
    var remaining: Array[Vector2i] = rules.get_candidate_positions(state)
    _expect(remaining.size() == 1 and remaining[0] == target, "wrong guess is eliminated without removing the true beacon")
    var correct_selection: Dictionary = rules.select_cell(state, target)
    _expect(bool(correct_selection.get("ok", false)), "remaining true beacon can be selected")
    var correct: Dictionary = rules.submit_target(correct_selection["state"])
    _expect(bool(correct.get("hit", false)) and int(correct.get("score", 0)) == 80, "one false guess applies the twenty-point penalty")

func _test_campaign_lock_and_restart() -> void:
    var rules := RulesScript.new()
    var state: Dictionary = rules.create_state(0)
    for mission_index in range(rules.get_mission_count()):
        if mission_index > 0:
            var advanced: Dictionary = rules.advance_mission(state)
            _expect(bool(advanced.get("ok", false)), "campaign advances to mission %d" % (mission_index + 1))
            state = advanced["state"]
        for sensor_index in range(rules.get_sensor_count()):
            var scan: Dictionary = rules.scan_sensor(state, sensor_index)
            _expect(bool(scan.get("ok", false)), "mission %d sensor %d scan succeeds" % [mission_index + 1, sensor_index])
            state = scan["state"]
        var target: Vector2i = rules.get_mission_target_for_test(mission_index)
        var selection: Dictionary = rules.select_cell(state, target)
        _expect(bool(selection.get("ok", false)), "mission %d target can be selected" % (mission_index + 1))
        var submitted: Dictionary = rules.submit_target(selection["state"])
        _expect(bool(submitted.get("hit", false)) and int(submitted.get("score", 0)) == 85, "mission %d earns 85 points after the fourth ping" % (mission_index + 1))
        state = submitted["state"]
    var completed: Dictionary = rules.advance_mission(state)
    _expect(bool(completed.get("ok", false)) and str(completed["state"].get("status", "")) == "campaign_complete", "last beacon completes the campaign")
    _expect(int(completed["state"].get("campaign_score", 0)) == 255, "campaign score accumulates exactly once per mission")
    var locked_scan: Dictionary = rules.scan_sensor(completed["state"], 0)
    var locked_submit: Dictionary = rules.submit_target(completed["state"])
    _expect(not bool(locked_scan.get("ok", true)) and not bool(locked_submit.get("ok", true)), "completed campaign rejects additional scans and score submissions")
    var restarted: Dictionary = rules.restart_campaign()
    _expect(bool(restarted.get("ok", false)) and int(restarted["state"].get("campaign_score", -1)) == 0, "campaign restart clears the accumulated score")
    _expect(str(restarted["state"].get("status", "")) == "playing", "campaign restart returns to the first mission")

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)

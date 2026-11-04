extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _expect(Rules.level_count() == 3, "campaign contains exactly three courier routes")
    for index in range(Rules.level_count()):
        var level: Dictionary = Rules.level_at(index)
        _expect(not str(level.get("name", "")).is_empty(), "route %d has a name" % (index + 1))
        _expect(level["platforms"].size() >= 4, "route %d contains ground and elevated platforms" % (index + 1))
        _expect(level["hazards"].size() >= 2, "route %d contains jump hazards" % (index + 1))
        _expect(not Rules.rects_overlap(level["package_rect"], level["exit_rect"]), "route %d parcel and airlock do not overlap" % (index + 1))
        for hazard_value in level["hazards"]:
            var hazard: Rect2 = hazard_value
            _expect(not Rules.rects_overlap(level["package_rect"], hazard), "route %d parcel is not inside a vent" % (index + 1))
            _expect(not Rules.rects_overlap(level["exit_rect"], hazard), "route %d airlock is not inside a vent" % (index + 1))

    var platforms: Array = [Rect2(0.0, 100.0, 100.0, 20.0)]
    _expect(Rules.landing_platform(Vector2(10.0, 40.0), Vector2(10.0, 70.0), 120.0, platforms) == 0, "falling player lands on a crossed platform")
    _expect(Rules.landing_platform(Vector2(10.0, 70.0), Vector2(10.0, 40.0), -120.0, platforms) == -1, "rising player does not snap to a one-way platform")
    _expect(Rules.landing_platform(Vector2(120.0, 40.0), Vector2(120.0, 70.0), 120.0, platforms) == -1, "platform landing requires horizontal overlap")

    var state: Dictionary = Rules.new_state()
    _expect(int(state["lives"]) == 3 and float(state["time_left"]) > 0.0, "new route starts with three suit charges and a time budget")
    _expect(str(state["status"]) == "active" and not bool(state["carrying"]), "new route begins active without a parcel")
    _expect(state["awarded"] == [false, false, false], "new campaign starts with an empty reward ledger")
    var preserved: Dictionary = Rules.new_state(1, 100, [true, false, false])
    _expect(int(preserved["campaign_score"]) == 100 and preserved["awarded"] == [true, false, false], "next route preserves campaign score and prior rewards")

    if failures.is_empty():
        print("KROLL Moonbase Courier rules tests passed.")
        quit(0)
    else:
        push_error("KROLL Moonbase Courier rules failures: " + str(failures))
        quit(1)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures.append(message)
        push_error("FAIL: " + message)

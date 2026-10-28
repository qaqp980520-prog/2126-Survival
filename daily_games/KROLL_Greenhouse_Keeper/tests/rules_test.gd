extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var first: Dictionary = Rules.new_game(32)
    var repeat: Dictionary = Rules.new_game(32)
    _expect(first == repeat, "same seed produces the same greenhouse")
    _expect(first["plots"].size() == 3, "three crop plots are initialized")
    _expect(not bool(Rules.water_plot(first, 9).get("ok", false)), "invalid plot index is rejected")
    _expect(first["water_left"] == Rules.STARTING_WATER, "invalid action does not consume water")

    var watered: Dictionary = Rules.water_plot(first, 0)
    _expect(bool(watered["ok"]), "watering a valid plot succeeds")
    _expect(is_equal_approx(float(watered["state"]["plots"][0]["moisture"]), 75.0), "watering adds the configured moisture")
    _expect(watered["state"]["water_left"] == 2, "watering consumes one tank charge")
    _expect(is_equal_approx(float(first["plots"][0]["moisture"]), 50.0), "watering does not mutate the source state")
    var unchanged: Dictionary = Rules.water_plot(watered["state"], 0)
    _expect(bool(unchanged["ok"]), "a partially wet plot can be watered again")
    _expect(unchanged["state"]["water_left"] == 1, "each successful watering consumes exactly one charge")

    var no_water: Dictionary = first.duplicate(true)
    no_water["water_left"] = 0
    _expect(not bool(Rules.water_plot(no_water, 1)["ok"]), "empty tank rejects watering")
    _expect(no_water["plots"][1]["moisture"] == 50.0, "failed watering leaves soil unchanged")

    var day_state: Dictionary = first.duplicate(true)
    var day_one: Dictionary = Rules.advance_day(day_state)
    _expect(bool(day_one["ok"]), "advancing a day succeeds")
    _expect(day_one["state"]["day"] == 2, "day counter advances once")
    _expect(day_one["state"]["plots"][0]["growth_stage"] == 1, "moist crop grows one stage")
    _expect(is_equal_approx(float(day_one["state"]["plots"][0]["moisture"]), 25.0), "daily moisture drain is applied")
    var day_two: Dictionary = Rules.advance_day(day_one["state"])
    _expect(day_two["state"]["plots"][0]["growth_stage"] == 2, "second adequately moist day advances growth")
    var day_three: Dictionary = Rules.advance_day(day_two["state"])
    _expect(day_three["state"]["plots"][0]["growth_stage"] == 2, "dry crop does not grow")
    _expect(day_three["state"]["plots"][0]["moisture"] == 0.0, "dry soil is clamped to zero")

    var mature: Dictionary = first.duplicate(true)
    var mature_plots: Array = mature["plots"]
    var tomato_index: int = -1
    for i in range(mature_plots.size()):
        if mature_plots[i]["crop_id"] == "tomato":
            tomato_index = i
            var tomato: Dictionary = mature_plots[i].duplicate(true)
            tomato["growth_stage"] = Rules.MAX_STAGE
            mature_plots[i] = tomato
            break
    mature["plots"] = mature_plots
    _expect(tomato_index >= 0, "seed layout contains tomato")
    var immature_harvest: Dictionary = Rules.harvest_plot(first, tomato_index)
    _expect(not bool(immature_harvest["ok"]), "immature crop cannot be harvested")
    var tomato_harvest: Dictionary = Rules.harvest_plot(mature, tomato_index)
    _expect(bool(tomato_harvest["ok"]), "mature tomato can be harvested")
    _expect(tomato_harvest["state"]["harvest_yield"] == 3, "tomato yields three units")
    _expect(tomato_harvest["state"]["plots"][tomato_index]["harvested"], "harvested plot is locked")
    _expect(not bool(mature["plots"][tomato_index]["harvested"]), "harvest does not mutate the source state")
    _expect(not bool(Rules.water_plot(tomato_harvest["state"], tomato_index)["ok"]), "harvested plot cannot be watered")
    var terminal_move: Dictionary = Rules.advance_day(tomato_harvest["state"])
    _expect(bool(terminal_move["ok"]), "nonterminal game continues after a partial harvest")

    var won: Dictionary = tomato_harvest["state"].duplicate(true)
    var remaining: Array = won["plots"]
    for i in range(remaining.size()):
        if i != tomato_index:
            var plot: Dictionary = remaining[i].duplicate(true)
            plot["growth_stage"] = Rules.MAX_STAGE
            remaining[i] = plot
    won["plots"] = remaining
    var other_index: int = 0 if tomato_index != 0 else 1
    var final_harvest: Dictionary = Rules.harvest_plot(won, other_index)
    _expect(final_harvest["state"]["harvest_yield"] >= Rules.TARGET_YIELD, "tomato plus one crop reaches target")
    _expect(final_harvest["state"]["status"] == "won", "target yield locks in victory")
    _expect(not bool(Rules.advance_day(final_harvest["state"])["ok"]), "terminal state rejects further actions")

    var too_late: Dictionary = first.duplicate(true)
    too_late["day"] = Rules.MAX_DAYS
    var failed_day: Dictionary = Rules.advance_day(too_late)
    _expect(failed_day["state"]["status"] == "failed", "season expires after the day limit without target yield")

    if failures.is_empty():
        print("KROLL Greenhouse Keeper rules tests passed.")
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

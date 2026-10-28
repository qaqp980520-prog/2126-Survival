extends RefCounted

const CROP_IDS: Array[String] = ["wheat", "tomato", "carrot"]
const MAX_STAGE := 3
const MAX_DAYS := 7
const STARTING_WATER := 3
const WATER_AMOUNT := 25.0
const DAILY_MOISTURE_DRAIN := 25.0
const TARGET_YIELD := 5
const CROP_YIELDS := {"wheat": 2, "tomato": 3, "carrot": 2}

static func new_game(seed_value: int = 32) -> Dictionary:
    var shift: int = posmod(seed_value, CROP_IDS.size())
    var plots: Array[Dictionary] = []
    for i in range(CROP_IDS.size()):
        plots.append({
            "crop_id": CROP_IDS[(i + shift) % CROP_IDS.size()],
            "growth_stage": 0,
            "moisture": 50.0,
            "harvested": false
        })
    return {
        "seed": seed_value,
        "day": 1,
        "water_left": STARTING_WATER,
        "selected_plot": 0,
        "plots": plots,
        "harvest_yield": 0,
        "status": "playing",
        "message": "Water carefully, then advance the day."
    }

static func select_plot(state: Dictionary, index: int) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    var plots: Array = state.get("plots", [])
    if index < 0 or index >= plots.size():
        return _result(false, "invalid_plot", state)
    var next: Dictionary = state.duplicate(true)
    next["selected_plot"] = index
    next["message"] = "Selected plot %d." % (index + 1)
    return _result(true, "selected", next)

static func water_plot(state: Dictionary, index: int) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    var plots: Array = state.get("plots", []).duplicate(true)
    if index < 0 or index >= plots.size():
        return _result(false, "invalid_plot", state)
    if int(state.get("water_left", 0)) <= 0:
        return _result(false, "empty_tank", state)
    var plot: Dictionary = plots[index].duplicate(true)
    if bool(plot.get("harvested", false)):
        return _result(false, "already_harvested", state)
    var moisture: float = float(plot.get("moisture", 0.0))
    if moisture >= 100.0:
        return _result(false, "soil_saturated", state)
    plot["moisture"] = minf(100.0, moisture + WATER_AMOUNT)
    plots[index] = plot
    var next: Dictionary = state.duplicate(true)
    next["plots"] = plots
    next["water_left"] = int(state.get("water_left", 0)) - 1
    next["message"] = "Plot %d watered." % (index + 1)
    return _result(true, "watered", next)

static func advance_day(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    var next: Dictionary = state.duplicate(true)
    var plots: Array = next.get("plots", [])
    for i in range(plots.size()):
        var plot: Dictionary = plots[i].duplicate(true)
        var moisture: float = maxf(0.0, float(plot.get("moisture", 0.0)))
        if not bool(plot.get("harvested", false)) and int(plot.get("growth_stage", 0)) < MAX_STAGE and moisture >= DAILY_MOISTURE_DRAIN:
            plot["growth_stage"] = int(plot.get("growth_stage", 0)) + 1
        plot["moisture"] = maxf(0.0, moisture - DAILY_MOISTURE_DRAIN)
        plots[i] = plot
    next["plots"] = plots
    next["day"] = int(next.get("day", 1)) + 1
    next["message"] = "Day advanced. Check soil moisture before the next cycle."
    if int(next.get("day", 1)) > MAX_DAYS and int(next.get("harvest_yield", 0)) < TARGET_YIELD:
        next["status"] = "failed"
        next["message"] = "Season ended before the harvest target was reached."
    return _result(true, "day_advanced", next)

static func harvest_plot(state: Dictionary, index: int) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return _result(false, "terminal", state)
    var plots: Array = state.get("plots", []).duplicate(true)
    if index < 0 or index >= plots.size():
        return _result(false, "invalid_plot", state)
    var plot: Dictionary = plots[index].duplicate(true)
    if bool(plot.get("harvested", false)):
        return _result(false, "already_harvested", state)
    if int(plot.get("growth_stage", 0)) < MAX_STAGE:
        return _result(false, "not_mature", state)
    plot["harvested"] = true
    plots[index] = plot
    var next: Dictionary = state.duplicate(true)
    next["plots"] = plots
    next["harvest_yield"] = int(state.get("harvest_yield", 0)) + int(CROP_YIELDS.get(str(plot.get("crop_id", "")), 0))
    next["message"] = "Harvested %s." % str(plot.get("crop_id", "crop"))
    if int(next["harvest_yield"]) >= TARGET_YIELD:
        next["status"] = "won"
        next["message"] = "Harvest target reached. Greenhouse secured!"
    elif _all_harvested(plots):
        next["status"] = "failed"
        next["message"] = "All plots harvested, but the yield target was missed."
    return _result(true, "harvested", next)

static func _all_harvested(plots: Array) -> bool:
    for value in plots:
        if not bool(value.get("harvested", false)):
            return false
    return true

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
    return {"ok": ok, "reason": reason, "state": state.duplicate(true)}

extends RefCounted

const MISSION_COUNT: int = 3
const ROW_COUNT: int = 8
const COLUMN_COUNT: int = 5
const START_ENERGY: int = 28
const MAX_HEAT: int = 100
const START_HULL: int = 5
const VENT_ENERGY_COST: int = 2
const VENT_COOLING: int = 24

static func get_mission(index: int) -> Dictionary:
    match posmod(index, MISSION_COUNT):
        0:
            return {
                "id": "copper_spine",
                "name": "COPPER SPINE",
                "region": "SURFACE ACCESS SHAFT",
                "quota": 5,
                "layout": [
                    "RRCRR",
                    "RIRWR",
                    "RRCRR",
                    "RRIIR",
                    "RRCRR",
                    "RIRRR",
                    "RRCRR",
                    "RRIIR"
                ]
            }
        1:
            return {
                "id": "ion_vein",
                "name": "ION VEIN",
                "region": "REACTOR CRUST",
                "quota": 5,
                "layout": [
                    "RRTGR",
                    "RIRWR",
                    "RRTRR",
                    "RIRCR",
                    "RRTRR",
                    "RIRWR",
                    "RRTRR",
                    "RIRCR"
                ]
            }
        _:
            return {
                "id": "mantle_edge",
                "name": "MANTLE EDGE",
                "region": "DEEP THERMAL SHELF",
                "quota": 6,
                "layout": [
                    "HRTRH",
                    "RIRLR",
                    "HRGRH",
                    "RRLTR",
                    "HRTRH",
                    "RIRLR",
                    "HRGRH",
                    "RRLTR"
                ]
            }

static func new_state(mission_index: int) -> Dictionary:
    return {
        "mission_index": posmod(mission_index, MISSION_COUNT),
        "row": 0,
        "lane": 2,
        "energy": START_ENERGY,
        "heat": 0,
        "hull": START_HULL,
        "ore": 0,
        "score": 0,
        "vented_this_row": false,
        "failed": false,
        "complete": false,
        "status": "SELECT A SAFE LANE, THEN DRILL DOWN",
        "mined_cells": []
    }

static func get_cell(mission: Dictionary, row: int, lane: int) -> String:
    var layout: Array = mission.get("layout", [])
    if row < 0 or row >= layout.size() or lane < 0 or lane >= COLUMN_COUNT:
        return "?"
    var line: String = str(layout[row])
    if line.length() != COLUMN_COUNT:
        return "?"
    return line.substr(lane, 1)

static func get_tile_info(tile: String) -> Dictionary:
    match tile:
        "R":
            return {"label": "ROCK", "name": "Rock", "energy_cost": 1, "heat_delta": 5, "hull_damage": 0, "ore": 0, "score": 5, "color": Color(0.24, 0.31, 0.37)}
        "C":
            return {"label": "Cu", "name": "Copper", "energy_cost": 2, "heat_delta": 9, "hull_damage": 0, "ore": 1, "score": 100, "color": Color(0.55, 0.36, 0.22)}
        "I":
            return {"label": "Fe", "name": "Iron", "energy_cost": 3, "heat_delta": 12, "hull_damage": 0, "ore": 1, "score": 150, "color": Color(0.47, 0.55, 0.62)}
        "T":
            return {"label": "Ti", "name": "Titanium", "energy_cost": 3, "heat_delta": 14, "hull_damage": 0, "ore": 1, "score": 220, "color": Color(0.30, 0.58, 0.76)}
        "G":
            return {"label": "GAS", "name": "Gas pocket", "energy_cost": -1, "heat_delta": -20, "hull_damage": 0, "ore": 0, "score": 25, "color": Color(0.16, 0.58, 0.49)}
        "W":
            return {"label": "ICE", "name": "Coolant ice", "energy_cost": 1, "heat_delta": -24, "hull_damage": 0, "ore": 0, "score": 20, "color": Color(0.20, 0.43, 0.72)}
        "L":
            return {"label": "LAVA", "name": "Lava pocket", "energy_cost": 4, "heat_delta": 28, "hull_damage": 1, "ore": 0, "score": 0, "color": Color(0.78, 0.25, 0.13)}
        "H":
            return {"label": "HARD", "name": "Hard rock", "energy_cost": 4, "heat_delta": 16, "hull_damage": 1, "ore": 0, "score": 0, "color": Color(0.38, 0.29, 0.27)}
        _:
            return {"label": "?", "name": "Unknown", "energy_cost": 0, "heat_delta": 0, "hull_damage": 0, "ore": 0, "score": 0, "color": Color(0.8, 0.1, 0.8)}

static func apply_drill(state: Dictionary, lane: int) -> Dictionary:
    var next: Dictionary = state.duplicate(true)
    if bool(next.get("failed", false)) or bool(next.get("complete", false)):
        return {"ok": false, "state": next, "reason": "terminal", "tile": ""}
    var row: int = int(next.get("row", 0))
    var current_lane: int = int(next.get("lane", 2))
    if row < 0 or row >= ROW_COUNT:
        return {"ok": false, "state": next, "reason": "depth_limit", "tile": ""}
    if lane < 0 or lane >= COLUMN_COUNT or abs(lane - current_lane) > 1:
        return {"ok": false, "state": next, "reason": "lane_out_of_reach", "tile": ""}
    var energy: int = int(next.get("energy", 0))
    if energy <= 0:
        next["failed"] = true
        next["status"] = "POWER EMPTY · DRILL SHUTDOWN"
        return {"ok": false, "state": next, "reason": "no_energy", "tile": ""}
    var mission: Dictionary = get_mission(int(next.get("mission_index", 0)))
    var tile: String = get_cell(mission, row, lane)
    var info: Dictionary = get_tile_info(tile)
    var energy_cost: int = int(info.get("energy_cost", 0))
    if energy < energy_cost:
        next["failed"] = true
        next["status"] = "INSUFFICIENT POWER · DRILL SHUTDOWN"
        return {"ok": false, "state": next, "reason": "insufficient_energy", "tile": tile}
    next["energy"] = mini(START_ENERGY, energy - energy_cost)
    next["heat"] = clampi(int(next.get("heat", 0)) + int(info.get("heat_delta", 0)), 0, MAX_HEAT)
    next["hull"] = maxi(0, int(next.get("hull", START_HULL)) - int(info.get("hull_damage", 0)))
    next["ore"] = int(next.get("ore", 0)) + int(info.get("ore", 0))
    next["score"] = int(next.get("score", 0)) + int(info.get("score", 0))
    var mined_cells: Array = next.get("mined_cells", [])
    mined_cells.append(Vector2i(row, lane))
    next["mined_cells"] = mined_cells
    next["row"] = row + 1
    next["lane"] = lane
    next["vented_this_row"] = false
    if int(next["heat"]) >= MAX_HEAT:
        next["failed"] = true
        next["status"] = "THERMAL LIMIT EXCEEDED"
    elif int(next["hull"]) <= 0:
        next["failed"] = true
        next["status"] = "DRILL HOUSING DESTROYED"
    elif int(next["row"]) >= ROW_COUNT:
        var quota: int = int(mission.get("quota", 1))
        if int(next["ore"]) >= quota:
            next["complete"] = true
            next["status"] = "CORE SAMPLE SECURED · NEXT SITE READY"
        else:
            next["failed"] = true
            next["status"] = "DEPTH REACHED · SAMPLE QUOTA MISSED"
    elif int(next["energy"]) <= 0:
        next["failed"] = true
        next["status"] = "POWER EMPTY · DRILL SHUTDOWN"
    else:
        next["status"] = "%s recovered · depth %d / %d" % [str(info.get("name", tile)), int(next["row"]), ROW_COUNT]
    return {"ok": true, "state": next, "reason": "drilled", "tile": tile}

static func vent(state: Dictionary) -> Dictionary:
    var next: Dictionary = state.duplicate(true)
    if bool(next.get("failed", false)) or bool(next.get("complete", false)):
        return {"ok": false, "state": next, "reason": "terminal"}
    if bool(next.get("vented_this_row", false)):
        return {"ok": false, "state": next, "reason": "already_vented"}
    if int(next.get("heat", 0)) <= 0:
        return {"ok": false, "state": next, "reason": "heat_is_clear"}
    if int(next.get("energy", 0)) < VENT_ENERGY_COST:
        return {"ok": false, "state": next, "reason": "insufficient_energy"}
    next["energy"] = int(next["energy"]) - VENT_ENERGY_COST
    next["heat"] = maxi(0, int(next["heat"]) - VENT_COOLING)
    next["vented_this_row"] = true
    next["status"] = "COOLANT PURGE COMPLETE"
    return {"ok": true, "state": next, "reason": "vented"}

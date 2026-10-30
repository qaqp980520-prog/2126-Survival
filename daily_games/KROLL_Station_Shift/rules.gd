extends RefCounted
class_name KrollStationShiftRules

const ROUND_COUNT: int = 6
const CREW_TOTAL: int = 5
const ENERGY_CAP: int = 20
const OXYGEN_CAP: int = 20
const HULL_CAP: int = 100
const ENERGY_PER_POWER_CREW: int = 4
const OXYGEN_PER_LIFE_CREW: int = 3
const HULL_PER_REPAIR_CREW: int = 7

const SCENARIOS: Array[Dictionary] = [
	{
		"id": "dockside",
		"title": "DOCKSIDE BLACKOUT",
		"description": "A damaged dock relay must survive six maintenance cycles.",
		"events": [
			{"name": "Grid brownout", "energy_demand": 7, "solar_bonus": 0, "oxygen_demand": 6, "hull_damage": 8},
			{"name": "Emergency lighting", "energy_demand": 8, "solar_bonus": 1, "oxygen_demand": 7, "hull_damage": 9},
			{"name": "Cooling fault", "energy_demand": 6, "solar_bonus": 0, "oxygen_demand": 7, "hull_damage": 10},
			{"name": "Docking vibration", "energy_demand": 9, "solar_bonus": 0, "oxygen_demand": 6, "hull_damage": 8},
			{"name": "Solar window", "energy_demand": 7, "solar_bonus": 2, "oxygen_demand": 8, "hull_damage": 9},
			{"name": "Final pressure check", "energy_demand": 8, "solar_bonus": 0, "oxygen_demand": 6, "hull_damage": 10}
		]
	},
	{
		"id": "ridge",
		"title": "RIDGE RESEARCH",
		"description": "A remote station faces high power demand and intermittent solar input.",
		"events": [
			{"name": "Lab startup", "energy_demand": 9, "solar_bonus": 0, "oxygen_demand": 5, "hull_damage": 7},
			{"name": "Array alignment", "energy_demand": 8, "solar_bonus": 2, "oxygen_demand": 6, "hull_damage": 10},
			{"name": "Sample freezer", "energy_demand": 10, "solar_bonus": 0, "oxygen_demand": 6, "hull_damage": 8},
			{"name": "Dust impact", "energy_demand": 7, "solar_bonus": 1, "oxygen_demand": 7, "hull_damage": 11},
			{"name": "Cold storage", "energy_demand": 9, "solar_bonus": 0, "oxygen_demand": 5, "hull_damage": 8},
			{"name": "Return beacon", "energy_demand": 8, "solar_bonus": 2, "oxygen_demand": 7, "hull_damage": 10}
		]
	},
	{
		"id": "floodplain",
		"title": "FLOODPLAIN HABITAT",
		"description": "A low-orbit habitat must balance oxygen demand against hull stress.",
		"events": [
			{"name": "Air scrubber overload", "energy_demand": 6, "solar_bonus": 1, "oxygen_demand": 8, "hull_damage": 9},
			{"name": "Power relay surge", "energy_demand": 9, "solar_bonus": 0, "oxygen_demand": 6, "hull_damage": 8},
			{"name": "Crew oxygen spike", "energy_demand": 7, "solar_bonus": 2, "oxygen_demand": 9, "hull_damage": 10},
			{"name": "Outer seal leak", "energy_demand": 8, "solar_bonus": 0, "oxygen_demand": 7, "hull_damage": 9},
			{"name": "Filter replacement", "energy_demand": 6, "solar_bonus": 1, "oxygen_demand": 8, "hull_damage": 11},
			{"name": "Final descent", "energy_demand": 9, "solar_bonus": 0, "oxygen_demand": 6, "hull_damage": 8}
		]
	}
]

static func get_scenario(index: int) -> Dictionary:
	if index < 0 or index >= SCENARIOS.size():
		return {}
	return SCENARIOS[index].duplicate(true)

static func new_state(scenario_index: int = 0) -> Dictionary:
	if scenario_index < 0 or scenario_index >= SCENARIOS.size():
		return {}
	return {
		"scenario_index": scenario_index,
		"round": 0,
		"energy": 10,
		"oxygen": 10,
		"hull": 80,
		"crew": [1, 2, 2],
		"status": "active",
		"message": "Assign all five crew before running a cycle.",
		"history": []
	}

static func set_crew(state: Dictionary, sector: int, delta: int) -> Dictionary:
	if not _is_active_state(state):
		return {"ok": false, "reason": "inactive", "state": state.duplicate(true)}
	if sector < 0 or sector >= 3 or not [-1, 1].has(delta):
		return {"ok": false, "reason": "invalid_assignment", "state": state.duplicate(true)}
	var source_crew: Variant = state.get("crew", null)
	if not (source_crew is Array) or source_crew.size() != 3:
		return {"ok": false, "reason": "invalid_crew", "state": state.duplicate(true)}
	var crew: Array = source_crew.duplicate()
	var current_total: int = 0
	for value in crew:
		if not (value is int) or int(value) < 1:
			return {"ok": false, "reason": "invalid_crew", "state": state.duplicate(true)}
		current_total += int(value)
	if current_total > CREW_TOTAL:
		return {"ok": false, "reason": "invalid_crew", "state": state.duplicate(true)}
	var next_state: Dictionary = state.duplicate(true)
	var next_value: int = int(crew[sector]) + delta
	if next_value < 1:
		return {"ok": false, "reason": "minimum_station_crew", "state": state.duplicate(true)}
	var assigned: int = 0
	for index in range(crew.size()):
		if index == sector:
			assigned += next_value
		else:
			assigned += int(crew[index])
	if assigned > CREW_TOTAL:
		return {"ok": false, "reason": "crew_pool_exceeded", "state": state.duplicate(true)}
	crew[sector] = next_value
	next_state["crew"] = crew
	return {"ok": true, "reason": "updated", "state": next_state}

static func advance(state: Dictionary) -> Dictionary:
	if not _is_active_state(state):
		return {"ok": false, "reason": "invalid_state", "state": state.duplicate(true)}
	var crew: Array = state.get("crew", [])
	if crew.size() != 3:
		return {"ok": false, "reason": "invalid_crew", "state": state.duplicate(true)}
	var assigned: int = 0
	for value in crew:
		if not (value is int) or int(value) < 1:
			return {"ok": false, "reason": "invalid_crew", "state": state.duplicate(true)}
		assigned += int(value)
	if assigned != CREW_TOTAL:
		return {"ok": false, "reason": "crew_must_total_five", "state": state.duplicate(true)}
	var scenario: Dictionary = get_scenario(int(state.get("scenario_index", -1)))
	var events: Array = scenario.get("events", [])
	var round_index: int = int(state.get("round", -1))
	if round_index < 0 or round_index >= events.size():
		return {"ok": false, "reason": "no_more_cycles", "state": state.duplicate(true)}
	var event: Dictionary = events[round_index]
	var next_state: Dictionary = state.duplicate(true)
	var power_crew: int = int(crew[0])
	var life_crew: int = int(crew[1])
	var repair_crew: int = int(crew[2])
	next_state["energy"] = clampi(
		int(state.get("energy", 0)) + power_crew * ENERGY_PER_POWER_CREW + int(event.get("solar_bonus", 0)) - int(event.get("energy_demand", 0)),
		0,
		ENERGY_CAP
	)
	next_state["oxygen"] = clampi(
		int(state.get("oxygen", 0)) + life_crew * OXYGEN_PER_LIFE_CREW - int(event.get("oxygen_demand", 0)),
		0,
		OXYGEN_CAP
	)
	next_state["hull"] = clampi(
		int(state.get("hull", 0)) + repair_crew * HULL_PER_REPAIR_CREW - int(event.get("hull_damage", 0)),
		0,
		HULL_CAP
	)
	next_state["round"] = round_index + 1
	var history: Array = next_state.get("history", []).duplicate(true)
	history.append({
		"round": round_index + 1,
		"event": str(event.get("name", "Unknown event")),
		"crew": crew.duplicate(),
		"energy": int(next_state["energy"]),
		"oxygen": int(next_state["oxygen"]),
		"hull": int(next_state["hull"])
	})
	next_state["history"] = history
	var energy: int = int(next_state["energy"])
	var oxygen: int = int(next_state["oxygen"])
	var hull: int = int(next_state["hull"])
	if energy <= 0 or oxygen <= 0 or hull <= 0:
		next_state["status"] = "failed"
		next_state["message"] = "Station failure: a critical reserve reached zero."
	elif int(next_state["round"]) >= ROUND_COUNT:
		if energy >= 5 and oxygen >= 5 and hull >= 30:
			next_state["status"] = "won"
			next_state["message"] = "Shift complete. All three station systems remain stable."
		else:
			next_state["status"] = "failed"
			next_state["message"] = "Shift ended below the minimum reserve targets."
	else:
		next_state["message"] = "Cycle %d complete. Reassign crew for the next event." % int(next_state["round"])
	return {"ok": true, "reason": "advanced", "state": next_state}

static func _is_active_state(state: Dictionary) -> bool:
	if str(state.get("status", "")) != "active":
		return false
	var scenario_index: int = int(state.get("scenario_index", -1))
	if scenario_index < 0 or scenario_index >= SCENARIOS.size():
		return false
	var round_index: int = int(state.get("round", -1))
	return round_index >= 0 and round_index < ROUND_COUNT

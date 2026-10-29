extends RefCounted
class_name BiomeBalanceRules

const SEEDS: Array[int] = [17, 29, 41]
const ZONE_ORDERS: Array = [
	["CANOPY", "MEADOW", "WETLAND"],
	["MEADOW", "WETLAND", "CANOPY"],
	["WETLAND", "CANOPY", "MEADOW"]
]
const MAX_TURNS: int = 6
const ACTIONS_PER_TURN: int = 2
const MAX_FLORA: int = 5
const MAX_HERBIVORES: int = 4
const MAX_PREDATORS: int = 3
const MAX_WATER: int = 5
const ACTION_PLANT: String = "plant"
const ACTION_GRAZER: String = "grazer"
const ACTION_WATER: String = "water"
const ACTION_CULL: String = "cull"

static func new_game(seed_value: int = 17) -> Dictionary:
	var layout_index: int = _layout_index(seed_value)
	var zones: Array[Dictionary] = []
	for zone_name_value in ZONE_ORDERS[layout_index]:
		var zone_name: String = str(zone_name_value)
		match zone_name:
			"CANOPY":
				zones.append(_make_zone("CANOPY", 2, 1, 0, 3))
			"MEADOW":
				zones.append(_make_zone("MEADOW", 3, 2, 1, 3))
			"WETLAND":
				zones.append(_make_zone("WETLAND", 1, 1, 1, 4))
	return {
		"seed": SEEDS[layout_index],
		"turn": 1,
		"actions_left": ACTIONS_PER_TURN,
		"actions_used": 0,
		"seed_tokens": 3,
		"grazer_tokens": 3,
		"water_cells": 4,
		"status": "playing",
		"zones": zones,
		"message": "Stabilize all three habitats for six turns. Two interventions per turn."
	}

static func perform_action(state: Dictionary, zone_index: int, action_name: String) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return _result(false, "terminal", state)
	if int(state.get("actions_left", 0)) <= 0:
		return _result(false, "no_actions_left", state)
	var zones_value: Variant = state.get("zones", null)
	if not (zones_value is Array) or zone_index < 0 or zone_index >= zones_value.size():
		return _result(false, "invalid_zone", state)
	var zone_value: Variant = zones_value[zone_index]
	if not (zone_value is Dictionary):
		return _result(false, "invalid_state", state)
	var next: Dictionary = state.duplicate(true)
	var zones: Array = next["zones"]
	var zone: Dictionary = zones[zone_index]
	match action_name:
		ACTION_PLANT:
			if int(next.get("seed_tokens", 0)) <= 0:
				return _result(false, "no_seed_tokens", state)
			if int(zone.get("flora", 0)) >= MAX_FLORA:
				return _result(false, "flora_at_capacity", state)
			zone["flora"] = int(zone["flora"]) + 1
			next["seed_tokens"] = int(next["seed_tokens"]) - 1
		ACTION_GRAZER:
			if int(next.get("grazer_tokens", 0)) <= 0:
				return _result(false, "no_grazer_tokens", state)
			if int(zone.get("herbivores", 0)) >= MAX_HERBIVORES:
				return _result(false, "herbivores_at_capacity", state)
			zone["herbivores"] = int(zone["herbivores"]) + 1
			next["grazer_tokens"] = int(next["grazer_tokens"]) - 1
		ACTION_WATER:
			if int(next.get("water_cells", 0)) <= 0:
				return _result(false, "no_water_cells", state)
			if int(zone.get("water", 0)) >= MAX_WATER:
				return _result(false, "water_at_capacity", state)
			zone["water"] = mini(MAX_WATER, int(zone["water"]) + 2)
			next["water_cells"] = int(next["water_cells"]) - 1
		ACTION_CULL:
			if int(zone.get("predators", 0)) <= 0:
				return _result(false, "no_predator_to_remove", state)
			zone["predators"] = int(zone["predators"]) - 1
		_:
			return _result(false, "unknown_action", state)
	zones[zone_index] = zone
	next["zones"] = zones
	next["actions_left"] = int(next["actions_left"]) - 1
	next["actions_used"] = int(next.get("actions_used", 0)) + 1
	next["message"] = "%s intervention applied to %s." % [action_name.to_upper(), str(zone.get("name", "HABITAT"))]
	return _result(true, "action_applied", next)

static func end_turn(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return _result(false, "terminal", state)
	var zones_value: Variant = state.get("zones", null)
	if not (zones_value is Array) or zones_value.size() != 3:
		return _result(false, "invalid_state", state)
	var next: Dictionary = state.duplicate(true)
	var zones: Array = next["zones"]
	for index in range(zones.size()):
		var zone_value: Variant = zones[index]
		if not (zone_value is Dictionary):
			return _result(false, "invalid_state", state)
		var zone: Dictionary = zone_value
		var flora: int = int(zone.get("flora", 0))
		var herbivores: int = int(zone.get("herbivores", 0))
		var predators: int = int(zone.get("predators", 0))
		var water: int = int(zone.get("water", 0))
		if water >= 2 and flora < MAX_FLORA:
			flora += 1
			water -= 2
		elif water > 0:
			water -= 1
		if flora >= 3:
			herbivores = mini(MAX_HERBIVORES, herbivores + 1)
		elif flora == 0:
			herbivores = maxi(0, herbivores - 1)
		if herbivores >= 3 and predators > 0:
			predators = mini(MAX_PREDATORS, predators + 1)
		elif herbivores == 0:
			predators = maxi(0, predators - 1)
		zone["flora"] = flora
		zone["herbivores"] = herbivores
		zone["predators"] = predators
		zone["water"] = water
		zones[index] = zone
	next["zones"] = zones
	var current_turn: int = int(next.get("turn", 1))
	if current_turn >= MAX_TURNS:
		next["status"] = "won" if _meets_goal(next) else "failed"
		next["message"] = "BIOME STABLE. Survey accepted." if str(next["status"]) == "won" else "ECOSYSTEM OUT OF BALANCE. Restart and intervene earlier."
	else:
		next["turn"] = current_turn + 1
		next["actions_left"] = ACTIONS_PER_TURN
		next["message"] = "Turn %d complete. Review each habitat and choose two interventions." % current_turn
	return _result(true, "turn_advanced", next)

static func zone_index_for_name(state: Dictionary, zone_name: String) -> int:
	var zones: Array = state.get("zones", [])
	for index in range(zones.size()):
		var zone_value: Variant = zones[index]
		if zone_value is Dictionary and str(zone_value.get("name", "")) == zone_name:
			return index
	return -1

static func _meets_goal(state: Dictionary) -> bool:
	if int(state.get("actions_used", 0)) < 6:
		return false
	var total_biodiversity: int = 0
	for zone_value in state.get("zones", []):
		if not (zone_value is Dictionary):
			return false
		var zone: Dictionary = zone_value
		var flora: int = int(zone.get("flora", 0))
		var herbivores: int = int(zone.get("herbivores", 0))
		var predators: int = int(zone.get("predators", 0))
		if flora < 2 or herbivores < 2 or predators > 2:
			return false
		total_biodiversity += flora + herbivores + predators
	return total_biodiversity >= 18

static func _make_zone(zone_name: String, flora: int, herbivores: int, predators: int, water: int) -> Dictionary:
	return {
		"name": zone_name,
		"flora": flora,
		"herbivores": herbivores,
		"predators": predators,
		"water": water
	}

static func _layout_index(seed_value: int) -> int:
	var found: int = SEEDS.find(seed_value)
	return found if found >= 0 else posmod(seed_value, SEEDS.size())

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "state": state.duplicate(true)}

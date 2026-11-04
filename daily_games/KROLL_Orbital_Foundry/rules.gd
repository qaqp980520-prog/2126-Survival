extends RefCounted

const RECIPES := {
	"alloy_plate": {"label":"Alloy Plate","inputs":{"iron":2,"carbon":1},"output":"alloy_plate","energy":2},
	"circuit_board": {"label":"Circuit Board","inputs":{"copper":1,"silicon":1},"output":"circuit_board","energy":3},
	"glass_lens": {"label":"Glass Lens","inputs":{"silica":2},"output":"glass_lens","energy":1},
	"power_cell": {"label":"Power Cell","inputs":{"alloy_plate":1,"circuit_board":1,"polymer":1},"output":"power_cell","energy":4},
	"sensor_array": {"label":"Sensor Array","inputs":{"circuit_board":1,"glass_lens":1},"output":"sensor_array","energy":2},
	"coolant_pump": {"label":"Coolant Pump","inputs":{"alloy_plate":1,"circuit_board":2},"output":"coolant_pump","energy":5}
}

const LEVELS := [
	{"name":"Sensor Calibration","stock":{"copper":1,"silicon":1,"silica":2},"goal":{"sensor_array":1},"energy":6,"action_limit":3},
	{"name":"Emergency Power Cell","stock":{"iron":2,"carbon":1,"copper":1,"silicon":1,"polymer":1},"goal":{"power_cell":1},"energy":9,"action_limit":3},
	{"name":"Pressure Transfer Pump","stock":{"iron":2,"carbon":1,"copper":2,"silicon":2},"goal":{"coolant_pump":1},"energy":13,"action_limit":4}
]

static func level_count() -> int:
	return LEVELS.size()

static func level_at(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return LEVELS[index].duplicate(true)

static func recipe_ids() -> Array[String]:
	var result: Array[String] = []
	for recipe_id in RECIPES.keys():
		result.append(str(recipe_id))
	result.sort()
	return result

static func recipe_info(recipe_id: String) -> Dictionary:
	if not RECIPES.has(recipe_id):
		return {}
	return RECIPES[recipe_id].duplicate(true)

static func new_state(level_index: int = 0, campaign_score: int = 0, completed_levels: Dictionary = {}) -> Dictionary:
	var level: Dictionary = level_at(level_index)
	if level.is_empty():
		return {}
	return {
		"level_index":level_index,
		"inventory":level.get("stock", {}).duplicate(true),
		"energy":int(level.get("energy", 0)),
		"starting_energy":int(level.get("energy", 0)),
		"actions":0,
		"action_limit":int(level.get("action_limit", 0)),
		"status":"active",
		"campaign_score":campaign_score,
		"completed_levels":completed_levels.duplicate(true)
	}

static func apply_recipe(state: Dictionary, recipe_id: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "")) != "active":
		return _rejected(next, "inactive")
	if not RECIPES.has(recipe_id):
		return _rejected(next, "unknown_recipe")
	var recipe: Dictionary = RECIPES[recipe_id]
	var action_limit: int = int(next.get("action_limit", 0))
	if int(next.get("actions", 0)) >= action_limit:
		return _rejected(next, "action_limit")
	var energy_cost: int = int(recipe.get("energy", 0))
	if int(next.get("energy", 0)) < energy_cost:
		return _rejected(next, "insufficient_energy")
	var inventory: Dictionary = next.get("inventory", {}).duplicate(true)
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id in inputs.keys():
		if int(inventory.get(item_id, 0)) < int(inputs[item_id]):
			return _rejected(next, "missing_materials")
	for item_id in inputs.keys():
		inventory[item_id] = int(inventory.get(item_id, 0)) - int(inputs[item_id])
	var output_id: String = str(recipe.get("output", ""))
	inventory[output_id] = int(inventory.get(output_id, 0)) + 1
	next["inventory"] = inventory
	next["energy"] = int(next.get("energy", 0)) - energy_cost
	next["actions"] = int(next.get("actions", 0)) + 1
	var level: Dictionary = level_at(int(next.get("level_index", 0)))
	if _goal_complete(inventory, level.get("goal", {})):
		next["status"] = "completed"
		var completed: Dictionary = next.get("completed_levels", {}).duplicate(true)
		var level_key: String = str(next.get("level_index", 0))
		if not completed.has(level_key):
			completed[level_key] = true
			next["campaign_score"] = int(next.get("campaign_score", 0)) + 100
		next["completed_levels"] = completed
		return {"accepted":true,"reason":"contract_complete","state":next}
	if int(next.get("actions", 0)) >= action_limit:
		next["status"] = "failed"
		return {"accepted":true,"reason":"action_limit_reached","state":next}
	return {"accepted":true,"reason":"crafted","state":next}

static func advance(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "")) != "completed":
		return _rejected(next, "contract_incomplete")
	var next_index: int = int(next.get("level_index", 0)) + 1
	if next_index >= level_count():
		next["status"] = "campaign_complete"
		return {"accepted":true,"reason":"campaign_complete","state":next}
	var replacement: Dictionary = new_state(next_index, int(next.get("campaign_score", 0)), next.get("completed_levels", {}))
	return {"accepted":true,"reason":"next_contract","state":replacement}

static func restart_level(state: Dictionary) -> Dictionary:
	return new_state(int(state.get("level_index", 0)), int(state.get("campaign_score", 0)), state.get("completed_levels", {}))

static func restart_campaign() -> Dictionary:
	return new_state()

static func _goal_complete(inventory: Dictionary, goal: Dictionary) -> bool:
	for item_id in goal.keys():
		if int(inventory.get(item_id, 0)) < int(goal[item_id]):
			return false
	return not goal.is_empty()

static func _rejected(state: Dictionary, reason: String) -> Dictionary:
	return {"accepted":false,"reason":reason,"state":state}

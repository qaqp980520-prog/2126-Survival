extends RefCounted
## Deterministic six-day ecosystem restoration simulation.
const GRID_WIDTH: int = 6
const GRID_HEIGHT: int = 5
const GRID_SIZE: int = GRID_WIDTH * GRID_HEIGHT
const DAYS: int = 6
const ACTIONS_PER_DAY: int = 4
const MAX_RESOURCE: int = 5
const MAX_POLLINATORS: int = 3
const SPECIES: Array[String] = ["fern", "moss", "bloom"]
const MISSIONS: Array[Dictionary] = [
	{"id":"fern_hall","name":"FERN HALL","brief":"Restore a shaded service dome. Establish a resilient mix of ground cover and flowering plants.","target_plants":8,"target_species":3,"target_pollinators":2,"max_pests":5},
	{"id":"orchid_bay","name":"ORCHID BAY","brief":"A dry research bay needs more plant cover. Keep the pollinator network active through the heat cycle.","target_plants":10,"target_species":3,"target_pollinators":2,"max_pests":4},
	{"id":"marsh_observatory","name":"MARSH OBSERVATORY","brief":"Rebuild a wetland dome with high biodiversity and a controlled pest population.","target_plants":12,"target_species":3,"target_pollinators":2,"max_pests":3}
]

static func get_mission(index: int) -> Dictionary:
	return MISSIONS[clampi(index, 0, MISSIONS.size() - 1)].duplicate(true)

static func new_game(mission_index: int = 0) -> Dictionary:
	var safe_index: int = clampi(mission_index, 0, MISSIONS.size() - 1)
	var cells: Array[Dictionary] = []
	for index in range(GRID_SIZE):
		cells.append({"species":"","moisture":4,"nutrients":4,"health":0,"stress":0,"pests":0})
	_seed_cell(cells, 7, "fern")
	_seed_cell(cells, 10, "moss")
	_seed_cell(cells, 20, "bloom")
	return {
		"mission_index":safe_index,"mission_id":str(MISSIONS[safe_index]["id"]),
		"day":1,"actions_left":ACTIONS_PER_DAY,"actions_used":0,"status":"playing",
		"pollinators":0,"seed_bank":6,"spread_count":0,"cells":cells,"history":[]
	}

static func _seed_cell(cells: Array[Dictionary], index: int, species: String) -> void:
	var cell: Dictionary = cells[index].duplicate(true)
	cell["species"] = species
	cell["health"] = 2
	cells[index] = cell

static func perform_action(state: Dictionary, action: String, cell_index: int = -1, species: String = "") -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status","")) != "playing" or int(next.get("actions_left",0)) <= 0:
		return next
	var cells: Array = next.get("cells",[]).duplicate(true)
	var success: bool = false
	match action:
		"plant":
			if _valid_cell_index(cell_index,cells.size()) and SPECIES.has(species) and int(next.get("seed_bank",0)) > 0:
				var cell: Dictionary = cells[cell_index].duplicate(true)
				if str(cell.get("species","")).is_empty():
					cell["species"]=species
					cell["health"]=2
					cell["stress"]=0
					cell["moisture"]=4
					cell["nutrients"]=4
					cell["pests"]=0
					cells[cell_index]=cell
					next["seed_bank"]=int(next["seed_bank"])-1
					success=true
		"water":
			if _valid_cell_index(cell_index,cells.size()):
				var cell: Dictionary = cells[cell_index].duplicate(true)
				var moisture: int = int(cell.get("moisture",0))
				if moisture < MAX_RESOURCE:
					cell["moisture"]=mini(MAX_RESOURCE,moisture+2)
					cells[cell_index]=cell
					success=true
		"enrich":
			if _valid_cell_index(cell_index,cells.size()):
				var cell: Dictionary = cells[cell_index].duplicate(true)
				var nutrients: int = int(cell.get("nutrients",0))
				if nutrients < MAX_RESOURCE:
					cell["nutrients"]=mini(MAX_RESOURCE,nutrients+2)
					cells[cell_index]=cell
					success=true
		"release_pollinators":
			var pollinators: int = int(next.get("pollinators",0))
			if pollinators < MAX_POLLINATORS:
				next["pollinators"]=pollinators+1
				success=true
		"prune":
			if _valid_cell_index(cell_index,cells.size()):
				var cell: Dictionary = cells[cell_index].duplicate(true)
				var pests: int = int(cell.get("pests",0))
				if pests > 0:
					cell["pests"]=maxi(0,pests-2)
					cells[cell_index]=cell
					success=true
		_:
			return next
	if not success:
		return next
	next["cells"]=cells
	next["actions_left"]=int(next.get("actions_left",0))-1
	next["actions_used"]=int(next.get("actions_used",0))+1
	var history: Array = next.get("history",[]).duplicate(true)
	history.append({"day":int(next.get("day",1)),"action":action,"cell":cell_index,"species":species})
	next["history"]=history
	return next

static func advance_day(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status","")) != "playing":
		return next
	var day: int = int(next.get("day",1))
	var cells: Array = next.get("cells",[]).duplicate(true)
	for index in range(cells.size()):
		var cell: Dictionary = cells[index].duplicate(true)
		var moisture: int = maxi(0,int(cell.get("moisture",0))-1)
		if day % 3 == 0:
			moisture=mini(MAX_RESOURCE,moisture+2)
		cell["moisture"]=moisture
		if str(cell.get("species","")).is_empty():
			cell["nutrients"]=mini(MAX_RESOURCE,int(cell.get("nutrients",0))+1)
		else:
			var nutrients: int = maxi(0,int(cell.get("nutrients",0))-1)
			cell["nutrients"]=nutrients
			if moisture >= 1 and nutrients >= 1:
				cell["health"]=mini(3,int(cell.get("health",0))+1)
				cell["stress"]=0
			else:
				var stress: int = int(cell.get("stress",0))+1
				if stress >= 2:
					cell["health"]=int(cell.get("health",0))-1
					stress=0
				cell["stress"]=stress
			if int(cell.get("health",0)) <= 0:
				cell["species"]=""
				cell["health"]=0
				cell["pests"]=0
		cells[index]=cell
	if int(next.get("pollinators",0)) >= 2:
		if _spread_seed(cells,day):
			next["spread_count"]=int(next.get("spread_count",0))+1
	else:
		_apply_pest_pressure(cells,day)
	if int(next.get("pollinators",0)) >= 2:
		for index in range(cells.size()):
			var cell: Dictionary = cells[index].duplicate(true)
			cell["pests"]=maxi(0,int(cell.get("pests",0))-1)
			cells[index]=cell
	next["cells"]=cells
	if day >= DAYS:
		var stats: Dictionary = get_stats(next)
		next["status"]="complete" if _meets_targets(stats,get_mission(int(next.get("mission_index",0)))) else "failed"
		next["day"]=DAYS
	else:
		next["day"]=day+1
		next["actions_left"]=ACTIONS_PER_DAY
	return next

static func _spread_seed(cells: Array, day: int) -> bool:
	var bloom_index: int = -1
	for index in range(cells.size()):
		var cell: Dictionary = cells[index]
		if str(cell.get("species","")) == "bloom" and int(cell.get("health",0)) >= 2:
			bloom_index=index
			break
	if bloom_index < 0:
		return false
	var neighbors: Array[int] = _neighbors(bloom_index)
	for offset in range(neighbors.size()):
		var candidate_index: int = neighbors[posmod(day+offset,neighbors.size())]
		var candidate: Dictionary = cells[candidate_index].duplicate(true)
		if str(candidate.get("species","")).is_empty() and int(candidate.get("moisture",0)) >= 2 and int(candidate.get("nutrients",0)) >= 2:
			candidate["species"]="moss" if day % 2 == 0 else "fern"
			candidate["health"]=1
			candidate["stress"]=0
			cells[candidate_index]=candidate
			return true
	return false

static func _neighbors(index: int) -> Array[int]:
	var x: int = index % GRID_WIDTH
	var y: int = int(index / GRID_WIDTH)
	var result: Array[int] = []
	if y > 0: result.append(index-GRID_WIDTH)
	if x > 0: result.append(index-1)
	if x < GRID_WIDTH-1: result.append(index+1)
	if y < GRID_HEIGHT-1: result.append(index+GRID_WIDTH)
	return result

static func _apply_pest_pressure(cells: Array, day: int) -> void:
	var start: int = posmod(day*7,cells.size())
	for offset in range(cells.size()):
		var index: int = posmod(start+offset,cells.size())
		var cell: Dictionary = cells[index].duplicate(true)
		if not str(cell.get("species","")).is_empty():
			cell["pests"]=mini(3,int(cell.get("pests",0))+1)
			cells[index]=cell
			return

static func _valid_cell_index(index: int, size: int) -> bool:
	return index >= 0 and index < size

static func get_stats(state: Dictionary) -> Dictionary:
	var cells: Array = state.get("cells",[])
	var species_seen: Dictionary = {}
	var plant_count: int = 0
	var pest_count: int = 0
	var health_total: int = 0
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var species: String = str(cell.get("species",""))
		pest_count += int(cell.get("pests",0))
		if not species.is_empty():
			plant_count += 1
			species_seen[species]=true
			health_total += int(cell.get("health",0))
	var mission: Dictionary = get_mission(int(state.get("mission_index",0)))
	var average_health: float = float(health_total)/float(plant_count) if plant_count > 0 else 0.0
	return {
		"plants":plant_count,"species":species_seen.size(),"pollinators":int(state.get("pollinators",0)),
		"pests":pest_count,"average_health":average_health,
		"target_plants":int(mission.get("target_plants",0)),"target_species":int(mission.get("target_species",0)),
		"target_pollinators":int(mission.get("target_pollinators",0)),"max_pests":int(mission.get("max_pests",0))
	}

static func _meets_targets(stats: Dictionary, mission: Dictionary) -> bool:
	return int(stats.get("plants",0)) >= int(mission.get("target_plants",0)) \
		and int(stats.get("species",0)) >= int(mission.get("target_species",0)) \
		and int(stats.get("pollinators",0)) >= int(mission.get("target_pollinators",0)) \
		and int(stats.get("pests",0)) <= int(mission.get("max_pests",0)) \
		and float(stats.get("average_health",0.0)) >= 1.0

static func is_mission_complete(state: Dictionary) -> bool:
	return _meets_targets(get_stats(state),get_mission(int(state.get("mission_index",0))))

static func reset(state: Dictionary) -> Dictionary:
	return new_game(int(state.get("mission_index",0)))

static func next_mission(state: Dictionary) -> Dictionary:
	if str(state.get("status","")) != "complete":
		return state.duplicate(true)
	var next_index: int = int(state.get("mission_index",0))+1
	if next_index >= MISSIONS.size():
		var finished: Dictionary = state.duplicate(true)
		finished["status"]="campaign_complete"
		return finished
	return new_game(next_index)

static func is_valid_mission(index: int) -> bool:
	if index < 0 or index >= MISSIONS.size():
		return false
	var mission: Dictionary = MISSIONS[index]
	return int(mission.get("target_plants",0)) >= 3 \
		and int(mission.get("target_species",0)) >= 1 \
		and int(mission.get("target_pollinators",0)) <= MAX_POLLINATORS \
		and int(mission.get("max_pests",-1)) >= 0

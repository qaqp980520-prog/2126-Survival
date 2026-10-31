extends SceneTree
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.MISSIONS.size() == 3,"three restoration domes are authored")
	for index in range(Rules.MISSIONS.size()):
		_expect(Rules.is_valid_mission(index),"mission %d has valid ecological targets" % index)
	var initial: Dictionary = Rules.new_game(0)
	_expect(str(initial.get("mission_id","")) == "fern_hall","campaign starts in Fern Hall")
	_expect(int(initial.get("day",0)) == 1 and int(initial.get("actions_left",0)) == 4,"each dome starts with four actions on day one")
	_expect(initial.get("cells",[]).size() == 30,"dome contains thirty independent growing plots")
	_expect(int(Rules.get_stats(initial).get("plants",0)) == 3,"three starter species establish initial biodiversity")
	var invalid: Dictionary = Rules.perform_action(initial,"plant",0,"unknown")
	_expect(int(invalid.get("actions_used",-1)) == 0,"unknown species does not spend an action")
	invalid=Rules.perform_action(initial,"plant",-1,"fern")
	_expect(int(invalid.get("actions_used",-1)) == 0,"invalid plot does not spend a seed or action")
	var watered: Dictionary = Rules.perform_action(initial,"water",0)
	_expect(int(watered["cells"][0]["moisture"]) == 5,"watering adds two moisture up to the resource cap")
	var enriched: Dictionary = Rules.perform_action(initial,"enrich",0)
	_expect(int(enriched["cells"][0]["nutrients"]) == 5,"compost adds two nutrients up to the resource cap")
	var pollinated: Dictionary = Rules.perform_action(initial,"release_pollinators")
	_expect(int(pollinated.get("pollinators",0)) == 1,"pollinator release increases ecosystem coverage")
	var pest_state: Dictionary = initial.duplicate(true)
	var pest_cells: Array = pest_state["cells"].duplicate(true)
	pest_cells[7]["pests"]=2
	pest_state["cells"]=pest_cells
	var pruned: Dictionary = Rules.perform_action(pest_state,"prune",7)
	_expect(int(pruned["cells"][7]["pests"]) == 0,"pruning removes up to two pests from the selected plot")
	for mission_index in range(Rules.MISSIONS.size()):
		var solved: Dictionary = _solve_mission(mission_index)
		var stats: Dictionary = Rules.get_stats(solved)
		var mission: Dictionary = Rules.get_mission(mission_index)
		_expect(str(solved.get("status","")) == "complete","mission %d has a deterministic winning route" % mission_index)
		_expect(int(stats.get("plants",0)) >= int(mission["target_plants"]),"mission %d reaches its plant target" % mission_index)
		_expect(int(stats.get("species",0)) >= int(mission["target_species"]),"mission %d preserves species diversity" % mission_index)
		_expect(int(stats.get("pollinators",0)) >= int(mission["target_pollinators"]),"mission %d establishes pollinator coverage" % mission_index)
		_expect(int(stats.get("pests",0)) <= int(mission["max_pests"]),"mission %d keeps pest pressure under control" % mission_index)
		var next: Dictionary = Rules.next_mission(solved)
		if mission_index < Rules.MISSIONS.size()-1:
			_expect(int(next.get("mission_index",-1)) == mission_index+1,"completed dome unlocks the next restoration site")
		else:
			_expect(str(next.get("status","")) == "campaign_complete","final dome completes the ecology campaign")
		var reset: Dictionary = Rules.reset(solved)
		_expect(int(reset.get("mission_index",-1)) == mission_index and int(reset.get("day",0)) == 1,"reset restarts the current dome")
	var locked: Dictionary = Rules.next_mission(initial)
	_expect(int(locked.get("mission_index",-1)) == 0,"unfinished dome cannot be skipped")
	var exhausted: Dictionary = initial.duplicate(true)
	exhausted["actions_left"]=0
	var no_action: Dictionary = Rules.perform_action(exhausted,"release_pollinators")
	_expect(int(no_action.get("pollinators",-1)) == 0,"empty action budget rejects a new action")
	if failures.is_empty():
		print("KROLL BioDome Keeper rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: "+failure)
		quit(1)

func _solve_mission(mission_index: int) -> Dictionary:
	var state: Dictionary = Rules.new_game(mission_index)
	state=Rules.perform_action(state,"release_pollinators")
	state=Rules.perform_action(state,"release_pollinators")
	var mission: Dictionary = Rules.get_mission(mission_index)
	var direct_plants: int = maxi(0,int(mission["target_plants"])-3-4)
	var positions: Array[int] = [0,5,24,29,2]
	var species: Array[String] = ["fern","moss","bloom","fern","moss"]
	for index in range(direct_plants):
		if int(state.get("actions_left",0)) <= 0:
			state=Rules.advance_day(state)
		state=Rules.perform_action(state,"plant",positions[index],species[index])
	while str(state.get("status","")) == "playing":
		state=Rules.advance_day(state)
	return state

func _expect(condition: bool,description: String) -> void:
	if condition:
		print("PASS: "+description)
	else:
		failures.append(description)
		push_error("FAIL: "+description)

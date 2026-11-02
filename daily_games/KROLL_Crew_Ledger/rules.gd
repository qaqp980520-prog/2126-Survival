extends RefCounted
class_name KROLLCrewLedgerRules

const CASES: Array[Dictionary] = [
	{
		"id": "relay_blackout",
		"title": "RELAY BLACKOUT",
		"crew": ["Mira", "Kade", "Sana", "Ivo"],
		"stations": ["Power", "Comms", "Life Support", "Navigation"],
		"clues": ["Kade is assigned to Comms.", "Ivo is assigned to Life Support.", "Mira is not assigned to Power.", "Sana is not assigned to Navigation."],
		"constraints": [
			{"crew": 1, "station": 1, "relation": "is"},
			{"crew": 3, "station": 2, "relation": "is"},
			{"crew": 0, "station": 0, "relation": "not"},
			{"crew": 2, "station": 3, "relation": "not"}
		],
		"solution": [3, 1, 0, 2]
	},
	{
		"id": "cryo_alert",
		"title": "CRYO ALERT",
		"crew": ["Rhea", "Dax", "Neri", "Sol"],
		"stations": ["Cryo", "Reactor", "Medbay", "Hydroponics"],
		"clues": ["Dax is assigned to Hydroponics.", "Neri is assigned to Medbay.", "Rhea is not assigned to Reactor.", "Sol is not assigned to Cryo."],
		"constraints": [
			{"crew": 1, "station": 3, "relation": "is"},
			{"crew": 2, "station": 2, "relation": "is"},
			{"crew": 0, "station": 1, "relation": "not"},
			{"crew": 3, "station": 0, "relation": "not"}
		],
		"solution": [0, 3, 2, 1]
	},
	{
		"id": "observatory_shift",
		"title": "OBSERVATORY SHIFT",
		"crew": ["Taro", "Uma", "Venn", "Yara"],
		"stations": ["Hangar", "Archive", "Fabrication", "Observation"],
		"clues": ["Uma is assigned to Archive.", "Venn is assigned to Observation.", "Taro is not assigned to Hangar.", "Yara is not assigned to Fabrication."],
		"constraints": [
			{"crew": 1, "station": 1, "relation": "is"},
			{"crew": 2, "station": 3, "relation": "is"},
			{"crew": 0, "station": 0, "relation": "not"},
			{"crew": 3, "station": 2, "relation": "not"}
		],
		"solution": [2, 1, 3, 0]
	}
]

func case_count() -> int:
	return CASES.size()

func get_case_definition(index: int) -> Dictionary:
	if index < 0 or index >= CASES.size():
		return {}
	var definition: Dictionary = CASES[index].duplicate(true)
	definition.erase("constraints")
	definition.erase("solution")
	return definition

func get_reference_solution(index: int) -> Array:
	if index < 0 or index >= CASES.size():
		return []
	return CASES[index]["solution"].duplicate()

func create_state(index: int, carried_score: int = 0) -> Dictionary:
	var definition: Dictionary = get_case_definition(index)
	if definition.is_empty():
		return {}
	return {"case_index": index, "case_id": str(definition["id"]), "title": str(definition["title"]), "assignments": [-1, -1, -1, -1], "status": "solving", "score": carried_score, "last_message": "Read all four clues, then assign each crew member to one unique station."}

func set_assignment(state: Dictionary, crew_index: int, station_index: int) -> Dictionary:
	if str(state.get("status", "")) != "solving":
		return {"ok": false, "reason": "case_not_open", "state": state.duplicate(true)}
	if crew_index < 0 or crew_index >= 4:
		return {"ok": false, "reason": "invalid_crew", "state": state.duplicate(true)}
	if station_index < -1 or station_index >= 4:
		return {"ok": false, "reason": "invalid_station", "state": state.duplicate(true)}
	var next_state: Dictionary = state.duplicate(true)
	var assignments: Array = next_state.get("assignments", []).duplicate()
	if assignments.size() != 4:
		return {"ok": false, "reason": "invalid_state", "state": state.duplicate(true)}
	assignments[crew_index] = station_index
	next_state["assignments"] = assignments
	next_state["last_message"] = "Assignment updated. Every station must be used exactly once."
	return {"ok": true, "state": next_state}

func submit_case(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "solving":
		return {"ok": false, "reason": "case_not_open", "state": state.duplicate(true)}
	var assignments: Array = state.get("assignments", [])
	if assignments.size() != 4:
		return {"ok": false, "reason": "invalid_state", "state": state.duplicate(true)}
	for station_index in assignments:
		if int(station_index) < 0 or int(station_index) >= 4:
			return {"ok": false, "reason": "incomplete_assignment", "state": state.duplicate(true)}
	if not _all_unique(assignments):
		return {"ok": false, "reason": "duplicate_station", "state": state.duplicate(true)}
	var case_index: int = int(state.get("case_index", -1))
	if case_index < 0 or case_index >= CASES.size():
		return {"ok": false, "reason": "invalid_case", "state": state.duplicate(true)}
	var next_state: Dictionary = state.duplicate(true)
	if _matches_constraints(case_index, assignments):
		next_state["status"] = "complete"
		next_state["score"] = int(next_state.get("score", 0)) + 100
		next_state["last_message"] = "Crew manifest verified. +100 points."
	else:
		next_state["status"] = "failed"
		next_state["last_message"] = "Manifest conflicts with the evidence. Reset the case and review the clues."
	return {"ok": true, "completed": str(next_state["status"]) == "complete", "state": next_state}

func reset_case(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) in ["complete", "campaign_complete"]:
		return {"ok": false, "reason": "already_complete", "state": state.duplicate(true)}
	var index: int = int(state.get("case_index", -1))
	if index < 0 or index >= CASES.size():
		return {"ok": false, "reason": "invalid_case", "state": state.duplicate(true)}
	return {"ok": true, "state": create_state(index, int(state.get("score", 0)))}

func advance_case(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "complete":
		return {"ok": false, "reason": "case_not_complete", "state": state.duplicate(true)}
	var next_index: int = int(state.get("case_index", -1)) + 1
	if next_index >= CASES.size():
		var finished: Dictionary = state.duplicate(true)
		finished["status"] = "campaign_complete"
		finished["last_message"] = "All three crew manifests are verified. Campaign complete."
		return {"ok": true, "complete": true, "state": finished}
	return {"ok": true, "complete": false, "state": create_state(next_index, int(state.get("score", 0)))}

func count_solutions(index: int) -> int:
	if index < 0 or index >= CASES.size():
		return 0
	var count: int = 0
	for a in range(4):
		for b in range(4):
			for c in range(4):
				for d in range(4):
					var candidate: Array = [a, b, c, d]
					if _all_unique(candidate) and _matches_constraints(index, candidate):
						count += 1
	return count

func _matches_constraints(index: int, assignments: Array) -> bool:
	if index < 0 or index >= CASES.size() or assignments.size() != 4:
		return false
	for constraint in CASES[index]["constraints"]:
		var actual: int = int(assignments[int(constraint["crew"])])
		var expected: int = int(constraint["station"])
		if str(constraint["relation"]) == "is" and actual != expected:
			return false
		if str(constraint["relation"]) == "not" and actual == expected:
			return false
	return true

func _all_unique(values: Array) -> bool:
	var seen: Dictionary = {}
	for value in values:
		var key: int = int(value)
		if seen.has(key):
			return false
		seen[key] = true
	return true

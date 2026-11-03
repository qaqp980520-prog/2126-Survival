extends RefCounted
class_name CasefileStationZeroRules

const MAX_STRIKES: int = 3
const CASE_REWARD: int = 100
const CASES: Array[Dictionary] = [
	{
		"id": "airlock_03",
		"title": "AIRLOCK 03",
		"brief": "A pressure-door override was forged during the night shift. Identify who issued it.",
		"suspects": [
			{"id": "mira", "name": "MIRA VALE", "role": "Shift engineer"},
			{"id": "taro", "name": "TARO CHEN", "role": "Dock technician"},
			{"id": "nia", "name": "NIA SOL", "role": "Life-support analyst"}
		],
		"evidence": [
			{"id": "console", "label": "CONSOLE AUDIT", "text": "The override request originated at console M-17."},
			{"id": "biometric", "label": "BIOMETRIC TRACE", "text": "M-17 was authenticated by Mira Vale's biometric session."},
			{"id": "coolant", "label": "COOLANT TRACE", "text": "The coolant pressure drift began eleven minutes after the override."}
		],
		"culprit": "mira",
		"proof": ["console", "biometric"]
	},
	{
		"id": "relay_04",
		"title": "RELAY 04",
		"brief": "A navigation beacon was redirected before a cargo tug entered the wrong corridor.",
		"suspects": [
			{"id": "dax", "name": "DAX ROWAN", "role": "Flight controller"},
			{"id": "imani", "name": "IMANI KADE", "role": "Signal operator"},
			{"id": "oren", "name": "OREN PIKE", "role": "Cargo marshal"}
		],
		"evidence": [
			{"id": "relay", "label": "RELAY CONFIG", "text": "The beacon route was changed from station R-4."},
			{"id": "assignment", "label": "SHIFT ROSTER", "text": "Station R-4 was assigned to Imani Kade during the incident."},
			{"id": "thermal", "label": "THERMAL TRACE", "text": "The thermal spike began outside the relay bay, after the route change."}
		],
		"culprit": "imani",
		"proof": ["relay", "assignment"]
	},
	{
		"id": "archive_09",
		"title": "ARCHIVE 09",
		"brief": "A sealed archive cabinet was opened without an authorized maintenance window.",
		"suspects": [
			{"id": "elio", "name": "ELIO PARK", "role": "Records curator"},
			{"id": "sana", "name": "SANA VOSS", "role": "Security auditor"},
			{"id": "juno", "name": "JUNO REED", "role": "Systems runner"}
		],
		"evidence": [
			{"id": "seal", "label": "SEAL LOG", "text": "The archive seal was disabled with security key S-9."},
			{"id": "ledger", "label": "KEY LEDGER", "text": "Key S-9 was issued to Sana Voss and was never returned."},
			{"id": "power", "label": "POWER EVENT", "text": "A power dip occurred thirty minutes after the seal event."}
		],
		"culprit": "sana",
		"proof": ["seal", "ledger"]
	}
]

func get_case_count() -> int:
	return CASES.size()

func get_max_score() -> int:
	return CASES.size() * CASE_REWARD

func get_case_definition(index: int) -> Dictionary:
	if index < 0 or index >= CASES.size():
		return {}
	return CASES[index].duplicate(true)

func create_state(seed_value: int = 103) -> Dictionary:
	return {
		"status": "playing",
		"case_index": 0,
		"score": 0,
		"strikes": 0,
		"submissions": 0,
		"selected_suspect": "",
		"selected_evidence": [],
		"solved": [false, false, false],
		"seed": seed_value
	}

func select_suspect(state: Dictionary, suspect_id: String) -> bool:
	if str(state.get("status", "")) != "playing":
		return false
	var definition: Dictionary = get_case_definition(int(state.get("case_index", -1)))
	var suspects: Array = definition.get("suspects", [])
	if not _contains_id(suspects, suspect_id):
		return false
	state["selected_suspect"] = suspect_id
	return true

func clear_suspect(state: Dictionary) -> void:
	state["selected_suspect"] = ""

func toggle_evidence(state: Dictionary, evidence_id: String) -> bool:
	if str(state.get("status", "")) != "playing":
		return false
	var definition: Dictionary = get_case_definition(int(state.get("case_index", -1)))
	var evidence: Array = definition.get("evidence", [])
	if not _contains_id(evidence, evidence_id):
		return false
	var selected: Array = state.get("selected_evidence", []).duplicate()
	var existing_index: int = selected.find(evidence_id)
	if existing_index >= 0:
		selected.remove_at(existing_index)
	elif selected.size() < 2:
		selected.append(evidence_id)
	else:
		return false
	state["selected_evidence"] = selected
	return true

func clear_selection(state: Dictionary) -> void:
	state["selected_suspect"] = ""
	state["selected_evidence"] = []

func is_correct_deduction(case_index: int, suspect_id: String, evidence_ids: Array) -> bool:
	var definition: Dictionary = get_case_definition(case_index)
	if definition.is_empty() or evidence_ids.size() != 2 or evidence_ids[0] == evidence_ids[1]:
		return false
	if suspect_id != str(definition.get("culprit", "")):
		return false
	var proof: Array = definition.get("proof", [])
	if proof.size() != 2:
		return false
	return evidence_ids.has(str(proof[0])) and evidence_ids.has(str(proof[1]))

func submit_deduction(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "not_playing"}
	var suspect_id: String = str(state.get("selected_suspect", ""))
	var evidence_ids: Array = state.get("selected_evidence", []).duplicate()
	if suspect_id.is_empty() or evidence_ids.size() != 2:
		return {"ok": false, "reason": "incomplete"}
	var case_index: int = int(state.get("case_index", -1))
	state["submissions"] = int(state.get("submissions", 0)) + 1
	if not is_correct_deduction(case_index, suspect_id, evidence_ids):
		var strikes: int = int(state.get("strikes", 0)) + 1
		state["strikes"] = strikes
		if strikes >= MAX_STRIKES:
			state["status"] = "failed"
		return {"ok": false, "reason": "incorrect", "strikes": strikes, "status": str(state.get("status", ""))}
	var solved: Array = state.get("solved", []).duplicate()
	if case_index >= 0 and case_index < solved.size() and not bool(solved[case_index]):
		solved[case_index] = true
		state["score"] = int(state.get("score", 0)) + CASE_REWARD
	state["solved"] = solved
	state["status"] = "victory" if case_index == CASES.size() - 1 else "case_solved"
	return {"ok": true, "reason": "correct", "status": str(state["status"]), "score": int(state.get("score", 0))}

func advance_case(state: Dictionary) -> bool:
	if str(state.get("status", "")) != "case_solved":
		return false
	var next_index: int = int(state.get("case_index", 0)) + 1
	if next_index < 0 or next_index >= CASES.size():
		return false
	state["case_index"] = next_index
	state["status"] = "playing"
	state["strikes"] = 0
	state["submissions"] = 0
	clear_selection(state)
	return true

func restart_case(state: Dictionary) -> bool:
	if str(state.get("status", "")) != "failed":
		return false
	state["status"] = "playing"
	state["strikes"] = 0
	state["submissions"] = 0
	clear_selection(state)
	return true

func restart_campaign(seed_value: int = 103) -> Dictionary:
	return create_state(seed_value)

func _contains_id(records: Array, target_id: String) -> bool:
	for record in records:
		if record is Dictionary and str(record.get("id", "")) == target_id:
			return true
	return false

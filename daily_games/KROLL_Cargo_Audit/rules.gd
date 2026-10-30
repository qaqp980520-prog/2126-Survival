extends RefCounted

const MAX_SCANS: int = 8
const MAX_ATTEMPTS: int = 2
const FIELDS: Array[String] = ["mass", "seal", "count"]
const MASS_TOLERANCE: float = 0.5

const CASES: Array[Dictionary] = [
	{
		"id": "dock_17",
		"name": "DOCK 17 // NIGHT INBOUND",
		"brief": "Seal control has certified every seal. Audit mass and item count; one container differs from its manifest.",
		"certified_field": "seal",
		"anomaly_container": 1,
		"anomaly_field": "mass",
		"containers": [
			{"manifest_mass": 12.0, "actual_mass": 12.0, "manifest_seal": "S-14", "actual_seal": "S-14", "manifest_count": 3, "actual_count": 3},
			{"manifest_mass": 18.0, "actual_mass": 19.6, "manifest_seal": "S-22", "actual_seal": "S-22", "manifest_count": 2, "actual_count": 2},
			{"manifest_mass": 9.5, "actual_mass": 9.5, "manifest_seal": "S-03", "actual_seal": "S-03", "manifest_count": 4, "actual_count": 4},
			{"manifest_mass": 15.0, "actual_mass": 15.0, "manifest_seal": "S-11", "actual_seal": "S-11", "manifest_count": 1, "actual_count": 1}
		]
	},
	{
		"id": "cold_chain",
		"name": "COLD CHAIN // TRANSFER 04",
		"brief": "Certified scales match every declared mass. Inspect seal identity and item count; one container is compromised.",
		"certified_field": "mass",
		"anomaly_container": 3,
		"anomaly_field": "seal",
		"containers": [
			{"manifest_mass": 12.0, "actual_mass": 12.0, "manifest_seal": "R-08", "actual_seal": "R-08", "manifest_count": 2, "actual_count": 2},
			{"manifest_mass": 21.0, "actual_mass": 21.0, "manifest_seal": "R-19", "actual_seal": "R-19", "manifest_count": 3, "actual_count": 3},
			{"manifest_mass": 14.5, "actual_mass": 14.5, "manifest_seal": "R-26", "actual_seal": "R-26", "manifest_count": 4, "actual_count": 4},
			{"manifest_mass": 8.0, "actual_mass": 8.0, "manifest_seal": "R-31", "actual_seal": "R-37", "manifest_count": 1, "actual_count": 1}
		]
	},
	{
		"id": "deep_storage",
		"name": "DEEP STORAGE // LIFT 02",
		"brief": "Inventory reconciliation has certified every item count. Inspect mass and seal identity to locate the single mismatch.",
		"certified_field": "count",
		"anomaly_container": 2,
		"anomaly_field": "seal",
		"containers": [
			{"manifest_mass": 17.0, "actual_mass": 17.0, "manifest_seal": "Q-03", "actual_seal": "Q-03", "manifest_count": 3, "actual_count": 3},
			{"manifest_mass": 10.0, "actual_mass": 10.0, "manifest_seal": "Q-08", "actual_seal": "Q-08", "manifest_count": 2, "actual_count": 2},
			{"manifest_mass": 24.0, "actual_mass": 24.0, "manifest_seal": "Q-17", "actual_seal": "Q-71", "manifest_count": 2, "actual_count": 2},
			{"manifest_mass": 14.0, "actual_mass": 14.0, "manifest_seal": "Q-24", "actual_seal": "Q-24", "manifest_count": 4, "actual_count": 4}
		]
	}
]

static func get_case_count() -> int:
	return CASES.size()

static func get_case(index: int) -> Dictionary:
	if index < 0 or index >= CASES.size():
		return {}
	var result: Dictionary = CASES[index].duplicate(true)
	var containers: Array = result.get("containers", [])
	for container_index in range(containers.size()):
		var manifest: Dictionary = containers[container_index]
		manifest.erase("actual_mass")
		manifest.erase("actual_seal")
		manifest.erase("actual_count")
		containers[container_index] = manifest
	result["containers"] = containers
	return result

static func create_state() -> Dictionary:
	return {
		"status": "investigating",
		"scans": {},
		"scans_used": 0,
		"scans_left": MAX_SCANS,
		"attempts_left": MAX_ATTEMPTS,
		"score": 0,
		"feedback": "Select a container and a non-certified field, then run a scan."
	}

static func scan(case_index: int, state: Dictionary, container_index: int, field: String) -> Dictionary:
	if case_index < 0 or case_index >= CASES.size():
		return {"ok": false, "reason": "invalid_case"}
	if str(state.get("status", "")) != "investigating":
		return {"ok": false, "reason": "case_finished"}
	var containers: Array = CASES[case_index].get("containers", [])
	if container_index < 0 or container_index >= containers.size() or not FIELDS.has(field):
		return {"ok": false, "reason": "invalid_selection"}
	if field == str(CASES[case_index].get("certified_field", "")):
		return {"ok": false, "reason": "certified_field"}
	var scan_key: String = "%d:%s" % [container_index, field]
	var scans: Dictionary = state.get("scans", {})
	if scans.has(scan_key):
		return {"ok": false, "reason": "already_scanned", "record": scans[scan_key]}
	if int(state.get("scans_left", 0)) <= 0:
		return {"ok": false, "reason": "scan_budget_exhausted"}
	var container: Dictionary = containers[container_index]
	var manifest_value: Variant = container.get("manifest_" + field, null)
	var actual_value: Variant = container.get("actual_" + field, null)
	if manifest_value == null or actual_value == null:
		return {"ok": false, "reason": "invalid_manifest"}
	var mismatch: bool = not _values_match(field, manifest_value, actual_value)
	var record: Dictionary = {
		"container_index": container_index,
		"field": field,
		"manifest_value": manifest_value,
		"actual_value": actual_value,
		"mismatch": mismatch
	}
	scans[scan_key] = record
	state["scans"] = scans
	state["scans_used"] = int(state.get("scans_used", 0)) + 1
	state["scans_left"] = maxi(0, int(state.get("scans_left", 0)) - 1)
	return {"ok": true, "reason": "mismatch" if mismatch else "match", "record": record}

static func accuse(case_index: int, state: Dictionary, container_index: int, field: String) -> Dictionary:
	if case_index < 0 or case_index >= CASES.size():
		return {"ok": false, "reason": "invalid_case"}
	if str(state.get("status", "")) != "investigating":
		return {"ok": false, "reason": "case_finished"}
	var containers: Array = CASES[case_index].get("containers", [])
	if container_index < 0 or container_index >= containers.size() or not FIELDS.has(field):
		return {"ok": false, "reason": "invalid_selection"}
	var correct: bool = container_index == int(CASES[case_index].get("anomaly_container", -1)) and field == str(CASES[case_index].get("anomaly_field", ""))
	if correct:
		var score: int = clampi(100 - int(state.get("scans_used", 0)) * 8 + (int(state.get("attempts_left", 0)) - 1) * 5, 0, 100)
		state["status"] = "cleared"
		state["score"] = score
		state["feedback"] = "AUDIT CLEARED // discrepancy confirmed."
		return {"ok": true, "reason": "correct", "score": score}
	var attempts_left: int = maxi(0, int(state.get("attempts_left", 0)) - 1)
	state["attempts_left"] = attempts_left
	if attempts_left <= 0:
		state["status"] = "failed"
		state["feedback"] = "AUDIT FAILED // two incorrect accusations."
	else:
		state["feedback"] = "FALSE FLAG // one accusation remains."
	return {"ok": false, "reason": "incorrect", "attempts_left": attempts_left}

static func validate_all_cases() -> bool:
	for case_value in CASES:
		if not (case_value is Dictionary):
			return false
		var containers: Array = case_value.get("containers", [])
		var certified_field: String = str(case_value.get("certified_field", ""))
		if containers.size() != 4 or not FIELDS.has(certified_field):
			return false
		var mismatch_count: int = 0
		var found_container: int = -1
		var found_field: String = ""
		for container_index in range(containers.size()):
			var container: Dictionary = containers[container_index]
			for field in FIELDS:
				var manifest_value: Variant = container.get("manifest_" + field, null)
				var actual_value: Variant = container.get("actual_" + field, null)
				if manifest_value == null or actual_value == null:
					return false
				if not _values_match(field, manifest_value, actual_value):
					mismatch_count += 1
					found_container = container_index
					found_field = field
					if field == certified_field:
						return false
		if mismatch_count != 1:
			return false
		if found_container != int(case_value.get("anomaly_container", -1)) or found_field != str(case_value.get("anomaly_field", "")):
			return false
	return true

static func _values_match(field: String, manifest_value: Variant, actual_value: Variant) -> bool:
	if field == "mass":
		return absf(float(manifest_value) - float(actual_value)) <= MASS_TOLERANCE
	if field == "seal":
		return str(manifest_value) == str(actual_value)
	return int(manifest_value) == int(actual_value)

static func format_value(field: String, value: Variant) -> String:
	if field == "mass":
		return "%.1f kg" % float(value)
	return str(value)

extends RefCounted
class_name KROLLTitrationBenchRules

const ACID_VOLUME_ML: float = 25.0
const TITRANT_MOLARITY: float = 0.1
const MAX_VOLUME_ML: float = 60.0
const ENDPOINT_TOLERANCE_ML: float = 0.5
const ALLOWED_ADDITIONS := [0.5, 1.0, 2.5]
const SAMPLES: Array[Dictionary] = [
	{"id": "sample_alpha", "title": "UNKNOWN ACID // ALPHA", "acid_molarity": 0.08},
	{"id": "sample_beta", "title": "UNKNOWN ACID // BETA", "acid_molarity": 0.12},
	{"id": "sample_gamma", "title": "UNKNOWN ACID // GAMMA", "acid_molarity": 0.16}
]

func get_sample_count() -> int:
	return SAMPLES.size()

func get_sample_definition(index: int) -> Dictionary:
	if index < 0 or index >= SAMPLES.size():
		return {}
	var sample: Dictionary = SAMPLES[index]
	return {
		"id": str(sample["id"]),
		"title": str(sample["title"]),
		"acid_volume_ml": ACID_VOLUME_ML,
		"titrant_molarity": TITRANT_MOLARITY,
		"max_volume_ml": MAX_VOLUME_ML
	}

func get_reference_endpoint_ml(index: int) -> float:
	if index < 0 or index >= SAMPLES.size():
		return -1.0
	var acid_moles: float = float(SAMPLES[index]["acid_molarity"]) * ACID_VOLUME_ML / 1000.0
	return acid_moles / TITRANT_MOLARITY * 1000.0

func calculate_ph(index: int, added_base_ml: float) -> float:
	if index < 0 or index >= SAMPLES.size() or not is_finite(added_base_ml) or added_base_ml < 0.0:
		return -1.0
	var acid_moles: float = float(SAMPLES[index]["acid_molarity"]) * ACID_VOLUME_ML / 1000.0
	var base_moles: float = TITRANT_MOLARITY * added_base_ml / 1000.0
	var total_volume_l: float = (ACID_VOLUME_ML + added_base_ml) / 1000.0
	var excess_moles: float = acid_moles - base_moles
	if absf(excess_moles) <= 0.000000000001:
		return 7.0
	if excess_moles > 0.0:
		return clampf(-log(excess_moles / total_volume_l) / log(10.0), 0.0, 14.0)
	var excess_hydroxide: float = -excess_moles / total_volume_l
	var poh: float = -log(excess_hydroxide) / log(10.0)
	return clampf(14.0 - poh, 0.0, 14.0)

func get_indicator_label(ph: float) -> String:
	if ph < 6.8:
		return "YELLOW · ACID"
	if ph > 7.2:
		return "BLUE · BASE"
	return "GREEN · ENDPOINT WINDOW"

func create_state(sample_index: int, carried_score: int = 0) -> Dictionary:
	var sample: Dictionary = get_sample_definition(sample_index)
	if sample.is_empty():
		return {}
	var initial_ph: float = calculate_ph(sample_index, 0.0)
	return {
		"sample_index": sample_index,
		"sample_id": str(sample["id"]),
		"title": str(sample["title"]),
		"volume_added_ml": 0.0,
		"ph": initial_ph,
		"indicator": get_indicator_label(initial_ph),
		"status": "titrating",
		"score": carried_score,
		"awarded": false,
		"readings": [{"volume_ml": 0.0, "ph": initial_ph}],
		"last_message": "Add titrant in measured steps. Stop inside the endpoint window, then submit."
	}

func add_titrant(state: Dictionary, amount_ml: float) -> Dictionary:
	if str(state.get("status", "")) != "titrating":
		return _result(false, "sample_not_open", state)
	if not is_finite(amount_ml) or not _is_allowed_addition(amount_ml):
		return _result(false, "invalid_addition", state)
	var current_volume: float = float(state.get("volume_added_ml", -1.0))
	if not is_finite(current_volume) or current_volume < 0.0:
		return _result(false, "invalid_state", state)
	var next_volume: float = current_volume + amount_ml
	if next_volume > MAX_VOLUME_ML + 0.000001:
		return _result(false, "maximum_volume_reached", state)
	var sample_index: int = int(state.get("sample_index", -1))
	var next_state: Dictionary = state.duplicate(true)
	var next_ph: float = calculate_ph(sample_index, next_volume)
	if next_ph < 0.0:
		return _result(false, "invalid_sample", state)
	next_state["volume_added_ml"] = next_volume
	next_state["ph"] = next_ph
	next_state["indicator"] = get_indicator_label(next_ph)
	next_state["last_message"] = "Reading recorded. Compare the pH curve before adding more."
	var readings: Array = next_state.get("readings", []).duplicate(true)
	readings.append({"volume_ml": next_volume, "ph": next_ph})
	next_state["readings"] = readings
	return _result(true, "", next_state)

func submit_endpoint(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "titrating":
		return _result(false, "sample_not_open", state)
	var sample_index: int = int(state.get("sample_index", -1))
	var reference_volume: float = get_reference_endpoint_ml(sample_index)
	var actual_volume: float = float(state.get("volume_added_ml", -1.0))
	if reference_volume < 0.0 or not is_finite(actual_volume):
		return _result(false, "invalid_state", state)
	if absf(actual_volume - reference_volume) > ENDPOINT_TOLERANCE_ML:
		var retry_state: Dictionary = state.duplicate(true)
		retry_state["last_message"] = "Endpoint not captured. Continue carefully or restart this sample."
		return _result(false, "endpoint_outside_tolerance", retry_state)
	var next_state: Dictionary = state.duplicate(true)
	next_state["status"] = "complete" if sample_index < SAMPLES.size() - 1 else "campaign_complete"
	next_state["awarded"] = true
	next_state["score"] = int(next_state.get("score", 0)) + 100
	next_state["last_message"] = "Endpoint captured. +100 points." if sample_index < SAMPLES.size() - 1 else "All three samples completed. Campaign score locked."
	return _result(true, "", next_state)

func advance_sample(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "complete":
		return _result(false, "sample_not_complete", state)
	var next_index: int = int(state.get("sample_index", -1)) + 1
	if next_index < 0 or next_index >= SAMPLES.size():
		return _result(false, "no_next_sample", state)
	return _result(true, "", create_state(next_index, int(state.get("score", 0))))

func restart_sample(state: Dictionary) -> Dictionary:
	var status: String = str(state.get("status", ""))
	if status == "complete" or status == "campaign_complete":
		return _result(false, "completed_sample_locked", state)
	var sample_index: int = int(state.get("sample_index", -1))
	if sample_index < 0 or sample_index >= SAMPLES.size():
		return _result(false, "invalid_sample", state)
	return _result(true, "", create_state(sample_index, int(state.get("score", 0))))

func restart_campaign() -> Dictionary:
	return create_state(0, 0)

func _is_allowed_addition(amount_ml: float) -> bool:
	for allowed_amount in ALLOWED_ADDITIONS:
		if is_equal_approx(amount_ml, float(allowed_amount)):
			return true
	return false

func _result(ok: bool, reason: String, next_state: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "state": next_state.duplicate(true)}

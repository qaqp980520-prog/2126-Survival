extends RefCounted
class_name KROLLPlanetaryClimateRules

const STEFAN_BOLTZMANN: float = 5.670374419e-8
const MIN_ALBEDO: float = 0.05
const MAX_ALBEDO: float = 0.80
const MIN_GREENHOUSE: float = 0.0
const MAX_GREENHOUSE: float = 0.70
const PARAMETER_STEP: float = 0.05
const TARGET_TOLERANCE_K: float = 1.5

const PLANETS: Array[Dictionary] = [
	{
		"id": "nysa",
		"title": "NYSA // TEMPERATE ARCHIVE",
		"solar_flux": 1361.0,
		"target_temp_k": 289.3,
		"initial_albedo": 0.55,
		"initial_greenhouse": 0.15
	},
	{
		"id": "vesper",
		"title": "VESPER // FROST RELAY",
		"solar_flux": 900.0,
		"target_temp_k": 243.3,
		"initial_albedo": 0.45,
		"initial_greenhouse": 0.05
	},
	{
		"id": "orin",
		"title": "ORIN // EQUATORIAL HABITAT",
		"solar_flux": 1800.0,
		"target_temp_k": 291.4,
		"initial_albedo": 0.65,
		"initial_greenhouse": 0.25
	}
]

func get_planet_count() -> int:
	return PLANETS.size()

func get_planet_definition(index: int) -> Dictionary:
	if index < 0 or index >= PLANETS.size():
		return {}
	var source: Dictionary = PLANETS[index]
	var target: float = float(source["target_temp_k"])
	return {
		"id": str(source["id"]),
		"title": str(source["title"]),
		"solar_flux": float(source["solar_flux"]),
		"target_temp_k": target,
		"target_min_k": target - TARGET_TOLERANCE_K,
		"target_max_k": target + TARGET_TOLERANCE_K,
		"initial_albedo": float(source["initial_albedo"]),
		"initial_greenhouse": float(source["initial_greenhouse"])
	}

func calculate_equilibrium_temperature(solar_flux: float, albedo: float, greenhouse: float) -> float:
	if not is_finite(solar_flux) or solar_flux <= 0.0:
		return -1.0
	if not _in_range(albedo, MIN_ALBEDO, MAX_ALBEDO):
		return -1.0
	if not _in_range(greenhouse, MIN_GREENHOUSE, MAX_GREENHOUSE):
		return -1.0
	var absorbed_flux: float = solar_flux * (1.0 - albedo) / 4.0
	var outgoing_factor: float = STEFAN_BOLTZMANN * (1.0 - greenhouse)
	if absorbed_flux <= 0.0 or outgoing_factor <= 0.0:
		return -1.0
	return pow(absorbed_flux / outgoing_factor, 0.25)

func create_state(planet_index: int, carried_score: int = 0) -> Dictionary:
	var definition: Dictionary = get_planet_definition(planet_index)
	if definition.is_empty() or carried_score < 0:
		return {}
	var albedo: float = float(definition["initial_albedo"])
	var greenhouse: float = float(definition["initial_greenhouse"])
	var temperature: float = calculate_equilibrium_temperature(float(definition["solar_flux"]), albedo, greenhouse)
	return {
		"planet_index": planet_index,
		"planet_id": str(definition["id"]),
		"albedo": albedo,
		"greenhouse": greenhouse,
		"equilibrium_temp_k": temperature,
		"error_k": absf(temperature - float(definition["target_temp_k"])),
		"status": "tuning",
		"score": carried_score,
		"awarded": false,
		"last_message": "Tune reflectivity and greenhouse retention, then simulate the climate."
	}

func set_albedo(state: Dictionary, value: float) -> Dictionary:
	var state_error: String = _validate_open_state(state)
	if not state_error.is_empty():
		return _result(false, state_error, state)
	if not _in_range(value, MIN_ALBEDO, MAX_ALBEDO) or not _is_grid_value(value):
		return _result(false, "invalid_albedo", state)
	return _update_parameters(state, value, float(state["greenhouse"]))

func set_greenhouse(state: Dictionary, value: float) -> Dictionary:
	var state_error: String = _validate_open_state(state)
	if not state_error.is_empty():
		return _result(false, state_error, state)
	if not _in_range(value, MIN_GREENHOUSE, MAX_GREENHOUSE) or not _is_grid_value(value):
		return _result(false, "invalid_greenhouse", state)
	return _update_parameters(state, float(state["albedo"]), value)

func adjust_albedo(state: Dictionary, direction: int) -> Dictionary:
	if direction != -1 and direction != 1:
		return _result(false, "invalid_direction", state)
	var current: float = float(state.get("albedo", -1.0))
	return set_albedo(state, current + float(direction) * PARAMETER_STEP)

func adjust_greenhouse(state: Dictionary, direction: int) -> Dictionary:
	if direction != -1 and direction != 1:
		return _result(false, "invalid_direction", state)
	var current: float = float(state.get("greenhouse", -1.0))
	return set_greenhouse(state, current + float(direction) * PARAMETER_STEP)

func simulate(state: Dictionary) -> Dictionary:
	var state_error: String = _validate_open_state(state)
	if not state_error.is_empty():
		return _result(false, state_error, state)
	var index: int = int(state["planet_index"])
	var definition: Dictionary = get_planet_definition(index)
	var temperature: float = calculate_equilibrium_temperature(
		float(definition["solar_flux"]),
		float(state["albedo"]),
		float(state["greenhouse"])
	)
	if temperature < 0.0:
		return _result(false, "invalid_state", state)
	var error_k: float = absf(temperature - float(definition["target_temp_k"]))
	var next_state: Dictionary = state.duplicate(true)
	next_state["equilibrium_temp_k"] = temperature
	next_state["error_k"] = error_k
	if error_k <= TARGET_TOLERANCE_K:
		next_state["status"] = "campaign_complete" if index == PLANETS.size() - 1 else "complete"
		next_state["awarded"] = true
		next_state["score"] = int(next_state.get("score", 0)) + 100
		next_state["last_message"] = "CLIMATE STABLE · +100 POINTS"
		return _result(true, "", next_state)
	next_state["last_message"] = "Outside target band · adjust the parameters and simulate again."
	return _result(false, "outside_target_band", next_state)

func advance_planet(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "complete":
		return _result(false, "planet_not_complete", state)
	var next_index: int = int(state.get("planet_index", -1)) + 1
	if next_index < 0 or next_index >= PLANETS.size():
		return _result(false, "no_next_planet", state)
	return _result(true, "", create_state(next_index, int(state.get("score", 0))))

func restart_planet(state: Dictionary) -> Dictionary:
	var status: String = str(state.get("status", ""))
	if status == "complete" or status == "campaign_complete":
		return _result(false, "completed_planet_locked", state)
	var index: int = int(state.get("planet_index", -1))
	if index < 0 or index >= PLANETS.size():
		return _result(false, "invalid_planet", state)
	return _result(true, "", create_state(index, int(state.get("score", 0))))

func restart_campaign() -> Dictionary:
	return create_state(0, 0)

func _update_parameters(state: Dictionary, albedo: float, greenhouse: float) -> Dictionary:
	var definition: Dictionary = get_planet_definition(int(state["planet_index"]))
	var temperature: float = calculate_equilibrium_temperature(float(definition["solar_flux"]), albedo, greenhouse)
	if temperature < 0.0:
		return _result(false, "invalid_parameters", state)
	var next_state: Dictionary = state.duplicate(true)
	next_state["albedo"] = albedo
	next_state["greenhouse"] = greenhouse
	next_state["equilibrium_temp_k"] = temperature
	next_state["error_k"] = absf(temperature - float(definition["target_temp_k"]))
	next_state["last_message"] = "Parameters updated · run the climate simulation."
	return _result(true, "", next_state)

func _validate_open_state(state: Dictionary) -> String:
	if str(state.get("status", "")) != "tuning":
		return "planet_not_open"
	var index: int = int(state.get("planet_index", -1))
	if index < 0 or index >= PLANETS.size():
		return "invalid_planet"
	if not state.has("albedo") or not state.has("greenhouse"):
		return "invalid_state"
	if not _in_range(float(state["albedo"]), MIN_ALBEDO, MAX_ALBEDO):
		return "invalid_state"
	if not _in_range(float(state["greenhouse"]), MIN_GREENHOUSE, MAX_GREENHOUSE):
		return "invalid_state"
	return ""

func _is_grid_value(value: float) -> bool:
	var units: float = round(value / PARAMETER_STEP)
	return absf(value - units * PARAMETER_STEP) <= 0.0001

func _in_range(value: float, minimum: float, maximum: float) -> bool:
	return is_finite(value) and value >= minimum and value <= maximum

func _result(ok: bool, reason: String, next_state: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "state": next_state.duplicate(true)}

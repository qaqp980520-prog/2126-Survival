extends RefCounted

const DIRECTIONS: Array[String] = ["N", "E", "S", "W"]
const ALIGNMENT_PERCENT: Array[int] = [100, 65, 20, 65]
const PITCH_OUTPUT_PERCENT: Array[int] = [125, 100, 75, 45]
const PITCH_HEAT_GAIN: Array[int] = [3, 2, 1, 0]
const TURBINE_COUNT: int = 3
const BATTERY_CAPACITY: int = 8
const INITIAL_BATTERY: int = 6
const COOLING_PER_ROUND: int = 1
const TRIP_HEAT: int = 6

const SCENARIOS: Array[Dictionary] = [
	{
		"id":"north_array",
		"name":"North Array",
		"brief":"Track the steady northern flow while keeping the battery ready for the evening lull.",
		"rounds":[
			{"wind_direction":0,"wind_speed":3,"demand":7},
			{"wind_direction":1,"wind_speed":3,"demand":7},
			{"wind_direction":1,"wind_speed":4,"demand":8},
			{"wind_direction":2,"wind_speed":3,"demand":7}
		]
	},
	{
		"id":"coastal_array",
		"name":"Coastal Array",
		"brief":"Coastal winds swing quickly; feather the blades when the gusts strengthen.",
		"rounds":[
			{"wind_direction":3,"wind_speed":4,"demand":9},
			{"wind_direction":2,"wind_speed":4,"demand":9},
			{"wind_direction":2,"wind_speed":3,"demand":7},
			{"wind_direction":1,"wind_speed":4,"demand":9}
		]
	},
	{
		"id":"polar_array",
		"name":"Polar Array",
		"brief":"High-speed polar gusts can overheat an aggressive pitch. Protect the turbines and spend the battery carefully.",
		"rounds":[
			{"wind_direction":0,"wind_speed":5,"demand":11},
			{"wind_direction":3,"wind_speed":5,"demand":11},
			{"wind_direction":2,"wind_speed":4,"demand":9},
			{"wind_direction":1,"wind_speed":5,"demand":11}
		]
	}
]

func get_scenario_count() -> int:
	return SCENARIOS.size()

func get_scenario(index: int) -> Dictionary:
	if index < 0 or index >= SCENARIOS.size():
		return {}
	return SCENARIOS[index].duplicate(true)

func make_state(scenario_index: int) -> Dictionary:
	if scenario_index < 0 or scenario_index >= SCENARIOS.size():
		return {}
	var turbines: Array[Dictionary] = []
	for _index in range(TURBINE_COUNT):
		turbines.append({"yaw":0,"pitch":1,"heat":0,"online":true})
	return {
		"scenario_index":scenario_index,
		"round_index":0,
		"battery":INITIAL_BATTERY,
		"turbines":turbines,
		"history":[],
		"status":"playing"
	}

func get_current_weather(state: Dictionary) -> Dictionary:
	if not _valid_state(state) or str(state["status"]) != "playing":
		return {}
	var rounds: Array = SCENARIOS[int(state["scenario_index"])]["rounds"]
	var index: int = int(state["round_index"])
	if index < 0 or index >= rounds.size():
		return {}
	return rounds[index].duplicate(true)

func set_turbine_yaw(state: Dictionary, turbine_index: int, yaw: int) -> Dictionary:
	if not _valid_state(state) or str(state["status"]) != "playing":
		return {"ok":false,"reason":"invalid_or_finished_state"}
	if turbine_index < 0 or turbine_index >= TURBINE_COUNT:
		return {"ok":false,"reason":"invalid_turbine"}
	if yaw < 0 or yaw > 3:
		return {"ok":false,"reason":"invalid_yaw"}
	var updated: Dictionary = state.duplicate(true)
	var turbines: Array = updated["turbines"]
	var turbine: Dictionary = turbines[turbine_index]
	turbine["yaw"] = yaw
	turbines[turbine_index] = turbine
	updated["turbines"] = turbines
	return {"ok":true,"state":updated}

func set_turbine_pitch(state: Dictionary, turbine_index: int, pitch: int) -> Dictionary:
	if not _valid_state(state) or str(state["status"]) != "playing":
		return {"ok":false,"reason":"invalid_or_finished_state"}
	if turbine_index < 0 or turbine_index >= TURBINE_COUNT:
		return {"ok":false,"reason":"invalid_turbine"}
	if pitch < 0 or pitch > 3:
		return {"ok":false,"reason":"invalid_pitch"}
	var updated: Dictionary = state.duplicate(true)
	var turbines: Array = updated["turbines"]
	var turbine: Dictionary = turbines[turbine_index]
	turbine["pitch"] = pitch
	turbines[turbine_index] = turbine
	updated["turbines"] = turbines
	return {"ok":true,"state":updated}

func estimate_turbine_output(wind_speed: int, wind_direction: int, yaw: int, pitch: int) -> int:
	if wind_speed < 0 or wind_direction < 0 or wind_direction > 3 or yaw < 0 or yaw > 3 or pitch < 0 or pitch > 3:
		return -1
	var difference: int = posmod(yaw - wind_direction, 4)
	var distance: int = mini(difference, 4 - difference)
	return int(floor(float(wind_speed * ALIGNMENT_PERCENT[distance] * PITCH_OUTPUT_PERCENT[pitch]) / 10000.0))

func get_estimated_outputs(state: Dictionary) -> Array[int]:
	var outputs: Array[int] = []
	var weather: Dictionary = get_current_weather(state)
	if weather.is_empty():
		return outputs
	var turbines: Array = state["turbines"]
	for turbine in turbines:
		if not bool(turbine.get("online", false)):
			outputs.append(0)
		else:
			outputs.append(estimate_turbine_output(
				int(weather["wind_speed"]),
				int(weather["wind_direction"]),
				int(turbine["yaw"]),
				int(turbine["pitch"])
			))
	return outputs

func get_estimated_total(state: Dictionary) -> int:
	var total: int = 0
	for output in get_estimated_outputs(state):
		total += output
	return total

func resolve_round(state: Dictionary) -> Dictionary:
	if not _valid_state(state) or str(state["status"]) != "playing":
		return {"ok":false,"reason":"invalid_or_finished_state"}
	var weather: Dictionary = get_current_weather(state)
	if weather.is_empty():
		return {"ok":false,"reason":"no_active_round"}
	var updated: Dictionary = state.duplicate(true)
	var turbines: Array = updated["turbines"]
	var outputs: Array[int] = []
	var tripped: Array[int] = []
	var generation: int = 0
	var wind_speed: int = int(weather["wind_speed"])
	var wind_direction: int = int(weather["wind_direction"])
	for index in range(TURBINE_COUNT):
		var turbine: Dictionary = turbines[index]
		if not bool(turbine["online"]):
			outputs.append(0)
			continue
		var output: int = estimate_turbine_output(wind_speed, wind_direction, int(turbine["yaw"]), int(turbine["pitch"]))
		outputs.append(output)
		generation += output
		var pitch: int = int(turbine["pitch"])
		var heat_gain: int = int(ceil(float(PITCH_HEAT_GAIN[pitch]) * float(wind_speed) / 3.0))
		var next_heat: int = maxi(0, int(turbine["heat"]) + heat_gain - COOLING_PER_ROUND)
		turbine["heat"] = next_heat
		if next_heat >= TRIP_HEAT:
			turbine["online"] = false
			tripped.append(index)
		turbines[index] = turbine
	updated["turbines"] = turbines
	var demand: int = int(weather["demand"])
	var battery_before: int = int(updated["battery"])
	var net_power: int = generation - demand
	var served: bool = true
	var unmet: int = 0
	if net_power >= 0:
		updated["battery"] = mini(BATTERY_CAPACITY, battery_before + net_power)
	else:
		var deficit: int = -net_power
		if battery_before >= deficit:
			updated["battery"] = battery_before - deficit
		else:
			served = false
			unmet = deficit - battery_before
			updated["battery"] = 0
	var history: Array = updated["history"]
	var report: Dictionary = {
		"round":int(updated["round_index"]) + 1,
		"wind_direction":wind_direction,
		"wind_speed":wind_speed,
		"demand":demand,
		"generation":generation,
		"outputs":outputs,
		"battery_before":battery_before,
		"battery_after":int(updated["battery"]),
		"served":served,
		"unmet":unmet,
		"tripped":tripped.duplicate()
	}
	history.append(report)
	updated["history"] = history
	updated["round_index"] = int(updated["round_index"]) + 1
	if not served:
		updated["status"] = "failed"
	elif int(updated["round_index"]) >= SCENARIOS[int(updated["scenario_index"])]["rounds"].size():
		updated["status"] = "won"
	return {"ok":true,"state":updated,"report":report}

func advance_scenario(state: Dictionary) -> Dictionary:
	if not _valid_state(state) or str(state["status"]) != "won":
		return {"ok":false,"reason":"scenario_not_won"}
	var next_index: int = int(state["scenario_index"]) + 1
	if next_index >= SCENARIOS.size():
		var finished: Dictionary = state.duplicate(true)
		finished["status"] = "campaign_complete"
		return {"ok":true,"state":finished}
	return {"ok":true,"state":make_state(next_index)}

func reset_state(state: Dictionary) -> Dictionary:
	if not _valid_state(state):
		return {}
	return make_state(int(state["scenario_index"]))

func get_progress(state: Dictionary) -> Dictionary:
	if not _valid_state(state):
		return {"round":0,"total_rounds":0,"battery":0,"status":"invalid"}
	var scenario: Dictionary = SCENARIOS[int(state["scenario_index"])]
	return {
		"round":int(state["round_index"]),
		"total_rounds":scenario["rounds"].size(),
		"battery":int(state["battery"]),
		"status":str(state["status"])
	}

func _valid_state(state: Dictionary) -> bool:
	for key in ["scenario_index","round_index","battery","turbines","history","status"]:
		if not state.has(key):
			return false
	if not (state["scenario_index"] is int) or int(state["scenario_index"]) < 0 or int(state["scenario_index"]) >= SCENARIOS.size():
		return false
	if not (state["round_index"] is int) or int(state["round_index"]) < 0 or int(state["round_index"]) > SCENARIOS[int(state["scenario_index"])]["rounds"].size():
		return false
	if not (state["battery"] is int) or int(state["battery"]) < 0 or int(state["battery"]) > BATTERY_CAPACITY:
		return false
	if not (state["turbines"] is Array) or state["turbines"].size() != TURBINE_COUNT:
		return false
	if not (state["history"] is Array):
		return false
	if not ["playing","failed","won","campaign_complete"].has(str(state["status"])):
		return false
	for turbine in state["turbines"]:
		if not (turbine is Dictionary):
			return false
		for key in ["yaw","pitch","heat","online"]:
			if not turbine.has(key):
				return false
		if not (turbine["yaw"] is int) or int(turbine["yaw"]) < 0 or int(turbine["yaw"]) > 3:
			return false
		if not (turbine["pitch"] is int) or int(turbine["pitch"]) < 0 or int(turbine["pitch"]) > 3:
			return false
		if not (turbine["heat"] is int) or int(turbine["heat"]) < 0 or int(turbine["heat"]) > TRIP_HEAT:
			return false
		if not (turbine["online"] is bool):
			return false
	return true

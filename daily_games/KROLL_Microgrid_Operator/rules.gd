extends RefCounted
class_name MicrogridOperatorRules

const MAX_TURNS: int = 8
const MAX_STABILITY: int = 100
const MAX_HEAT: int = 100
const MAX_POWER: int = 30

static func create_game(seed_value: int = 20261028) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var demands: Array[int] = []
	for _index in range(MAX_TURNS):
		demands.append(rng.randi_range(5, 8))
	return {
		"seed": seed_value,
		"turn": 0,
		"power": 6,
		"fuel": 16,
		"heat": 24,
		"stability": 70,
		"demands": demands,
		"status": "running",
		"message": "Balance power, fuel, heat and grid stability."
	}

static func apply_action(state: Dictionary, action: String) -> bool:
	if str(state.get("status", "")) != "running":
		return false
	if action not in ["generate", "cool", "optimize"]:
		return false
	if action == "generate" and int(state.get("fuel", 0)) < 2:
		state["message"] = "Not enough fuel. Cool or optimize the grid."
		return false

	var power := int(state.get("power", 0))
	var fuel := int(state.get("fuel", 0))
	var heat := int(state.get("heat", 0))
	var stability := int(state.get("stability", 0))

	match action:
		"generate":
			power += 10
			fuel -= 2
			heat += 14
		"cool":
			heat = maxi(0, heat - 22)
			power += 2
		"optimize":
			stability = mini(MAX_STABILITY, stability + 12)
			power += 3
			heat = maxi(0, heat - 5)

	power = mini(MAX_POWER, power)
	var turn := int(state.get("turn", 0))
	var demands: Variant = state.get("demands", [])
	if not (demands is Array) or turn < 0 or turn >= demands.size():
		state["status"] = "lost"
		state["message"] = "Grid schedule is invalid."
		return false

	var demand := int(demands[turn])
	var shortage := maxi(0, demand - power)
	power = maxi(0, power - demand)
	if shortage > 0:
		stability -= shortage * 8

	state["power"] = power
	state["fuel"] = fuel
	state["heat"] = heat
	state["stability"] = stability
	state["turn"] = turn + 1

	if heat >= MAX_HEAT:
		state["status"] = "lost"
		state["message"] = "Thermal runaway. Reset to try again."
	elif stability <= 0:
		state["status"] = "lost"
		state["message"] = "Grid stability collapsed. Reset to try again."
	elif int(state["turn"]) >= MAX_TURNS:
		state["status"] = "won"
		state["message"] = "Grid stable for all 8 cycles. Shift complete."
	else:
		state["message"] = "Demand %d served; %d power short." % [demand, shortage]
	return true

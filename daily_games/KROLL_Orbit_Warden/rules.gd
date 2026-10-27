extends RefCounted
class_name KrollOrbitWardenRules

const REQUIRED_CELLS := 6
const STARTING_LIVES := 3
const TIME_LIMIT := 75.0

static func new_state() -> Dictionary:
	return {
		"cells_collected": 0,
		"score": 0,
		"lives": STARTING_LIVES,
		"time_left": TIME_LIMIT,
		"status": "playing",
		"reason": ""
	}

static func collect_cell(state: Dictionary) -> bool:
	if str(state.get("status", "")) != "playing":
		return false
	var collected := int(state.get("cells_collected", 0)) + 1
	state["cells_collected"] = mini(REQUIRED_CELLS, collected)
	state["score"] = int(state.get("score", 0)) + 100
	if int(state["cells_collected"]) >= REQUIRED_CELLS:
		state["status"] = "won"
		state["reason"] = "all_cells_recovered"
	return true

static func lose_life(state: Dictionary) -> bool:
	if str(state.get("status", "")) != "playing":
		return false
	state["lives"] = maxi(0, int(state.get("lives", STARTING_LIVES)) - 1)
	if int(state["lives"]) <= 0:
		state["status"] = "lost"
		state["reason"] = "hull_breach"
	return true

static func tick(state: Dictionary, delta: float) -> void:
	if str(state.get("status", "")) != "playing":
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	state["time_left"] = maxf(0.0, float(state.get("time_left", TIME_LIMIT)) - delta)
	if float(state["time_left"]) <= 0.0:
		state["status"] = "lost"
		state["reason"] = "time_expired"

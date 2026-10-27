extends RefCounted
class_name KrollVentRunnerRules

const REQUIRED_CELLS := 5
const STARTING_LIVES := 3
const TIME_LIMIT := 90.0

static func new_state() -> Dictionary:
	return {
		"cells_collected": 0,
		"lives": STARTING_LIVES,
		"time_left": TIME_LIMIT,
		"score": 0,
		"status": "playing",
		"reason": ""
	}

static func collect_cell(state: Dictionary) -> bool:
	if str(state.get("status", "")) != "playing":
		return false
	var count := int(state.get("cells_collected", 0))
	if count >= REQUIRED_CELLS:
		return false
	state["cells_collected"] = count + 1
	state["score"] = int(state.get("score", 0)) + 100
	return true

static func hit_hazard(state: Dictionary) -> bool:
	if str(state.get("status", "")) != "playing":
		return false
	var lives := maxi(0, int(state.get("lives", STARTING_LIVES)) - 1)
	state["lives"] = lives
	if lives == 0:
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

static func try_exit(state: Dictionary) -> bool:
	if str(state.get("status", "")) != "playing":
		return false
	if int(state.get("cells_collected", 0)) < REQUIRED_CELLS:
		return false
	state["status"] = "won"
	state["reason"] = "extracted"
	return true

extends RefCounted
class_name VerticalRelayRules

const REQUIRED_DATA: int = 5
const TIME_LIMIT: float = 75.0

static func new_state() -> Dictionary:
	return {
		"status": "playing",
		"data_ids": [],
		"remaining_time": TIME_LIMIT,
		"last_action": "start"
	}

static func collect_data(state: Dictionary, data_id: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "playing")) != "playing":
		return next
	if data_id.is_empty() or data_id != data_id.strip_edges():
		next["last_action"] = "invalid_data_id"
		return next
	var ids: Array = next.get("data_ids", [])
	if ids.has(data_id):
		next["last_action"] = "duplicate_data"
		return next
	ids.append(data_id)
	next["data_ids"] = ids
	next["last_action"] = "data_collected"
	return next

static func reach_exit(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "playing")) != "playing":
		return next
	var ids: Array = next.get("data_ids", [])
	if ids.size() >= REQUIRED_DATA:
		next["status"] = "won"
		next["last_action"] = "mission_complete"
	else:
		next["last_action"] = "gate_locked"
	return next

static func tick(state: Dictionary, delta: float) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "playing")) != "playing" or not is_finite(delta):
		return next
	var safe_delta: float = maxf(0.0, delta)
	next["remaining_time"] = maxf(0.0, float(next.get("remaining_time", TIME_LIMIT)) - safe_delta)
	if float(next["remaining_time"]) <= 0.0:
		next["status"] = "failed"
		next["last_action"] = "timeout"
	return next

static func fail(state: Dictionary, reason: String = "fell") -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "playing")) == "playing":
		next["status"] = "failed"
		next["last_action"] = reason
	return next

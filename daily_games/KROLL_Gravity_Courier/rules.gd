extends RefCounted

const CARGO_IDS: Array[String] = ["cargo_1", "cargo_2", "cargo_3", "cargo_4"]
const REQUIRED_CARGO: int = 4

static func new_game() -> Dictionary:
	return {"gravity_sign": 1, "collected": [], "flip_count": 0, "result": "playing"}

static func flip_gravity(state: Dictionary) -> Dictionary:
	if not _valid_state(state):
		return {"ok": false, "reason": "invalid_state", "state": state.duplicate(true)}
	if str(state["result"]) != "playing":
		return {"ok": false, "reason": "finished", "state": state.duplicate(true)}
	var next: Dictionary = state.duplicate(true)
	next["gravity_sign"] = -int(next["gravity_sign"])
	next["flip_count"] = int(next["flip_count"]) + 1
	return {"ok": true, "reason": "flipped", "state": next}

static func collect_cargo(state: Dictionary, cargo_id: String) -> Dictionary:
	if not _valid_state(state):
		return {"ok": false, "reason": "invalid_state", "state": state.duplicate(true)}
	if str(state["result"]) != "playing":
		return {"ok": false, "reason": "finished", "state": state.duplicate(true)}
	if not CARGO_IDS.has(cargo_id):
		return {"ok": false, "reason": "unknown_cargo", "state": state.duplicate(true)}
	if state["collected"].has(cargo_id):
		return {"ok": false, "reason": "already_collected", "state": state.duplicate(true)}
	var next: Dictionary = state.duplicate(true)
	var collected: Array = next["collected"].duplicate()
	collected.append(cargo_id)
	next["collected"] = collected
	return {"ok": true, "reason": "collected", "state": next}

static func try_exit(state: Dictionary) -> Dictionary:
	if not _valid_state(state):
		return {"ok": false, "reason": "invalid_state", "state": state.duplicate(true)}
	if str(state["result"]) != "playing":
		return {"ok": false, "reason": "finished", "state": state.duplicate(true)}
	if state["collected"].size() != REQUIRED_CARGO:
		return {"ok": false, "reason": "cargo_missing", "state": state.duplicate(true)}
	var next: Dictionary = state.duplicate(true)
	next["result"] = "won"
	return {"ok": true, "reason": "complete", "state": next}

static func _valid_state(state: Dictionary) -> bool:
	if not state.has("gravity_sign") or not state.has("collected") or not state.has("flip_count") or not state.has("result"):
		return false
	if not (state["gravity_sign"] is int) or (int(state["gravity_sign"]) != -1 and int(state["gravity_sign"]) != 1):
		return false
	if not (state["collected"] is Array) or not (state["flip_count"] is int) or int(state["flip_count"]) < 0:
		return false
	if not (state["result"] is String) or not ["playing", "won"].has(str(state["result"])):
		return false
	var seen: Dictionary = {}
	for cargo_id in state["collected"]:
		if not (cargo_id is String) or not CARGO_IDS.has(str(cargo_id)) or seen.has(str(cargo_id)):
			return false
		seen[str(cargo_id)] = true
	return true

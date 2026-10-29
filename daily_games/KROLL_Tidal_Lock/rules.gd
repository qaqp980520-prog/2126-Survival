extends RefCounted
class_name TidalLockRules

const CHAMBER_COUNT: int = 4
const MAX_TURNS: int = 10
const MAX_PUMP_ENERGY: int = 3
const MIN_LEVEL: int = 0
const MAX_LEVEL: int = 3
const SEEDS: Array[int] = [7, 8, 9, 10]
const LAYOUTS: Array[Array] = [
	[1, 0, 2, 1],
	[0, 1, 3, 2],
	[2, 1, 2, 1],
	[1, 2, 0, 1]
]

static func new_game(seed_value: int = 7) -> Dictionary:
	var index: int = _layout_index(seed_value)
	return {
		"seed": SEEDS[index],
		"levels": LAYOUTS[index].duplicate(true),
		"gates": [false, false, false],
		"position": 0,
		"turns": 0,
		"pump_energy": MAX_PUMP_ENERGY,
		"status": "playing",
		"message": "Open gate 1, then cross when pressure is safe."
	}

static func toggle_gate(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return _result(false, "terminal", state)
	var position: int = int(state.get("position", -1))
	if position < 0 or position >= CHAMBER_COUNT - 1:
		return _result(false, "no_gate", state)
	var next: Dictionary = state.duplicate(true)
	var gates: Array = next.get("gates", []).duplicate(true)
	gates[position] = not bool(gates[position])
	next["gates"] = gates
	next["turns"] = int(next.get("turns", 0)) + 1
	next["message"] = "Gate %d %s." % [position + 1, "opened" if bool(gates[position]) else "closed"]
	_resolve_terminal(next)
	return _result(true, "gate_toggled", next)

static func pump(state: Dictionary, delta: int) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return _result(false, "terminal", state)
	if delta != -1 and delta != 1:
		return _result(false, "invalid_delta", state)
	if int(state.get("pump_energy", 0)) <= 0:
		return _result(false, "pump_empty", state)
	var position: int = int(state.get("position", -1))
	var levels: Array = state.get("levels", []).duplicate(true)
	if position < 0 or position >= levels.size():
		return _result(false, "invalid_position", state)
	var target: int = int(levels[position]) + delta
	if target < MIN_LEVEL or target > MAX_LEVEL:
		return _result(false, "level_limit", state)
	var next: Dictionary = state.duplicate(true)
	levels[position] = target
	next["levels"] = levels
	next["pump_energy"] = int(next.get("pump_energy", 0)) - 1
	next["turns"] = int(next.get("turns", 0)) + 1
	next["message"] = "Chamber %d water level adjusted to %d." % [position + 1, target]
	_resolve_terminal(next)
	return _result(true, "pumped", next)

static func move_boat(state: Dictionary, direction: int) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return _result(false, "terminal", state)
	if direction != -1 and direction != 1:
		return _result(false, "invalid_direction", state)
	var position: int = int(state.get("position", -1))
	var target: int = position + direction
	if target < 0 or target >= CHAMBER_COUNT:
		return _result(false, "edge", state)
	var gate_index: int = mini(position, target)
	var gates: Array = state.get("gates", [])
	if gate_index < 0 or gate_index >= gates.size() or not bool(gates[gate_index]):
		return _result(false, "gate_closed", state)
	var levels: Array = state.get("levels", [])
	if levels.size() != CHAMBER_COUNT:
		return _result(false, "invalid_levels", state)
	if absi(int(levels[position]) - int(levels[target])) > 1:
		return _result(false, "pressure_mismatch", state)
	var next: Dictionary = state.duplicate(true)
	next["position"] = target
	next["turns"] = int(next.get("turns", 0)) + 1
	next["message"] = "Boat entered chamber %d." % (target + 1)
	_resolve_terminal(next)
	return _result(true, "moved", next)

static func _resolve_terminal(state: Dictionary) -> void:
	if int(state.get("position", -1)) == CHAMBER_COUNT - 1:
		state["status"] = "won"
		state["message"] = "LOCK TRANSIT COMPLETE. Vessel reached the outlet."
	elif int(state.get("turns", 0)) >= MAX_TURNS:
		state["status"] = "failed"
		state["message"] = "TURN BUDGET EXHAUSTED. Reset and plan a safer route."

static func _layout_index(seed_value: int) -> int:
	var found: int = SEEDS.find(seed_value)
	return found if found >= 0 else posmod(seed_value, LAYOUTS.size())

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "state": state.duplicate(true)}

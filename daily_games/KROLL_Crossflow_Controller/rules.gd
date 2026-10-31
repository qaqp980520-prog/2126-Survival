extends RefCounted

const AXIS_NS: int = 0
const AXIS_EW: int = 1
const PHASE_NS_GREEN: String = "NS_GREEN"
const PHASE_EW_GREEN: String = "EW_GREEN"
const PHASE_CLEARANCE: String = "CLEARANCE"
const DIRECTIONS: Array[String] = ["north", "east", "south", "west"]

const LEVELS: Array[Dictionary] = [
	{
		"id": "depot_rush",
		"name": "Depot Rush",
		"max_ticks": 24,
		"target_deliveries": 12,
		"queue_limit": 5,
		"clearance_ticks": 1,
		"arrivals": ["north", "east", "south", "west", "north", "east", "south", "west", "north", "east", "south", "west", "north", "east", "south", "west"]
	},
	{
		"id": "rain_shift",
		"name": "Rain Shift",
		"max_ticks": 28,
		"target_deliveries": 15,
		"queue_limit": 4,
		"clearance_ticks": 1,
		"arrivals": ["north", "east", "south", "west", "north", "east", "south", "west", "north", "east", "south", "west", "north", "east", "south", "west", "north", "east", "south", "west"]
	},
	{
		"id": "freight_window",
		"name": "Freight Window",
		"max_ticks": 34,
		"target_deliveries": 18,
		"queue_limit": 4,
		"clearance_ticks": 2,
		"arrivals": ["north", "east", "south", "west", "north", "east", "south", "west", "north", "east", "south", "west", "north", "east", "south", "west", "north", "east", "south", "west", "north", "east", "south", "west"]
	}
]

static func get_level_count() -> int:
	return LEVELS.size()

static func get_level_data(level_index: int) -> Dictionary:
	if level_index < 0 or level_index >= LEVELS.size():
		return {}
	return LEVELS[level_index].duplicate(true)

static func create_state(level_index: int = 0) -> Dictionary:
	var safe_index: int = clampi(level_index, 0, LEVELS.size() - 1)
	var level: Dictionary = get_level_data(safe_index)
	return {
		"level_index": safe_index,
		"level_id": str(level.get("id", "")),
		"level_name": str(level.get("name", "")),
		"tick": 0,
		"max_ticks": int(level.get("max_ticks", 24)),
		"target_deliveries": int(level.get("target_deliveries", 12)),
		"queue_limit": int(level.get("queue_limit", 5)),
		"clearance_ticks": int(level.get("clearance_ticks", 1)),
		"arrivals": level.get("arrivals", []).duplicate(true),
		"queues": {"north": [], "east": [], "south": [], "west": []},
		"phase": PHASE_NS_GREEN,
		"pending_axis": -1,
		"clearance_remaining": 0,
		"delivered": 0,
		"next_vehicle_id": 1,
		"last_served": {"ns": "", "ew": ""},
		"status": "running",
		"reason": ""
	}

static func request_signal(state: Dictionary, target_axis: int) -> bool:
	if str(state.get("status", "")) != "running":
		return false
	if target_axis != AXIS_NS and target_axis != AXIS_EW:
		return false
	if str(state.get("phase", "")) == PHASE_CLEARANCE:
		return false
	var current_axis: int = AXIS_NS if str(state.get("phase", "")) == PHASE_NS_GREEN else AXIS_EW
	if current_axis == target_axis:
		return false
	state["phase"] = PHASE_CLEARANCE
	state["pending_axis"] = target_axis
	state["clearance_remaining"] = maxi(1, int(state.get("clearance_ticks", 1)))
	return true

static func advance_tick(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "running":
		return state.duplicate(true)
	var tick_index: int = int(state.get("tick", 0))
	var queues: Dictionary = state.get("queues", {})
	var arrivals: Array = state.get("arrivals", [])
	if tick_index >= 0 and tick_index < arrivals.size():
		var direction: String = str(arrivals[tick_index])
		if not queues.has(direction):
			_fail(state, "invalid_arrival")
			return state.duplicate(true)
		var arrival_queue: Array = queues[direction]
		if arrival_queue.size() >= int(state.get("queue_limit", 5)):
			_fail(state, "queue_overflow")
			return state.duplicate(true)
		arrival_queue.append(int(state.get("next_vehicle_id", 1)))
		state["next_vehicle_id"] = int(state.get("next_vehicle_id", 1)) + 1

	if str(state.get("phase", "")) == PHASE_CLEARANCE:
		var remaining: int = int(state.get("clearance_remaining", 0)) - 1
		state["clearance_remaining"] = remaining
		if remaining <= 0:
			var pending_axis: int = int(state.get("pending_axis", -1))
			state["phase"] = PHASE_NS_GREEN if pending_axis == AXIS_NS else PHASE_EW_GREEN
			state["pending_axis"] = -1
			state["clearance_remaining"] = 0
	else:
		var active_axis: int = AXIS_NS if str(state.get("phase", "")) == PHASE_NS_GREEN else AXIS_EW
		var approach: String = _select_approach(queues, active_axis, state.get("last_served", {}))
		if not approach.is_empty():
			var active_queue: Array = queues[approach]
			active_queue.pop_front()
			state["delivered"] = int(state.get("delivered", 0)) + 1
			var last_served: Dictionary = state.get("last_served", {})
			last_served["ns" if active_axis == AXIS_NS else "ew"] = approach

	state["tick"] = tick_index + 1
	if int(state.get("delivered", 0)) >= int(state.get("target_deliveries", 1)):
		state["status"] = "won"
		state["reason"] = "quota_met"
	elif int(state.get("tick", 0)) >= int(state.get("max_ticks", 1)):
		_fail(state, "timeout")
	return state.duplicate(true)

static func get_queue_counts(state: Dictionary) -> Dictionary:
	var queues: Dictionary = state.get("queues", {})
	var counts: Dictionary = {}
	for direction in DIRECTIONS:
		var queue: Array = queues.get(direction, [])
		counts[direction] = queue.size()
	return counts

static func get_phase_label(state: Dictionary) -> String:
	match str(state.get("phase", "")):
		PHASE_NS_GREEN:
			return "NORTH / SOUTH GREEN"
		PHASE_EW_GREEN:
			return "EAST / WEST GREEN"
		PHASE_CLEARANCE:
			return "ALL-RED CLEARANCE"
		_:
			return "SIGNAL FAULT"

static func _select_approach(queues: Dictionary, axis: int, last_served: Dictionary) -> String:
	var first: String = "north" if axis == AXIS_NS else "east"
	var second: String = "south" if axis == AXIS_NS else "west"
	var first_queue: Array = queues.get(first, [])
	var second_queue: Array = queues.get(second, [])
	if first_queue.is_empty():
		return second if not second_queue.is_empty() else ""
	if second_queue.is_empty():
		return first
	if first_queue.size() > second_queue.size():
		return first
	if second_queue.size() > first_queue.size():
		return second
	var last_key: String = "ns" if axis == AXIS_NS else "ew"
	return second if str(last_served.get(last_key, "")) == first else first

static func _fail(state: Dictionary, reason: String) -> void:
	state["status"] = "failed"
	state["reason"] = reason

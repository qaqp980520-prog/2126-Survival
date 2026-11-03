extends RefCounted

const ACTIONS: Array[String] = [
	"chop", "grill", "simmer", "brew", "chill", "butter",
	"glaze", "wash", "plate", "pour", "wait"
]

const SHIFTS: Array[Dictionary] = [
	{
		"name": "Dockside Breakfast",
		"orders": [
			{"id": "s0_o0", "dish": "Solar Wrap", "steps": ["chop", "grill", "plate"], "deadline": 4},
			{"id": "s0_o1", "dish": "Ion Soup", "steps": ["chop", "simmer", "plate"], "deadline": 7},
			{"id": "s0_o2", "dish": "Nebula Tea", "steps": ["brew", "chill", "pour"], "deadline": 10},
			{"id": "s0_o3", "dish": "Fusion Toast", "steps": ["grill", "butter", "plate"], "deadline": 13}
		]
	},
	{
		"name": "Midday Rush",
		"orders": [
			{"id": "s1_o0", "dish": "Comet Skewer", "steps": ["wash", "grill", "glaze", "plate"], "deadline": 5},
			{"id": "s1_o1", "dish": "Lunar Salad", "steps": ["wash", "chop", "plate"], "deadline": 8},
			{"id": "s1_o2", "dish": "Reactor Coffee", "steps": ["brew", "pour", "plate"], "deadline": 11},
			{"id": "s1_o3", "dish": "Aurora Stew", "steps": ["chop", "simmer", "glaze", "plate"], "deadline": 15}
		]
	},
	{
		"name": "Night Shift",
		"orders": [
			{"id": "s2_o0", "dish": "Meteor Bento", "steps": ["wash", "chop", "grill", "plate"], "deadline": 5},
			{"id": "s2_o1", "dish": "Plasma Noodles", "steps": ["chop", "simmer", "glaze", "plate"], "deadline": 9},
			{"id": "s2_o2", "dish": "Zero-G Cocoa", "steps": ["brew", "chill", "pour"], "deadline": 12},
			{"id": "s2_o3", "dish": "Dockside Pie", "steps": ["chop", "butter", "glaze", "plate"], "deadline": 16}
		]
	}
]

func get_shift_count() -> int:
	return SHIFTS.size()

func get_order_count() -> int:
	return 4

func get_action_names() -> Array[String]:
	return ACTIONS.duplicate()

func get_shift_name(shift_index: int) -> String:
	if shift_index < 0 or shift_index >= SHIFTS.size():
		return ""
	return str(SHIFTS[shift_index].get("name", ""))

func create_state(shift_index: int = 0, campaign_score: int = 0, served_total: int = 0, failed_total: int = 0) -> Dictionary:
	if shift_index < 0 or shift_index >= SHIFTS.size():
		return {}
	var orders: Array[Dictionary] = []
	var definitions: Array = SHIFTS[shift_index].get("orders", [])
	for definition_value in definitions:
		if not (definition_value is Dictionary):
			continue
		var definition: Dictionary = definition_value
		var steps: Array = definition.get("steps", []).duplicate(true)
		var deadline: int = int(definition.get("deadline", 0))
		orders.append({
			"id": str(definition.get("id", "")),
			"dish": str(definition.get("dish", "")),
			"steps": steps,
			"progress": 0,
			"deadline": deadline,
			"remaining": deadline,
			"status": "active",
			"mistakes": 0
		})
	return {
		"shift_index": shift_index,
		"shift_name": get_shift_name(shift_index),
		"orders": orders,
		"turn": 0,
		"score": campaign_score,
		"served_count": 0,
		"failed_count": 0,
		"served_total": served_total,
		"failed_total": failed_total,
		"wrong_actions": 0,
		"status": "playing"
	}

func get_order_snapshot(state: Dictionary, order_id: String) -> Dictionary:
	var orders: Array = state.get("orders", [])
	for order_value in orders:
		if order_value is Dictionary and str(order_value.get("id", "")) == order_id:
			return (order_value as Dictionary).duplicate(true)
	return {}

func get_next_action(state: Dictionary, order_id: String) -> String:
	var order: Dictionary = get_order_snapshot(state, order_id)
	if order.is_empty() or str(order.get("status", "")) != "active":
		return ""
	var steps: Array = order.get("steps", [])
	var progress: int = int(order.get("progress", 0))
	if progress < 0 or progress >= steps.size():
		return ""
	return str(steps[progress])

func perform_action(state: Dictionary, order_id: String, action: String) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "shift_not_active"}
	if not ACTIONS.has(action):
		return {"ok": false, "reason": "invalid_action"}
	var next_state: Dictionary = state.duplicate(true)
	var orders: Array = next_state.get("orders", [])
	var target_index: int = -1
	for index in range(orders.size()):
		if orders[index] is Dictionary and str(orders[index].get("id", "")) == order_id:
			target_index = index
			break
	if target_index < 0:
		return {"ok": false, "reason": "unknown_order"}
	var target: Dictionary = orders[target_index]
	if str(target.get("status", "")) != "active":
		return {"ok": false, "reason": "order_not_active"}
	var steps: Array = target.get("steps", [])
	var progress: int = int(target.get("progress", 0))
	if progress < 0 or progress >= steps.size():
		return {"ok": false, "reason": "invalid_order_progress"}
	var expected: String = str(steps[progress])
	var correct: bool = action == expected
	if correct:
		target["progress"] = progress + 1
		if int(target["progress"]) >= steps.size():
			target["status"] = "served"
			next_state["served_count"] = int(next_state.get("served_count", 0)) + 1
			next_state["served_total"] = int(next_state.get("served_total", 0)) + 1
			next_state["score"] = int(next_state.get("score", 0)) + 100 + int(target.get("remaining", 0)) * 5
	else:
		target["mistakes"] = int(target.get("mistakes", 0)) + 1
		next_state["wrong_actions"] = int(next_state.get("wrong_actions", 0)) + 1
	orders[target_index] = target
	for index in range(orders.size()):
		var order: Dictionary = orders[index]
		if str(order.get("status", "")) == "active":
			order["remaining"] = maxi(0, int(order.get("remaining", 0)) - 1)
			if int(order["remaining"]) <= 0:
				order["status"] = "failed"
				next_state["failed_count"] = int(next_state.get("failed_count", 0)) + 1
				next_state["failed_total"] = int(next_state.get("failed_total", 0)) + 1
			orders[index] = order
	next_state["orders"] = orders
	next_state["turn"] = int(next_state.get("turn", 0)) + 1
	_refresh_shift_status(next_state)
	return {
		"ok": true,
		"correct": correct,
		"expected": expected,
		"action": action,
		"order_id": order_id,
		"state": next_state
	}

func advance_shift(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "shift_passed":
		return {"ok": false, "reason": "shift_not_passed"}
	var next_index: int = int(state.get("shift_index", -1)) + 1
	if next_index >= SHIFTS.size():
		return {"ok": false, "reason": "campaign_complete"}
	return {
		"ok": true,
		"state": create_state(
			next_index,
			int(state.get("score", 0)),
			int(state.get("served_total", 0)),
			int(state.get("failed_total", 0))
		)
	}

func restart_campaign() -> Dictionary:
	return create_state(0)

func _refresh_shift_status(state: Dictionary) -> void:
	var orders: Array = state.get("orders", [])
	for order_value in orders:
		if order_value is Dictionary and str(order_value.get("status", "")) == "active":
			return
	var passed: bool = int(state.get("served_count", 0)) >= 3
	if int(state.get("shift_index", 0)) >= SHIFTS.size() - 1:
		state["status"] = "campaign_passed" if int(state.get("served_total", 0)) >= 9 else "campaign_failed"
	else:
		state["status"] = "shift_passed" if passed else "shift_failed"

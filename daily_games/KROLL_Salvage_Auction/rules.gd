extends RefCounted
class_name KROLLSalvageAuctionRules

const INITIAL_CREDITS: int = 100
const TARGET_CREDITS: int = 160
const TARGET_WINS: int = 3
const LOTS: Array[Dictionary] = [
	{"id":"lot_01","name":"Auxiliary Thruster Pair","reserve":10,"estimate_min":18,"estimate_max":30,"true_value":34,"rival_bid":18},
	{"id":"lot_02","name":"Cryo Pump Assembly","reserve":14,"estimate_min":20,"estimate_max":36,"true_value":15,"rival_bid":25},
	{"id":"lot_03","name":"Survey Drone Crate","reserve":20,"estimate_min":32,"estimate_max":48,"true_value":55,"rival_bid":30},
	{"id":"lot_04","name":"Reactor Shield Plates","reserve":16,"estimate_min":25,"estimate_max":42,"true_value":46,"rival_bid":28},
	{"id":"lot_05","name":"Damaged Cargo Scanner","reserve":22,"estimate_min":30,"estimate_max":50,"true_value":28,"rival_bid":42},
	{"id":"lot_06","name":"Precision Gyroscope","reserve":24,"estimate_min":40,"estimate_max":60,"true_value":72,"rival_bid":45},
	{"id":"lot_07","name":"Long-Range Antenna","reserve":25,"estimate_min":35,"estimate_max":55,"true_value":63,"rival_bid":38},
	{"id":"lot_08","name":"Sealed Sample Vault","reserve":30,"estimate_min":42,"estimate_max":64,"true_value":40,"rival_bid":52},
	{"id":"lot_09","name":"Prototype Ion Core","reserve":34,"estimate_min":50,"estimate_max":75,"true_value":90,"rival_bid":58}
]

static func lot_count() -> int:
	return LOTS.size()

static func lot_at(index: int) -> Dictionary:
	if index < 0 or index >= LOTS.size():
		return {}
	return LOTS[index].duplicate(true)

static func bid_price(lot: Dictionary, tier: String) -> int:
	match tier:
		"low":
			return int(lot.get("reserve", 0))
		"standard":
			return ceili((float(lot.get("estimate_min", 0)) + float(lot.get("estimate_max", 0))) / 2.0)
		"aggressive":
			return int(lot.get("estimate_max", 0))
	return -1

static func new_state() -> Dictionary:
	return {
		"lot_index": 0,
		"credits": INITIAL_CREDITS,
		"wins": 0,
		"scan_tokens": 1,
		"inspected": false,
		"inspection_value": -1,
		"status": "active",
		"history": [],
		"last_result": {}
	}

static func perform_action(state: Dictionary, action: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "")) != "active":
		return _rejected(next, "campaign_finished")
	var lot_index: int = int(next.get("lot_index", -1))
	if lot_index < 0 or lot_index >= LOTS.size():
		return _rejected(next, "invalid_lot_index")
	var lot: Dictionary = lot_at(lot_index)

	if action == "inspect":
		if bool(next.get("inspected", false)):
			return _rejected(next, "lot_already_inspected")
		if int(next.get("scan_tokens", 0)) <= 0:
			return _rejected(next, "no_scan_tokens")
		next["scan_tokens"] = int(next["scan_tokens"]) - 1
		next["inspected"] = true
		next["inspection_value"] = int(lot["true_value"])
		next["last_result"] = {"kind":"inspection","message":"Inspection complete. True resale value revealed."}
		return {"accepted":true,"state":next,"reason":"inspected"}

	if action == "pass":
		_append_history(next, lot, "pass", 0, false, 0)
		_advance(next)
		return {"accepted":true,"state":next,"reason":"passed"}

	var tier: String = ""
	if action == "bid_low":
		tier = "low"
	elif action == "bid_standard":
		tier = "standard"
	elif action == "bid_aggressive":
		tier = "aggressive"
	else:
		return _rejected(next, "unknown_action")

	var price: int = bid_price(lot, tier)
	if price < int(lot["reserve"]):
		return _rejected(next, "below_reserve")
	if price > int(next.get("credits", 0)):
		return _rejected(next, "insufficient_credits")

	var won: bool = price >= int(lot["rival_bid"])
	var profit: int = 0
	if won:
		profit = int(lot["true_value"]) - price
		next["credits"] = int(next["credits"]) - price + int(lot["true_value"])
		next["wins"] = int(next.get("wins", 0)) + 1
	_append_history(next, lot, tier, price, won, profit)
	_advance(next)
	return {"accepted":true,"state":next,"reason":"won" if won else "outbid"}

static func _append_history(state: Dictionary, lot: Dictionary, action: String, price: int, won: bool, profit: int) -> void:
	var history: Array = state.get("history", []).duplicate(true)
	history.append({
		"lot_id": str(lot["id"]),
		"lot_name": str(lot["name"]),
		"action": action,
		"bid": price,
		"won": won,
		"true_value": int(lot["true_value"]),
		"rival_bid": int(lot["rival_bid"]),
		"profit": profit
	})
	state["history"] = history
	state["last_result"] = {
		"kind":"resolution",
		"lot_name":str(lot["name"]),
		"won":won,
		"bid":price,
		"true_value":int(lot["true_value"]),
		"rival_bid":int(lot["rival_bid"]),
		"profit":profit
	}

static func _advance(state: Dictionary) -> void:
	state["lot_index"] = int(state.get("lot_index", 0)) + 1
	state["inspected"] = false
	state["inspection_value"] = -1
	if int(state["lot_index"]) < LOTS.size() and int(state["lot_index"]) % 3 == 0:
		state["scan_tokens"] = 1
	if int(state["lot_index"]) >= LOTS.size():
		var won_campaign: bool = int(state.get("credits", 0)) >= TARGET_CREDITS and int(state.get("wins", 0)) >= TARGET_WINS
		state["status"] = "won" if won_campaign else "lost"

static func _rejected(state: Dictionary, reason: String) -> Dictionary:
	return {"accepted":false,"state":state,"reason":reason}

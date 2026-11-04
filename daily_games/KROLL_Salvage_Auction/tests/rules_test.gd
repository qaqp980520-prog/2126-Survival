extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_bid_prices()
	_test_inspection_budget()
	_test_affordability_and_outbid()
	_test_full_campaign()
	if failures.is_empty():
		print("KROLL Salvage Auction rules tests passed.")
		quit(0)
	else:
		push_error("KROLL Salvage Auction rules test failures: " + str(failures))
		quit(1)

func _test_bid_prices() -> void:
	var lot: Dictionary = Rules.lot_at(0)
	_expect(Rules.bid_price(lot, "low") == 10, "low bid equals reserve")
	_expect(Rules.bid_price(lot, "standard") == 24, "standard bid is rounded estimate midpoint")
	_expect(Rules.bid_price(lot, "aggressive") == 30, "aggressive bid equals estimate ceiling")
	_expect(Rules.bid_price(lot, "unknown") == -1, "unknown bid tier is rejected")

func _test_inspection_budget() -> void:
	var state: Dictionary = Rules.new_state()
	var inspected: Dictionary = Rules.perform_action(state, "inspect")
	_expect(bool(inspected["accepted"]), "first inspection in a market is accepted")
	state = inspected["state"]
	_expect(int(state["scan_tokens"]) == 0 and bool(state["inspected"]), "inspection consumes one token and marks the current lot")
	_expect(int(state["inspection_value"]) == 34, "inspection reveals the true value")
	var repeated: Dictionary = Rules.perform_action(state, "inspect")
	_expect(not bool(repeated["accepted"]), "same lot cannot be inspected twice")
	_expect(int(repeated["state"]["scan_tokens"]) == 0, "rejected inspection does not restore or consume tokens")
	state = Rules.perform_action(state, "pass")["state"]
	_expect(int(state["lot_index"]) == 1, "passing advances exactly one lot")
	_expect(int(state["scan_tokens"]) == 0, "scan token does not reset within a market")
	state = Rules.perform_action(state, "pass")["state"]
	state = Rules.perform_action(state, "pass")["state"]
	_expect(int(state["lot_index"]) == 3 and int(state["scan_tokens"]) == 1, "new market grants one inspection token")

func _test_affordability_and_outbid() -> void:
	var state: Dictionary = Rules.new_state()
	state["credits"] = 5
	var unaffordable: Dictionary = Rules.perform_action(state, "bid_aggressive")
	_expect(not bool(unaffordable["accepted"]), "bid above available credits is rejected")
	_expect(int(unaffordable["state"]["credits"]) == 5 and int(unaffordable["state"]["lot_index"]) == 0, "unaffordable bid has no side effects")
	state = Rules.new_state()
	var low_bid: Dictionary = Rules.perform_action(state, "bid_low")
	_expect(bool(low_bid["accepted"]), "reserve bid is accepted for resolution")
	_expect(str(low_bid["reason"]) == "outbid", "bid below rival offer loses the lot")
	_expect(int(low_bid["state"]["credits"]) == Rules.INITIAL_CREDITS, "losing an auction spends no credits")
	var standard_bid: Dictionary = Rules.perform_action(low_bid["state"], "bid_standard")
	_expect(bool(standard_bid["accepted"]), "standard bid resolves next lot")
	_expect(int(standard_bid["state"]["credits"]) == 110, "winning bid pays price and receives true resale value")
	_expect(int(standard_bid["state"]["wins"]) == 1, "winning lot increments wins once")

func _test_full_campaign() -> void:
	var state: Dictionary = Rules.new_state()
	var plan: Array[String] = [
		"inspect", "bid_standard",
		"pass",
		"bid_standard",
		"inspect", "bid_standard",
		"pass",
		"bid_standard",
		"inspect", "bid_standard",
		"pass",
		"bid_standard"
	]
	for action in plan:
		var result: Dictionary = Rules.perform_action(state, action)
		_expect(bool(result["accepted"]), "campaign action accepted: " + action)
		state = result["state"]
	_expect(str(state["status"]) == "won", "deterministic strategy completes the contract")
	_expect(int(state["credits"]) == 204, "campaign final balance is deterministic")
	_expect(int(state["wins"]) == 6, "campaign records six acquired lots")
	_expect((state["history"] as Array).size() == 9, "each lot resolves exactly once")
	var after_finish: Dictionary = Rules.perform_action(state, "pass")
	_expect(not bool(after_finish["accepted"]), "completed campaign cannot resolve another lot")
	_expect(int(after_finish["state"]["credits"]) == 204, "post-completion action cannot alter credits")

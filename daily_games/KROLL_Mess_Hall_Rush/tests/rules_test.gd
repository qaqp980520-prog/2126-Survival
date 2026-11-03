extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules = RulesScript.new()
	_test_shift_contract(rules)
	_test_correct_action_and_immutability(rules)
	_test_served_order_cannot_score_twice(rules)
	_test_wrong_action_consumes_time(rules)
	_test_expired_order(rules)
	_test_full_campaign_solution(rules)
	_test_campaign_guards(rules)
	_test_restart_campaign_resets(rules)
	if failures.is_empty():
		print("KROLL Mess Hall Rush rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_shift_contract(rules: Variant) -> void:
	_expect(rules.get_shift_count() == 3, "three authored cafeteria shifts exist")
	_expect(rules.get_order_count() == 4, "each shift contains four orders")
	_expect(rules.get_action_names().size() == 11, "eleven workstation actions are available")
	for shift_index in range(3):
		var state: Dictionary = rules.create_state(shift_index)
		_expect(not state.is_empty(), "shift %d creates a valid state" % shift_index)
		_expect(state.get("orders", []).size() == 4, "shift %d creates four order tickets" % shift_index)
		_expect(str(state.get("status", "")) == "playing", "shift %d begins active" % shift_index)

func _test_correct_action_and_immutability(rules: Variant) -> void:
	var state: Dictionary = rules.create_state(0)
	var original: Dictionary = state.duplicate(true)
	var order_id: String = "s0_o0"
	var result: Dictionary = rules.perform_action(state, order_id, "chop")
	_expect(bool(result.get("ok", false)) and bool(result.get("correct", false)), "correct prep station advances an order")
	_expect(state == original, "perform_action does not mutate its input state")
	if bool(result.get("ok", false)):
		var next_state: Dictionary = result["state"]
		var snapshot: Dictionary = rules.get_order_snapshot(next_state, order_id)
		_expect(int(snapshot.get("progress", 0)) == 1, "correct station increments progress once")
		_expect(int(snapshot.get("remaining", 0)) == 3, "every action advances the active ticket countdown")
		_expect(rules.get_next_action(next_state, order_id) == "grill", "next station follows the authored recipe")

func _test_wrong_action_consumes_time(rules: Variant) -> void:
	var state: Dictionary = rules.create_state(0)
	var before: int = int(rules.get_order_snapshot(state, "s0_o0").get("remaining", 0))
	var result: Dictionary = rules.perform_action(state, "s0_o0", "brew")
	_expect(bool(result.get("ok", false)) and not bool(result.get("correct", true)), "wrong station input is recorded as a consumed action")
	if bool(result.get("ok", false)):
		var next_state: Dictionary = result["state"]
		var snapshot: Dictionary = rules.get_order_snapshot(next_state, "s0_o0")
		_expect(int(snapshot.get("remaining", 0)) == before - 1, "wrong station consumes one deadline tick")
		_expect(int(snapshot.get("progress", 0)) == 0, "wrong station does not advance recipe progress")
		_expect(int(next_state.get("wrong_actions", 0)) == 1, "wrong station increments the campaign error counter")

func _test_expired_order(rules: Variant) -> void:
	var state: Dictionary = rules.create_state(0)
	for index in range(4):
		var result: Dictionary = rules.perform_action(state, "s0_o0", "wait")
		_expect(bool(result.get("ok", false)), "waiting is accepted as a time-consuming action")
		if not bool(result.get("ok", false)):
			return
		state = result["state"]
	var snapshot: Dictionary = rules.get_order_snapshot(state, "s0_o0")
	_expect(str(snapshot.get("status", "")) == "failed", "an order expires when its deadline reaches zero")
	_expect(int(state.get("failed_count", 0)) >= 1, "expired order increments the failed ticket count")

func _complete_shift(rules: Variant, state: Dictionary) -> Dictionary:
	for order_index in range(4):
		var order_id: String = str(state.get("orders", [])[order_index].get("id", ""))
		while str(rules.get_order_snapshot(state, order_id).get("status", "")) == "active":
			var action: String = rules.get_next_action(state, order_id)
			if action.is_empty():
				return state
			var result: Dictionary = rules.perform_action(state, order_id, action)
			if not bool(result.get("ok", false)) or not bool(result.get("correct", false)):
				_expect(false, "authored shift solution uses the required workstation")
				return state
			state = result["state"]
	return state

func _test_full_campaign_solution(rules: Variant) -> void:
	var state: Dictionary = rules.create_state(0)
	for shift_index in range(3):
		state = _complete_shift(rules, state)
		var expected_status: String = "campaign_passed" if shift_index == 2 else "shift_passed"
		_expect(str(state.get("status", "")) == expected_status, "authored solution completes shift %d" % shift_index)
		if shift_index < 2:
			var advance: Dictionary = rules.advance_shift(state)
			_expect(bool(advance.get("ok", false)), "campaign advances after a passed shift")
			if not bool(advance.get("ok", false)):
				return
			state = advance["state"]
	_expect(int(state.get("served_total", 0)) == 12, "perfect campaign serves all twelve orders")
	_expect(int(state.get("failed_total", 0)) == 0, "perfect campaign has no expired orders")
	_expect(int(state.get("score", 0)) >= 1200, "perfect campaign reaches the score target")

func _test_campaign_guards(rules: Variant) -> void:
	var state: Dictionary = rules.create_state(0)
	var early_advance: Dictionary = rules.advance_shift(state)
	_expect(not bool(early_advance.get("ok", false)) and str(early_advance.get("reason", "")) == "shift_not_passed", "cannot skip an unfinished shift")
	var invalid: Dictionary = rules.perform_action(state, "s0_o0", "teleport")
	_expect(not bool(invalid.get("ok", false)) and str(invalid.get("reason", "")) == "invalid_action", "unknown workstation actions are rejected")

func _test_served_order_cannot_score_twice(rules: Variant) -> void:
	var state: Dictionary = rules.create_state(0)
	var order_id: String = "s0_o0"
	for index in range(3):
		var action: String = rules.get_next_action(state, order_id)
		var result: Dictionary = rules.perform_action(state, order_id, action)
		_expect(bool(result.get("ok", false)) and bool(result.get("correct", false)), "authored recipe action completes without a penalty")
		state = result["state"]
	var score_before: int = int(state.get("score", 0))
	var served_before: int = int(state.get("served_count", 0))
	var duplicate: Dictionary = rules.perform_action(state, order_id, "plate")
	_expect(not bool(duplicate.get("ok", false)) and str(duplicate.get("reason", "")) == "order_not_active", "served order rejects duplicate completion")
	_expect(int(state.get("score", 0)) == score_before, "duplicate completion cannot award score twice")
	_expect(int(state.get("served_count", 0)) == served_before, "duplicate completion cannot increment served count")

func _test_restart_campaign_resets(rules: Variant) -> void:
	var restarted: Dictionary = rules.restart_campaign()
	_expect(int(restarted.get("shift_index", -1)) == 0, "restart returns to the first shift")
	_expect(int(restarted.get("score", -1)) == 0, "restart clears the campaign score")
	_expect(int(restarted.get("served_total", -1)) == 0, "restart clears the served total")
	_expect(int(restarted.get("failed_total", -1)) == 0, "restart clears the failed total")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

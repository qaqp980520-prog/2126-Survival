extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var a: Dictionary = Rules.new_blueprint(101)
	var b: Dictionary = Rules.new_blueprint(101)
	_expect(a == b, "same seed creates a deterministic blueprint", failures)
	_expect(a.get("decks", []).size() == Rules.SPAN_COUNT, "blueprint has five deck spans", failures)
	_expect(int(a.get("budget_left", -1)) == Rules.BUDGET, "initial budget is intact", failures)
	var invalid_span: Dictionary = Rules.set_deck(a, -1, Rules.DECK_STANDARD)
	_expect(not bool(invalid_span.get("ok", false)) and invalid_span.get("reason") == "invalid_span", "negative span is rejected", failures)
	_expect(a == invalid_span.get("state", {}), "invalid span does not mutate source state", failures)
	var invalid_kind: Dictionary = Rules.set_deck(a, 0, "glass")
	_expect(not bool(invalid_kind.get("ok", false)) and a == invalid_kind.get("state", {}), "unknown deck kind is rejected without mutation", failures)
	var no_anchor: Dictionary = Rules.toggle_brace(a, 1)
	_expect(not bool(no_anchor.get("ok", false)) and no_anchor.get("reason") == "no_anchor", "unsupported span cannot receive a brace", failures)
	var too_many: Dictionary = Rules.new_blueprint(101)
	for span in range(4):
		too_many = Rules.set_deck(too_many, span, Rules.DECK_REINFORCED)["state"]
	var over_budget: Dictionary = Rules.set_deck(too_many, 4, Rules.DECK_REINFORCED)
	_expect(not bool(over_budget.get("ok", false)) and over_budget.get("reason") == "over_budget", "over-budget deck placement is rejected", failures)
	_expect(str(too_many["decks"][4]) == Rules.DECK_EMPTY and int(too_many["budget_used"]) == Rules.BUDGET, "rejected placement leaves the previous blueprint intact", failures)
	for seed_value in Rules.SEEDS:
		var state: Dictionary = Rules.new_blueprint(seed_value)
		var anchors: Array = state["anchor_spans"]
		for span in range(Rules.SPAN_COUNT):
			var kind: String = Rules.DECK_STANDARD if anchors.has(span) else Rules.DECK_REINFORCED
			var deck_result: Dictionary = Rules.set_deck(state, span, kind)
			_expect(bool(deck_result.get("ok", false)), "seed %d span %d deck placement succeeds" % [seed_value, span + 1], failures)
			state = deck_result["state"]
			if anchors.has(span):
				var brace_result: Dictionary = Rules.toggle_brace(state, span)
				_expect(bool(brace_result.get("ok", false)), "seed %d anchor span %d accepts brace" % [seed_value, span + 1], failures)
				state = brace_result["state"]
		_expect(int(state["budget_used"]) == Rules.BUDGET, "seed %d solution exactly uses the budget" % seed_value, failures)
		var test_result: Dictionary = Rules.run_load_test(state)
		_expect(bool(test_result.get("ok", false)), "seed %d load test can run" % seed_value, failures)
		state = test_result["state"]
		_expect(str(state["status"]) == "won", "seed %d solution carries the cart safely" % seed_value, failures)
		for span in range(Rules.SPAN_COUNT):
			_expect(Rules.capacity_for_span(state, span) >= Rules.CART_LOAD, "seed %d span %d meets the load" % [seed_value, span + 1], failures)
		var terminal_action: Dictionary = Rules.set_deck(state, 0, Rules.DECK_EMPTY)
		_expect(not bool(terminal_action.get("ok", false)) and terminal_action.get("reason") == "terminal", "won blueprint locks edits", failures)
	var repair: Dictionary = Rules.new_blueprint(101)
	for span in range(Rules.SPAN_COUNT):
		repair = Rules.set_deck(repair, span, Rules.DECK_STANDARD)["state"]
	var failed_test: Dictionary = Rules.run_load_test(repair)
	_expect(str(failed_test["state"]["status"]) == "building" and int(failed_test["state"]["test_count"]) == 1, "failed load test permits redesign", failures)
	if failures.is_empty():
		print("KROLL Span Engineer rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

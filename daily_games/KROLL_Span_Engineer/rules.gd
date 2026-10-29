extends RefCounted
class_name SpanEngineerRules

const SPAN_COUNT: int = 5
const BUDGET: int = 12
const CART_LOAD: int = 3
const DECK_EMPTY: String = "empty"
const DECK_STANDARD: String = "standard"
const DECK_REINFORCED: String = "reinforced"
const SEEDS: Array[int] = [101, 202, 303]
const ANCHOR_LAYOUTS: Array[Array] = [
	[0, 2, 4],
	[0, 1, 3],
	[1, 2, 4]
]

static func new_blueprint(seed_value: int = 101) -> Dictionary:
	var index: int = _layout_index(seed_value)
	return {
		"seed": SEEDS[index],
		"anchor_spans": ANCHOR_LAYOUTS[index].duplicate(true),
		"decks": [DECK_EMPTY, DECK_EMPTY, DECK_EMPTY, DECK_EMPTY, DECK_EMPTY],
		"braces": [false, false, false, false, false],
		"budget_used": 0,
		"budget_left": BUDGET,
		"test_count": 0,
		"status": "building",
		"message": "Build all five spans. Cart load is 3; stay within the 12-unit budget."
	}

static func set_deck(state: Dictionary, span: int, deck_kind: String) -> Dictionary:
	if str(state.get("status", "")) != "building":
		return _result(false, "terminal", state)
	if span < 0 or span >= SPAN_COUNT:
		return _result(false, "invalid_span", state)
	if not [DECK_EMPTY, DECK_STANDARD, DECK_REINFORCED].has(deck_kind):
		return _result(false, "invalid_deck", state)
	var decks: Array = state.get("decks", [])
	var braces: Array = state.get("braces", [])
	if decks.size() != SPAN_COUNT or braces.size() != SPAN_COUNT:
		return _result(false, "invalid_state", state)
	var next: Dictionary = state.duplicate(true)
	next["decks"][span] = deck_kind
	if deck_kind == DECK_EMPTY:
		next["braces"][span] = false
	_recalculate_budget(next)
	if int(next["budget_used"]) > BUDGET:
		return _result(false, "over_budget", state)
	next["message"] = "Span %d deck set to %s." % [span + 1, deck_kind]
	return _result(true, "deck_set", next)

static func toggle_brace(state: Dictionary, span: int) -> Dictionary:
	if str(state.get("status", "")) != "building":
		return _result(false, "terminal", state)
	if span < 0 or span >= SPAN_COUNT:
		return _result(false, "invalid_span", state)
	var anchors: Array = state.get("anchor_spans", [])
	if not anchors.has(span):
		return _result(false, "no_anchor", state)
	var decks: Array = state.get("decks", [])
	if decks.size() != SPAN_COUNT or str(decks[span]) == DECK_EMPTY:
		return _result(false, "deck_required", state)
	var next: Dictionary = state.duplicate(true)
	next["braces"][span] = not bool(next["braces"][span])
	_recalculate_budget(next)
	if int(next["budget_used"]) > BUDGET:
		return _result(false, "over_budget", state)
	next["message"] = "Span %d support %s." % [span + 1, "installed" if bool(next["braces"][span]) else "removed"]
	return _result(true, "brace_toggled", next)

static func run_load_test(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "building":
		return _result(false, "terminal", state)
	var next: Dictionary = state.duplicate(true)
	next["test_count"] = int(next.get("test_count", 0)) + 1
	var weak_spans: Array[int] = []
	for span in range(SPAN_COUNT):
		if capacity_for_span(next, span) < CART_LOAD:
			weak_spans.append(span + 1)
	if weak_spans.is_empty():
		next["status"] = "won"
		next["message"] = "LOAD TEST PASSED. The cart reached the far bank safely."
	else:
		next["message"] = "LOAD TEST FAILED on spans %s. Reinforce or brace them, then test again." % str(weak_spans)
	return _result(true, "load_tested", next)

static func capacity_for_span(state: Dictionary, span: int) -> int:
	if span < 0 or span >= SPAN_COUNT:
		return 0
	var decks: Array = state.get("decks", [])
	var braces: Array = state.get("braces", [])
	if decks.size() != SPAN_COUNT or braces.size() != SPAN_COUNT:
		return 0
	var capacity: int = 0
	match str(decks[span]):
		DECK_STANDARD:
			capacity = 2
		DECK_REINFORCED:
			capacity = 3
		_:
			return 0
	if bool(braces[span]):
		capacity += 1
	return capacity

static func _recalculate_budget(state: Dictionary) -> void:
	var total: int = 0
	var decks: Array = state.get("decks", [])
	var braces: Array = state.get("braces", [])
	for span in range(mini(decks.size(), SPAN_COUNT)):
		match str(decks[span]):
			DECK_STANDARD:
				total += 1
			DECK_REINFORCED:
				total += 3
		if span < braces.size() and bool(braces[span]):
			total += 1
	state["budget_used"] = total
	state["budget_left"] = BUDGET - total

static func _layout_index(seed_value: int) -> int:
	var found: int = SEEDS.find(seed_value)
	return found if found >= 0 else posmod(seed_value, SEEDS.size())

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "state": state.duplicate(true)}

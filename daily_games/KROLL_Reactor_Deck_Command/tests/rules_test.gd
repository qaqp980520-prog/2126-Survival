extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules: RefCounted = RulesScript.new()
	_expect(rules.get_encounter_count() == 3, "three reactor encounters are authored")
	var state: Dictionary = rules.create_state(17)
	var opening_hand: Array = state.get("hand", [])
	var opening_draw: Array = state.get("draw_pile", [])
	var opening_discard: Array = state.get("discard_pile", [])
	_expect(int(state.get("hp", 0)) == 36, "campaign starts with 36 core HP")
	_expect(int(state.get("energy", 0)) == 3, "each turn starts with three energy")
	_expect(opening_hand.size() == 5, "opening hand contains five cards")
	_expect(opening_draw.size() + opening_discard.size() + opening_hand.size() == 15, "all fifteen starter cards are accounted for")

	var invalid_state: Dictionary = rules.create_state(17)
	var invalid_energy: int = int(invalid_state.get("energy", 0))
	var invalid_report: Dictionary = rules.play_card(invalid_state, 99)
	_expect(not bool(invalid_report.get("ok", true)), "out-of-range hand index is rejected")
	_expect(int(invalid_state.get("energy", 0)) == invalid_energy, "invalid card selection does not consume energy")

	var pulse_state: Dictionary = rules.create_state(1)
	pulse_state["hand"] = ["pulse"]
	pulse_state["energy"] = 1
	pulse_state["enemy_hp"] = 20
	var pulse_report: Dictionary = rules.play_card(pulse_state, 0)
	_expect(bool(pulse_report.get("ok", false)), "Pulse is playable with one energy")
	_expect(int(pulse_state.get("enemy_hp", 0)) == 16, "Pulse deals four damage")
	_expect(int(pulse_state.get("block", 0)) == 4, "Pulse adds four block")
	_expect(int(pulse_state.get("energy", 0)) == 0, "Pulse consumes exactly one energy")

	var turn_state: Dictionary = rules.create_state(2)
	turn_state["hand"] = []
	turn_state["block"] = 4
	turn_state["enemy_attack"] = 7
	turn_state["base_attack"] = 7
	turn_state["attack_growth"] = 2
	var turn_report: Dictionary = rules.end_turn(turn_state)
	_expect(bool(turn_report.get("ok", false)), "end turn resolves while the encounter is active")
	_expect(int(turn_state.get("hp", 0)) == 33, "block absorbs incoming damage before core HP")
	_expect(int(turn_state.get("block", -1)) == 0, "block resets after the enemy attack")
	_expect(int(turn_state.get("turn", 0)) == 2, "turn counter advances after surviving the attack")
	_expect(int(turn_state.get("enemy_attack", 0)) == 9, "enemy intent escalates by the configured growth")

	var draw_state: Dictionary = {
		"seed": 3,
		"shuffle_count": 0,
		"draw_pile": [],
		"discard_pile": ["brace", "pulse"],
		"hand": []
	}
	var drawn: int = rules.draw_cards(draw_state, 2)
	var reshuffled_hand: Array = draw_state.get("hand", [])
	var reshuffled_discard: Array = draw_state.get("discard_pile", [])
	_expect(drawn == 2, "empty draw pile reshuffles the discard pile")
	_expect(reshuffled_hand.size() == 2, "reshuffled cards enter the hand")
	_expect(reshuffled_discard.is_empty(), "reshuffle clears the discard pile")
	_expect(int(draw_state.get("shuffle_count", 0)) == 1, "reshuffle count is recorded")

	var coolant_state: Dictionary = rules.create_state(4)
	coolant_state["hand"] = ["coolant"]
	coolant_state["draw_pile"] = ["brace"]
	coolant_state["discard_pile"] = []
	coolant_state["energy"] = 0
	coolant_state["enemy_hp"] = 50
	var coolant_report: Dictionary = rules.play_card(coolant_state, 0)
	var coolant_hand: Array = coolant_state.get("hand", [])
	_expect(bool(coolant_report.get("ok", false)), "zero-cost Coolant can be played with no energy")
	_expect(int(coolant_state.get("block", 0)) == 3, "Coolant adds three block")
	_expect(coolant_hand.has("brace"), "Coolant draws one card after being discarded")

	var repair_state: Dictionary = rules.create_state(5)
	repair_state["hand"] = ["repair"]
	repair_state["energy"] = 2
	repair_state["hp"] = 34
	var repair_report: Dictionary = rules.play_card(repair_state, 0)
	_expect(bool(repair_report.get("ok", false)), "Repair is playable with two energy")
	_expect(int(repair_state.get("hp", 0)) == 36, "Repair cannot exceed maximum core HP")

	var overload_state: Dictionary = rules.create_state(6)
	overload_state["hand"] = ["overload"]
	overload_state["energy"] = 2
	overload_state["hp"] = 2
	overload_state["enemy_hp"] = 50
	var overload_report: Dictionary = rules.play_card(overload_state, 0)
	_expect(bool(overload_report.get("ok", false)), "Overload is accepted when its energy cost is available")
	_expect(int(overload_state.get("hp", 0)) == 0, "Overload recoil cannot reduce core HP below zero")
	_expect(str(overload_state.get("status", "")) == "defeat", "lethal Overload recoil defeats the campaign")

	var campaign: Dictionary = rules.create_state(7)
	for encounter_index in range(3):
		campaign["enemy_hp"] = 6
		campaign["hand"] = ["arc_bolt"]
		campaign["energy"] = 3
		var victory_report: Dictionary = rules.play_card(campaign, 0)
		_expect(bool(victory_report.get("ok", false)), "authored campaign encounter can be defeated")
		_expect(int(campaign.get("score", 0)) == (encounter_index + 1) * 100, "each encounter awards exactly 100 points once")
		if encounter_index < 2:
			_expect(str(campaign.get("status", "")) == "encounter_won", "non-final encounter waits for explicit advance")
			_expect(rules.advance_encounter(campaign), "next encounter advances after a win")
		else:
			_expect(str(campaign.get("status", "")) == "victory", "third encounter completes the campaign")
	_expect(int(campaign.get("score", 0)) == 300, "perfect campaign score is capped at 300")
	_expect(not rules.advance_encounter(campaign), "campaign victory cannot advance to a nonexistent encounter")
	_expect(not bool(rules.play_card(campaign, 0).get("ok", true)), "completed campaign cannot replay cards for duplicate rewards")

	var restarted: Dictionary = rules.restart_campaign(7)
	_expect(int(restarted.get("score", -1)) == 0, "campaign restart clears accumulated score")
	_expect(str(restarted.get("status", "")) == "playing", "campaign restart returns to the first encounter")

	var defeat_state: Dictionary = rules.create_state(8)
	defeat_state["hand"] = []
	defeat_state["hp"] = 1
	defeat_state["block"] = 0
	defeat_state["enemy_attack"] = 5
	var defeat_report: Dictionary = rules.end_turn(defeat_state)
	_expect(bool(defeat_report.get("ok", false)), "enemy attack resolves at end turn")
	_expect(str(defeat_state.get("status", "")) == "defeat", "unblocked lethal attack defeats the campaign")
	_expect(int(defeat_state.get("hp", -1)) == 0, "core HP is clamped at zero")

	if failures.is_empty():
		print("KROLL Reactor Deck Command rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

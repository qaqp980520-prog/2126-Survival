extends RefCounted
class_name FreightSorterRules

const ROUND_SECONDS: float = 60.0
const STARTING_LIVES: int = 3
const CRATE_SECONDS: float = 2.8
const BASE_SCORE: int = 10
const HAZARD_SCORE: int = 15
const MAX_COMBO_BONUS: int = 5

const BAY_ACTIONS: Dictionary = {
	"ORE": "bay_ore",
	"MEDICAL": "bay_medical",
	"DATA": "bay_data"
}

static func resolve(crate_type: String, action: String, combo: int) -> Dictionary:
	var expected_action: String = str(BAY_ACTIONS.get(crate_type, ""))
	var correct := false
	var reason := "wrong_bay"
	if crate_type == "HAZARD":
		correct = action == "quarantine"
		reason = "hazard_quarantined" if correct else "hazard_misrouted"
	elif expected_action.is_empty():
		reason = "unknown_crate"
	else:
		correct = action == expected_action
		reason = "sorted" if correct else "wrong_bay"

	if not correct:
		return {
			"correct": false,
			"score_delta": 0,
			"next_combo": 0,
			"reason": reason
		}

	if crate_type == "HAZARD":
		return {
			"correct": true,
			"score_delta": HAZARD_SCORE,
			"next_combo": combo + 1,
			"reason": reason
		}

	var bonus := mini(maxi(combo, 0), MAX_COMBO_BONUS) * 2
	return {
		"correct": true,
		"score_delta": BASE_SCORE + bonus,
		"next_combo": combo + 1,
		"reason": reason
	}

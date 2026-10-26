extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	_test_matching_bays_score_and_combo()
	_test_wrong_bay_resets_combo()
	_test_hazard_requires_quarantine()
	_test_unknown_crate_is_rejected()
	print("KROLL Freight Sorter rules tests passed.")
	quit(0)

func _test_matching_bays_score_and_combo() -> void:
	var first := Rules.resolve("ORE", "bay_ore", 0)
	assert(first["correct"] and first["score_delta"] == 10 and first["next_combo"] == 1)
	var streak := Rules.resolve("DATA", "bay_data", 3)
	assert(streak["correct"] and streak["score_delta"] == 16 and streak["next_combo"] == 4)

func _test_wrong_bay_resets_combo() -> void:
	var result := Rules.resolve("MEDICAL", "bay_ore", 4)
	assert(not result["correct"] and result["score_delta"] == 0 and result["next_combo"] == 0)

func _test_hazard_requires_quarantine() -> void:
	var correct := Rules.resolve("HAZARD", "quarantine", 2)
	assert(correct["correct"] and correct["score_delta"] == 15 and correct["next_combo"] == 3)
	var wrong := Rules.resolve("HAZARD", "bay_data", 2)
	assert(not wrong["correct"] and wrong["next_combo"] == 0)

func _test_unknown_crate_is_rejected() -> void:
	var result := Rules.resolve("UNKNOWN", "bay_ore", 1)
	assert(not result["correct"] and result["reason"] == "unknown_crate")

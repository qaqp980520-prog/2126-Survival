extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules: RefCounted = RulesScript.new()
	_expect(rules.get_gallery_count() == 3, "three authored galleries exist")
	_expect(rules.get_gallery(-1).is_empty(), "negative gallery index is rejected")
	_expect(rules.get_gallery(3).is_empty(), "out-of-range gallery index is rejected")

	var engineering: Dictionary = rules.get_gallery(0)
	var life_sciences: Dictionary = rules.get_gallery(1)
	var exploration: Dictionary = rules.get_gallery(2)
	_expect(engineering.get("theme") == "engineering" and engineering.get("cards", []).size() == 6, "engineering gallery exposes six cards and its theme")
	_expect(life_sciences.get("theme") == "biology" and life_sciences.get("cards", []).size() == 6, "life-sciences gallery exposes six cards and its theme")
	_expect(exploration.get("theme") == "exploration" and exploration.get("cards", []).size() == 6, "exploration gallery exposes six cards and its theme")

	var engineering_layout := {0: 0, 1: 1, 2: 2, 3: 3}
	var engineering_report: Dictionary = rules.calculate_score(0, engineering_layout)
	_expect(bool(engineering_report.get("ok", false)), "engineering exhibit score is valid")
	_expect(int(engineering_report.get("base_score", 0)) == 14, "engineering exhibit base score is deterministic")
	_expect(int(engineering_report.get("theme_count", 0)) == 3, "engineering exhibit counts matching theme items")
	_expect(int(engineering_report.get("adjacency_count", 0)) == 4, "engineering exhibit counts only four orthogonal links")
	_expect(int(engineering_report.get("total_score", 0)) == 31 and bool(engineering_report.get("passed", false)), "engineering exhibit reaches its target")

	var life_layout := {0: 0, 1: 1, 2: 2, 3: 3}
	var life_report: Dictionary = rules.calculate_score(1, life_layout)
	_expect(int(life_report.get("total_score", 0)) == 29 and bool(life_report.get("passed", false)), "life-sciences exhibit reaches its target")

	var exploration_layout := {0: 0, 1: 1, 2: 3, 3: 5}
	var exploration_report: Dictionary = rules.calculate_score(2, exploration_layout)
	_expect(int(exploration_report.get("total_score", 0)) == 29 and bool(exploration_report.get("passed", false)), "exploration exhibit reaches its target")

	var diagonal_only := {0: 0, 3: 3}
	var diagonal_report: Dictionary = rules.calculate_score(0, diagonal_only)
	_expect(int(diagonal_report.get("adjacency_count", -1)) == 0, "diagonal cases do not create adjacency links")

	var placed: Dictionary = rules.place_card({}, 0, 0)
	_expect(bool(placed.get("ok", false)), "first card can be placed into an open case")
	var duplicate_card: Dictionary = rules.place_card(placed.get("placements", {}), 0, 1)
	_expect(not bool(duplicate_card.get("ok", true)), "the same artifact cannot occupy two cases")
	var occupied_slot: Dictionary = rules.place_card(placed.get("placements", {}), 1, 0)
	_expect(not bool(occupied_slot.get("ok", true)), "an occupied case cannot be overwritten")
	var invalid_card: Dictionary = rules.place_card({}, 6, 0)
	_expect(not bool(invalid_card.get("ok", true)), "out-of-range card index is rejected")
	var invalid_slot: Dictionary = rules.place_card({}, 0, 4)
	_expect(not bool(invalid_slot.get("ok", true)), "out-of-range case index is rejected")

	var duplicate_layout: Dictionary = rules.calculate_score(0, {0: 0, 1: 0})
	_expect(not bool(duplicate_layout.get("ok", true)), "score evaluation rejects duplicate artifact placement")
	var partial_layout: Dictionary = rules.calculate_score(0, {0: 0, 1: 1, 2: 2})
	_expect(bool(partial_layout.get("ok", false)) and not bool(partial_layout.get("passed", true)), "a partial exhibit cannot pass a gallery")
	var copied_gallery: Dictionary = rules.get_gallery(0)
	copied_gallery["cards"][0]["name"] = "tampered"
	_expect(str(rules.get_gallery(0)["cards"][0]["name"]) == "Reactor Blueprint", "gallery data is returned as a defensive deep copy")

	if failures.is_empty():
		print("KROLL Archive Curator rules tests passed.")
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

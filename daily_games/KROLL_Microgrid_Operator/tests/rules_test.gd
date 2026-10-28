extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = Rules.create_game(42)
	var second: Dictionary = Rules.create_game(42)
	_expect(first["demands"] == second["demands"], "same seed creates the same demand schedule")
	_expect(first["demands"].size() == Rules.MAX_TURNS, "schedule contains eight cycles")
	_expect(int(first["power"]) == 6 and int(first["fuel"]) == 16, "new grid starts with known resources")

	var before: Dictionary = first.duplicate(true)
	_expect(not Rules.apply_action(first, "invalid"), "unknown action is rejected")
	_expect(first == before, "unknown action does not mutate game state")

	_expect(Rules.apply_action(first, "generate"), "generation action is accepted with sufficient fuel")
	_expect(int(first["fuel"]) == 14, "generation consumes two fuel")
	_expect(int(first["heat"]) == 38, "generation adds heat")
	_expect(int(first["turn"]) == 1, "accepted action advances one cycle")

	var no_fuel: Dictionary = Rules.create_game(3)
	no_fuel["fuel"] = 0
	var no_fuel_turn := int(no_fuel["turn"])
	_expect(not Rules.apply_action(no_fuel, "generate"), "generation is rejected without fuel")
	_expect(int(no_fuel["turn"]) == no_fuel_turn, "rejected generation does not advance the cycle")

	var winning: Dictionary = Rules.create_game(9)
	winning["turn"] = Rules.MAX_TURNS - 1
	winning["power"] = Rules.MAX_POWER
	winning["fuel"] = 10
	winning["heat"] = 0
	winning["stability"] = Rules.MAX_STABILITY
	_expect(Rules.apply_action(winning, "optimize"), "final safe optimization action is accepted")
	_expect(str(winning["status"]) == "won", "surviving the final cycle wins")
	_expect(not Rules.apply_action(winning, "cool"), "terminal state rejects further actions")

	var losing: Dictionary = Rules.create_game(10)
	losing["power"] = 0
	losing["stability"] = 1
	losing["demands"] = [8, 8, 8, 8, 8, 8, 8, 8]
	_expect(Rules.apply_action(losing, "cool"), "cooling action resolves a cycle")
	_expect(str(losing["status"]) == "lost", "unserved demand can collapse stability")

	var overheating: Dictionary = Rules.create_game(11)
	overheating["heat"] = 90
	_expect(Rules.apply_action(overheating, "generate"), "generation can be attempted near the thermal limit")
	_expect(str(overheating["status"]) == "lost", "thermal runaway ends the shift")

	if failures.is_empty():
		print("KROLL Microgrid Operator rules tests passed.")
	else:
		print("KROLL Microgrid Operator rules tests failed.")
		for failure in failures:
			push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

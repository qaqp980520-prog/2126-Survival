extends SceneTree

const GameScene = preload("res://main.tscn")
const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.has_method("get_current_state"), "game exposes its assignment state")
	_expect(game.call("get_title_text") == "KROLL // CREW LEDGER", "game displays its title")
	_expect(game.call("get_assignment_button_count") == 4, "game builds four crew assignment buttons")
	_expect(game.call("get_clues_text").contains("Kade is assigned to Comms"), "game displays the case clues")

	var rules = RulesScript.new()
	var solution: Array = rules.get_reference_solution(0)
	for crew_index in range(4):
		var current: int = int(game.call("get_current_state").get("assignments", [-1, -1, -1, -1])[crew_index])
		while current != int(solution[crew_index]):
			game.call("_cycle_assignment", crew_index)
			current = int(game.call("get_current_state").get("assignments", [-1, -1, -1, -1])[crew_index])
	game.call("_submit_case")
	_expect(str(game.call("get_current_state").get("status", "")) == "complete", "runtime accepts the correct Relay Blackout manifest")
	_expect(int(game.call("get_current_state").get("score", 0)) == 100, "runtime awards the correct case score")
	game.call("_next_case")
	_expect(str(game.call("get_current_state").get("case_id", "")) == "cryo_alert", "runtime advances to the next case")
	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("KROLL Crew Ledger runtime smoke test passed.")
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

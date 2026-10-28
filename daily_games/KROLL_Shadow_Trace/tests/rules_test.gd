extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = Rules.new_game(30)
	var repeat: Dictionary = Rules.new_game(30)
	_expect(first == repeat, "same seed creates identical stealth layout")
	_expect(first["intel"].size() == 3 and first["guards"].size() == 2, "layout contains three intel caches and two guards")
	_expect(Rules.new_game(31)["intel"] != first["intel"], "next seed changes the intel route")

	var moved: Dictionary = Rules.step(first, Vector2i(1, 0))
	_expect(bool(moved.get("ok", false)), "legal cardinal move succeeds")
	_expect(int(moved["state"]["turns"]) == 1, "legal move consumes one turn")
	var blocked: Dictionary = Rules.step(moved["state"], Vector2i(1, 0))
	_expect(not bool(blocked.get("ok", false)), "wall blocks movement")
	_expect(int(blocked["state"]["turns"]) == 1, "blocked movement does not consume a turn")

	var collection_state: Dictionary = Rules.new_game(30)
	collection_state["player"] = Vector2i(0, 2)
	var collection_result: Dictionary = Rules.step(collection_state, Vector2i(0, 1))
	_expect(bool(collection_result.get("ok", false)), "movement onto an intel cache succeeds")
	_expect(collection_result["state"]["collected"].size() == 1, "intel is collected when entered")

	_expect(Rules.guard_can_see_player(Vector2i(3, 0), Vector2i(5, 0)), "guard sees along a clear row within three tiles")
	_expect(not Rules.guard_can_see_player(Vector2i(3, 0), Vector2i(0, 0)), "wall blocks guard line of sight")
	_expect(not Rules.guard_can_see_player(Vector2i(3, 0), Vector2i(4, 1)), "diagonal cells are outside guard line of sight")

	var wait_state: Dictionary = Rules.new_game(30)
	var waited: Dictionary = Rules.step(wait_state, Vector2i.ZERO)
	_expect(bool(waited.get("ok", false)), "wait action is legal")
	_expect(waited["state"]["player"] == wait_state["player"] and int(waited["state"]["turns"]) == 1, "wait advances patrols without moving player")

	var caught_state: Dictionary = Rules.new_game(30)
	caught_state["player"] = Vector2i(4, 0)
	var caught: Dictionary = Rules.step(caught_state, Vector2i.ZERO)
	_expect(caught["state"]["status"] == "caught", "guard collision ends the run")

	var win_state: Dictionary = Rules.new_game(30)
	win_state["player"] = Vector2i(7, 6)
	win_state["collected"] = win_state["intel"].duplicate(true)
	var win_result: Dictionary = Rules.step(win_state, Vector2i(0, 1))
	_expect(win_result["state"]["status"] == "won", "exit wins only after collecting all intel")
	var locked: Dictionary = Rules.step(win_result["state"], Vector2i(-1, 0))
	_expect(not bool(locked.get("ok", false)), "terminal state rejects further actions")

	if failures.is_empty():
		print("KROLL Shadow Trace rules tests passed.")
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

extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = Rules.create_game(4128)
	var same_seed: Dictionary = Rules.create_game(4128)
	_expect(first["sequence"] == same_seed["sequence"], "same seed creates the same opening sequence")
	_expect((first["sequence"] as Array).size() == 3, "opening round contains three signals")
	for tile in first["sequence"]:
		_expect(int(tile) >= 0 and int(tile) < Rules.TILE_COUNT, "generated signal is inside the nine-tile grid")
	_expect(not Rules.press_tile(first, 0), "input is locked while the sequence is showing")
	_expect(Rules.begin_input(first), "sequence playback can enter input phase")
	var before_index := int(first["input_index"])
	_expect(not Rules.press_tile(first, -1), "negative tile index is rejected")
	_expect(int(first["input_index"]) == before_index, "invalid input does not mutate progress")
	var sequence: Array = first["sequence"]
	_expect(Rules.press_tile(first, int(sequence[0])), "correct first signal is accepted")
	var wrong_tile := (int(sequence[1]) + 1) % Rules.TILE_COUNT
	_expect(Rules.press_tile(first, wrong_tile), "wrong signal is handled as a mistake")
	_expect(int(first["mistakes"]) == 1 and str(first["status"]) == "showing", "first mistake replays the same sequence")
	_expect(Rules.begin_input(first), "replayed sequence returns to input phase")
	sequence = first["sequence"]
	for tile in sequence:
		Rules.press_tile(first, int(tile))
	_expect(int(first["round"]) == 2 and str(first["status"]) == "showing", "perfect replay advances to a longer second round")
	_expect((first["sequence"] as Array).size() == 4, "second round adds one signal")

	while str(first["status"]) == "showing":
		if int(first["round"]) > Rules.MAX_ROUNDS:
			break
		Rules.begin_input(first)
		var round_sequence: Array = first["sequence"]
		for tile in round_sequence:
			Rules.press_tile(first, int(tile))
	_expect(str(first["status"]) == "won", "six completed rounds win the game")
	_expect(not Rules.press_tile(first, 0), "won game rejects further input")
	_expect(not Rules.begin_input(first), "won game cannot re-enter input phase")

	var lost: Dictionary = Rules.create_game(99)
	for _mistake in range(Rules.MAX_MISTAKES):
		if str(lost["status"]) == "showing":
			Rules.begin_input(lost)
		var lost_sequence: Array = lost["sequence"]
		var wrong := (int(lost_sequence[0]) + 1) % Rules.TILE_COUNT
		Rules.press_tile(lost, wrong)
	_expect(str(lost["status"]) == "lost", "third mistake ends the run")
	_expect(not Rules.press_tile(lost, 0), "lost game rejects further input")

	if failures.is_empty():
		print("KROLL Memory Matrix rules tests passed.")
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

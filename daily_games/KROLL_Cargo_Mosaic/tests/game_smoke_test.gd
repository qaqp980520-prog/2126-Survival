extends SceneTree

const GameScene = preload("res://main_root.tscn")
const FIXTURES: Array[Array] = [
	[{"id":"ION","origin":Vector2i(1,1),"rotation":3},{"id":"FORK","origin":Vector2i(2,4),"rotation":0},{"id":"HOOK","origin":Vector2i(4,0),"rotation":0},{"id":"CORE","origin":Vector2i(2,1),"rotation":0}],
	[{"id":"ION","origin":Vector2i(1,2),"rotation":0},{"id":"FORK","origin":Vector2i(0,3),"rotation":1},{"id":"HOOK","origin":Vector2i(4,3),"rotation":2},{"id":"CORE","origin":Vector2i(3,4),"rotation":2}],
	[{"id":"ION","origin":Vector2i(5,2),"rotation":1},{"id":"FORK","origin":Vector2i(1,1),"rotation":1},{"id":"HOOK","origin":Vector2i(2,4),"rotation":3},{"id":"CORE","origin":Vector2i(3,1),"rotation":0}]
]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // CARGO MOSAIC", "game title")
	_expect(game.call("get_board_button_count") == 36, "6x6 board")
	_expect(game.call("get_piece_button_count") == 4, "four module controls")
	_expect(str(game.call("get_piece_preview_text", "FORK")).contains("■"), "module controls show their spatial silhouettes")
	_expect(game.call("get_target_cell_count") == 16, "sixteen target cells")
	_expect(game.call("try_place_piece", "ION", Vector2i(1,1), 3), "valid module placement")
	_expect(not game.call("try_place_piece", "CORE", Vector2i(1,1), 0), "overlap rejection")
	game.call("reset_level")
	for level_index in range(3):
		for fixture in FIXTURES[level_index]:
			_expect(game.call("try_place_piece", fixture["id"], fixture["origin"], fixture["rotation"]), "authored placement for bay %d" % (level_index + 1))
		_expect(game.call("get_current_state").get("solved", false), "exact cover for bay %d" % (level_index + 1))
		if level_index < 2:
			_expect(game.call("advance_level"), "advance to next bay")
	_expect(game.call("advance_level"), "complete final bay")
	_expect(game.call("get_current_state").get("campaign_complete", false), "campaign terminal state")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Cargo Mosaic runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)

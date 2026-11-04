extends SceneTree

const GameScene = preload("res://main.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.find_child("BoardGrid", true, false) != null, "playable three-lane board is present")
	_expect(game.find_child("StartWaveButton", true, false) != null, "wave start button is present")
	for lane in range(3):
		for column in range(5):
			_expect(game.find_child("Cell_%d_%d" % [lane, column], true, false) != null, "board cell exists")
	_expect(game.build_tower_at(0, 1), "first tower can be built")
	_expect(game.build_tower_at(1, 2), "second tower can be built")
	_expect(not game.build_tower_at(0, 1), "occupied cell rejects a duplicate tower")
	var prepared: Dictionary = game.get_state_snapshot()
	_expect(int(prepared["credits"]) == 20, "tower construction deducts forty credits each")
	_expect(prepared["towers"].size() == 2, "both towers are represented in the live game state")
	_expect(game.start_wave(), "first wave can start")
	for tick in range(30):
		game._process(0.1)
	var active: Dictionary = game.get_state_snapshot()
	_expect(int(active["spawned"]) >= 2, "wave spawns enemies on its deterministic lane sequence")
	_expect(active["towers"].size() == 2, "tower ownership remains stable while the wave runs")
	_expect(game.is_wave_running(), "wave remains active while later enemies are pending")
	game.restart_campaign()
	var restarted: Dictionary = game.get_state_snapshot()
	_expect(int(restarted["core_hp"]) == 20, "campaign restart restores core integrity")
	_expect(int(restarted["credits"]) == 100, "campaign restart restores starting credits")
	_expect(restarted["towers"].is_empty(), "campaign restart clears placed towers")
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("KROLL Bastion Array runtime smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)

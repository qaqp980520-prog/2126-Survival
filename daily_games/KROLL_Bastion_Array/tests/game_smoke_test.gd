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
	for wave in range(3):
		_expect(game.start_wave(), "wave %d can start" % [wave + 1])
		var ticks: int = 0
		while game.is_wave_running() and ticks < 400:
			game._process(0.05)
			ticks += 1
		var after_wave: Dictionary = game.get_state_snapshot()
		_expect(not game.is_wave_running(), "wave %d resolves within the simulation budget" % [wave + 1])
		_expect(not bool(after_wave["game_over"]), "core survives wave %d" % [wave + 1])
		_expect(int(after_wave["wave_index"]) == wave + 1, "wave %d awards progression once" % [wave + 1])
		_expect(int(after_wave["score"]) == (wave + 1) * 100, "wave %d awards one hundred campaign points" % [wave + 1])
	var completed: Dictionary = game.get_state_snapshot()
	_expect(bool(completed["won"]), "all three waves complete the campaign")
	_expect(int(completed["score"]) == 300, "campaign score reaches the 300-point cap")
	_expect(int(completed["core_hp"]) > 0, "the deterministic two-tower opening strategy can protect the core")
	_expect(int(completed["leaks"]) == 4, "only the four unguarded-lane enemies reach the core")
	game.restart_campaign()
	var restarted: Dictionary = game.get_state_snapshot()
	_expect(int(restarted["core_hp"]) == 20, "campaign restart restores core integrity")
	_expect(int(restarted["credits"]) == 100, "campaign restart restores starting credits")
	_expect(restarted["towers"].is_empty(), "campaign restart clears placed towers")
	_expect(int(restarted["score"]) == 0, "campaign restart clears the campaign score")
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

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	assert(packed != null, "Main scene must load")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.notes.size() == 32, "Chart should contain 32 notes")
	assert(game.lives == 5 and game.score == 0 and game.playing)
	game.elapsed = float(game.notes[0]["hit_time"])
	game._hit_lane(0)
	assert(game.score == 300 and game.combo == 1, "Perfect hit should score 300 and increment combo")
	assert(bool(game.notes[0]["resolved"]))
	game.elapsed = float(game.notes[1]["hit_time"]) + 0.11
	game._hit_lane(1)
	assert(game.score == 400 and game.combo == 2, "Good hit should score 100 and keep the combo")
	game.elapsed = float(game.notes[2]["hit_time"]) + 0.20
	game._hit_lane(2)
	assert(game.lives == 4 and game.combo == 0, "Off-beat input should consume one core and reset combo")
	game.reset_game()
	assert(game.lives == 5 and game.score == 0 and game.combo == 0 and game.playing)
	print("KROLL Pulse Rhythm runtime smoke test passed.")
	quit(0)

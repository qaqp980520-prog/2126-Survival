extends SceneTree
const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	_expect(game != null, "Neon Climber scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	_expect(game.has_method("get_run_state"), "game exposes its run state")
	_expect(game.get_player() != null and game.get_player().is_inside_tree(), "player and physics body are created")
	_expect(game.get_core_count() == 3, "each sector has three data cores")
	_expect(not game.get_exit_unlocked(), "exit starts locked")
	var player: CharacterBody2D = game.get_player()
	var spawn: Vector2 = player.global_position
	_expect(game.collect_core("core_a"), "first core can be collected")
	_expect(not game.collect_core("core_a"), "duplicate collection is rejected")
	var checkpoint: Vector2 = Rules.get_level(0).get("checkpoint_position", Vector2.ZERO)
	_expect(not game.activate_checkpoint("midway", Vector2(760, 400)), "unsafe checkpoint position inside platform is rejected")
	_expect(str(game.get_run_state()["checkpoint_id"]) == "start", "rejected checkpoint does not mutate progress")
	_expect(game.activate_checkpoint("midway", checkpoint), "authored safe checkpoint activation succeeds")
	_expect(game.get_checkpoint_position() == checkpoint, "checkpoint stores the authored grounded respawn position")
	game.hit_hazard()
	await physics_frame
	await physics_frame
	_expect(int(game.get_run_state()["deaths"]) == 1, "hazard increments the fall counter")
	_expect(player.global_position.is_equal_approx(checkpoint), "hazard respawns player at the checkpoint")
	_expect(player.is_on_floor(), "checkpoint respawn leaves the player grounded on its platform")
	_expect((game.get_run_state()["collected"] as Array).size() == 1, "hazard respawn preserves recovered cores")
	_expect(not game.try_complete_level(), "exit rejects incomplete core collection")
	_expect(game.collect_core("core_b") and game.collect_core("core_c"), "remaining data cores can be collected")
	_expect(game.get_exit_unlocked(), "all data cores unlock the exit")
	_expect(game.try_complete_level(), "unlocked exit completes the sector")
	_expect(game.next_level() and game.get_current_level_index() == 1, "N progression loads Reactor Scaffold")
	game.reset_level()
	_expect(game.get_current_level_index() == 1 and (game.get_run_state()["collected"] as Array).is_empty(), "reset restarts the current sector")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Neon Climber runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

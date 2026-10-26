extends SceneTree

func _initialize() -> void:
	call_deferred("_run_smoke_test")

func _run_smoke_test() -> void:
	var packed: PackedScene = load("res://Main.tscn")
	assert(packed != null, "Main.tscn should load")
	var game: Node = packed.instantiate()
	assert(game != null, "main scene should instantiate")
	root.add_child(game)
	await process_frame
	assert(int(game.get("credits")) == 80, "initial credits should be 80")
	assert(int(game.get("base_health")) == 10, "base should start with 10 health")
	assert(int(game.get("spawn_remaining")) == 6, "wave 1 should queue six drones")
	assert(game.get("path_cells").size() > 10, "route should contain multiple tiles")
	assert(game.has_method("_build_tower"), "tower build action should exist")
	root.remove_child(game)
	game.free()
	print("KROLL Core Defense scene smoke test passed.")
	quit(0)

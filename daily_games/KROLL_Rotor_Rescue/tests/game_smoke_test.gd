extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = MainScene.instantiate() as Control
	assert(game != null, "Rotor Rescue main scene must instantiate")
	root.add_child(game)
	await process_frame
	var state: Dictionary = game.get("game_state")
	assert(int(state.get("seed", 0)) == 1, "Main scene starts with the first deterministic layout")
	assert(game.get_node_or_null("Button") != null, "Touch control buttons are created")
	var next: Dictionary = Rules.step(state, Vector2.RIGHT, 0.1)
	var next_position: Vector2 = next["position"]
	var initial_position: Vector2 = state["position"]
	assert(next_position.x > initial_position.x, "Rules module advances the flight state")
	game.queue_free()
	await process_frame
	print("KROLL Rotor Rescue runtime smoke test passed.")
	quit(0)

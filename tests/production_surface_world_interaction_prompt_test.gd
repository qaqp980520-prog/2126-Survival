extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: Node3D = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld instantiates for interaction prompt coverage")
	if world == null:
		quit(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	var prompt: Label = world.get("interaction_prompt") as Label
	_expect(prompt != null, "production HUD creates a dedicated interaction prompt")
	if prompt == null:
		world.queue_free()
		await process_frame
		quit(1)
		return

	var surface_crate: Node3D = _find_world_prop(world, "SalvageCrate", "Chunk_0_0")
	_expect(surface_crate != null, "surface origin chunk exposes its salvage crate")
	if surface_crate != null:
		world.player.global_position = surface_crate.global_position + Vector3(0.0, 1.0, 0.0)
		world.call("_refresh_hud")
		_expect(prompt.text.contains("OPEN SALVAGE CRATE"), "surface HUD prompts F interaction when a crate is in reach")

	world.player.global_position = Vector3(1.5, 2.0, 7.5)
	_expect(bool(world.call("_toggle_mine_access")), "test enters the production underground lift")
	var gold_cache: Node3D = _find_world_prop(world, "MineCache_Gold", "UndergroundMine_0_0")
	_expect(gold_cache != null, "origin mine room exposes its stateful gold cache")
	if gold_cache != null:
		world.player.global_position = gold_cache.global_position + Vector3(0.0, 1.0, 0.0)
		world.call("_refresh_hud")
		_expect(prompt.text.contains("OPEN GOLD ORE CACHE"), "underground HUD identifies the nearest cache and its remaining loot")

	var origin_vein: Node3D = _find_world_prop(world, "Vein_0", "UndergroundMine_0_0", true)
	_expect(origin_vein != null, "origin mine room exposes a mineral vein")
	if origin_vein != null:
		world.player.global_position = origin_vein.global_position + Vector3(0.0, 1.0, 0.0)
		world.call("_refresh_hud")
		_expect(prompt.text.contains("MINE "), "underground HUD switches to mining when the vein is the nearest target")

	world.player.global_position = Vector3(100.0, -8.25, 100.0)
	world.call("_refresh_hud")
	_expect(prompt.text == "NO CACHE OR VEIN IN REACH", "underground HUD reports when no cache or vein is within interaction range")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("Production SurfaceWorld interaction prompt tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _find_world_prop(world: Node, node_name: String, chunk_name: String, mineral: bool = false) -> Node3D:
	var candidates: Array = world.chunk_controller.get_loaded_mineral_nodes() if mineral else world.chunk_controller.get_loaded_world_state_nodes()
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.name != node_name:
			continue
		var parent_node: Node = candidate.get_parent()
		if is_instance_valid(parent_node) and parent_node.name == chunk_name:
			return candidate as Node3D
	return null

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

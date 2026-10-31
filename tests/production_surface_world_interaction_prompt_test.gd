extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const MineralCatalogScript = preload("res://systems/MineralCatalog.gd")
var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld instantiates for camera-ray interaction coverage")
	if world == null:
		quit(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	var prompt: Label = world.get("interaction_prompt") as Label
	_expect(prompt != null, "production HUD creates a dedicated interaction prompt")
	if prompt == null:
		_finish(1)
		return

	var surface_crate: Node3D = _find_world_prop("SalvageCrate", "Chunk_0_0")
	_expect(surface_crate != null, "surface origin chunk exposes its salvage crate")
	if surface_crate != null:
		await _aim_at(surface_crate)
		var target: Dictionary = world.call("get_camera_interaction_target")
		_expect(str(target.get("kind", "")) == "prop" and target.get("node") == surface_crate, "camera ray selects the salvage crate rather than the nearest object by distance")
		world.call("_refresh_hud")
		_expect(prompt.text.begins_with("F  OPEN ") and prompt.text.contains("CACHE"), "surface HUD prompts F for the crate under the reticle")
		world.camera.rotate_y(PI)
		await physics_frame
		await physics_frame
		var facing_away: Dictionary = world.call("get_camera_interaction_target")
		_expect(facing_away.is_empty(), "a nearby crate is not selected when the camera faces away")
		await _aim_at(surface_crate)
		var unrelated_area := Area3D.new()
		unrelated_area.name = "NonInteractionTriggerArea"
		unrelated_area.collision_layer = 1
		unrelated_area.collision_mask = 0
		unrelated_area.monitoring = false
		var unrelated_collision := CollisionShape3D.new()
		var unrelated_shape := BoxShape3D.new()
		unrelated_shape.size = Vector3(1.2, 1.2, 1.2)
		unrelated_collision.shape = unrelated_shape
		unrelated_area.add_child(unrelated_collision)
		world.add_child(unrelated_area)
		unrelated_area.global_position = world.camera.global_position.lerp(surface_crate.global_position + Vector3(0.0, 0.55, 0.0), 0.5)
		await physics_frame
		await physics_frame
		var target_through_trigger: Dictionary = world.call("get_camera_interaction_target")
		_expect(str(target_through_trigger.get("kind", "")) == "prop" and target_through_trigger.get("node") == surface_crate, "unrelated trigger areas do not block a valid interaction target")
		unrelated_area.queue_free()
		await physics_frame
		await physics_frame
		var blocker := StaticBody3D.new()
		blocker.name = "RaycastOcclusionTestBlocker"
		var blocker_collision := CollisionShape3D.new()
		var blocker_shape := BoxShape3D.new()
		blocker_shape.size = Vector3(1.2, 1.2, 1.2)
		blocker_collision.shape = blocker_shape
		blocker.add_child(blocker_collision)
		world.add_child(blocker)
		blocker.global_position = world.camera.global_position.lerp(surface_crate.global_position + Vector3(0.0, 0.55, 0.0), 0.5)
		await physics_frame
		await physics_frame
		var blocked_target: Dictionary = world.call("get_camera_interaction_target")
		_expect(blocked_target.is_empty(), "solid world geometry blocks the interaction ray")
		blocker.queue_free()
		await physics_frame
		await physics_frame
		await _aim_at(surface_crate)
		var crate_before: int = int(surface_crate.get("loot_remaining"))
		var crate_result: Dictionary = world.call("_interact_nearest_world_prop")
		_expect(bool(crate_result.get("ok", false)), "F action interacts with the crate selected by the camera ray")
		_expect(int(surface_crate.get("loot_remaining")) == crate_before - 1, "camera-selected crate consumes exactly one salvage unit")

	var crop_plots: Array = world.chunk_controller.call("get_loaded_crop_plots")
	_expect(not crop_plots.is_empty(), "surface world exposes a crop plot target")
	if not crop_plots.is_empty():
		var crop_plot: Node3D = crop_plots[0] as Node3D
		await _aim_at(crop_plot, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
		var crop_target: Dictionary = world.call("get_camera_interaction_target")
		_expect(str(crop_target.get("kind", "")) == "crop" and crop_target.get("node") == crop_plot, "camera ray resolves the crop-plot interaction area to its registered plot")
		world.call("_refresh_hud")
		_expect(prompt.text == "E  MANAGE CROP PLOT", "surface HUD prompts E for the crop plot under the reticle")

	var surface_lift: Node3D = world.get_node_or_null("KrollMineShaftEntrance") as Node3D
	_expect(surface_lift != null, "surface mine lift has a raycast target even in headless mode")
	if surface_lift != null:
		await _aim_at(surface_lift, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
		var lift_target: Dictionary = world.call("get_camera_interaction_target")
		_expect(str(lift_target.get("kind", "")) == "lift", "camera ray resolves the surface mine lift")
		world.call("_refresh_hud")
		_expect(prompt.text.contains("ENTER KROLL MINE LIFT"), "surface HUD prompts for the lift under the reticle")
		_expect(bool(world.call("_toggle_mine_access")), "G enters the mine when the player aims at the lift")

	var gold_cache: Node3D = _find_world_prop("MineCache_Gold", "UndergroundMine_0_0")
	_expect(gold_cache != null, "origin mine room exposes its stateful gold cache")
	if gold_cache != null:
		await _aim_at(gold_cache, Vector3(0.0, 1.0, -2.0), Vector3(0.0, 0.55, 0.0))
		var cache_target: Dictionary = world.call("get_camera_interaction_target")
		var gold_data: Dictionary = MineralCatalogScript.get_mineral("gold_ore")
		var expected_cache_name: String = str(gold_data.get("display_name", "gold_ore")).to_upper()
		var expected_remaining: int = int(gold_cache.get("loot_remaining"))
		_expect(str(cache_target.get("kind", "")) == "prop" and cache_target.get("node") == gold_cache, "camera ray selects the underground gold cache")
		world.call("_refresh_hud")
		var expected_cache_prompt: String = "F  OPEN %s CACHE · %d LEFT" % [expected_cache_name, expected_remaining]
		_expect(prompt.text == expected_cache_prompt, "underground HUD shows catalog display name and remaining cache stock")
		var cache_result: Dictionary = world.call("_interact_nearest_world_prop")
		_expect(bool(cache_result.get("ok", false)) and int(cache_result.get("remaining", -1)) == expected_remaining - 1, "F consumes one unit from the cache under the reticle")

	var origin_vein: Node3D = _find_mineral_node("Vein_0", "UndergroundMine_0_0")
	_expect(origin_vein != null, "origin mine room exposes a mineral vein")
	if origin_vein != null:
		await _aim_at(origin_vein, Vector3(0.0, 1.0, -2.0), Vector3(0.0, 0.55, 0.0))
		var vein_target: Dictionary = world.call("get_camera_interaction_target")
		_expect(str(vein_target.get("kind", "")) == "vein" and vein_target.get("node") == origin_vein, "camera ray selects the mineral vein under the reticle")
		world.call("_refresh_hud")
		_expect(prompt.text.begins_with("F  MINE "), "underground HUD switches to mining for the aimed vein")
		var mine_result: Dictionary = world.call("_interact_nearest_world_prop")
		_expect(bool(mine_result.get("ok", false)) and int(mine_result.get("amount", 0)) == 1, "F mines the vein selected by the camera ray")

	world.player.global_position = Vector3(100.0, -8.25, 100.0)
	await physics_frame
	await physics_frame
	world.call("_refresh_hud")
	_expect(prompt.text == "NO INTERACTION IN SIGHT", "HUD reports when no target is visible within interaction range")
	_finish(0 if failures.is_empty() else 1)

func _aim_at(target: Node3D, player_offset: Vector3 = Vector3(0.0, 1.0, 2.0), target_offset: Vector3 = Vector3(0.0, 0.55, 0.0)) -> void:
	world.player.global_position = target.global_position + player_offset
	world.camera.look_at(target.global_position + target_offset, Vector3.UP)
	await physics_frame
	await physics_frame

func _find_world_prop(node_name: String, chunk_name: String) -> Node3D:
	var candidates: Array = world.chunk_controller.call("get_loaded_world_state_nodes")
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.name != node_name:
			continue
		var parent_node: Node = candidate.get_parent()
		if is_instance_valid(parent_node) and parent_node.name == chunk_name:
			return candidate as Node3D
	return null

func _find_mineral_node(node_name: String, chunk_name: String) -> Node3D:
	var candidates: Array = world.chunk_controller.call("get_loaded_mineral_nodes")
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

func _finish(exit_code: int) -> void:
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("Production SurfaceWorld interaction prompt tests passed.")
		print("Production SurfaceWorld camera-ray interaction tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

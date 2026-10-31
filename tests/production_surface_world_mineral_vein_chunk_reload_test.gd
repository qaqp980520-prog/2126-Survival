extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const Adapter = preload("res://systems/MineralChunkLifecycleAdapter.gd")
const MINE_CHUNK_ID: String = "underground/mine_0_0"
var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld instantiates for mineral-vein reload coverage")
	if world == null:
		quit(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame

	var surface_lift: Node3D = world.get_node_or_null("KrollMineShaftEntrance") as Node3D
	_expect(surface_lift != null, "surface world exposes its production mine lift")
	if surface_lift == null:
		await _finish(1)
		return
	await _aim_at(surface_lift, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
	_expect(bool(world.call("_toggle_mine_access")), "camera-selected lift enters the production underground mine")
	_expect(bool(world.get("_is_underground")), "world records underground mode after entering the lift")

	var original_root: Node3D = world.chunk_controller.call("get_chunk_root", MINE_CHUNK_ID) as Node3D
	var original_vein: Node3D = _find_vein(MINE_CHUNK_ID, "Vein_0")
	_expect(original_root != null and original_vein != null, "origin mine chunk exposes a real factory-created mineral vein")
	if original_root == null or original_vein == null:
		await _finish(1)
		return

	var local_path: String = "%s/%s" % [str(original_root.name), str(original_vein.name)]
	var stable_id: String = Adapter.make_stable_id(MINE_CHUNK_ID, local_path)
	var registry: Node = world.chunk_controller.get("registry") as Node
	_expect(stable_id == "underground/mine_0_0/vein/UndergroundMine_0_0/Vein_0", "vein receives the deterministic chunk/local-path stable ID")
	_expect(registry.call("get_registered_ids").has(stable_id), "origin vein is registered while its chunk is loaded")

	await _aim_at(original_vein, Vector3(0.0, 1.0, -2.0), Vector3(0.0, 0.55, 0.0))
	var original_target: Dictionary = world.call("get_camera_interaction_target")
	var original_proxy: Area3D = original_target.get("proxy") as Area3D
	_expect(str(original_target.get("kind", "")) == "vein" and original_target.get("node") == original_vein, "camera ray selects the original mine vein")
	_expect(original_proxy != null and is_instance_valid(original_proxy) and original_proxy.is_inside_tree(), "original vein has a live interaction proxy")
	if original_proxy == null or not is_instance_valid(original_proxy):
		await _finish(1)
		return
	var original_instance: int = original_vein.get_instance_id()
	var original_proxy_instance: int = original_proxy.get_instance_id()
	var before_mining: int = int(original_vein.get("remaining_units"))
	var first_mining: Dictionary = world.call("_interact_nearest_world_prop")
	_expect(bool(first_mining.get("ok", false)) and int(first_mining.get("amount", 0)) == 1, "F mines one unit from the camera-selected production vein")
	var after_mining: int = int(original_vein.get("remaining_units"))
	_expect(after_mining == before_mining - 1, "first mining action reduces the live vein stock by exactly one")

	var now: int = int(Time.get_unix_time_from_system())
	var far_position := Vector3(31.5, -8.25, 7.5)
	world.player.global_position = far_position
	_expect(bool(world.mine_director.call("sync_to_world_position", far_position, now)), "mine director moves the active underground window away from the origin")
	_expect(not bool(world.chunk_controller.call("is_chunk_loaded", MINE_CHUNK_ID)), "origin mine chunk unloads outside the active window")
	var saved_payload: Dictionary = registry.call("to_save_dict")
	var saved_veins: Dictionary = saved_payload.get("veins", {})
	var saved_record: Dictionary = saved_veins.get(stable_id, {})
	_expect(not saved_record.is_empty(), "unloaded vein remains in the persistent mineral registry")
	_expect(int(saved_record.get("remaining_units", -1)) == after_mining, "unload captures the exact post-mining stock")
	_expect(not registry.call("get_registered_ids").has(stable_id), "unloaded vein is no longer registered as a live node")
	_expect(registry.call("get_saved_ids").has(stable_id), "stable vein ID remains in the saved-ID set")
	var stale_target: Dictionary = world.call("get_camera_interaction_target")
	_expect(stale_target.is_empty(), "camera target cache rejects the unloaded vein and its stale proxy")
	await process_frame
	_expect(not is_instance_valid(original_vein) and not is_instance_valid(original_proxy), "old vein node and interaction proxy are freed after unload")

	var return_position := Vector3(1.5, -8.25, 7.5)
	_expect(bool(world.mine_director.call("sync_to_world_position", return_position, now)), "mine director reloads the origin underground window")
	world.player.global_position = return_position
	var restored_root: Node3D = world.chunk_controller.call("get_chunk_root", MINE_CHUNK_ID) as Node3D
	var restored_vein: Node3D = _find_vein(MINE_CHUNK_ID, "Vein_0")
	_expect(restored_root != null and restored_vein != null, "origin mine factory creates a replacement vein node")
	if restored_vein == null:
		await _finish(1)
		return
	_expect(restored_vein.get_instance_id() != original_instance, "reloaded vein is a new scene instance")
	_expect(int(restored_vein.get("remaining_units")) == after_mining, "replacement vein restores the saved remaining stock")
	var restored_proxy: Area3D = restored_vein.get_node_or_null("InteractionArea") as Area3D
	_expect(restored_proxy != null and is_instance_valid(restored_proxy) and restored_proxy.is_inside_tree(), "replacement vein recreates an in-tree interaction proxy")
	if restored_proxy != null and is_instance_valid(restored_proxy):
		_expect(restored_proxy.get_instance_id() != original_proxy_instance, "reloaded vein registers a fresh proxy instance")
		_expect((restored_proxy.collision_layer & (1 << 1)) != 0, "fresh proxy remains on the interaction collision layer")

	await _aim_at(restored_vein, Vector3(0.0, 1.0, -2.0), Vector3(0.0, 0.55, 0.0))
	var restored_target: Dictionary = world.call("get_camera_interaction_target")
	_expect(str(restored_target.get("kind", "")) == "vein" and restored_target.get("node") == restored_vein, "camera ray selects the reloaded vein through its fresh proxy")
	_expect(restored_target.get("proxy") == restored_proxy, "target cache references the replacement proxy, not the stale one")
	var second_mining: Dictionary = world.call("_interact_nearest_world_prop")
	_expect(bool(second_mining.get("ok", false)) and int(second_mining.get("remaining", -1)) == after_mining - 1, "F mining works again after chunk unload and reload")

	await _finish(0 if failures.is_empty() else 1)

func _find_vein(chunk_id: String, node_name: String) -> Node3D:
	var nodes: Array = world.chunk_controller.call("get_loaded_mineral_nodes")
	var chunk_root: Node = world.chunk_controller.call("get_chunk_root", chunk_id)
	for candidate in nodes:
		if not is_instance_valid(candidate) or candidate.name != node_name:
			continue
		var ancestor: Node = candidate.get_parent()
		while ancestor != null and ancestor != world.chunk_controller:
			if ancestor == chunk_root:
				return candidate as Node3D
			ancestor = ancestor.get_parent()
	return null

func _aim_at(target: Node3D, player_offset: Vector3 = Vector3(0.0, 1.0, 2.0), target_offset: Vector3 = Vector3(0.0, 0.55, 0.0)) -> void:
	world.player.global_position = target.global_position + player_offset
	world.camera.look_at(target.global_position + target_offset, Vector3.UP)
	await physics_frame
	await physics_frame

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
		print("Production SurfaceWorld mineral-vein chunk reload tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

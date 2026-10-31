extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const MINE_CHUNK_ID: String = "underground/mine_0_0"
const INTERACTION_LAYER: int = 1 << 1

var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld instantiates for underground cache/lift reload coverage")
	if world == null:
		quit(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame

	var surface_lift: Node3D = world.get_node_or_null("KrollMineShaftEntrance") as Node3D
	_expect(surface_lift != null, "surface world exposes the production mine shaft")
	if surface_lift == null:
		await _finish(1)
		return
	await _aim_at(surface_lift, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
	_expect(bool(world.call("_toggle_mine_access")), "camera-selected shaft enters the production underground mine")
	_expect(bool(world.get("_is_underground")), "world enters underground mode")

	var original_root: Node3D = world.chunk_controller.call("get_chunk_root", MINE_CHUNK_ID) as Node3D
	var original_cache: Node3D = _find_stateful_node(MINE_CHUNK_ID, "MineCache_Gold")
	var original_lift: Node3D = _find_stateful_node(MINE_CHUNK_ID, "MineLiftAnchor")
	_expect(original_root != null and original_cache != null, "origin mine chunk exposes its real gold salvage cache")
	_expect(original_lift != null, "origin mine chunk exposes its stateful lift anchor")
	if original_root == null or original_cache == null or original_lift == null:
		await _finish(1)
		return

	var cache_stable_id: String = _stable_id(original_root, original_cache)
	var lift_stable_id: String = _stable_id(original_root, original_lift)
	_expect(cache_stable_id == "underground/mine_0_0/object/UndergroundMine_0_0/MineCache_Gold", "cache uses its deterministic chunk/local-path stable ID")
	_expect(lift_stable_id == "underground/mine_0_0/object/UndergroundMine_0_0/MineLiftAnchor", "lift uses its deterministic chunk/local-path stable ID")
	var object_registry: Node = world.get("object_state_registry") as Node
	_expect(object_registry != null, "production world binds the world-object state registry")
	if object_registry == null:
		await _finish(1)
		return

	var original_cache_proxy: Area3D = original_cache.get_node_or_null("InteractionArea") as Area3D
	var original_lift_proxy: Area3D = original_lift.get_node_or_null("InteractionArea") as Area3D
	_expect(_valid_proxy(original_cache_proxy), "original cache has an in-tree interaction proxy")
	_expect(_valid_proxy(original_lift_proxy), "original lift has an in-tree interaction proxy")
	if not _valid_proxy(original_cache_proxy) or not _valid_proxy(original_lift_proxy):
		await _finish(1)
		return

	var original_cache_instance: int = original_cache.get_instance_id()
	var original_cache_proxy_instance: int = original_cache_proxy.get_instance_id()
	var original_lift_instance: int = original_lift.get_instance_id()
	var original_lift_proxy_instance: int = original_lift_proxy.get_instance_id()
	_expect(int(original_cache.get("loot_remaining")) == 2, "gold cache starts with two recoverable units")

	await _aim_at(original_cache, Vector3(0.0, 1.0, -2.0), Vector3(0.0, 0.6, 0.0))
	var cache_target: Dictionary = world.call("get_camera_interaction_target")
	_expect(str(cache_target.get("kind", "")) == "prop" and cache_target.get("node") == original_cache, "camera ray selects the underground cache as a prop")
	_expect(cache_target.get("proxy") == original_cache_proxy, "cache target stores its exact interaction proxy")
	var first_collect: Dictionary = world.call("_interact_nearest_world_prop")
	_expect(bool(first_collect.get("ok", false)) and int(first_collect.get("remaining", -1)) == 1, "F interaction collects one gold unit before streaming")

	await _aim_at(original_lift, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
	var lift_target: Dictionary = world.call("get_camera_interaction_target")
	_expect(str(lift_target.get("kind", "")) == "lift" and lift_target.get("node") == original_lift, "stateful lift is resolved as a lift, not a generic prop")
	_expect(lift_target.get("proxy") == original_lift_proxy, "lift target stores its exact interaction proxy")
	_expect(bool(world.call("_descend_mine_layer")), "V interaction descends through the camera-selected lift")

	var saved_cache: Dictionary = object_registry.call("get_object_state", cache_stable_id)
	var saved_lift: Dictionary = object_registry.call("get_object_state", lift_stable_id)
	_expect(bool(saved_cache.get("state", {}).get("opened", false)) and int(saved_cache.get("state", {}).get("loot_remaining", -1)) == 1, "layer transition persists the opened cache and remaining stock")
	_expect(int(saved_lift.get("state", {}).get("layer_index", -1)) == 0, "layer transition persists the lift's authored layer identity")
	await process_frame
	_expect(not is_instance_valid(original_root) and not is_instance_valid(original_cache) and not is_instance_valid(original_cache_proxy), "old origin chunk, cache and proxy are freed after descent")
	_expect(not is_instance_valid(original_lift) and not is_instance_valid(original_lift_proxy), "old lift anchor and proxy are freed after descent")

	var layer_one_id: String = "underground/layer_1/mine_0_0"
	var layer_one_root: Node3D = world.chunk_controller.call("get_chunk_root", layer_one_id) as Node3D
	var layer_one_lift: Node3D = _find_stateful_node(layer_one_id, "MineLiftAnchor")
	_expect(layer_one_root != null and layer_one_lift != null, "layer one creates a new stateful lift anchor")
	if layer_one_lift == null:
		await _finish(1)
		return
	var layer_one_proxy: Area3D = layer_one_lift.get_node_or_null("InteractionArea") as Area3D
	_expect(_valid_proxy(layer_one_proxy), "layer-one lift registers a fresh interaction proxy")
	_expect(int(layer_one_lift.get("layer_index")) == 1, "layer-one lift carries its own authored layer index")
	await _aim_at(layer_one_lift, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
	var layer_one_target: Dictionary = world.call("get_camera_interaction_target")
	_expect(str(layer_one_target.get("kind", "")) == "lift" and layer_one_target.get("node") == layer_one_lift, "camera ray selects the newly streamed layer-one lift")
	_expect(bool(world.call("_toggle_mine_access")), "G interaction ascends from layer one to layer zero")

	var restored_root: Node3D = world.chunk_controller.call("get_chunk_root", MINE_CHUNK_ID) as Node3D
	var restored_cache: Node3D = _find_stateful_node(MINE_CHUNK_ID, "MineCache_Gold")
	var restored_lift: Node3D = _find_stateful_node(MINE_CHUNK_ID, "MineLiftAnchor")
	_expect(restored_root != null and restored_cache != null and restored_lift != null, "ascending recreates the origin cache and lift")
	if restored_cache == null or restored_lift == null:
		await _finish(1)
		return
	_expect(restored_cache.get_instance_id() != original_cache_instance, "reloaded cache is a new node instance")
	_expect(restored_lift.get_instance_id() != original_lift_instance, "reloaded lift is a new node instance")
	_expect(_stable_id(restored_root, restored_cache) == cache_stable_id, "reloaded cache retains the same stable ID")
	_expect(_stable_id(restored_root, restored_lift) == lift_stable_id, "reloaded lift retains the same stable ID")
	_expect(bool(restored_cache.get("opened")) and int(restored_cache.get("loot_remaining")) == 1, "reloaded cache restores its opened state and exact remaining stock")
	_expect(int(restored_lift.get("layer_index")) == 0, "reloaded lift restores the layer-zero identity")

	var restored_cache_proxy: Area3D = restored_cache.get_node_or_null("InteractionArea") as Area3D
	var restored_lift_proxy: Area3D = restored_lift.get_node_or_null("InteractionArea") as Area3D
	_expect(_valid_proxy(restored_cache_proxy) and _valid_proxy(restored_lift_proxy), "reloaded cache and lift both recreate in-tree proxies")
	if _valid_proxy(restored_cache_proxy):
		_expect(restored_cache_proxy.get_instance_id() != original_cache_proxy_instance, "reloaded cache receives a fresh proxy instance")
		_expect((restored_cache_proxy.collision_layer & INTERACTION_LAYER) != 0, "reloaded cache proxy remains on the interaction layer")
	if _valid_proxy(restored_lift_proxy):
		_expect(restored_lift_proxy.get_instance_id() != original_lift_proxy_instance, "reloaded lift receives a fresh proxy instance")
		_expect((restored_lift_proxy.collision_layer & INTERACTION_LAYER) != 0, "reloaded lift proxy remains on the interaction layer")

	await _aim_at(restored_cache, Vector3(0.0, 1.0, -2.0), Vector3(0.0, 0.6, 0.0))
	var restored_cache_target: Dictionary = world.call("get_camera_interaction_target")
	_expect(str(restored_cache_target.get("kind", "")) == "prop" and restored_cache_target.get("node") == restored_cache, "camera ray selects the reloaded cache")
	_expect(restored_cache_target.get("proxy") == restored_cache_proxy, "reloaded cache target references only the new proxy")
	var second_collect: Dictionary = world.call("_interact_nearest_world_prop")
	_expect(bool(second_collect.get("ok", false)) and int(second_collect.get("remaining", -1)) == 0, "F interaction collects the final unit after cache reload")

	await _aim_at(restored_lift, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
	var restored_lift_target: Dictionary = world.call("get_camera_interaction_target")
	_expect(str(restored_lift_target.get("kind", "")) == "lift" and restored_lift_target.get("node") == restored_lift, "camera ray selects the reloaded lift")
	_expect(bool(world.call("_toggle_mine_access")), "G interaction returns from the reloaded lift to the surface")
	_expect(not bool(world.get("_is_underground")), "surface return clears underground mode")

	await _finish(0 if failures.is_empty() else 1)

func _find_stateful_node(chunk_id: String, node_name: String) -> Node3D:
	var nodes: Array = world.chunk_controller.call("get_loaded_world_state_nodes")
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

func _stable_id(chunk_root: Node3D, node: Node3D) -> String:
	var local_path: String = "%s/%s" % [str(chunk_root.name), str(node.name)]
	return str(world.chunk_controller.call("_make_world_object_stable_id", MINE_CHUNK_ID, local_path))

func _valid_proxy(proxy: Area3D) -> bool:
	return proxy != null and is_instance_valid(proxy) and proxy.is_inside_tree() and (proxy.collision_layer & INTERACTION_LAYER) != 0

func _aim_at(target: Node3D, player_offset: Vector3, target_offset: Vector3) -> void:
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
		print("Production SurfaceWorld underground cache/lift reload tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

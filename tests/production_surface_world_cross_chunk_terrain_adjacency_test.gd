extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const SURFACE_PREFIX: String = "surface/"
const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")

var failures: Array[String] = []
var world: Node3D
var _test_time: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_time = int(Time.get_unix_time_from_system()) + 20
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld instantiates for cross-chunk terrain adjacency")
	if world == null:
		quit(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame

	var controller: Node = world.get("chunk_controller") as Node
	var registry: Node = world.get("object_state_registry") as Node
	_expect(controller != null and registry != null, "world exposes the chunk controller and object-state registry")
	if controller == null or registry == null:
		await _finish(1)
		return

	_expect(_surface_chunk_count(controller) == 9, "initial world window contains nine surface chunks")
	_expect(_terrain_patch_count(controller) == 63, "initial world window contains seven terrain patches in every surface chunk")
	_expect(_count_cross_chunk_pairs(controller) == 12, "all six east-west and six north-south chunk seams are bound")

	var pair: Dictionary = _find_first_east_pair(controller)
	_expect(not pair.is_empty(), "at least one real east-west cross-chunk pair is available")
	if pair.is_empty():
		await _finish(1)
		return
	var first_chunk: String = str(pair["first_chunk"])
	var second_chunk: String = str(pair["second_chunk"])
	var first: Node3D = pair["first"] as Node3D
	var second: Node3D = pair["second"] as Node3D
	_expect((second.global_position - first.global_position).distance_to(Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)) <= 0.01, "east/west boundary patches are exactly one patch apart across chunk origins")
	_expect(str(first.call("get_edge_policy", "east").get("mode", "")) == "flush_join", "equal-height cross-chunk edge begins as a flush join")
	_expect(not _ramp_enabled(first, "East") and not _ramp_enabled(second, "West"), "both ramps are disabled at the shared chunk boundary")

	var first_state: Dictionary = first.call("get_world_object_state")
	first_state["height_level"] = 2
	first_state["surface_type"] = "metal"
	first_state["revision"] = int(first_state.get("revision", 0)) + 1
	_expect(bool(first.call("apply_world_object_state", first_state)), "left chunk accepts a higher persisted terrain edit")
	var second_state: Dictionary = second.call("get_world_object_state")
	second_state["height_level"] = 0
	second_state["surface_type"] = "soil"
	second_state["revision"] = int(second_state.get("revision", 0)) + 1
	_expect(bool(second.call("apply_world_object_state", second_state)), "right chunk accepts an independent lower terrain edit")
	_expect(str(first.call("get_edge_policy", "east").get("mode", "")) == "local_higher", "higher left patch publishes its live cross-chunk edge state")
	_expect(str(second.call("get_edge_policy", "west").get("mode", "")) == "neighbor_higher", "lower right patch receives the reciprocal higher-neighbor state")
	_expect(not _ramp_enabled(first, "East") and not _ramp_enabled(second, "West"), "unequal-height cross-chunk edge remains a deliberate step without overlapping ramps")

	var first_root: Node3D = controller.call("get_chunk_root", first_chunk) as Node3D
	var second_root: Node3D = controller.call("get_chunk_root", second_chunk) as Node3D
	var first_id: String = _stable_id(controller, first_chunk, first_root, first)
	var second_id: String = _stable_id(controller, second_chunk, second_root, second)
	var first_instance: int = first.get_instance_id()
	var second_instance: int = second.get_instance_id()
	var first_proxy: Area3D = first.get_node_or_null("InteractionArea") as Area3D
	var second_proxy: Area3D = second.get_node_or_null("InteractionArea") as Area3D
	_expect(first_proxy != null and second_proxy != null, "both cross-chunk patches expose live interaction proxies")
	if first_proxy == null or second_proxy == null:
		await _finish(1)
		return
	var first_proxy_instance: int = first_proxy.get_instance_id()
	var second_proxy_instance: int = second_proxy.get_instance_id()
	var first_proxy_weak: WeakRef = weakref(first_proxy)
	var second_proxy_weak: WeakRef = weakref(second_proxy)
	var first_weak: WeakRef = weakref(first)
	var second_weak: WeakRef = weakref(second)
	var saved_first_state: Dictionary = first.call("get_world_object_state")
	var saved_second_state: Dictionary = second.call("get_world_object_state")
	var payload: Dictionary = world.call("serialize_stream_state")
	_expect(not payload.is_empty(), "world save captures both edited cross-chunk patch states")
	var saved_objects: Dictionary = payload.get("world_objects", {}).get("objects", {})
	_expect(saved_objects.has(first_id) and saved_objects.has(second_id), "schema-1 save contains both cross-chunk stable IDs")
	if saved_objects.has(first_id) and saved_objects.has(second_id):
		_expect(saved_objects[first_id].get("state", {}) == saved_first_state, "save contains the exact left boundary patch state")
		_expect(saved_objects[second_id].get("state", {}) == saved_second_state, "save contains the exact right boundary patch state")

	_expect(bool(world.call("debug_move_player_to", Vector3(41.5, 2.0, 41.5), _test_time)), "moving away unloads the original surface window")
	await process_frame
	await process_frame
	_expect(not bool(controller.call("is_chunk_loaded", first_chunk)) and not bool(controller.call("is_chunk_loaded", second_chunk)), "both original chunks unload together")
	_expect(first_weak.get_ref() == null and second_weak.get_ref() == null, "both old terrain nodes are released")
	_expect(first_proxy_weak.get_ref() == null and second_proxy_weak.get_ref() == null, "both old interaction proxies are released")
	_expect(registry.call("get_object_state", first_id).get("state", {}) == saved_first_state, "left boundary state survives chunk unload")
	_expect(registry.call("get_object_state", second_id).get("state", {}) == saved_second_state, "right boundary state survives chunk unload")

	_expect(bool(world.call("debug_move_player_to", Vector3(8.0, 2.0, 5.5), _test_time + 1)), "returning reloads the original 3x3 surface window")
	await process_frame
	await physics_frame
	var fresh_first: Node3D = _find_patch(controller, first_chunk, "TerrainPatch_CrossEast")
	var fresh_second: Node3D = _find_patch(controller, second_chunk, "TerrainPatch_CrossWest")
	_expect(fresh_first != null and fresh_second != null, "both cross-chunk boundary patches are recreated")
	if fresh_first != null and fresh_second != null:
		_expect(fresh_first.get_instance_id() != first_instance and fresh_second.get_instance_id() != second_instance, "reloaded boundary patches are fresh node instances")
		_expect(_stable_id(controller, first_chunk, controller.call("get_chunk_root", first_chunk), fresh_first) == first_id, "left patch retains its stable ID")
		_expect(_stable_id(controller, second_chunk, controller.call("get_chunk_root", second_chunk), fresh_second) == second_id, "right patch retains its stable ID")
		_expect(fresh_first.call("get_world_object_state") == saved_first_state, "left patch restores its height, material and revision")
		_expect(fresh_second.call("get_world_object_state") == saved_second_state, "right patch restores its height, material and revision")
		var fresh_first_proxy: Area3D = fresh_first.get_node_or_null("InteractionArea") as Area3D
		var fresh_second_proxy: Area3D = fresh_second.get_node_or_null("InteractionArea") as Area3D
		_expect(fresh_first_proxy != null and fresh_second_proxy != null, "reloaded patches rebuild both interaction proxies")
		_expect(fresh_first_proxy.get_instance_id() != first_proxy_instance and fresh_second_proxy.get_instance_id() != second_proxy_instance, "reloaded interaction proxies are fresh instances")
		_expect(str(fresh_first.call("get_edge_policy", "east").get("mode", "")) == "local_higher", "left cross-chunk edge policy is rebuilt after reload")
		_expect(str(fresh_second.call("get_edge_policy", "west").get("mode", "")) == "neighbor_higher", "right cross-chunk edge policy is rebuilt reciprocally")
	_expect(_count_cross_chunk_pairs(controller) == 12, "all twelve cross-chunk seams are rebuilt after reload")

	_expect(bool(world.call("restore_stream_state", payload, _test_time + 2)), "schema-1 world restore accepts the cross-chunk terrain snapshot")
	var restored_first: Node3D = _find_patch(controller, first_chunk, "TerrainPatch_CrossEast")
	var restored_second: Node3D = _find_patch(controller, second_chunk, "TerrainPatch_CrossWest")
	_expect(restored_first != null and restored_second != null, "schema-1 restore recreates both boundary patches")
	if restored_first != null and restored_second != null:
		_expect(restored_first.call("get_world_object_state") == saved_first_state, "schema-1 restore preserves the left boundary state")
		_expect(restored_second.call("get_world_object_state") == saved_second_state, "schema-1 restore preserves the right boundary state")
		_expect(str(restored_first.call("get_edge_policy", "east").get("mode", "")) == "local_higher", "schema-1 restore rebinds the higher left edge")
		_expect(str(restored_second.call("get_edge_policy", "west").get("mode", "")) == "neighbor_higher", "schema-1 restore rebinds the lower right edge")
	_expect(_count_cross_chunk_pairs(controller) == 12, "schema-1 restore reconstructs all twelve derived cross-chunk seams")
	await _finish(0)

func _surface_chunk_count(controller: Node) -> int:
	var count: int = 0
	for chunk_value in controller.call("get_loaded_chunk_ids"):
		if str(chunk_value).begins_with(SURFACE_PREFIX):
			count += 1
	return count

func _terrain_patch_count(controller: Node) -> int:
	var count: int = 0
	for patch in controller.call("get_loaded_world_state_nodes"):
		if is_instance_valid(patch) and str(patch.name).begins_with("TerrainPatch"):
			count += 1
	return count

func _count_cross_chunk_pairs(controller: Node) -> int:
	var loaded: Dictionary = {}
	var surface_ids: Array[String] = []
	for chunk_value in controller.call("get_loaded_chunk_ids"):
		var chunk_id: String = str(chunk_value)
		loaded[chunk_id] = true
		if chunk_id.begins_with(SURFACE_PREFIX):
			surface_ids.append(chunk_id)
	var count: int = 0
	for chunk_id in surface_ids:
		if loaded.has(_offset_surface_chunk(chunk_id, 1, 0)):
			count += 1
		if loaded.has(_offset_surface_chunk(chunk_id, 0, 1)):
			count += 1
	return count

func _find_first_east_pair(controller: Node) -> Dictionary:
	var loaded: Dictionary = {}
	for chunk_value in controller.call("get_loaded_chunk_ids"):
		loaded[str(chunk_value)] = true
	for chunk_value in loaded.keys():
		var chunk_id: String = str(chunk_value)
		if not chunk_id.begins_with(SURFACE_PREFIX):
			continue
		var east_id: String = _offset_surface_chunk(chunk_id, 1, 0)
		if not loaded.has(east_id):
			continue
		var first: Node3D = _find_patch(controller, chunk_id, "TerrainPatch_CrossEast")
		var second: Node3D = _find_patch(controller, east_id, "TerrainPatch_CrossWest")
		if first != null and second != null:
			return {"first_chunk": chunk_id, "second_chunk": east_id, "first": first, "second": second}
	return {}

func _offset_surface_chunk(chunk_id: String, dx: int, dy: int) -> String:
	var coordinate_text: String = chunk_id.trim_prefix(SURFACE_PREFIX).trim_prefix("chunk_")
	var parts: PackedStringArray = coordinate_text.split("_")
	if parts.size() != 2:
		return ""
	return SURFACE_PREFIX + "chunk_%d_%d" % [int(parts[0]) + dx, int(parts[1]) + dy]

func _find_patch(controller: Node, chunk_id: String, node_name: String) -> Node3D:
	var chunk_root: Node3D = controller.call("get_chunk_root", chunk_id) as Node3D
	return chunk_root.get_node_or_null(node_name) as Node3D if chunk_root != null else null

func _stable_id(controller: Node, chunk_id: String, chunk_root: Node3D, patch: Node3D) -> String:
	if chunk_root == null or patch == null:
		return ""
	return str(controller.call("_make_world_object_stable_id", chunk_id, "%s/%s" % [chunk_root.name, patch.name]))

func _ramp_enabled(patch: Node3D, side: String) -> bool:
	var body := patch.get_node_or_null("TerrainRampBody_" + side) as StaticBody3D
	if body == null:
		return false
	var collision := body.get_node_or_null("TerrainRampCollision_" + side) as CollisionShape3D
	return body.collision_layer == 1 and collision != null and not collision.disabled

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func _finish(exit_code: int) -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty() and exit_code == 0:
		print("Production SurfaceWorld cross-chunk terrain adjacency tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

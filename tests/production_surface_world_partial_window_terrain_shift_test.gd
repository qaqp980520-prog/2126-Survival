extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const SURFACE_PREFIX: String = "surface/"
const CHUNK_SIZE: float = 10.0

var world: Node3D
var failures: Array[String] = []
var _test_time: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_time = int(Time.get_unix_time_from_system()) + 40
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld instantiates for partial-window terrain shifts")
	if world == null:
		quit(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	var controller: Node = world.get("chunk_controller") as Node
	var registry: Node = world.get("object_state_registry") as Node
	_expect(controller != null and registry != null, "world exposes the production chunk controller and state registry")
	if controller == null or registry == null:
		await _finish(1)
		return
	_expect_window(controller, Vector2i.ZERO, "initial")
	var edited_chunk_id: String = _chunk_id(Vector2i(-1, 0))
	var edited_root: Node3D = controller.call("get_chunk_root", edited_chunk_id) as Node3D
	var edited_patch: Node3D = _find_patch(controller, edited_chunk_id, "TerrainPatch_CrossEast")
	_expect(edited_root != null and edited_patch != null, "west-edge source patch exists before the first shift")
	if edited_root == null or edited_patch == null:
		await _finish(1)
		return
	var edited_proxy: Area3D = edited_patch.get_node_or_null("InteractionArea") as Area3D
	_expect(edited_proxy != null, "edited source patch exposes an interaction proxy")
	if edited_proxy == null:
		await _finish(1)
		return
	var stable_id: String = _stable_id(controller, edited_chunk_id, edited_root, edited_patch)
	var edited_state: Dictionary = edited_patch.call("get_world_object_state")
	edited_state["height_level"] = 2
	edited_state["surface_type"] = "metal"
	edited_state["revision"] = int(edited_state.get("revision", 0)) + 1
	_expect(bool(edited_patch.call("apply_world_object_state", edited_state)), "west-edge patch accepts a persistent height/material edit")
	var retained_neighbor: Node3D = _find_patch(controller, _chunk_id(Vector2i(0, 0)), "TerrainPatch_CrossWest")
	_expect(retained_neighbor != null, "reciprocal patch in the overlapping center chunk exists")
	if retained_neighbor != null:
		_expect(str(retained_neighbor.call("get_edge_policy", "west").get("mode", "")) == "neighbor_higher", "overlap neighbor sees the edited west patch as higher")
	var old_root_instance: int = edited_root.get_instance_id()
	var old_patch_instance: int = edited_patch.get_instance_id()
	var old_proxy_instance: int = edited_proxy.get_instance_id()
	var old_root_weak: WeakRef = weakref(edited_root)
	var old_patch_weak: WeakRef = weakref(edited_patch)
	var old_proxy_weak: WeakRef = weakref(edited_proxy)
	var retained_root: Node3D = controller.call("get_chunk_root", _chunk_id(Vector2i(0, 0))) as Node3D
	if retained_root == null:
		await _finish(1)
		return
	var retained_root_instance: int = retained_root.get_instance_id()
	var underground_before: Dictionary = _underground_ids(controller)
	_expect(underground_before.size() == 9, "initial SurfaceWorld keeps its independent nine-chunk underground window")
	var retained_patch_instance: int = retained_neighbor.get_instance_id() if retained_neighbor != null else 0
	var centers: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0)]
	for step_index in range(centers.size()):
		var center: Vector2i = centers[step_index]
		var previous: Dictionary = _snapshot_roots(controller)
		var previous_ids: Dictionary = {}
		for id in previous.keys():
			previous_ids[str(id)] = true
		var target_ids: Dictionary = _expected_ids(center)
		var entered: int = 0
		var leaving: int = 0
		for id in target_ids.keys():
			if not previous_ids.has(str(id)):
				entered += 1
		for id in previous_ids.keys():
			if not target_ids.has(str(id)):
				leaving += 1
		_expect(entered == 3 and leaving == 3, "one-cell shift %d has exactly three entering and three leaving chunks" % (step_index + 1))
		var target_position := Vector3(float(center.x) * CHUNK_SIZE + 1.5, 2.0, float(center.y) * CHUNK_SIZE + 1.5)
		var moved: bool = bool(world.call("debug_move_player_to", target_position, _test_time + step_index + 1))
		_expect(moved, "production director accepts one-cell window shift %d" % (step_index + 1))
		await process_frame
		await process_frame
		await physics_frame
		_expect_window(controller, center, "shift %d" % (step_index + 1))
		_expect(_same_ids(underground_before, _underground_ids(controller)), "surface shift %d leaves all underground chunk IDs unchanged" % (step_index + 1))
		for id in previous.keys():
			var entry: Dictionary = previous[id]
			if target_ids.has(str(id)):
				var live_root: Node3D = controller.call("get_chunk_root", str(id)) as Node3D
				_expect(live_root != null and live_root.get_instance_id() == int(entry["instance"]), "overlapping chunk %s retains its live root" % str(id))
			else:
				var old_ref: WeakRef = entry["weak"] as WeakRef
				_expect(old_ref.get_ref() == null, "leaving chunk %s releases its old root" % str(id))
		if step_index == 0:
			_expect(old_root_weak.get_ref() == null and old_patch_weak.get_ref() == null and old_proxy_weak.get_ref() == null, "first eastward shift releases the edited chunk, terrain patch and proxy")
			var saved_record: Dictionary = registry.call("get_object_state", stable_id)
			_expect(saved_record.get("state", {}) == edited_state, "edited patch state remains in the registry while its chunk is outside the window")
			var cleared_neighbor: Node3D = _find_patch(controller, _chunk_id(Vector2i(0, 0)), "TerrainPatch_CrossWest")
			if cleared_neighbor != null:
				_expect(str(cleared_neighbor.call("get_edge_policy", "west").get("mode", "")) == "ground_ramp", "remaining west edge restores its isolated ground ramp after neighbor unload")
				_expect(_ramp_enabled(cleared_neighbor, "West"), "remaining patch re-enables its west ramp after seam removal")
			var retained_cross_east: Node3D = _find_patch(controller, _chunk_id(Vector2i(1, 0)), "TerrainPatch_CrossEast")
			var entering_cross_west: Node3D = _find_patch(controller, _chunk_id(Vector2i(2, 0)), "TerrainPatch_CrossWest")
			_expect(retained_cross_east != null and entering_cross_west != null, "new eastern seam has both boundary patches")
			if retained_cross_east != null and entering_cross_west != null:
				_expect(str(retained_cross_east.call("get_edge_policy", "east").get("mode", "")) == "flush_join", "new seam binds the retained east patch")
				_expect(str(entering_cross_west.call("get_edge_policy", "west").get("mode", "")) == "flush_join", "new seam binds the entering west patch")
				_expect(not _ramp_enabled(retained_cross_east, "East") and not _ramp_enabled(entering_cross_west, "West"), "both ramps are suppressed on the newly formed seam")
		if step_index == 2:
			var restored_root: Node3D = controller.call("get_chunk_root", edited_chunk_id) as Node3D
			var restored_patch: Node3D = _find_patch(controller, edited_chunk_id, "TerrainPatch_CrossEast")
			_expect(restored_root != null and restored_patch != null, "westward shift re-enters the edited source chunk")
			if restored_root != null and restored_patch != null:
				_expect(restored_root.get_instance_id() != old_root_instance and restored_patch.get_instance_id() != old_patch_instance, "re-entered chunk and terrain patch are fresh instances")
				_expect(_stable_id(controller, edited_chunk_id, restored_root, restored_patch) == stable_id, "re-entered terrain patch retains its stable ID")
				_expect(restored_patch.call("get_world_object_state") == edited_state, "re-entered terrain patch restores the exact edited state")
				var restored_proxy: Area3D = restored_patch.get_node_or_null("InteractionArea") as Area3D
				_expect(restored_proxy != null and restored_proxy.get_instance_id() != old_proxy_instance, "re-entered terrain patch registers a fresh interaction proxy")
				var reciprocal: Node3D = _find_patch(controller, _chunk_id(Vector2i(0, 0)), "TerrainPatch_CrossWest")
				_expect(reciprocal != null and str(reciprocal.call("get_edge_policy", "west").get("mode", "")) == "neighbor_higher", "re-entered patch rebuilds its reciprocal unequal-height seam")
	var final_patch: Node3D = _find_patch(controller, edited_chunk_id, "TerrainPatch_CrossEast")
	_expect(final_patch != null and final_patch.call("get_world_object_state") == edited_state, "final northward shift preserves the restored terrain state")
	var final_retained_root: Node3D = controller.call("get_chunk_root", _chunk_id(Vector2i(0, 0))) as Node3D
	var final_retained_patch: Node3D = _find_patch(controller, _chunk_id(Vector2i(0, 0)), "TerrainPatch_CrossWest")
	_expect(final_retained_root != null and final_retained_root.get_instance_id() == retained_root_instance, "center chunk root remains the same instance through all four shifts")
	_expect(final_retained_patch != null and final_retained_patch.get_instance_id() == retained_patch_instance, "overlapping center terrain patch remains the same instance")
	_expect(controller.call("get_loaded_chunk_ids").size() == 18, "surface and underground windows each retain nine loaded chunks")
	await _finish(0)

func _expect_window(controller: Node, center: Vector2i, label: String) -> void:
	var expected: Dictionary = _expected_ids(center)
	var loaded_surface: Dictionary = {}
	for raw_id in controller.call("get_loaded_chunk_ids"):
		var id: String = str(raw_id)
		if id.begins_with(SURFACE_PREFIX):
			loaded_surface[id] = true
	_expect(loaded_surface.size() == 9, "%s window contains exactly nine surface chunks" % label)
	for id in expected.keys():
		_expect(loaded_surface.has(str(id)), "%s window contains expected chunk %s" % [label, str(id)])
	_expect(_terrain_patch_count(controller) == 63, "%s window contains all 63 terrain patches" % label)
	_expect(_count_cross_chunk_pairs(controller) == 12, "%s window rebuilds all 12 cross-chunk seams" % label)
	_expect(_underground_ids(controller).size() == 9, "%s window preserves the independent nine-chunk underground window" % label)

func _expected_ids(center: Vector2i) -> Dictionary:
	var ids: Dictionary = {}
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			ids[_chunk_id(Vector2i(x, y))] = true
	return ids

func _snapshot_roots(controller: Node) -> Dictionary:
	var snapshot: Dictionary = {}
	for raw_id in controller.call("get_loaded_chunk_ids"):
		var id: String = str(raw_id)
		if not id.begins_with(SURFACE_PREFIX):
			continue
		var chunk_root: Node3D = controller.call("get_chunk_root", id) as Node3D
		if chunk_root != null:
			snapshot[id] = {"instance":chunk_root.get_instance_id(),"weak":weakref(chunk_root)}
	return snapshot

func _underground_ids(controller: Node) -> Dictionary:
	var ids: Dictionary = {}
	for raw_id in controller.call("get_loaded_chunk_ids"):
		var id: String = str(raw_id)
		if id.begins_with("underground/"):
			ids[id] = true
	return ids

func _same_ids(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for id in left.keys():
		if not right.has(id):
			return false
	return true

func _terrain_patch_count(controller: Node) -> int:
	var count: int = 0
	for node in controller.call("get_loaded_world_state_nodes"):
		if is_instance_valid(node) and str(node.name).begins_with("TerrainPatch"):
			count += 1
	return count

func _count_cross_chunk_pairs(controller: Node) -> int:
	var loaded: Dictionary = {}
	for raw_id in controller.call("get_loaded_chunk_ids"):
		loaded[str(raw_id)] = true
	var count: int = 0
	for raw_id in loaded.keys():
		var id: String = str(raw_id)
		if not id.begins_with(SURFACE_PREFIX):
			continue
		if loaded.has(_offset_chunk(id, 1, 0)):
			count += 1
		if loaded.has(_offset_chunk(id, 0, 1)):
			count += 1
	return count

func _offset_chunk(id: String, dx: int, dy: int) -> String:
	var parts: PackedStringArray = id.trim_prefix(SURFACE_PREFIX).trim_prefix("chunk_").split("_")
	if parts.size() != 2:
		return ""
	return _chunk_id(Vector2i(int(parts[0]) + dx, int(parts[1]) + dy))

func _chunk_id(coord: Vector2i) -> String:
	return SURFACE_PREFIX + "chunk_%d_%d" % [coord.x, coord.y]

func _find_patch(controller: Node, chunk_id: String, node_name: String) -> Node3D:
	var chunk_root: Node3D = controller.call("get_chunk_root", chunk_id) as Node3D
	return chunk_root.get_node_or_null(node_name) as Node3D if chunk_root != null else null

func _stable_id(controller: Node, chunk_id: String, chunk_root: Node3D, patch: Node3D) -> String:
	return str(controller.call("_make_world_object_stable_id", chunk_id, "%s/%s" % [chunk_root.name, patch.name]))

func _ramp_enabled(patch: Node3D, side: String) -> bool:
	var body := patch.get_node_or_null("TerrainRampBody_" + side.capitalize()) as StaticBody3D
	if body == null:
		return false
	var collision := body.get_node_or_null("TerrainRampCollision_" + side.capitalize()) as CollisionShape3D
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
		print("Production SurfaceWorld partial-window terrain shift tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const SURFACE_PREFIX: String = "surface/"
const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
var _test_time: int = 0
var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_time = int(Time.get_unix_time_from_system()) + 20
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld instantiates for all-chunk terrain coverage")
	if world == null:
		quit(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame

	var controller: Node = world.get("chunk_controller") as Node
	var registry: Node = world.get("object_state_registry") as Node
	_expect(controller != null and registry != null, "world exposes chunk controller and object-state registry")
	if controller == null or registry == null:
		await _finish(1)
		return

	var entries: Array[Dictionary] = _collect_surface_patches(controller)
	_expect(entries.size() == 63, "initial 3x3 active surface window contains seven terrain patches per chunk")
	if entries.size() != 63:
		await _finish(1)
		return

	var unique_ids: Dictionary = {}
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var patch: Node3D = entry["patch"] as Node3D
		var stable_id: String = str(entry["stable_id"])
		_expect(not unique_ids.has(stable_id), "surface patch stable IDs are unique across the active window")
		unique_ids[stable_id] = true
		var proxy: Area3D = patch.get_node_or_null("InteractionArea") as Area3D
		_expect(proxy != null and proxy.is_inside_tree(), "surface patch %d has a live interaction proxy" % index)
		for edit_index in range((index % 3) + 1):
			var edit: Dictionary = patch.call("cycle_terrain_edit")
			_expect(bool(edit.get("ok", false)), "surface patch %d accepts deterministic edit %d" % [index, edit_index + 1])
		entry["state"] = patch.call("get_world_object_state")
		_expect_patch_geometry(patch, entry["state"], "edited patch %d" % index, entry.get("disabled_sides", []))
		entry["patch_instance"] = patch.get_instance_id()
		entry["proxy_instance"] = proxy.get_instance_id()
		entry["patch_weak"] = weakref(patch)
		entry["proxy_weak"] = weakref(proxy)
		entry.erase("patch")
		entries[index] = entry

	for chunk_id_value in controller.call("get_loaded_chunk_ids"):
		var chunk_id: String = str(chunk_id_value)
		if chunk_id.begins_with(SURFACE_PREFIX):
			_expect_adjacency_pair(controller, chunk_id, "edited %s" % chunk_id)
	_expect_cross_chunk_adjacency(controller, "edited")

	var save_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not save_payload.is_empty(), "world serialization captures all sixty-three terrain patch states")
	var saved_objects: Dictionary = save_payload.get("world_objects", {}).get("objects", {})
	for entry in entries:
		var stable_id: String = str(entry["stable_id"])
		_expect(saved_objects.has(stable_id), "schema-1 save includes terrain patch %s" % stable_id)
		if saved_objects.has(stable_id):
			_expect(saved_objects[stable_id].get("state", {}) == entry["state"], "save contains the exact per-chunk terrain state")

	var moved_away: bool = bool(world.call("debug_move_player_to", Vector3(41.5, 2.0, 41.5), _test_time))
	_expect(moved_away, "production director moves to a disjoint surface window")
	for entry in entries:
		_expect(not bool(controller.call("is_chunk_loaded", str(entry["chunk_id"]))), "original surface chunk unloads")
	await process_frame
	await process_frame
	for entry in entries:
		var old_patch_weak: WeakRef = entry["patch_weak"] as WeakRef
		var old_proxy_weak: WeakRef = entry["proxy_weak"] as WeakRef
		_expect(old_patch_weak.get_ref() == null, "unloaded terrain node is released")
		_expect(old_proxy_weak.get_ref() == null, "unloaded interaction proxy is released")
		var record: Dictionary = registry.call("get_object_state", str(entry["stable_id"]))
		_expect(record.get("state", {}) == entry["state"], "registry retains each edited state while its chunk is unloaded")

	var returned: bool = bool(world.call("debug_move_player_to", Vector3(8.0, 2.0, 5.5), _test_time + 1))
	_expect(returned, "production director reloads the original 3x3 surface window")
	await process_frame
	await physics_frame

	for entry in entries:
		var chunk_id: String = str(entry["chunk_id"])
		var stable_id: String = str(entry["stable_id"])
		_expect(bool(controller.call("is_chunk_loaded", chunk_id)), "original surface chunk is loaded again")
		var fresh_patch: Node3D = _find_patch(controller, chunk_id, str(entry["node_name"]))
		_expect(fresh_patch != null, "reloaded chunk recreates its terrain patch")
		if fresh_patch == null:
			continue
		_expect(fresh_patch.get_instance_id() != int(entry["patch_instance"]), "reloaded patch is a fresh node instance")
		_expect(str(controller.call("_make_world_object_stable_id", chunk_id, "%s/%s" % [fresh_patch.get_parent().name, fresh_patch.name])) == stable_id, "reloaded patch retains its deterministic stable ID")
		_expect(fresh_patch.call("get_world_object_state") == entry["state"], "reloaded patch restores its unique height/material/revision")
		_expect_patch_geometry(fresh_patch, entry["state"], "reloaded patch %s" % chunk_id, entry.get("disabled_sides", []))
		var fresh_proxy: Area3D = fresh_patch.get_node_or_null("InteractionArea") as Area3D
		_expect(fresh_proxy != null and fresh_proxy.is_inside_tree(), "reloaded patch rebuilds its interaction proxy")
		if fresh_proxy != null:
			_expect(fresh_proxy.get_instance_id() != int(entry["proxy_instance"]), "reloaded interaction proxy is a fresh instance")

	for chunk_id_value in controller.call("get_loaded_chunk_ids"):
		var chunk_id: String = str(chunk_id_value)
		if chunk_id.begins_with(SURFACE_PREFIX):
			_expect_adjacency_pair(controller, chunk_id, "reloaded %s" % chunk_id)
	_expect_cross_chunk_adjacency(controller, "reloaded")

	var roundtrip_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not roundtrip_payload.is_empty(), "reloaded sixty-three-patch window can be serialized again")
	_expect(bool(world.call("restore_stream_state", save_payload, _test_time + 2)), "schema-1 save restores all sixty-three surface terrain patches")
	for entry in entries:
		var restored_patch: Node3D = _find_patch(controller, str(entry["chunk_id"]), str(entry["node_name"]))
		_expect(restored_patch != null and restored_patch.call("get_world_object_state") == entry["state"], "schema-1 restore preserves each chunk's independent terrain state")
		if restored_patch != null:
			_expect_patch_geometry(restored_patch, entry["state"], "schema-1 restored patch %s" % str(entry["chunk_id"]), entry.get("disabled_sides", []))

	for chunk_id_value in controller.call("get_loaded_chunk_ids"):
		var chunk_id: String = str(chunk_id_value)
		if chunk_id.begins_with(SURFACE_PREFIX):
			_expect_adjacency_pair(controller, chunk_id, "schema-1 restored %s" % chunk_id)
	_expect_cross_chunk_adjacency(controller, "schema-1 restored")

	await _finish(0)

func _collect_surface_patches(controller: Node) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var chunk_ids: Array = controller.call("get_loaded_chunk_ids")
	var loaded_chunks: Dictionary = {}
	for chunk_value in chunk_ids:
		loaded_chunks[str(chunk_value)] = true
	for chunk_value in chunk_ids:
		var chunk_id: String = str(chunk_value)
		if not chunk_id.begins_with(SURFACE_PREFIX):
			continue
		var chunk_root: Node3D = controller.call("get_chunk_root", chunk_id) as Node3D
		if chunk_root == null:
			continue
		for child_value in chunk_root.get_children():
			var patch: Node3D = child_value as Node3D
			if patch == null or not patch.has_method("bind_neighbor_patch") or not patch.has_method("get_edge_policy"):
				continue
			var node_name: String = str(patch.name)
			var local_path: String = "%s/%s" % [chunk_root.name, node_name]
			var stable_id: String = str(controller.call("_make_world_object_stable_id", chunk_id, local_path))
			var disabled_sides: Array[String] = []
			match node_name:
				"TerrainPatch_AdjacentWest":
					disabled_sides.append("East")
				"TerrainPatch_AdjacentEast":
					disabled_sides.append("West")
				"TerrainPatch_CrossEast":
					if loaded_chunks.has(_offset_surface_chunk(chunk_id, 1, 0)):
						disabled_sides.append("East")
				"TerrainPatch_CrossWest":
					if loaded_chunks.has(_offset_surface_chunk(chunk_id, -1, 0)):
						disabled_sides.append("West")
				"TerrainPatch_CrossNorth":
					if loaded_chunks.has(_offset_surface_chunk(chunk_id, 0, -1)):
						disabled_sides.append("North")
				"TerrainPatch_CrossSouth":
					if loaded_chunks.has(_offset_surface_chunk(chunk_id, 0, 1)):
						disabled_sides.append("South")
			entries.append({
				"chunk_id": chunk_id,
				"stable_id": stable_id,
				"node_name": node_name,
				"disabled_sides": disabled_sides,
				"patch": patch
			})
	return entries

func _offset_surface_chunk(chunk_id: String, dx: int, dy: int) -> String:
	var coordinate_text: String = chunk_id.trim_prefix(SURFACE_PREFIX).trim_prefix("chunk_")
	var parts: PackedStringArray = coordinate_text.split("_")
	if parts.size() != 2:
		return ""
	return SURFACE_PREFIX + "chunk_%d_%d" % [int(parts[0]) + dx, int(parts[1]) + dy]

func _expect_adjacency_pair(controller: Node, chunk_id: String, label: String) -> void:
	var west: Node3D = _find_patch(controller, chunk_id, "TerrainPatch_AdjacentWest")
	var east: Node3D = _find_patch(controller, chunk_id, "TerrainPatch_AdjacentEast")
	_expect(west != null and east != null, "%s has both adjacent production terrain tiles" % label)
	if west == null or east == null:
		return
	var west_state: Dictionary = west.call("get_world_object_state")
	var east_state: Dictionary = east.call("get_world_object_state")
	var expected_west_mode: String = "flush_join"
	var expected_east_mode: String = "flush_join"
	if int(east_state.get("height_level", 0)) > int(west_state.get("height_level", 0)):
		expected_west_mode = "neighbor_higher"
		expected_east_mode = "local_higher"
	elif int(west_state.get("height_level", 0)) > int(east_state.get("height_level", 0)):
		expected_west_mode = "local_higher"
		expected_east_mode = "neighbor_higher"
	_expect(str(west.call("get_edge_policy", "east").get("mode", "")) == expected_west_mode, "%s west tile tracks the live east-neighbor height" % label)
	_expect(str(east.call("get_edge_policy", "west").get("mode", "")) == expected_east_mode, "%s east tile tracks the live west-neighbor height" % label)
	_expect(not _ramp_enabled(west, "East") and not _ramp_enabled(east, "West"), "%s disables both ramps on the shared edge" % label)

func _expect_cross_chunk_adjacency(controller: Node, label: String) -> void:
	var loaded_chunks: Dictionary = {}
	var surface_ids: Array[String] = []
	for chunk_value in controller.call("get_loaded_chunk_ids"):
		var chunk_id: String = str(chunk_value)
		loaded_chunks[chunk_id] = true
		if chunk_id.begins_with(SURFACE_PREFIX):
			surface_ids.append(chunk_id)
	var pair_count: int = 0
	for chunk_id in surface_ids:
		var east_id: String = _offset_surface_chunk(chunk_id, 1, 0)
		if loaded_chunks.has(east_id):
			_expect_cross_pair(
				_find_patch(controller, chunk_id, "TerrainPatch_CrossEast"),
				_find_patch(controller, east_id, "TerrainPatch_CrossWest"),
				Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0),
				"east", "west", "%s %s -> %s" % [label, chunk_id, east_id]
			)
			pair_count += 1
		var south_id: String = _offset_surface_chunk(chunk_id, 0, 1)
		if loaded_chunks.has(south_id):
			_expect_cross_pair(
				_find_patch(controller, chunk_id, "TerrainPatch_CrossSouth"),
				_find_patch(controller, south_id, "TerrainPatch_CrossNorth"),
				Vector3(0.0, 0.0, PatchScript.PATCH_SIZE),
				"south", "north", "%s %s -> %s" % [label, chunk_id, south_id]
			)
			pair_count += 1
	_expect(pair_count == 12, "%s rebuilds all twelve cross-chunk seams in the 3x3 window" % label)

func _expect_cross_pair(first: Node3D, second: Node3D, expected_offset: Vector3, first_side: String, second_side: String, label: String) -> void:
	_expect(first != null and second != null, "%s has both cross-chunk terrain patches" % label)
	if first == null or second == null:
		return
	_expect((second.global_position - first.global_position).distance_to(expected_offset) <= 0.01, "%s patches meet at exact cardinal PATCH_SIZE spacing" % label)
	var first_state: Dictionary = first.call("get_world_object_state")
	var second_state: Dictionary = second.call("get_world_object_state")
	var expected_first_mode: String = "flush_join"
	var expected_second_mode: String = "flush_join"
	if int(second_state.get("height_level", 0)) > int(first_state.get("height_level", 0)):
		expected_first_mode = "neighbor_higher"
		expected_second_mode = "local_higher"
	elif int(first_state.get("height_level", 0)) > int(second_state.get("height_level", 0)):
		expected_first_mode = "local_higher"
		expected_second_mode = "neighbor_higher"
	_expect(str(first.call("get_edge_policy", first_side).get("mode", "")) == expected_first_mode, "%s first patch sees the correct neighbor height" % label)
	_expect(str(second.call("get_edge_policy", second_side).get("mode", "")) == expected_second_mode, "%s second patch sees the reciprocal height" % label)
	_expect(not _ramp_enabled(first, first_side.capitalize()) and not _ramp_enabled(second, second_side.capitalize()), "%s suppresses both shared-edge ramps" % label)

func _expect_patch_geometry(patch: Node3D, state: Dictionary, label: String, disabled_sides: Array = []) -> void:
	var collision: CollisionShape3D = patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
	_expect(collision != null and collision.shape is BoxShape3D, "%s has a box collision shape" % label)
	if collision == null or not (collision.shape is BoxShape3D):
		return
	var expected_height: float = 0.05 + float(state.get("height_level", 0)) * 0.25
	var box: BoxShape3D = collision.shape as BoxShape3D
	_expect(is_equal_approx(box.size.y, expected_height), "%s collision height matches its saved state" % label)
	_expect(is_equal_approx(collision.position.y, expected_height * 0.5), "%s collision remains grounded" % label)
	_expect_edge_ramps(patch, expected_height, label, disabled_sides)

func _expect_edge_ramps(patch: Node3D, expected_height: float, label: String, disabled_sides: Array = []) -> void:
	var body := patch.get_node_or_null("TerrainCollisionBody") as StaticBody3D
	_expect(body != null, "%s retains its terrain collision body" % label)
	if body == null:
		return
	var slope_length: float = sqrt(PatchScript.EDGE_RAMP_RUN*PatchScript.EDGE_RAMP_RUN+expected_height*expected_height)
	var angle: float = atan(expected_height/PatchScript.EDGE_RAMP_RUN)
	for side in ["East", "West", "North", "South"]:
		var ramp_body := patch.get_node_or_null("TerrainRampBody_" + side) as StaticBody3D
		_expect(ramp_body != null, "%s has an independent %s ramp body" % [label, side])
		if ramp_body == null:
			continue
		var expected_enabled: bool = not disabled_sides.has(side)
		_expect(ramp_body != body and ramp_body.collision_layer == (1 if expected_enabled else 0) and ramp_body.collision_mask == 0, "%s %s ramp body matches its adjacency policy" % [label, side])
		var ramp := ramp_body.get_node_or_null("TerrainRampCollision_" + side) as CollisionShape3D
		_expect(ramp != null, "%s has a %s edge ramp collision shape" % [label, side])
		if ramp != null:
			_expect(ramp.disabled == not expected_enabled, "%s %s ramp collision enablement matches adjacency" % [label, side])
		if ramp == null:
			continue
		var ramp_box := ramp.shape as BoxShape3D
		_expect(ramp_box != null, "%s %s ramp uses a box collision slab" % [label, side])
		if ramp_box == null:
			continue
		var expected_size := Vector3(slope_length,PatchScript.EDGE_RAMP_COLLISION_THICKNESS,PatchScript.PATCH_SIZE) if side == "East" or side == "West" else Vector3(PatchScript.PATCH_SIZE,PatchScript.EDGE_RAMP_COLLISION_THICKNESS,slope_length)
		_expect(ramp_box.size.distance_to(expected_size) <= 0.0001, "%s %s ramp collision dimensions match saved height" % [label, side])
		var expected_rotation := Vector3.ZERO
		match side:
			"East": expected_rotation=Vector3(0.0,0.0,-angle)
			"West": expected_rotation=Vector3(0.0,0.0,angle)
			"North": expected_rotation=Vector3(-angle,0.0,0.0)
			"South": expected_rotation=Vector3(angle,0.0,0.0)
		_expect(ramp.rotation.distance_to(expected_rotation) <= 0.0001, "%s %s ramp keeps its edge orientation" % [label, side])
		var top_center: Vector3 = ramp.transform*Vector3(0.0,ramp_box.size.y*0.5,0.0)
		_expect(absf(top_center.y-expected_height*0.5) <= 0.0001, "%s %s ramp top face stays centered on the visual slope" % [label, side])

func _ramp_enabled(patch: Node3D, side: String) -> bool:
	var body := patch.get_node_or_null("TerrainRampBody_" + side) as StaticBody3D
	if body == null:
		return false
	var collision := body.get_node_or_null("TerrainRampCollision_" + side) as CollisionShape3D
	return body.collision_layer == 1 and collision != null and not collision.disabled

func _find_patch(controller: Node, chunk_id: String, node_name: String) -> Node3D:
	var chunk_root: Node3D = controller.call("get_chunk_root", chunk_id) as Node3D
	return chunk_root.get_node_or_null(node_name) as Node3D if chunk_root != null else null

func _finish(exit_code: int) -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty() and exit_code == 0:
		print("Production SurfaceWorld all-chunk terrain patch reload tests passed.")
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

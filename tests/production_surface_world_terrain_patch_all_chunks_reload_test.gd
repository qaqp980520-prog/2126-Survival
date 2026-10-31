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
	_expect(entries.size() == 9, "initial 3x3 active surface window contains nine terrain patches")
	if entries.size() != 9:
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
		_expect_patch_geometry(patch, entry["state"], "edited patch %d" % index)
		entry["patch_instance"] = patch.get_instance_id()
		entry["proxy_instance"] = proxy.get_instance_id()
		entry["patch_weak"] = weakref(patch)
		entry["proxy_weak"] = weakref(proxy)
		entry.erase("patch")
		entries[index] = entry

	var save_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not save_payload.is_empty(), "world serialization captures all nine terrain patch states")
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
		var fresh_patch: Node3D = _find_patch(controller, chunk_id)
		_expect(fresh_patch != null, "reloaded chunk recreates its terrain patch")
		if fresh_patch == null:
			continue
		_expect(fresh_patch.get_instance_id() != int(entry["patch_instance"]), "reloaded patch is a fresh node instance")
		_expect(str(controller.call("_make_world_object_stable_id", chunk_id, "%s/TerrainPatch" % fresh_patch.get_parent().name)) == stable_id, "reloaded patch retains its deterministic stable ID")
		_expect(fresh_patch.call("get_world_object_state") == entry["state"], "reloaded patch restores its unique height/material/revision")
		_expect_patch_geometry(fresh_patch, entry["state"], "reloaded patch %s" % chunk_id)
		var fresh_proxy: Area3D = fresh_patch.get_node_or_null("InteractionArea") as Area3D
		_expect(fresh_proxy != null and fresh_proxy.is_inside_tree(), "reloaded patch rebuilds its interaction proxy")
		if fresh_proxy != null:
			_expect(fresh_proxy.get_instance_id() != int(entry["proxy_instance"]), "reloaded interaction proxy is a fresh instance")

	var roundtrip_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not roundtrip_payload.is_empty(), "reloaded nine-patch window can be serialized again")
	_expect(bool(world.call("restore_stream_state", save_payload, _test_time + 2)), "schema-1 save restores all nine surface terrain patches")
	for entry in entries:
		var restored_patch: Node3D = _find_patch(controller, str(entry["chunk_id"]))
		_expect(restored_patch != null and restored_patch.call("get_world_object_state") == entry["state"], "schema-1 restore preserves each chunk's independent terrain state")
		if restored_patch != null:
			_expect_patch_geometry(restored_patch, entry["state"], "schema-1 restored patch %s" % str(entry["chunk_id"]))

	await _finish(0)

func _collect_surface_patches(controller: Node) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var chunk_ids: Array = controller.call("get_loaded_chunk_ids")
	for chunk_value in chunk_ids:
		var chunk_id: String = str(chunk_value)
		if not chunk_id.begins_with(SURFACE_PREFIX):
			continue
		var chunk_root: Node3D = controller.call("get_chunk_root", chunk_id) as Node3D
		if chunk_root == null:
			continue
		var patch: Node3D = chunk_root.get_node_or_null("TerrainPatch") as Node3D
		if patch == null:
			continue
		var local_path: String = "%s/TerrainPatch" % chunk_root.name
		var stable_id: String = str(controller.call("_make_world_object_stable_id", chunk_id, local_path))
		entries.append({
			"chunk_id": chunk_id,
			"stable_id": stable_id,
			"patch": patch
		})
	return entries

func _expect_patch_geometry(patch: Node3D, state: Dictionary, label: String) -> void:
	var collision: CollisionShape3D = patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
	_expect(collision != null and collision.shape is BoxShape3D, "%s has a box collision shape" % label)
	if collision == null or not (collision.shape is BoxShape3D):
		return
	var expected_height: float = 0.05 + float(state.get("height_level", 0)) * 0.25
	var box: BoxShape3D = collision.shape as BoxShape3D
	_expect(is_equal_approx(box.size.y, expected_height), "%s collision height matches its saved state" % label)
	_expect(is_equal_approx(collision.position.y, expected_height * 0.5), "%s collision remains grounded" % label)
	_expect_edge_ramps(patch, expected_height, label)

func _expect_edge_ramps(patch: Node3D, expected_height: float, label: String) -> void:
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
		_expect(ramp_body != body and ramp_body.collision_layer == 1 and ramp_body.collision_mask == 0, "%s %s ramp body is isolated on the world collision layer" % [label, side])
		var ramp := ramp_body.get_node_or_null("TerrainRampCollision_" + side) as CollisionShape3D
		_expect(ramp != null, "%s has a %s edge ramp collision shape" % [label, side])
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

func _find_patch(controller: Node, chunk_id: String) -> Node3D:
	var chunk_root: Node3D = controller.call("get_chunk_root", chunk_id) as Node3D
	return chunk_root.get_node_or_null("TerrainPatch") as Node3D if chunk_root != null else null

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

extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var holder := Node3D.new()
	holder.name = "AdjacentTerrainTestRoot"
	root.add_child(holder)
	var west_patch: Node3D = PatchScript.new()
	west_patch.name = "WestPatch"
	var east_patch: Node3D = PatchScript.new()
	east_patch.name = "EastPatch"
	east_patch.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
	var far_patch: Node3D = PatchScript.new()
	far_patch.name = "FarPatch"
	far_patch.position = Vector3(PatchScript.PATCH_SIZE * 3.0, 0.0, 0.0)
	holder.add_child(west_patch)
	holder.add_child(east_patch)
	holder.add_child(far_patch)
	await process_frame
	await physics_frame
	var west_state: Dictionary = west_patch.call("get_world_object_state")
	var east_state: Dictionary = east_patch.call("get_world_object_state")
	_expect(_ramp_enabled(west_patch, "East"), "isolated west patch initially exposes its east ground ramp")
	_expect(_ramp_enabled(east_patch, "West"), "isolated east patch initially exposes its west ground ramp")
	_expect(bool(west_patch.call("bind_neighbor_patch", "east", east_patch)), "west patch accepts its east neighbor state")
	_expect(bool(east_patch.call("bind_neighbor_patch", "west", west_patch)), "east patch accepts its west neighbor state")
	_expect(str(west_patch.call("get_edge_policy", "east").get("mode", "")) == "flush_join", "same-height patches resolve to a flush shared edge")
	_expect(not _ramp_enabled(west_patch, "East"), "west patch disables its overlapping east ground ramp")
	_expect(not _ramp_enabled(east_patch, "West"), "east patch disables its overlapping west ground ramp")
	_expect(not bool(west_patch.call("bind_neighbor_patch", "east", far_patch)), "non-adjacent patch cannot be bound as a neighbor")
	_expect(str(west_patch.call("get_edge_policy", "east").get("mode", "")) == "flush_join", "rejected distant neighbor leaves the existing binding unchanged")
	await physics_frame
	var equal_west_hit: Dictionary = _ray_height_at(0.99)
	var equal_east_hit: Dictionary = _ray_height_at(1.01)
	_expect(not equal_west_hit.is_empty() and absf(float(equal_west_hit.get("position", Vector3.ZERO).y) - 0.05) <= 0.01, "equal-height west patch collision reaches the shared seam")
	_expect(not equal_east_hit.is_empty() and absf(float(equal_east_hit.get("position", Vector3.ZERO).y) - 0.05) <= 0.01, "equal-height east patch collision reaches the shared seam")
	_expect(_ramp_enabled(west_patch, "North") and _ramp_enabled(east_patch, "South"), "unrelated outer edges retain base-ground ramps")
	var raised_state := {"height_level": 2, "surface_type": "metal", "revision": 1}
	_expect(bool(east_patch.call("apply_world_object_state", raised_state)), "neighbor patch accepts a higher persisted terrain state")
	_expect(bool(west_patch.call("bind_neighbor_patch", "east", east_patch)), "west patch refreshes its neighbor height")
	_expect(bool(east_patch.call("bind_neighbor_patch", "west", west_patch)), "east patch refreshes its neighbor height")
	var west_policy: Dictionary = west_patch.call("get_edge_policy", "east")
	var east_policy: Dictionary = east_patch.call("get_edge_policy", "west")
	_expect(str(west_policy.get("mode", "")) == "neighbor_higher", "lower west patch identifies its east neighbor as higher")
	_expect(str(east_policy.get("mode", "")) == "local_higher", "raised east patch identifies itself as higher")
	_expect(is_equal_approx(float(west_policy.get("height_delta", 0.0)), 0.5), "adjacent height difference is 0.5 m")
	_expect(not _ramp_enabled(west_patch, "East") and not _ramp_enabled(east_patch, "West"), "different-height shared edge suppresses both conflicting ramps")
	await physics_frame
	var step_west_hit: Dictionary = _ray_height_at(0.99)
	var step_east_hit: Dictionary = _ray_height_at(1.01)
	_expect(not step_west_hit.is_empty() and absf(float(step_west_hit.get("position", Vector3.ZERO).y) - 0.05) <= 0.01, "lower patch retains its collision height up to the step")
	_expect(not step_east_hit.is_empty() and absf(float(step_east_hit.get("position", Vector3.ZERO).y) - 0.55) <= 0.01, "higher patch retains its collision height beyond the step")
	_expect(west_patch.call("get_world_object_state") == west_state, "neighbor binding does not mutate west saved state")
	_expect(east_patch.call("get_world_object_state") == raised_state, "neighbor binding does not mutate east saved state")
	var invalid_state := {"height_level": "bad", "surface_type": "soil", "revision": 0}
	_expect(not bool(west_patch.call("set_neighbor_edge_state", "east", invalid_state)), "invalid neighbor state is rejected")
	_expect(str(west_patch.call("get_edge_policy", "east").get("mode", "")) == "neighbor_higher", "invalid neighbor update leaves previous edge policy intact")
	_expect(bool(west_patch.call("clear_neighbor_edge_state", "east")), "west patch can clear its east neighbor binding")
	_expect(bool(east_patch.call("clear_neighbor_edge_state", "west")), "east patch can clear its west neighbor binding")
	_expect(_ramp_enabled(west_patch, "East") and _ramp_enabled(east_patch, "West"), "clearing adjacency restores isolated ground ramps")
	holder.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("Surface terrain patch adjacency tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

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

func _ray_height_at(x: float) -> Dictionary:
	var space_state: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 2.0, 0.0), Vector3(x, -1.0, 0.0))
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)


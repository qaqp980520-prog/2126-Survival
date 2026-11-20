extends SceneTree

const BrainScript = preload("res://systems/BackroomsEntityBrain.gd")
const MovementDriverScript = preload("res://systems/BackroomsEntityMovementDriver.gd")
const CollisionFactoryScript = preload("res://systems/BackroomsEntityCollisionFactory.gd")
const NavigationFactoryScript = preload("res://systems/BackroomsCellNavigationFactory.gd")

class FakeRuntime:
	extends Node
	var active: bool = true
	var cell_roots: Dictionary = {}
	var route_snapshot: Dictionary = {}
	var route_snapshot_current: bool = true
	var transfer_succeeds: bool = false
	var transfer_calls: int = 0
	var last_transfer: Dictionary = {}

	func is_active() -> bool:
		return active

	func get_loaded_cell_keys() -> Array:
		var keys: Array = cell_roots.keys()
		keys.sort()
		return keys

	func get_cell_root(cell_key: String) -> Node3D:
		var value: Variant = cell_roots.get(cell_key, null)
		if value is Node3D and is_instance_valid(value):
			return value as Node3D
		return null

	func plan_route_between_loaded_cells(start_cell: Vector2i, goal_cell: Vector2i) -> Dictionary:
		if route_snapshot.is_empty():
			return {"ok": false, "reason": "route_not_configured"}
		if route_snapshot.get("start_cell", null) != start_cell or route_snapshot.get("goal_cell", null) != goal_cell:
			return {"ok": false, "reason": "route_endpoint_mismatch"}
		return route_snapshot.duplicate(true)

	func is_route_snapshot_current(route: Dictionary) -> bool:
		return (
			route_snapshot_current
			and route.get("start_cell", null) == route_snapshot.get("start_cell", null)
			and route.get("goal_cell", null) == route_snapshot.get("goal_cell", null)
		)

	func transfer_entity_to_next_cell(spawn_cell_key: String, entity_id: String, route: Dictionary) -> Dictionary:
		transfer_calls += 1
		var keys_value: Variant = route.get("cell_keys", null)
		var directions_value: Variant = route.get("edge_directions", null)
		if not (keys_value is Array) or keys_value.size() < 2 or not (directions_value is Array) or directions_value.is_empty():
			return {"ok": false, "reason": "fake_route_invalid"}
		var source_root: Node3D = get_cell_root(str(keys_value[0]))
		if source_root == null:
			return {"ok": false, "reason": "fake_source_unavailable"}
		var entity_root: CharacterBody3D = null
		for child in source_root.get_children():
			if not (child is CharacterBody3D) or str(child.get_meta("backrooms_entity_id", "")) != entity_id:
				continue
			var spawn_value: Variant = child.get_meta("spawn_cell", null)
			if spawn_value is Vector2i:
				var spawn_cell: Vector2i = spawn_value
				if ("%d,%d" % [spawn_cell.x, spawn_cell.y]) == spawn_cell_key:
					entity_root = child as CharacterBody3D
					break
		if entity_root == null:
			return {"ok": false, "reason": "fake_entity_unavailable"}
		var direction_value: Variant = directions_value[0]
		if not (direction_value is Vector2i):
			return {"ok": false, "reason": "fake_direction_invalid"}
		var direction: Vector2i = direction_value
		var local_position: Vector3 = source_root.to_local(entity_root.global_position)
		var safe_extent: float = 3.35
		var edge_coordinate: float = local_position.x if direction.x != 0 else local_position.z
		var expected_edge: float = float(direction.x) * safe_extent if direction.x != 0 else float(direction.y) * safe_extent
		var edge_error: float = absf(edge_coordinate - expected_edge)
		last_transfer = {
			"spawn_cell_key": spawn_cell_key,
			"entity_id": entity_id,
			"cell_keys": keys_value.duplicate(),
			"edge_error": edge_error
		}
		if edge_error > 0.25:
			return {"ok": false, "reason": "fake_transfer_not_at_edge"}
		if not transfer_succeeds:
			return {"ok": false, "reason": "fake_transfer_rejected"}
		return {
			"ok": true,
			"from_owner_cell_key": str(keys_value[0]),
			"to_owner_cell_key": str(keys_value[1]),
			"owner_revision": 1
		}

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _assert_same_cell_pursuit_moves_toward_player()
	await _assert_wall_collision_blocks_pursuit()
	await _assert_navigation_agent_routes_around_obstacle()
	await _assert_smiler_approach_uses_unseen_player_target()
	await _assert_cross_cell_target_fails_closed()
	await _assert_hound_cross_cell_pursuit_uses_precision_edge()
	await _assert_avoidance_moves_away_from_player()
	await _assert_duller_retreat_moves_away_from_player()
	await _assert_patrol_moves_within_cell()
	await _assert_patrol_index_metadata_is_authoritative()
	await _assert_deathmoth_aerial_patrol_changes_height()
	await _assert_anchored_entities_remain_stationary()
	await _assert_round_robin_movement_budget()
	await _assert_invalid_and_inactive_runtime_rejection()
	if failures.is_empty():
		print("Backrooms entity movement driver tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _assert_same_cell_pursuit_moves_toward_player() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "hound", "Level 2", Vector2i.ZERO, 20261118, Vector3.ZERO)
	var brain: Node = entity["brain"] as Node as Node
	var entity_root: Node3D = entity["root"] as Node3D as Node3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 3.0,
		"has_line_of_sight": true,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"player_position": Vector3(3.0, 0.0, 0.0)
	}, 0.2)
	_expect(str(decision.get("state", "")) == "pursue", "visible nearby Hound receives a pursue movement intent")
	await physics_frame
	var start_position: Vector3 = entity_root.global_position
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("moved_count", 0)) == 1, "bounded movement driver updates one eligible entity")
	_expect(entity_root.global_position.x > start_position.x, "Hound moves toward a same-cell player target")
	_expect(str(entity_root.get_meta("backrooms_movement_mode", "")) == "cell_local_physics_v1", "movement mode is explicitly marked as cell-local physics collision")
	driver.call("reset")
	world_root.free()
	await physics_frame

func _assert_wall_collision_blocks_pursuit() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var wall := StaticBody3D.new()
	wall.name = "TestWall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector3(1.0, 1.0, 0.0)
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.2, 2.0, 4.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	cell_root.add_child(wall)
	var entity: Dictionary = _add_entity(cell_root, "hound", "Level 2", Vector2i.ZERO, 20261118, Vector3(0.0, 0.55, 0.0))
	var brain: Node = entity["brain"] as Node
	var entity_root: CharacterBody3D = entity["root"] as CharacterBody3D
	brain.call("evaluate_perception", {
		"distance_to_player": 3.0,
		"has_line_of_sight": true,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"player_position": Vector3(3.0, 0.55, 0.0)
	}, 0.2)
	await physics_frame
	var driver = MovementDriverScript.new()
	var blocked_total: int = 0
	for _tick_index in range(6):
		var result: Dictionary = driver.call("tick", runtime, 0.1)
		blocked_total += int(result.get("blocked_count", 0))
		await physics_frame
	var local_position: Vector3 = cell_root.to_local(entity_root.global_position)
	_expect(blocked_total > 0, "a real StaticBody3D wall reports a blocked movement result")
	_expect(local_position.x > 0.2, "Hound advances toward the wall before contact")
	_expect(local_position.x < 0.75, "Hound collision proxy cannot pass through the wall")
	driver.call("reset")
	world_root.free()
	await physics_frame

func _assert_navigation_agent_routes_around_obstacle() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var navigation_region := cell_root.get_node_or_null("CellNavigation") as NavigationRegion3D
	_expect(navigation_region != null, "cell-local navigation region exists for the obstacle fixture")
	if navigation_region == null:
		world_root.free()
		await physics_frame
		return
	navigation_region.navigation_mesh = _make_wall_detour_navigation_mesh()
	var wall := StaticBody3D.new()
	wall.name = "NavigationDetourWall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector3(1.0, 1.0, 0.0)
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.2, 2.0, 4.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	cell_root.add_child(wall)
	var entity: Dictionary = _add_entity(cell_root, "hound", "Level 2", Vector2i.ZERO, 20261118, Vector3(0.0, 0.55, 0.0))
	var brain: Node = entity["brain"] as Node
	var entity_root: CharacterBody3D = entity["root"] as CharacterBody3D
	brain.call("evaluate_perception", {
		"distance_to_player": 3.0,
		"has_line_of_sight": true,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"player_position": Vector3(3.0, 0.55, 0.0)
	}, 0.2)
	await physics_frame
	var agent := NavigationFactoryScript.get_agent(entity_root)
	_expect(agent != null, "Hound exposes its NavigationAgent3D")
	if agent == null:
		world_root.free()
		await physics_frame
		return
	var target_world := Vector3(3.0, NavigationFactoryScript.NAVIGATION_SURFACE_Y, 0.0)
	_expect(
		NavigationFactoryScript.set_agent_target(agent, target_world, 1.1),
		"NavigationAgent3D accepts a same-cell target"
	)
	await physics_frame
	var navigation_result: Dictionary = NavigationFactoryScript.get_next_waypoint(agent)
	_expect(bool(navigation_result.get("ok", false)), "NavigationAgent3D produces a path around the wall cut-out")
	var path: PackedVector3Array = agent.get_current_navigation_path()
	var detour_found: bool = false
	for point in path:
		if absf(point.z) > 2.2:
			detour_found = true
	_expect(path.size() >= 3 and detour_found, "navigation path contains an intermediate waypoint outside the inflated wall bounds")
	print("Navigation detour path points: %s" % str(path))
	var driver = MovementDriverScript.new()
	var blocked_total: int = 0
	var blocked_events: Array[String] = []
	for tick_index in range(40):
		var before_position: Vector3 = entity_root.global_position
		var movement_result: Dictionary = driver.call("tick", runtime, 0.1)
		var tick_blocked: int = int(movement_result.get("blocked_count", 0))
		blocked_total += tick_blocked
		if tick_blocked > 0:
			var normal_value: Variant = entity_root.get_meta("backrooms_last_collision_normal") if entity_root.has_meta("backrooms_last_collision_normal") else Vector3.ZERO
			blocked_events.append(
				"tick=%d before=%s after=%s normal=%s" % [
					tick_index,
					str(before_position),
					str(entity_root.global_position),
					str(normal_value)
				]
			)
		await physics_frame
	var final_local: Vector3 = cell_root.to_local(entity_root.global_position)
	print("Navigation detour diagnostic: blocked=%d final=%s events=%s" % [blocked_total, str(final_local), str(blocked_events)])
	_expect(
		blocked_total == 0,
		"NavigationAgent3D detour avoids physical wall collisions (blocked=%d)" % blocked_total
	)
	_expect(
		final_local.x > 1.5 and absf(final_local.z) < 1.0,
		"Hound reaches the far side of the wall and returns toward the target corridor"
	)
	driver.call("reset")
	world_root.free()
	await physics_frame

func _make_wall_detour_navigation_mesh() -> NavigationMesh:
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.vertices = PackedVector3Array([
		Vector3(-3.35, NavigationFactoryScript.NAVIGATION_SURFACE_Y, -3.35),
		Vector3(0.45, NavigationFactoryScript.NAVIGATION_SURFACE_Y, -3.35),
		Vector3(1.55, NavigationFactoryScript.NAVIGATION_SURFACE_Y, -3.35),
		Vector3(3.35, NavigationFactoryScript.NAVIGATION_SURFACE_Y, -3.35),
		Vector3(-3.35, NavigationFactoryScript.NAVIGATION_SURFACE_Y, -2.55),
		Vector3(0.45, NavigationFactoryScript.NAVIGATION_SURFACE_Y, -2.55),
		Vector3(1.55, NavigationFactoryScript.NAVIGATION_SURFACE_Y, -2.55),
		Vector3(3.35, NavigationFactoryScript.NAVIGATION_SURFACE_Y, -2.55),
		Vector3(-3.35, NavigationFactoryScript.NAVIGATION_SURFACE_Y, 2.55),
		Vector3(0.45, NavigationFactoryScript.NAVIGATION_SURFACE_Y, 2.55),
		Vector3(1.55, NavigationFactoryScript.NAVIGATION_SURFACE_Y, 2.55),
		Vector3(3.35, NavigationFactoryScript.NAVIGATION_SURFACE_Y, 2.55),
		Vector3(-3.35, NavigationFactoryScript.NAVIGATION_SURFACE_Y, 3.35),
		Vector3(0.45, NavigationFactoryScript.NAVIGATION_SURFACE_Y, 3.35),
		Vector3(1.55, NavigationFactoryScript.NAVIGATION_SURFACE_Y, 3.35),
		Vector3(3.35, NavigationFactoryScript.NAVIGATION_SURFACE_Y, 3.35)
	])
	navigation_mesh.add_polygon(PackedInt32Array([4, 5, 1, 0]))
	navigation_mesh.add_polygon(PackedInt32Array([8, 9, 5, 4]))
	navigation_mesh.add_polygon(PackedInt32Array([12, 13, 9, 8]))
	navigation_mesh.add_polygon(PackedInt32Array([5, 6, 2, 1]))
	navigation_mesh.add_polygon(PackedInt32Array([13, 14, 10, 9]))
	navigation_mesh.add_polygon(PackedInt32Array([6, 7, 3, 2]))
	navigation_mesh.add_polygon(PackedInt32Array([10, 11, 7, 6]))
	navigation_mesh.add_polygon(PackedInt32Array([14, 15, 11, 10]))
	return navigation_mesh

func _assert_smiler_approach_uses_unseen_player_target() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "smiler", "Level 1", Vector2i.ZERO, 19, Vector3.ZERO)
	var brain: Node = entity["brain"] as Node as Node
	var entity_root: Node3D = entity["root"] as Node3D as Node3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 4.0,
		"has_line_of_sight": false,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"is_dark": true,
		"player_position": Vector3(3.0, 0.0, 0.0)
	}, 0.2)
	_expect(str(decision.get("state", "")) == "approach", "dark unseen Smiler receives an approach intent")
	_expect(bool(decision.get("has_target_position", false)), "unseen Smiler retains the current player position as its target")
	await physics_frame
	var start_x: float = entity_root.global_position.x
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("moved_count", 0)) == 1, "Smiler receives a bounded approach movement update")
	_expect(entity_root.global_position.x > start_x, "Smiler approaches the unseen player while its cell is dark")
	driver.call("reset")
	world_root.free()
	await physics_frame

func _assert_cross_cell_target_fails_closed() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "hound", "Level 2", Vector2i.ZERO, 7, Vector3.ZERO)
	var brain: Node = entity["brain"] as Node
	var entity_root: Node3D = entity["root"] as Node3D
	brain.call("evaluate_perception", {
		"distance_to_player": 8.0,
		"has_line_of_sight": true,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"player_position": Vector3(8.0, 0.0, 0.0)
	}, 0.2)
	await physics_frame
	var start_position: Vector3 = entity_root.global_position
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("blocked_count", 0)) == 1, "cross-cell Hound pursuit fails closed when no loaded-cell route is available")
	_expect(entity_root.global_position.is_equal_approx(start_position), "entity never crosses an unloaded or unowned cell boundary")
	driver.call("reset")
	world_root.free()
	await physics_frame

func _assert_hound_cross_cell_pursuit_uses_precision_edge() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var source_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	_add_cell(runtime, "1,0", Vector2i(1, 0))
	_add_cell(runtime, "2,0", Vector2i(2, 0))
	runtime.route_snapshot = {
		"ok": true,
		"start_cell": Vector2i.ZERO,
		"goal_cell": Vector2i(2, 0),
		"cell_keys": ["0,0", "1,0", "2,0"],
		"edge_directions": [Vector2i(1, 0), Vector2i(1, 0)]
	}
	runtime.transfer_succeeds = true
	var entity: Dictionary = _add_entity(
		source_root, "hound", "Level 2", Vector2i.ZERO, 20261120, Vector3(2.5, 0.55, 0.0)
	)
	var brain: Node = entity["brain"] as Node
	var entity_root: CharacterBody3D = entity["root"] as CharacterBody3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 13.5,
		"has_line_of_sight": true,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"player_position": Vector3(16.0, 0.55, 0.0)
	}, 0.2)
	_expect(str(decision.get("state", "")) == "pursue", "visible Hound target two loaded cells away produces a pursue intent")
	await physics_frame
	var driver = MovementDriverScript.new()
	var start_position: Vector3 = entity_root.global_position
	runtime.route_snapshot_current = false
	var stale_result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(stale_result.get("blocked_count", 0)) == 1, "stale cross-cell route snapshot fails closed")
	_expect(entity_root.global_position.is_equal_approx(start_position), "stale route cannot move the Hound toward an uncommitted cell")
	_expect(runtime.transfer_calls == 0, "stale route cannot request an ownership transfer")
	runtime.route_snapshot_current = true
	await physics_frame
	var first_move: Dictionary = driver.call("tick", runtime, 0.1)
	var agent: NavigationAgent3D = NavigationFactoryScript.get_agent(entity_root)
	_expect(int(first_move.get("moved_count", 0)) == 1, "Hound advances toward the first route edge")
	_expect(runtime.transfer_calls == 0, "Hound does not transfer before reaching the edge tolerance")
	_expect(
		agent != null and absf(agent.target_desired_distance - 0.05) <= 0.0001,
		"cross-cell edge approach uses the dedicated 0.05 m NavigationAgent target tolerance"
	)
	await physics_frame
	var second_move: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(second_move.get("transferred_count", 0)) == 1, "Hound commits exactly one ownership hop after reaching the edge")
	var transfer_results: Array = second_move.get("transfer_results", [])
	_expect(
		transfer_results.size() == 1
		and transfer_results[0] is Dictionary
		and bool(transfer_results[0].get("ok", false)),
		"movement tick exposes the committed first-hop result to its caller"
	)
	_expect(runtime.transfer_calls == 1, "one movement tick can commit at most the current route's first hop")
	_expect(str(runtime.last_transfer.get("spawn_cell_key", "")) == "0,0", "cross-cell handoff retains the immutable spawn-cell identity")
	_expect(str(runtime.last_transfer.get("entity_id", "")) == "hound", "cross-cell handoff identifies the Hound entity")
	_expect(
		runtime.last_transfer.get("cell_keys", []) == ["0,0", "1,0", "2,0"],
		"cross-cell handoff retains the complete validated multi-cell route snapshot"
	)
	_expect(
		str(transfer_results[0].get("from_owner_cell_key", "")) == "0,0"
		and str(transfer_results[0].get("to_owner_cell_key", "")) == "1,0"
		and int(transfer_results[0].get("owner_revision", -1)) == 1,
		"a target two cells away still commits only the first hop to the adjacent owner cell"
	)
	_expect(float(runtime.last_transfer.get("edge_error", 1.0)) <= 0.25, "precision approach reaches the runtime's 0.25 m transfer boundary")
	driver.call("reset")
	world_root.free()
	await physics_frame

func _assert_avoidance_moves_away_from_player() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "faceling", "Level 3", Vector2i.ZERO, 11, Vector3(0.5, 0.0, 0.0))
	var brain: Node = entity["brain"] as Node
	var entity_root: Node3D = entity["root"] as Node3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 2.0,
		"has_line_of_sight": false,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"player_position": Vector3(2.5, 0.0, 0.0)
	}, 0.2)
	_expect(str(decision.get("state", "")) == "avoid", "Faceling avoidance state retains the player position without line of sight")
	_expect(bool(decision.get("has_target_position", false)), "avoidance decision exposes a valid movement target")
	await physics_frame
	var start_x: float = entity_root.global_position.x
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("moved_count", 0)) == 1, "Faceling receives a bounded avoidance movement update")
	_expect(entity_root.global_position.x < start_x, "Faceling moves away from the nearby player")
	driver.call("reset")
	world_root.free()
	await physics_frame

func _assert_duller_retreat_moves_away_from_player() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "duller", "Level 4", Vector2i.ZERO, 23, Vector3(0.5, 0.0, 0.0))
	var brain: Node = entity["brain"] as Node as Node
	var entity_root: Node3D = entity["root"] as Node3D as Node3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 5.0,
		"has_line_of_sight": false,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"player_position": Vector3(2.5, 0.0, 0.0)
	}, 0.2)
	_expect(str(decision.get("state", "")) == "retreat", "Duller enters retreat without line of sight")
	await physics_frame
	var start_x: float = entity_root.global_position.x
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("moved_count", 0)) == 1, "Duller receives a bounded retreat movement update")
	_expect(entity_root.global_position.x < start_x, "Duller withdraws from the nearby player")
	driver.call("reset")
	world_root.free()
	await physics_frame

func _assert_patrol_moves_within_cell() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "hound", "Level 2", Vector2i(3, -2), 2026, Vector3.ZERO)
	var brain: Node = entity["brain"] as Node
	var entity_root: Node3D = entity["root"] as Node3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 30.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}, 0.2)
	_expect(str(decision.get("state", "")) == "patrol", "Hound selects patrol when no player or sound signal is available")
	await physics_frame
	var start_position: Vector3 = entity_root.global_position
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("moved_count", 0)) == 1, "patrolling Hound receives a movement update")
	_expect(entity_root.global_position.distance_to(start_position) > 0.01, "patrol waypoint produces actual movement")
	var local_position: Vector3 = cell_root.to_local(entity_root.global_position)
	_expect(absf(local_position.x) <= 3.35 and absf(local_position.z) <= 3.35, "patrol remains inside the safe owning-cell bounds")
	driver.call("reset")
	world_root.free()
	await physics_frame

func _assert_patrol_index_metadata_is_authoritative() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "hound", "Level 2", Vector2i.ZERO, 20261118, Vector3.ZERO)
	var entity_root: CharacterBody3D = entity["root"] as CharacterBody3D
	var driver = MovementDriverScript.new()
	driver.call("_advance_patrol", "0,0|hound", entity_root)
	entity_root.set_meta("backrooms_patrol_index", 3)
	var target: Vector3 = driver.call("_get_patrol_target", entity_root, "0,0|hound", entity_root.position, "patrol")
	_expect(target.x < 0.0 and target.z > 0.0, "restored entity patrol metadata overrides a stale in-memory waypoint index")
	_expect(int(entity_root.get_meta("backrooms_patrol_index", -1)) == 3, "patrol metadata remains the authoritative persisted waypoint")
	driver.call("reset")
	world_root.free()
	await physics_frame


func _assert_deathmoth_aerial_patrol_changes_height() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "deathmoth", "Level 5", Vector2i.ZERO, 29, Vector3(0.0, 1.55, 0.0))
	var brain: Node = entity["brain"] as Node as Node
	var entity_root: Node3D = entity["root"] as Node3D as Node3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 30.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}, 0.2)
	_expect(str(decision.get("state", "")) == "fly_patrol", "Deathmoth selects aerial patrol without a player signal")
	await physics_frame
	var start_y: float = entity_root.global_position.y
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("moved_count", 0)) == 1, "Deathmoth receives a bounded aerial patrol update")
	_expect(entity_root.global_position.y > start_y, "Deathmoth changes altitude during its aerial patrol")
	driver.call("reset")
	world_root.free()
	await physics_frame

func _assert_anchored_entities_remain_stationary() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var window_entity: Dictionary = _add_entity(cell_root, "window", "Level 1", Vector2i.ZERO, 31, Vector3(0.0, 1.2, -3.9))
	var clump_entity: Dictionary = _add_entity(cell_root, "clump", "Level 3", Vector2i.ZERO, 37, Vector3(0.0, 0.42, 0.0))
	var window_root: Node3D = window_entity["root"] as Node3D
	var clump_root: Node3D = clump_entity["root"] as Node3D
	(window_entity["brain"] as Node).call("evaluate_perception", {
		"distance_to_player": 2.0,
		"has_line_of_sight": true,
		"player_looking_at_entity": true,
		"noise_strength": 0.0,
		"player_position": Vector3(1.0, 0.0, 0.0)
	}, 0.2)
	(clump_entity["brain"] as Node).call("evaluate_perception", {
		"distance_to_player": 4.0,
		"has_line_of_sight": true,
		"noise_strength": 0.0,
		"player_position": Vector3(1.0, 0.0, 0.0)
	}, 0.2)
	await physics_frame
	var window_start: Vector3 = window_root.global_position
	var clump_start: Vector3 = clump_root.global_position
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("total_count", 0)) == 0, "Window and Clump are excluded from mobile entity scheduling")
	_expect(window_root.global_position.is_equal_approx(window_start), "Window remains attached to its wall")
	_expect(clump_root.global_position.is_equal_approx(clump_start), "Clump remains anchored in its cell")
	driver.call("reset")
	world_root.free()
	await physics_frame

func _assert_round_robin_movement_budget() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	for index in range(13):
		var cell := Vector2i(index, 0)
		var key: String = "%d,0" % index
		var cell_root: Node3D = _add_cell(runtime, key, cell)
		var entity: Dictionary = _add_entity(cell_root, "hound", "Level 2", cell, 100 + index, Vector3.ZERO)
		var brain: Node = entity["brain"] as Node
		brain.call("evaluate_perception", {
			"distance_to_player": 30.0,
			"has_line_of_sight": false,
			"noise_strength": 0.0
		}, 0.2)
	await physics_frame
	var driver = MovementDriverScript.new()
	var first: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(first.get("sampled_count", 0)) == 12, "one movement tick never exceeds the 12-entity work budget")
	_expect(int(first.get("pending_count", -1)) == 1, "round-robin movement reports one deferred entity")
	var deferred_key: String = str(first.get("next_entity_key", ""))
	var deferred_parts: PackedStringArray = deferred_key.split("|")
	var deferred_cell_key: String = deferred_parts[0] if not deferred_parts.is_empty() else ""
	var deferred_cell_root: Node3D = runtime.get_cell_root(deferred_cell_key)
	var deferred_entity_root: Node3D = null
	if deferred_cell_root != null:
		for child in deferred_cell_root.get_children():
			if child is Node3D and str(child.get_meta("backrooms_entity_id", "")) == "hound":
				deferred_entity_root = child as Node3D
				break
	_expect(deferred_entity_root != null, "the round-robin cursor identifies the deferred entity")
	var deferred_start: Vector3 = deferred_entity_root.global_position if deferred_entity_root != null else Vector3.ZERO
	var second: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(second.get("sampled_count", 0)) == 12, "the next movement tick keeps the full 12-entity budget")
	_expect(int(second.get("pending_count", -1)) == 1, "round-robin defers one different entity on each tick")
	if deferred_entity_root != null:
		_expect(
			deferred_entity_root.global_position.distance_to(deferred_start) > 0.01,
			"the previously deferred entity is serviced on the next movement tick"
		)
	driver.call("reset")
	world_root.free()
	await physics_frame

func _assert_invalid_and_inactive_runtime_rejection() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var driver = MovementDriverScript.new()
	var invalid: Dictionary = driver.call("tick", runtime, NAN)
	_expect(not bool(invalid.get("ok", true)) and str(invalid.get("reason", "")) == "delta_seconds_invalid", "non-finite movement delta is rejected")
	var hitch: Dictionary = driver.call("tick", runtime, 2.0)
	_expect(bool(hitch.get("ok", false)) and int(hitch.get("tick_index", 0)) == 5, "large frame hitches are capped to half a second of movement scheduling")
	runtime.active = false
	var inactive: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(not bool(inactive.get("ok", true)) and str(inactive.get("reason", "")) == "runtime_inactive", "inactive Backrooms Runtime is rejected and movement state resets")
	driver.call("reset")
	world_root.free()
	await physics_frame

func _add_cell(runtime: FakeRuntime, cell_key: String, cell: Vector2i) -> Node3D:
	var cell_root := Node3D.new()
	cell_root.name = "Cell_" + cell_key.replace(",", "_")
	cell_root.position = Vector3(float(cell.x) * 8.0, 0.0, float(cell.y) * 8.0)
	cell_root.set_meta("backrooms_cell", cell)
	cell_root.set_meta("backrooms_cell_size", 8.0)
	cell_root.set_meta("backrooms_cell_key", cell_key)
	var navigation_region: NavigationRegion3D = NavigationFactoryScript.create_cell_region(8.0)
	_expect(navigation_region != null, "fake runtime cell creates its navigation region")
	if navigation_region != null:
		navigation_region.enabled = true
		cell_root.add_child(navigation_region)
	runtime.add_child(cell_root)
	runtime.cell_roots[cell_key] = cell_root
	return cell_root

func _add_entity(
	cell_root: Node3D,
	entity_id: String,
	level_id: String,
	spawn_cell: Vector2i,
	world_seed: int,
	local_position: Vector3
) -> Dictionary:
	var entity_root := CharacterBody3D.new()
	entity_root.name = "Entity_" + entity_id
	entity_root.position = local_position
	entity_root.set_meta("backrooms_entity_id", entity_id)
	entity_root.set_meta("spawn_cell", spawn_cell)
	entity_root.set_meta("spawn_world_seed", world_seed)
	_expect(
		CollisionFactoryScript.attach_collision(entity_root, entity_id, true),
		"%s collision proxy configures for its allowed level" % entity_id
	)
	if NavigationFactoryScript.is_mobile_entity(entity_id):
		_expect(
			NavigationFactoryScript.attach_agent(entity_root, entity_id),
			"%s receives a NavigationAgent3D" % entity_id
		)
	cell_root.add_child(entity_root)
	var brain: Node = BrainScript.new()
	brain.name = "AI"
	_expect(bool(brain.call("configure", entity_id, level_id, spawn_cell, world_seed)), "%s brain configures for its allowed level" % entity_id)
	entity_root.add_child(brain)
	return {"root": entity_root, "brain": brain}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

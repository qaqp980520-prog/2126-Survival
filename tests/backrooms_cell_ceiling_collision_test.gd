extends SceneTree

const RuntimeScript = preload("res://systems/BackroomsMazeCellRuntime.gd")
const EntityDirectorScript = preload("res://systems/BackroomsEntityDirector.gd")
const CollisionFactoryScript = preload("res://systems/BackroomsEntityCollisionFactory.gd")

const WORLD_SEED: int = 20261124
const CELL_SIZE: float = 8.0
const PROBE_RADIUS: float = 0.25
const PROBE_TRAVEL: float = 0.8

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(DisplayServer.get_name() != "headless", "Xvfb provides a graphical World3D for production cell geometry")
	var stage := Node3D.new()
	stage.name = "BackroomsCellCeilingCollisionTestStage"
	root.add_child(stage)

	var runtime: Node3D = RuntimeScript.new() as Node3D
	stage.add_child(runtime)
	var prepared: Dictionary = runtime.call(
		"prepare_destination",
		"Level 1",
		WORLD_SEED,
		Vector3.ZERO,
		CELL_SIZE,
		1
	)
	_expect(bool(prepared.get("ok", false)), "production runtime prepares a nine-cell Level 1 window")
	if not bool(prepared.get("ok", false)):
		_finish(stage)
		return

	var loaded_keys_value: Variant = runtime.call("get_loaded_cell_keys")
	if not (loaded_keys_value is Array):
		_expect(false, "production runtime exposes its loaded cell keys")
		_finish(stage)
		return
	var loaded_keys: Array = loaded_keys_value
	_expect(loaded_keys.size() == 9, "ceiling geometry is built for all nine loaded cells")

	for key_value in loaded_keys:
		var key: String = str(key_value)
		var cell_root: Node3D = runtime.call("get_cell_root", key) as Node3D
		_assert_cell_enclosure(cell_root, key)

	var origin_root: Node3D = runtime.call("get_cell_root", "0,0") as Node3D
	if origin_root == null:
		_expect(false, "origin cell exists for the ceiling collision probe")
		_finish(stage)
		return
	var origin_collision: StaticBody3D = origin_root.get_node_or_null("WorldCollision") as StaticBody3D
	if origin_collision == null:
		_expect(false, "origin cell exposes its production WorldCollision body")
		_finish(stage)
		return

	var probe := CharacterBody3D.new()
	probe.name = "CeilingCollisionProbe"
	probe.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	probe.collision_layer = 1 << 3
	probe.collision_mask = RuntimeScript.WORLD_GEOMETRY_LAYER
	probe.safe_margin = 0.02
	var probe_shape := CollisionShape3D.new()
	var probe_sphere := SphereShape3D.new()
	probe_sphere.radius = PROBE_RADIUS
	probe_shape.shape = probe_sphere
	probe.add_child(probe_shape)
	stage.add_child(probe)

	var start_local := Vector3(0.0, RuntimeScript.WALL_HEIGHT - 0.55, 0.0)
	probe.global_position = origin_root.to_global(start_local)
	await physics_frame
	var staged_collision: KinematicCollision3D = probe.move_and_collide(
		Vector3.UP * PROBE_TRAVEL,
		false,
		probe.safe_margin,
		false
	)
	_expect(staged_collision == null, "prepared destination keeps ceiling collision disabled")
	_expect(
		probe.global_position.y > RuntimeScript.WALL_HEIGHT + 0.1,
		"staged probe passes through the inactive ceiling before destination activation"
	)

	probe.global_position = origin_root.to_global(start_local)
	await physics_frame
	_expect(bool(runtime.call("activate_destination")), "prepared destination activates its production geometry")
	await physics_frame

	for key_value in loaded_keys:
		var key: String = str(key_value)
		var cell_root: Node3D = runtime.call("get_cell_root", key) as Node3D
		var world_collision: StaticBody3D = null
		if cell_root != null:
			world_collision = cell_root.get_node_or_null("WorldCollision") as StaticBody3D
		_expect(
			world_collision != null and world_collision.collision_layer == RuntimeScript.WORLD_GEOMETRY_LAYER,
			"activated cell %s enables its floor, wall and ceiling collision together" % key
		)

	var active_collision: KinematicCollision3D = probe.move_and_collide(
		Vector3.UP * PROBE_TRAVEL,
		false,
		probe.safe_margin,
		false
	)
	_expect(active_collision != null, "active production ceiling blocks upward CharacterBody3D movement")
	if active_collision != null:
		_expect(
			active_collision.get_collider() == origin_collision,
			"ceiling collision is owned by the cell's WorldCollision body"
		)
	_expect(
		probe.global_position.y <= RuntimeScript.WALL_HEIGHT - PROBE_RADIUS + 0.05,
		"collision keeps the probe fully below the ceiling underside"
	)
	print(
		"CEILING_COLLISION_PROBE: final_y=%.3f ceiling_underside=%.3f"
		% [probe.global_position.y, RuntimeScript.WALL_HEIGHT]
	)

	# Shift the live window one cell east. Six existing roots must be retained,
	# three new roots must be staged and activated, and the west column retired.
	var retained_root: Node3D = runtime.call("get_cell_root", "0,0") as Node3D
	var retired_root: Node3D = runtime.call("get_cell_root", "-1,0") as Node3D
	_expect(retained_root != null, "active window has a root that should survive the shift")
	_expect(retired_root != null, "active window has a west-edge root that should be retired")
	var shift_result: Dictionary = runtime.call(
		"sync_to_world_position",
		Vector3(CELL_SIZE, 0.0, 0.0)
	)
	_expect(bool(shift_result.get("ok", false)), "active runtime commits an eastward streaming-window shift")
	if not bool(shift_result.get("ok", false)):
		_finish(stage)
		return
	_expect(
		shift_result.get("center_cell", Vector2i.ZERO) == Vector2i(1, 0),
		"streaming shift commits center cell (1, 0)"
	)
	_expect(int(shift_result.get("load_count", -1)) == 3, "eastward shift stages exactly three new cells")
	_expect(int(shift_result.get("keep_count", -1)) == 6, "eastward shift retains six overlapping cells")
	_expect(int(shift_result.get("unload_count", -1)) == 3, "eastward shift retires exactly three west-edge cells")
	_expect(
		runtime.call("get_cell_root", "0,0") == retained_root,
		"overlapping origin cell keeps the same production root across the shift"
	)
	_expect(not is_instance_valid(retired_root), "retired west-edge cell root is freed after the shift commits")
	_expect(runtime.call("get_cell_root", "-1,0") == null, "retired west-edge cell is absent from the runtime root map")

	var shifted_keys_value: Variant = runtime.call("get_loaded_cell_keys")
	if not (shifted_keys_value is Array):
		_expect(false, "shifted runtime exposes its committed cell keys")
		_finish(stage)
		return
	var shifted_keys: Array = shifted_keys_value
	_expect(shifted_keys.size() == 9, "shifted runtime still owns exactly nine loaded cells")
	_expect(
		shifted_keys.has("2,0") and not shifted_keys.has("-1,0"),
		"shifted loaded window contains the new east column and excludes the retired west column"
	)
	for key_value in shifted_keys:
		var key: String = str(key_value)
		var shifted_root: Node3D = runtime.call("get_cell_root", key) as Node3D
		var shifted_collision_body: StaticBody3D = null
		if shifted_root != null:
			shifted_collision_body = shifted_root.get_node_or_null("WorldCollision") as StaticBody3D
		_expect(
			shifted_collision_body != null
			and shifted_collision_body.collision_layer == RuntimeScript.WORLD_GEOMETRY_LAYER,
			"shifted active cell %s keeps floor, wall and ceiling collision enabled" % key
		)

	var east_root: Node3D = runtime.call("get_cell_root", "2,0") as Node3D
	if east_root == null:
		_expect(false, "new east-edge cell exists for the post-shift ceiling probe")
		_finish(stage)
		return
	var east_collision: StaticBody3D = east_root.get_node_or_null("WorldCollision") as StaticBody3D
	_expect(
		east_collision != null and east_collision.collision_layer == RuntimeScript.WORLD_GEOMETRY_LAYER,
		"newly streamed east-edge cell activates its production ceiling collision"
	)
	var east_ceiling: CollisionShape3D = east_collision.get_node_or_null("CeilingCollision") as CollisionShape3D if east_collision != null else null
	_expect(east_ceiling != null, "newly streamed east-edge cell contains its ceiling collision shape")
	probe.global_position = east_root.to_global(start_local)
	await physics_frame
	var shifted_collision: KinematicCollision3D = probe.move_and_collide(
		Vector3.UP * PROBE_TRAVEL,
		false,
		probe.safe_margin,
		false
	)
	_expect(
		shifted_collision != null,
		"newly streamed active ceiling blocks upward CharacterBody3D movement"
	)
	if shifted_collision != null and east_collision != null:
		_expect(
			shifted_collision.get_collider() == east_collision,
			"post-shift ceiling collision is owned by the new cell's WorldCollision body"
		)
	_expect(
		probe.global_position.y <= RuntimeScript.WALL_HEIGHT - PROBE_RADIUS + 0.05,
		"post-shift collision keeps the probe below the ceiling underside"
	)
	print(
		"SHIFTED_CEILING_COLLISION_PROBE: final_y=%.3f ceiling_underside=%.3f"
		% [probe.global_position.y, RuntimeScript.WALL_HEIGHT]
	)

	runtime.call("deactivate_destination")
	await _test_level5_deathmoth_collision(stage)
	_finish(stage)


func _test_level5_deathmoth_collision(stage: Node3D) -> void:
	var deathmoth_cell := Vector2i(0, 2)
	var allowed_entities: Array[String] = EntityDirectorScript.get_allowed_entities("Level 5")
	_expect(
		allowed_entities.size() == 1 and allowed_entities[0] == "deathmoth",
		"modern Level 5 production roster contains only Deathmoth"
	)
	var deterministic_spawns: Array[String] = EntityDirectorScript.get_cell_spawns("Level 5", deathmoth_cell)
	_expect(
		deterministic_spawns.has("deathmoth"),
		"Level 5 fixture deterministically selects a Deathmoth in cell (0,2)"
	)

	var deathmoth_runtime: Node3D = RuntimeScript.new() as Node3D
	stage.add_child(deathmoth_runtime)
	var prepared: Dictionary = deathmoth_runtime.call(
		"prepare_destination",
		"Level 5",
		WORLD_SEED,
		Vector3.ZERO,
		CELL_SIZE,
		2
	)
	_expect(bool(prepared.get("ok", false)), "production runtime prepares a 25-cell Level 5 window")
	if not bool(prepared.get("ok", false)):
		return
	_expect(
		int(deathmoth_runtime.call("get_loaded_cell_count")) == 25,
		"Level 5 radius-two window contains all 25 production cells"
	)

	var deathmoth_cell_root: Node3D = deathmoth_runtime.call("get_cell_root", "0,2") as Node3D
	if deathmoth_cell_root == null:
		_expect(false, "deterministic Level 5 Deathmoth spawn cell has a production root")
		deathmoth_runtime.call("deactivate_destination")
		return
	var deathmoth: CharacterBody3D = null
	for child in deathmoth_cell_root.get_children():
		if child is CharacterBody3D and str(child.get_meta("backrooms_entity_id", "")) == "deathmoth":
			deathmoth = child as CharacterBody3D
	_expect(deathmoth != null, "production Level 5 cell builds the deterministic Deathmoth CharacterBody3D")
	if deathmoth == null:
		deathmoth_runtime.call("deactivate_destination")
		return

	var deathmoth_shape: CollisionShape3D = deathmoth.get_node_or_null("EntityCollision") as CollisionShape3D
	var world_collision: StaticBody3D = deathmoth_cell_root.get_node_or_null("WorldCollision") as StaticBody3D
	_expect(
		deathmoth_shape != null and deathmoth_shape.shape is SphereShape3D,
		"production Deathmoth owns its spherical collision proxy"
	)
	_expect(
		deathmoth.collision_layer == 0 and deathmoth.collision_mask == 0,
		"staged Level 5 Deathmoth collision remains disabled before activation"
	)
	_expect(
		deathmoth_shape != null and deathmoth_shape.disabled,
		"staged Deathmoth collision shape remains disabled before activation"
	)
	_expect(
		world_collision != null and world_collision.collision_layer == 0,
		"staged Level 5 ceiling collision remains disabled before activation"
	)
	_expect(
		bool(deathmoth_runtime.call("activate_destination")),
		"production Level 5 destination activates its Deathmoth and room geometry"
	)
	await physics_frame
	_expect(
		deathmoth.collision_layer == CollisionFactoryScript.ENTITY_COLLISION_LAYER
		and deathmoth.collision_mask == CollisionFactoryScript.ENTITY_COLLISION_MASK,
		"active Deathmoth uses the production entity/player/world collision contract"
	)
	_expect(
		deathmoth_shape != null and not deathmoth_shape.disabled,
		"active Deathmoth enables its production collision shape"
	)
	_expect(
		world_collision != null and world_collision.collision_layer == RuntimeScript.WORLD_GEOMETRY_LAYER,
		"active Level 5 cell enables its ceiling world-geometry collision"
	)

	var deathmoth_spawn_position: Vector3 = deathmoth.global_position
	var ceiling_hit: KinematicCollision3D = deathmoth.move_and_collide(
		Vector3.UP * 2.0,
		false,
		deathmoth.safe_margin,
		false
	)
	_expect(ceiling_hit != null, "flying Deathmoth is physically blocked by the active production ceiling")
	if ceiling_hit != null and world_collision != null:
		_expect(
			ceiling_hit.get_collider() == world_collision,
			"Deathmoth ceiling contact is owned by its cell WorldCollision body"
		)
	_expect(
		deathmoth.global_position.y <= RuntimeScript.WALL_HEIGHT - 0.38 + 0.05,
		"Deathmoth sphere remains below the 3.2 m ceiling underside"
	)
	print(
		"DEATHMOTH_CEILING_PROBE: final_y=%.3f ceiling_underside=%.3f"
		% [deathmoth.global_position.y, RuntimeScript.WALL_HEIGHT]
	)

	deathmoth.global_position = deathmoth_spawn_position
	await physics_frame
	var player_probe := CharacterBody3D.new()
	player_probe.name = "DeathmothPlayerCollisionProbe"
	player_probe.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	player_probe.collision_layer = CollisionFactoryScript.PLAYER_COLLISION_LAYER
	player_probe.collision_mask = CollisionFactoryScript.ENTITY_COLLISION_LAYER
	player_probe.safe_margin = 0.02
	var player_shape := CollisionShape3D.new()
	var player_sphere := SphereShape3D.new()
	player_sphere.radius = 0.25
	player_shape.shape = player_sphere
	player_probe.add_child(player_shape)
	stage.add_child(player_probe)
	player_probe.global_position = deathmoth_spawn_position + Vector3(-1.0, 0.0, 0.0)
	await physics_frame
	var player_hit: KinematicCollision3D = player_probe.move_and_collide(
		Vector3.RIGHT * 2.0,
		false,
		player_probe.safe_margin,
		false
	)
	_expect(player_hit != null, "player-layer probe physically collides with the production Deathmoth")
	if player_hit != null:
		_expect(
			player_hit.get_collider() == deathmoth,
			"player-layer collision resolves to the live Deathmoth CharacterBody3D"
		)
	print(
		"DEATHMOTH_PLAYER_PROBE: hit=%s"
		% [str(player_hit != null and player_hit.get_collider() == deathmoth)]
	)
	player_probe.queue_free()
	deathmoth_runtime.call("deactivate_destination")


func _assert_cell_enclosure(cell_root: Node3D, cell_key: String) -> void:
	_expect(cell_root != null, "loaded cell %s has a production root" % cell_key)
	if cell_root == null:
		return

	var ceiling_mesh: MeshInstance3D = cell_root.get_node_or_null("Ceiling") as MeshInstance3D
	_expect(ceiling_mesh != null, "loaded cell %s owns a Ceiling MeshInstance3D" % cell_key)
	if ceiling_mesh == null:
		return
	var ceiling_box: BoxMesh = ceiling_mesh.mesh as BoxMesh
	_expect(ceiling_box != null, "loaded cell %s ceiling uses a BoxMesh" % cell_key)
	if ceiling_box != null:
		_expect(
			ceiling_box.size.is_equal_approx(Vector3(CELL_SIZE, RuntimeScript.CEILING_THICKNESS, CELL_SIZE)),
			"loaded cell %s ceiling covers the complete cell footprint" % cell_key
		)
	_expect(
		ceiling_mesh.position.is_equal_approx(
			Vector3(0.0, RuntimeScript.WALL_HEIGHT + RuntimeScript.CEILING_THICKNESS * 0.5, 0.0)
		),
		"loaded cell %s ceiling underside aligns with the wall tops" % cell_key
	)
	_expect(
		ceiling_mesh.material_override is StandardMaterial3D,
		"loaded cell %s ceiling has an explicit production material" % cell_key
	)

	var world_collision: StaticBody3D = cell_root.get_node_or_null("WorldCollision") as StaticBody3D
	_expect(world_collision != null, "loaded cell %s owns its production collision body" % cell_key)
	if world_collision == null:
		return
	_expect(world_collision.collision_layer == 0, "prepared cell %s keeps all world collision disabled" % cell_key)
	var ceiling_shape: CollisionShape3D = world_collision.get_node_or_null("CeilingCollision") as CollisionShape3D
	_expect(ceiling_shape != null, "loaded cell %s has a named ceiling collision shape" % cell_key)
	if ceiling_shape != null:
		var ceiling_box_shape: BoxShape3D = ceiling_shape.shape as BoxShape3D
		_expect(ceiling_box_shape != null, "loaded cell %s ceiling collision uses a BoxShape3D" % cell_key)
		if ceiling_box_shape != null:
			_expect(
				ceiling_box_shape.size.is_equal_approx(Vector3(CELL_SIZE, RuntimeScript.CEILING_THICKNESS, CELL_SIZE)),
				"loaded cell %s ceiling collision matches its visual bounds" % cell_key
			)
		_expect(
			ceiling_shape.position.is_equal_approx(ceiling_mesh.position),
			"loaded cell %s ceiling collision matches the visual transform" % cell_key
		)

	var light: OmniLight3D = cell_root.get_node_or_null("BackroomsCeilingLight") as OmniLight3D
	if light != null:
		var ceiling_bottom: float = ceiling_mesh.position.y - RuntimeScript.CEILING_THICKNESS * 0.5
		_expect(light.position.y < ceiling_bottom, "cell %s keeps its ceiling light below the ceiling surface" % cell_key)

	var open_edges_value: Variant = cell_root.get_meta("backrooms_open_edges", null)
	_expect(open_edges_value is Dictionary, "loaded cell %s preserves its maze edge descriptor" % cell_key)
	if open_edges_value is Dictionary:
		var open_edges: Dictionary = open_edges_value
		for edge in ["north", "east", "south", "west"]:
			var wall: Node = cell_root.get_node_or_null("Wall_" + edge.capitalize())
			var edge_is_open: bool = bool(open_edges.get(edge, false))
			_expect(
				(wall == null) == edge_is_open,
				"loaded cell %s preserves the %s doorway while adding a ceiling" % [cell_key, edge]
			)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
		return
	failures.append(message)
	push_error("FAIL: " + message)


func _finish(stage: Node) -> void:
	if stage != null and is_instance_valid(stage):
		stage.queue_free()
	if failures.is_empty():
		print("Backrooms cell ceiling geometry and collision tests passed.")
		quit(0)
		return
	push_error("Backrooms cell ceiling geometry and collision tests failed: %d" % failures.size())
	quit(1)

extends SceneTree

const RuntimeScript = preload("res://systems/BackroomsMazeCellRuntime.gd")

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

	runtime.call("deactivate_destination")
	_finish(stage)


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

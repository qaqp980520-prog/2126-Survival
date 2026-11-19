extends SceneTree

const NavigationFactoryScript = preload("res://systems/BackroomsCellNavigationFactory.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(
		NavigationFactoryScript.create_cell_region(1.0) == null,
		"cell navigation rejects a cell that cannot contain the safe inset"
	)
	var region: NavigationRegion3D = NavigationFactoryScript.create_cell_region(8.0)
	_expect(region != null, "cell navigation creates a region for a valid eight-metre cell")
	if region == null:
		_finish()
		return
	_expect(not region.enabled, "new cell navigation regions start disabled")
	_expect(not region.use_edge_connections, "cell regions never auto-connect across cell boundaries")
	_expect(region.navigation_layers == NavigationFactoryScript.NAVIGATION_LAYER, "cell navigation uses its dedicated layer")
	_expect(region.navigation_mesh != null, "cell region owns a procedural NavigationMesh")
	if region.navigation_mesh != null:
		var vertices: PackedVector3Array = region.navigation_mesh.vertices
		_expect(vertices.size() == 4, "production cell navigation is a single deterministic floor polygon")
		for vertex in vertices:
			_expect(
				absf(vertex.x) <= 3.35 and absf(vertex.z) <= 3.35,
				"navigation polygon remains inside the physical cell safe extent"
			)
	var body := CharacterBody3D.new()
	_expect(NavigationFactoryScript.attach_agent(body, "hound"), "mobile Hound receives a NavigationAgent3D")
	var agent := body.get_node_or_null("NavigationAgent") as NavigationAgent3D
	_expect(agent != null, "mobile entity agent is attached under its CharacterBody3D")
	if agent != null:
		_expect(not agent.avoidance_enabled, "agent avoidance stays disabled until a separate bounded avoidance design exists")
		_expect(absf(agent.radius - 0.32) <= 0.0001, "Hound navigation radius matches its collision proxy")
	_expect(not NavigationFactoryScript.attach_agent(body, "hound"), "duplicate NavigationAgent3D attachment is rejected")
	var anchored := CharacterBody3D.new()
	_expect(not NavigationFactoryScript.attach_agent(anchored, "window"), "anchored Window entities do not receive navigation agents")

	var world_root := Node3D.new()
	root.add_child(world_root)
	world_root.add_child(region)
	body.position = Vector3(-2.0, 0.55, 0.0)
	world_root.add_child(body)
	region.enabled = true
	await physics_frame
	await physics_frame
	if agent != null:
		var target := Vector3(2.0, NavigationFactoryScript.NAVIGATION_SURFACE_Y, 0.0)
		_expect(
			NavigationFactoryScript.set_agent_target(agent, target, 0.5),
			"active NavigationAgent3D accepts a finite target"
		)
		_expect(agent.has_meta("backrooms_navigation_target_position"), "first target assignment stores a target cache without missing-meta diagnostics")
		var path_result: Dictionary = NavigationFactoryScript.get_next_waypoint(agent)
		_expect(bool(path_result.get("ok", false)), "headless NavigationServer returns a live cell-local path")
		_expect(int(path_result.get("path_point_count", 0)) >= 2, "live path contains a start and destination point")
	_expect(not NavigationFactoryScript.set_agent_target(agent, Vector3(NAN, 0.0, 0.0), 0.5), "navigation rejects a non-finite target")
	_expect(NavigationFactoryScript.set_region_enabled(world_root, false), "cell navigation region can be disabled during runtime deactivation")
	_expect(not region.enabled, "disabled cell region leaves the navigation map")

	world_root.free()
	if is_instance_valid(anchored):
		anchored.free()
	await physics_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("Backrooms cell navigation factory tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

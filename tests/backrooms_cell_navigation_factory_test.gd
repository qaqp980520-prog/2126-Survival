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
	body.position = Vector3(-2.0, 0.55, 0.0)
	_expect(NavigationFactoryScript.attach_agent(body, "hound"), "mobile Hound receives a NavigationAgent3D")
	var navigation_anchor := body.get_node_or_null("NavigationAnchor") as Node3D
	var agent := NavigationFactoryScript.get_agent(body)
	_expect(agent != null, "mobile entity agent is attached under its CharacterBody3D")
	_expect(navigation_anchor != null, "mobile agent receives a Node3D navigation anchor")
	if agent != null and navigation_anchor != null:
		_expect(
			absf(navigation_anchor.position.y + body.position.y - NavigationFactoryScript.NAVIGATION_SURFACE_Y) <= 0.0001,
			"NavigationAgent3D parent origin is aligned to the cell floor independently of capsule center height"
		)
		_expect(not agent.avoidance_enabled, "agent avoidance stays disabled until a separate bounded avoidance design exists")
		_expect(absf(agent.path_desired_distance - 0.2) <= 0.0001, "waypoint acceptance is tight enough to avoid cutting obstacle corners")
		_expect(absf(agent.radius - 0.32) <= 0.0001, "Hound navigation radius matches its collision proxy")
	_expect(not NavigationFactoryScript.attach_agent(body, "hound"), "duplicate NavigationAgent3D attachment is rejected")
	var anchored := CharacterBody3D.new()
	_expect(not NavigationFactoryScript.attach_agent(anchored, "window"), "anchored Window entities do not receive navigation agents")

	var world_root := Node3D.new()
	root.add_child(world_root)
	world_root.add_child(region)
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
		_expect(
			absf(agent.target_desired_distance - NavigationFactoryScript.MIN_TARGET_DESIRED_DISTANCE) <= 0.0001,
			"ordinary pursuit retains the 0.5 m minimum target distance"
		)
		_expect(
			NavigationFactoryScript.set_agent_target(agent, target, 0.05, true),
			"edge-precision navigation accepts a 0.05 m transfer target"
		)
		_expect(
			absf(agent.target_desired_distance - 0.05) <= 0.0001,
			"edge-precision navigation applies the narrow 0.05 m target distance"
		)
		_expect(
			not NavigationFactoryScript.set_agent_target(agent, target, 0.2, true),
			"edge-precision mode rejects a loose target distance above 0.1 m"
		)
		_expect(
			NavigationFactoryScript.set_agent_target(agent, target, 0.05),
			"ordinary navigation can leave edge-precision mode"
		)
		_expect(
			absf(agent.target_desired_distance - NavigationFactoryScript.MIN_TARGET_DESIRED_DISTANCE) <= 0.0001,
			"leaving edge-precision mode restores the ordinary 0.5 m minimum"
		)
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

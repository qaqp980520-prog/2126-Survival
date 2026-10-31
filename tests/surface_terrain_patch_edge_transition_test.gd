extends SceneTree
const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const SIDES: Array[String] = ["East","West","North","South"]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var patch: Node3D = PatchScript.new()
	root.add_child(patch)
	await process_frame
	_expect(patch != null and patch.is_inside_tree(),"terrain patch builds inside the scene tree")
	for height_level in range(PatchScript.MAX_HEIGHT_LEVEL+1):
		var state := {
			"height_level":height_level,
			"surface_type":PatchScript.SURFACE_TYPES[posmod(height_level,PatchScript.SURFACE_TYPES.size())],
			"revision":height_level
		}
		_expect(bool(patch.call("apply_world_object_state",state)),"height level %d applies" % height_level)
		var expected_height: float = 0.05+float(height_level)*0.25
		var profile: Dictionary = patch.call("get_edge_ramp_profile")
		_expect(is_equal_approx(float(profile.get("rise",-1.0)),expected_height),"profile rise matches saved terrain height")
		_expect(is_equal_approx(float(profile.get("run",-1.0)),PatchScript.EDGE_RAMP_RUN),"all edge ramps use the same run")
		var slope_length: float = sqrt(PatchScript.EDGE_RAMP_RUN*PatchScript.EDGE_RAMP_RUN+expected_height*expected_height)
		_expect(is_equal_approx(float(profile.get("slope_length",-1.0)),slope_length),"visual slope length preserves exact horizontal run and vertical rise")
		_expect(is_equal_approx(float(profile.get("collision_thickness",-1.0)),PatchScript.EDGE_RAMP_COLLISION_THICKNESS),"collision ramp thickness is explicit and stable")
		await physics_frame
		# Let newly added/reconfigured edge bodies finish their physics-server registration before ray queries.
		await physics_frame
		var space_state: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
		var body := patch.get_node_or_null("TerrainCollisionBody") as StaticBody3D
		_expect(body != null,"terrain collision body exists")
		if body == null:
			continue
		for side in SIDES:
			var ramp_body := patch.get_node_or_null("TerrainRampBody_"+side) as StaticBody3D
			_expect(ramp_body != null,"%s ramp has an independent static collision body" % side)
			if ramp_body == null:
				continue
			_expect(ramp_body != body and ramp_body.collision_layer == 1 and ramp_body.collision_mask == 0,"%s ramp body is isolated on the world collision layer" % side)
			var ramp := ramp_body.get_node_or_null("TerrainRampCollision_"+side) as CollisionShape3D
			_expect(ramp != null,"%s ramp collision exists" % side)
			if ramp == null:
				continue
			var box := ramp.shape as BoxShape3D
			_expect(box != null,"%s ramp uses a stable BoxShape3D collision slab" % side)
			if box == null:
				continue
			var expected_size := Vector3(slope_length,PatchScript.EDGE_RAMP_COLLISION_THICKNESS,PatchScript.PATCH_SIZE) if side == "East" or side == "West" else Vector3(PatchScript.PATCH_SIZE,PatchScript.EDGE_RAMP_COLLISION_THICKNESS,slope_length)
			_expect(box.size.distance_to(expected_size) <= 0.0001,"%s ramp collision dimensions match its slope and width" % side)
			var expected_rotation: Vector3 = _expected_rotation(side,expected_height)
			_expect(ramp.rotation.distance_to(expected_rotation) <= 0.0001,"%s collision slab rotation matches the visual slope" % side)
			var top_center: Vector3 = ramp.transform*Vector3(0.0,box.size.y*0.5,0.0)
			_expect(absf(top_center.y-expected_height*0.5) <= 0.0001,"%s collision top face is centered on the visual slope" % side)
			var local_x_values: Array[float] = [-box.size.x*0.5,box.size.x*0.5]
			var local_z_values: Array[float] = [-box.size.z*0.5,box.size.z*0.5]
			var top_points: Array[Vector3] = []
			for local_x in local_x_values:
				for local_z in local_z_values:
					top_points.append(ramp.transform*Vector3(local_x,box.size.y*0.5,local_z))
			var min_y: float = INF
			var max_y: float = -INF
			var min_x: float = INF
			var max_x: float = -INF
			var min_z: float = INF
			var max_z: float = -INF
			for point in top_points:
				min_y=minf(min_y,point.y)
				max_y=maxf(max_y,point.y)
				min_x=minf(min_x,point.x)
				max_x=maxf(max_x,point.x)
				min_z=minf(min_z,point.z)
				max_z=maxf(max_z,point.z)
			_expect(absf(min_y) <= 0.001 and absf(max_y-expected_height) <= 0.001,"%s top face joins ground to patch top" % side)
			if side == "East" or side == "West":
				_expect(absf((max_x-min_x)-PatchScript.EDGE_RAMP_RUN) <= 0.001,"%s top face spans configured horizontal run" % side)
				_expect(absf((max_z-min_z)-PatchScript.PATCH_SIZE) <= 0.001,"%s top face spans full patch width" % side)
			else:
				_expect(absf((max_z-min_z)-PatchScript.EDGE_RAMP_RUN) <= 0.001,"%s top face spans configured vertical run" % side)
				_expect(absf((max_x-min_x)-PatchScript.PATCH_SIZE) <= 0.001,"%s top face spans full patch width" % side)
			var inner_edge: float = PatchScript.PATCH_SIZE*0.5
			var outer_edge: float = inner_edge+PatchScript.EDGE_RAMP_RUN
			var inner_top_found: bool = false
			var outer_ground_found: bool = false
			for point in top_points:
				var edge_value: float = point.x if side == "East" or side == "West" else point.z
				var inner_value: float = inner_edge if side == "East" or side == "South" else -inner_edge
				var outer_value: float = outer_edge if side == "East" or side == "South" else -outer_edge
				if absf(edge_value-inner_value) <= 0.001 and absf(point.y-expected_height) <= 0.001:
					inner_top_found=true
				if absf(edge_value-outer_value) <= 0.001 and absf(point.y) <= 0.001:
					outer_ground_found=true
			_expect(inner_top_found,"%s ramp meets raised patch edge" % side)
			_expect(outer_ground_found,"%s ramp meets surrounding ground" % side)
			for fraction_value in [0.25,0.5,0.75]:
				var fraction: float = float(fraction_value)
				var sample := Vector3.ZERO
				match side:
					"East": sample=Vector3(inner_edge+PatchScript.EDGE_RAMP_RUN*fraction,0.0,0.0)
					"West": sample=Vector3(-inner_edge-PatchScript.EDGE_RAMP_RUN*fraction,0.0,0.0)
					"North": sample=Vector3(0.0,0.0,-inner_edge-PatchScript.EDGE_RAMP_RUN*fraction)
					"South": sample=Vector3(0.0,0.0,inner_edge+PatchScript.EDGE_RAMP_RUN*fraction)
				var ray := PhysicsRayQueryParameters3D.create(
					Vector3(sample.x,expected_height+1.0,sample.z),
					Vector3(sample.x,-0.25,sample.z)
				)
				ray.collision_mask=1
				ray.collide_with_areas=false
				ray.collide_with_bodies=true
				var hit: Dictionary = space_state.intersect_ray(ray)
				_expect(not hit.is_empty(),"%s ramp has a physics hit at sample %.2f" % [side,fraction])
				if not hit.is_empty():
					var hit_position: Vector3 = hit.get("position",Vector3.ZERO)
					var expected_y: float = expected_height*(1.0-fraction)
					_expect(absf(hit_position.y-expected_y) <= 0.01,"%s ramp collision follows its linear visual slope at sample %.2f" % [side,fraction])
	patch.queue_free()
	await process_frame
	if failures.is_empty():
		print("Surface terrain patch edge transition tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: "+failure)
		quit(1)

func _expected_rotation(side: String,height: float) -> Vector3:
	var angle: float = atan(height/PatchScript.EDGE_RAMP_RUN)
	match side:
		"East": return Vector3(0.0,0.0,-angle)
		"West": return Vector3(0.0,0.0,angle)
		"North": return Vector3(-angle,0.0,0.0)
		"South": return Vector3(angle,0.0,0.0)
	return Vector3.ZERO

func _expect(condition: bool,description: String) -> void:
	if condition:
		print("PASS: "+description)
	else:
		failures.append(description)
		push_error("FAIL: "+description)

extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")
const PATCH_SIZE: float = 2.0
const POSITION_TOLERANCE: float = 0.025
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_three_by_three_checkerboard_multi_junctions()
	await _test_compatible_and_incompatible_adjacent_junctions_fall_back_together()
	if failures.is_empty():
		print("Three-by-three terrain multi-junction corner cap regression passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_three_by_three_checkerboard_multi_junctions() -> void:
	var holder := Node3D.new()
	holder.name = "ThreeByThreeCornerCapTestRoot"
	root.add_child(holder)

	var patches: Array[Node3D] = []
	var stable_ids: Dictionary = {}
	var patches_by_id: Dictionary = {}
	for z in range(3):
		for x in range(3):
			var patch: Node3D = PatchScript.new()
			patch.name = "Patch_%d_%d" % [x, z]
			patch.position = Vector3(float(x) * PATCH_SIZE, 0.0, float(z) * PATCH_SIZE)
			holder.add_child(patch)
			var stable_id: String = "multi/%d_%d" % [x, z]
			patches.append(patch)
			stable_ids[patch.get_instance_id()] = stable_id
			patches_by_id[stable_id] = patch

	await process_frame
	await physics_frame

	for z in range(3):
		for x in range(3):
			var level: int = 2 if (x + z) % 2 == 0 else 0
			var state := {"height_level": level, "surface_type": "metal" if level == 2 else "soil", "revision": 1}
			var patch_id: String = "multi/%d_%d" % [x, z]
			_expect(bool(patches_by_id[patch_id].call("apply_world_object_state", state)), patch_id + " accepts checkerboard terrain state")

	var binding: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	_expect(bool(binding.get("ok", false)), "nine patches bind into a complete 3x3 adjacency window")
	_expect(int(binding.get("pair_count", -1)) == 12, "3x3 window exposes all twelve cardinal shared edges")
	if not bool(binding.get("ok", false)):
		holder.queue_free()
		await process_frame
		return

	var manager: Node3D = ManagerScript.new()
	holder.add_child(manager)
	var descriptors: Dictionary = binding.get("descriptors", {})
	var report: Dictionary = manager.call("sync_transitions", descriptors, patches_by_id)
	await process_frame
	await physics_frame

	_expect(bool(report.get("ok", false)), "manager accepts four compatible interior junctions")
	_expect(int(report.get("active_count", -1)) == 12, "all twelve shared edge ramps are staged")
	_expect(int(report.get("blocked_count", -1)) == 0, "compatible multi-junction layout has no fallback edges")
	_expect(int(report.get("corner_cap_count", -1)) == 16, "four interior junctions produce sixteen per-patch corner caps")
	_expect(int(manager.call("get_corner_cap_count")) == 16, "manager owns all sixteen committed cap bodies")
	_expect(int(manager.call("get_transition_count")) == 12, "manager owns all twelve committed edge bodies")
	if not bool(report.get("ok", false)):
		holder.queue_free()
		await process_frame
		return

	var cap_body_ids: Dictionary = {}
	var midpoint_height: float = 0.30
	for junction_z in [1, 3]:
		for junction_x in [1, 3]:
			var west_x: int = int(float(junction_x - 1) / 2.0)
			var east_x: int = west_x + 1
			var north_z: int = int(float(junction_z - 1) / 2.0)
			var south_z: int = north_z + 1
			var corner_cases: Array[Dictionary] = [
				{"x": west_x, "z": north_z, "corner": "south_east", "sx": 1.0, "sz": 1.0},
				{"x": east_x, "z": north_z, "corner": "south_west", "sx": -1.0, "sz": 1.0},
				{"x": west_x, "z": south_z, "corner": "north_east", "sx": 1.0, "sz": -1.0},
				{"x": east_x, "z": south_z, "corner": "north_west", "sx": -1.0, "sz": -1.0}
			]
			for entry in corner_cases:
				var stable_id: String = "multi/%d_%d" % [int(entry["x"]), int(entry["z"])]
				var corner: String = str(entry["corner"])
				var cap_body: StaticBody3D = manager.call("get_corner_cap_body", stable_id, corner)
				_expect(is_instance_valid(cap_body), stable_id + " owns " + corner + " cap")
				if not is_instance_valid(cap_body):
					continue
				cap_body_ids[cap_body.get_instance_id()] = true
				_expect(cap_body.collision_layer == 1, stable_id + " cap collision is enabled after commit")
				var collision := cap_body.get_node_or_null("CornerCapCollision") as CollisionShape3D
				_expect(collision != null and collision.shape is ConcavePolygonShape3D, stable_id + " cap has a concave collision shell")
				if collision != null and collision.shape is ConcavePolygonShape3D:
					var faces: PackedVector3Array = (collision.shape as ConcavePolygonShape3D).get_faces()
					_expect(faces.size() == 36, stable_id + " cap has a closed 36-vertex collision shell")

				var patch: Node3D = patches_by_id[stable_id]
				var sign_x: float = float(entry["sx"])
				var sign_z: float = float(entry["sz"])
				var sample_position: Vector3 = patch.global_position + Vector3(
					sign_x * (PATCH_SIZE * 0.5 - 0.375),
					0.0,
					sign_z * (PATCH_SIZE * 0.5 - 0.375)
				)
				var query := PhysicsRayQueryParameters3D.create(
					sample_position + Vector3.UP * 2.0,
					sample_position - Vector3.UP * 1.0,
					1
				)
				var hit: Dictionary = holder.get_world_3d().direct_space_state.intersect_ray(query)
				_expect(not hit.is_empty(), stable_id + " " + corner + " cap center is raycastable")
				if not hit.is_empty():
					_expect(hit.get("collider") == cap_body, stable_id + " " + corner + " ray hits its own cap")
					var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
					var expected_height: float = patch.global_position.y + (float(patch.call("get_top_height")) + midpoint_height) * 0.5
					_expect(absf(hit_position.y - expected_height) <= POSITION_TOLERANCE, stable_id + " " + corner + " cap center height matches its triangulated surface")

	_expect(cap_body_ids.size() == 16, "all sixteen cap bodies have unique instance ownership")

	var single_trim_count: int = 0
	var double_trim_count: int = 0
	for edge_key in descriptors.keys():
		var edge_body: StaticBody3D = manager.call("get_transition_body", str(edge_key))
		_expect(is_instance_valid(edge_body), "shared edge body exists for " + str(edge_key))
		if not is_instance_valid(edge_body):
			continue
		var edge_collision := edge_body.get_node_or_null("SharedTransitionCollision") as CollisionShape3D
		var box: BoxShape3D = null
		if edge_collision != null:
			box = edge_collision.shape as BoxShape3D
		_expect(box != null, "shared edge uses a box collision shape")
		if box == null:
			continue
		if absf(box.size.z - 0.5) <= POSITION_TOLERANCE:
			double_trim_count += 1
		elif absf(box.size.z - 1.25) <= POSITION_TOLERANCE:
			single_trim_count += 1
		else:
			_expect(false, "shared edge width is either single-end or double-end trimmed: " + str(box.size.z))
	_expect(double_trim_count == 4, "four interior shared edges are trimmed at both junction endpoints")
	_expect(single_trim_count == 8, "eight perimeter shared edges are trimmed at one junction endpoint")

	var reports: Array = report.get("blocked_corner_reports", [])
	_expect(reports.size() == 16, "all sixteen per-patch corner reports remain available")
	for report_value in reports:
		_expect(str(report_value.get("policy", "")) == "shared_corner_cap", "every compatible interior corner reports shared_corner_cap")

	manager.call("clear_all")
	await process_frame
	await physics_frame
	_expect(int(manager.call("get_corner_cap_count")) == 0, "clear_all retires all sixteen corner caps")
	_expect(int(manager.call("get_transition_count")) == 0, "clear_all retires all twelve shared ramps")
	for patch in patches:
		var base_collision := patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
		_expect(base_collision != null and not base_collision.disabled, "clear_all restores base collision for " + patch.name)
		for side in ["east", "west", "north", "south"]:
			_expect(not bool(patch.call("is_shared_transition_active", side)), "clear_all resets " + patch.name + " " + side + " ownership")

	holder.queue_free()
	await process_frame
	await process_frame

func _test_compatible_and_incompatible_adjacent_junctions_fall_back_together() -> void:
	var holder := Node3D.new()
	holder.name = "MixedCompatibilityCornerCapTestRoot"
	root.add_child(holder)

	var levels: Array = [
		[2, 0, 1],
		[0, 2, 0],
		[0, 2, 0]
	]
	var patches: Array[Node3D] = []
	var stable_ids: Dictionary = {}
	var patches_by_id: Dictionary = {}
	for z in range(3):
		for x in range(3):
			var patch: Node3D = PatchScript.new()
			patch.name = "MixedPatch_%d_%d" % [x, z]
			patch.position = Vector3(float(x) * PATCH_SIZE, 0.0, float(z) * PATCH_SIZE)
			holder.add_child(patch)
			var stable_id: String = "mixed/%d_%d" % [x, z]
			patches.append(patch)
			stable_ids[patch.get_instance_id()] = stable_id
			patches_by_id[stable_id] = patch
	await process_frame
	await physics_frame

	for z in range(3):
		for x in range(3):
			var level: int = int(levels[z][x])
			var state := {"height_level": level, "surface_type": "metal" if level == 2 else "soil", "revision": 1}
			var stable_id: String = "mixed/%d_%d" % [x, z]
			_expect(bool(patches_by_id[stable_id].call("apply_world_object_state", state)), stable_id + " accepts mixed terrain state")

	var binding: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	_expect(bool(binding.get("ok", false)), "mixed 3x3 patches bind into a complete adjacency window")
	_expect(int(binding.get("pair_count", -1)) == 12, "mixed 3x3 fixture binds all twelve cardinal adjacency pairs")
	if not bool(binding.get("ok", false)):
		holder.queue_free()
		await process_frame
		return

	var manager: Node3D = ManagerScript.new()
	holder.add_child(manager)
	var descriptors: Dictionary = binding.get("descriptors", {})
	var report: Dictionary = manager.call("sync_transitions", descriptors, patches_by_id)
	await process_frame
	await physics_frame

	_expect(bool(report.get("ok", false)), "manager accepts the mixed-compatibility topology")
	_expect(int(report.get("corner_cap_count", -1)) == 0, "a compatible junction sharing an edge with an incompatible junction is conservatively demoted")
	_expect(int(manager.call("get_corner_cap_count")) == 0, "no partial cap set is committed across mixed junction compatibility")
	_expect(int(report.get("blocked_count", -1)) == 7, "all seven edges incident to either conflicting junction remain blocked")
	_expect(int(report.get("active_count", -1)) == 2, "only the two non-conflicting bottom-row ramps remain active")
	_expect(int(manager.call("get_transition_count")) == 2, "manager owns only the two non-conflicting bottom-row ramps")

	var shared_edge_key: String = ""
	for edge_key in descriptors.keys():
		var descriptor: Dictionary = descriptors[edge_key]
		var first_id: String = str(descriptor.get("first_stable_id", ""))
		var second_id: String = str(descriptor.get("second_stable_id", ""))
		if (first_id == "mixed/1_0" and second_id == "mixed/1_1") or (first_id == "mixed/1_1" and second_id == "mixed/1_0"):
			shared_edge_key = str(edge_key)
	_expect(not shared_edge_key.is_empty(), "shared edge between compatible and incompatible junctions is present")
	if not shared_edge_key.is_empty():
		_expect(report.get("blocked_edge_keys", []).has(shared_edge_key), "shared edge remains blocked when either endpoint junction is incompatible")
		_expect(not is_instance_valid(manager.call("get_transition_body", shared_edge_key)), "shared edge does not receive a one-sided ramp that overlaps the fallback endpoint")

	var reports: Array = report.get("blocked_corner_reports", [])
	_expect(reports.size() == 8, "both adjacent junctions retain all eight corner reports")
	for report_value in reports:
		_expect(str(report_value.get("policy", "")) == "step_fallback", "both connected junctions report safe step_fallback")
	for z in range(2):
		for x in range(3):
			var patch: Node3D = patches_by_id["mixed/%d_%d" % [x, z]]
			for side in ["east", "west", "north", "south"]:
				_expect(not bool(patch.call("is_shared_transition_active", side)), patch.name + " keeps fallback collision on " + side)
			var base_collision := patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
			_expect(base_collision != null and not base_collision.disabled, patch.name + " retains full base collision")

	manager.call("clear_all")
	await process_frame
	await physics_frame
	for patch in patches:
		var base_collision := patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
		_expect(base_collision != null and not base_collision.disabled, "clear_all restores base collision for " + patch.name)
	holder.queue_free()
	await process_frame
	await process_frame

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

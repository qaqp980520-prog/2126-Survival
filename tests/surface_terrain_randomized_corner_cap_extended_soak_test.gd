extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")
const PATCH_SIZE: float = 2.0
const CORNERS: Array[String] = ["north_east", "south_east", "south_west", "north_west"]
const SIDES: Array[String] = ["east", "west", "north", "south"]
const SEEDS: Array[int] = [0x990001, 0x990002, 0x990003, 0x990004, 0x990005]
var failures: Array[String] = []
var compatible_layouts: int = 0
var mixed_layouts: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var global_trial: int = 0
	for seed_index in range(SEEDS.size()):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEEDS[seed_index]
		for local_trial in range(24):
			await _run_layout(global_trial, rng, local_trial % 2 == 0, seed_index)
			global_trial += 1
	if failures.is_empty():
		print("Run 99 extended 4x4 terrain corner-cap soak passed (%d layouts, %d compatible, %d mixed, %d seeds)." % [global_trial, compatible_layouts, mixed_layouts, SEEDS.size()])
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _run_layout(trial: int, rng: RandomNumberGenerator, compatible: bool, seed_index: int) -> void:
	var holder := Node3D.new()
	holder.name = "Run99TerrainSoak_%02d" % trial
	root.add_child(holder)
	var patches: Array[Node3D] = []
	var stable_ids: Dictionary = {}
	var patches_by_id: Dictionary = {}
	var low_level: int = rng.randi_range(0, 1)
	var high_level: int = 2
	var parity: int = rng.randi_range(0, 1)
	var perturb_count: int = rng.randi_range(2, 8) if not compatible else 0
	var perturbed_cells: Dictionary = {}
	while perturbed_cells.size() < perturb_count:
		perturbed_cells[rng.randi_range(0, 15)] = true
	_expect(perturbed_cells.size() == perturb_count, "mixed layout selects the requested number of distinct perturbations")
	var middle_level: int = 1 if low_level == 0 else 0
	var levels: Array = []
	for z in range(4):
		var row: Array[int] = []
		for x in range(4):
			var level: int = high_level if (x + z + parity) % 2 == 0 else low_level
			if not compatible and perturbed_cells.has(z * 4 + x):
				level = middle_level
			row.append(level)
		levels.append(row)

	for z in range(4):
		for x in range(4):
			var patch: Node3D = PatchScript.new()
			patch.name = "Patch_%d_%d" % [x, z]
			patch.position = Vector3(float(x) * PATCH_SIZE, 0.0, float(z) * PATCH_SIZE)
			holder.add_child(patch)
			var stable_id: String = "run99_s%d/%02d_%d_%d" % [seed_index, trial, x, z]
			patches.append(patch)
			stable_ids[patch.get_instance_id()] = stable_id
			patches_by_id[stable_id] = patch

	await process_frame
	await physics_frame
	for z in range(4):
		for x in range(4):
			var level: int = int(levels[z][x])
			var surface_type: String = "metal" if level == high_level else "soil"
			var stable_id: String = "run97_s%d/%02d_%d_%d" % [seed_index, trial, x, z]
			var state := {"height_level": level, "surface_type": surface_type, "revision": 1}
			_expect(bool(patches_by_id[stable_id].call("apply_world_object_state", state)), stable_id + " accepts seeded height state")

	var binding: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	_expect(bool(binding.get("ok", false)), "4x4 layout %02d binds successfully" % trial)
	_expect(int(binding.get("pair_count", -1)) == 24, "4x4 layout exposes all 24 cardinal shared edges")
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
	_expect(bool(report.get("ok", false)), "4x4 layout %02d synchronizes without partial commit" % trial)
	if not bool(report.get("ok", false)):
		holder.queue_free()
		await process_frame
		return

	var expected_caps: int = 36 if compatible else 0
	if compatible:
		compatible_layouts += 1
		_expect(int(report.get("corner_cap_count", -1)) == expected_caps, "compatible layout stages nine junctions and 36 unique caps")
		_expect(int(report.get("active_count", -1)) == 24, "compatible 4x4 layout stages all 24 shared edge ramps")
		_expect(int(report.get("blocked_count", -1)) == 0, "compatible 4x4 layout has no fallback edges")
	else:
		mixed_layouts += 1
		_expect(int(report.get("corner_cap_count", -1)) == 0, "multiple incompatible cells propagate fallback across all nine connected junctions")
	var required_edge_count: int = 0
	for descriptor_value in descriptors.values():
		if descriptor_value is Dictionary and bool(descriptor_value.get("transition_required", false)):
			required_edge_count += 1
	_expect(int(report.get("active_count", 0)) + int(report.get("blocked_count", 0)) == required_edge_count, "active and blocked accounting covers every required height transition (%d)" % required_edge_count)
	_expect(int(manager.call("get_corner_cap_count")) == expected_caps, "manager cap ownership matches the seeded layout")

	var cap_ids: Dictionary = {}
	for patch in patches:
		var stable_id: String = str(stable_ids[patch.get_instance_id()])
		for corner in CORNERS:
			var body: StaticBody3D = manager.call("get_corner_cap_body", stable_id, corner)
			if not is_instance_valid(body):
				continue
			cap_ids[body.get_instance_id()] = true
			_expect(body.collision_layer == 1, stable_id + " " + corner + " cap collision is active")
			var collision := body.get_node_or_null("CornerCapCollision") as CollisionShape3D
			_expect(collision != null and collision.shape is ConcavePolygonShape3D, stable_id + " " + corner + " cap has a concave collision shell")
			if collision != null and collision.shape is ConcavePolygonShape3D:
				var faces: PackedVector3Array = (collision.shape as ConcavePolygonShape3D).get_faces()
				_expect(faces.size() == 36, stable_id + " " + corner + " cap shell has 36 vertices")
	_expect(cap_ids.size() == expected_caps, "all committed cap bodies have unique per-patch ownership")

	var blocked_set: Dictionary = {}
	for edge_key_value in report.get("blocked_edge_keys", []):
		blocked_set[str(edge_key_value)] = true
	var fallback_edges: Dictionary = {}
	var shared_cap_reports: int = 0
	for report_value in report.get("blocked_corner_reports", []):
		if not (report_value is Dictionary):
			continue
		var corner_report: Dictionary = report_value
		var policy: String = str(corner_report.get("policy", ""))
		if policy == "shared_corner_cap":
			shared_cap_reports += 1
			var cap_body: StaticBody3D = manager.call("get_corner_cap_body", str(corner_report.get("stable_id", "")), str(corner_report.get("corner", "")))
			_expect(is_instance_valid(cap_body), "shared-corner report resolves to its unique committed cap body")
		elif policy == "step_fallback":
			for edge_key_value in corner_report.get("edge_keys", []):
				fallback_edges[str(edge_key_value)] = true
	_expect(shared_cap_reports == expected_caps, "corner report policy count matches committed cap count")
	for edge_key_value in descriptors.keys():
		var edge_key: String = str(edge_key_value)
		var edge_descriptor: Dictionary = descriptors[edge_key_value]
		var transition_required: bool = bool(edge_descriptor.get("transition_required", false))
		var body: StaticBody3D = manager.call("get_transition_body", edge_key)
		if fallback_edges.has(edge_key):
			_expect(transition_required, "fallback report only names edges requiring a height transition")
			_expect(blocked_set.has(edge_key), "fallback edge %s cannot be re-enabled by a neighboring cap" % edge_key)
		if not transition_required:
			_expect(not blocked_set.has(edge_key), "equal-height edge %s is excluded from blocked-transition accounting" % edge_key)
			_expect(not is_instance_valid(body), "equal-height edge %s does not create a redundant ramp" % edge_key)
			continue
		if blocked_set.has(edge_key):
			_expect(not is_instance_valid(body), "blocked edge %s has no active shared ramp" % edge_key)
		else:
			_expect(is_instance_valid(body), "active edge %s has one shared ramp body" % edge_key)

	if trial == 0:
		var original_cap_count: int = manager.call("get_corner_cap_count")
		var original_edge_count: int = manager.call("get_transition_count")
		var original_body: StaticBody3D = null
		var original_edge_key: String = ""
		var sorted_keys: Array = descriptors.keys()
		sorted_keys.sort()
		for edge_key_value in sorted_keys:
			var candidate: Dictionary = descriptors[edge_key_value]
			if bool(candidate.get("transition_required", false)):
				original_edge_key = str(edge_key_value)
				original_body = manager.call("get_transition_body", original_edge_key)
				break
		var invalid_descriptors: Dictionary = descriptors.duplicate(true)
		if not original_edge_key.is_empty():
			var invalid_descriptor: Dictionary = invalid_descriptors[original_edge_key]
			invalid_descriptor["first_side"] = 17
			invalid_descriptors[original_edge_key] = invalid_descriptor
			var rejected: Dictionary = manager.call("sync_transitions", invalid_descriptors, patches_by_id)
			_expect(not bool(rejected.get("ok", false)) and str(rejected.get("error", "")) == "invalid_edge_sides", "invalid descriptor fails before replacing committed geometry")
			_expect(int(manager.call("get_corner_cap_count")) == original_cap_count, "failed preflight preserves the previous cap set")
			_expect(int(manager.call("get_transition_count")) == original_edge_count, "failed preflight preserves the previous ramp set")
			if is_instance_valid(original_body):
				_expect(manager.call("get_transition_body", original_edge_key) == original_body, "failed preflight retains the original shared ramp instance")

	manager.call("clear_all")
	await process_frame
	await physics_frame
	_expect(int(manager.call("get_corner_cap_count")) == 0, "clear_all retires every cap from layout %02d" % trial)
	_expect(int(manager.call("get_transition_count")) == 0, "clear_all retires every ramp from layout %02d" % trial)
	for patch in patches:
		var base_collision := patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
		_expect(base_collision != null and not base_collision.disabled, "clear_all restores base collision for " + patch.name)
		for side in SIDES:
			_expect(not bool(patch.call("is_shared_transition_active", side)), "clear_all resets %s %s ownership" % [patch.name, side])
	holder.queue_free()
	await process_frame
	await process_frame

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

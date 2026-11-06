extends SceneTree

const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const GRID_WIDTH: int = 20
const GRID_HEIGHT: int = 20
const PATCH_SIZE: float = 2.0

class FixturePatch:
	extends Node3D
	const FIXTURE_PATCH_SIZE: float = 2.0

	var neighbors: Dictionary = {}
	var state: Dictionary = {"height_level": 0, "surface_type": "soil", "revision": 0}

	func bind_neighbor_patch(side: String, neighbor: Node3D) -> bool:
		if not ["east", "west", "north", "south"].has(side) or neighbor == null:
			return false
		neighbors[side] = neighbor
		return true

	func clear_neighbor_edge_state(side: String) -> bool:
		neighbors.erase(side)
		return true

	func get_edge_ramp_profile() -> Dictionary:
		return {"patch_size": FIXTURE_PATCH_SIZE}

	func get_world_object_state() -> Dictionary:
		return state.duplicate(true)

	func validate_world_object_state(candidate: Dictionary) -> bool:
		if candidate.size() != 3 or not candidate.has("height_level") or not candidate.has("surface_type") or not candidate.has("revision"):
			return false
		return (
			candidate["height_level"] is int
			and int(candidate["height_level"]) >= 0
			and int(candidate["height_level"]) <= 2
			and candidate["surface_type"] is String
			and ["soil", "rock", "metal"].has(str(candidate["surface_type"]))
			and candidate["revision"] is int
			and int(candidate["revision"]) >= 0
		)

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_large_negative_coordinate_grid()
	await _test_tolerance_bucket_boundaries_and_preflight_preservation()
	if failures.is_empty():
		print("Surface terrain adjacency spatial index tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_large_negative_coordinate_grid() -> void:
	var holder := Node3D.new()
	holder.name = "SpatialIndexGridFixture"
	root.add_child(holder)
	var patches: Array[Node3D] = []
	var stable_ids: Dictionary = {}
	for x_index in range(GRID_WIDTH):
		for z_index in range(GRID_HEIGHT):
			var patch := FixturePatch.new()
			patch.name = "Patch_%d_%d" % [x_index, z_index]
			patch.position = Vector3(float(x_index - GRID_WIDTH / 2) * PATCH_SIZE, 0.0, float(z_index - GRID_HEIGHT / 2) * PATCH_SIZE)
			holder.add_child(patch)
			patches.append(patch)
			stable_ids[patch.get_instance_id()] = "spatial/grid/%d/%d" % [x_index, z_index]
	await process_frame
	await physics_frame

	var report: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	var expected_pairs: int = (GRID_WIDTH - 1) * GRID_HEIGHT + (GRID_HEIGHT - 1) * GRID_WIDTH
	var patch_count: int = GRID_WIDTH * GRID_HEIGHT
	_expect(bool(report.get("ok", false)), "spatial index accepts a 20x20 production-shaped patch grid at negative and positive coordinates")
	_expect(int(report.get("patch_count", -1)) == patch_count, "spatial index reports all 400 patches")
	_expect(int(report.get("pair_count", -1)) == expected_pairs, "spatial index discovers all 760 cardinal adjacency pairs")
	_expect(int(report.get("descriptor_count", -1)) == expected_pairs, "spatial index builds one descriptor per cardinal pair")
	_expect(int(report.get("adjacency_candidate_checks", -1)) == expected_pairs, "neighbor candidate checks remain proportional to actual adjacency pairs")
	_expect(int(report.get("duplicate_position_candidate_checks", -1)) == 0, "well-spaced grid requires no duplicate-position candidate comparisons")
	_expect(int(report.get("position_bucket_lookups", -1)) == patch_count * 27, "duplicate validation checks a fixed 27-bucket neighborhood per patch")
	_expect(int(report.get("adjacency_bucket_lookups", -1)) == patch_count * 4 * 27, "adjacency discovery checks a fixed 27-bucket neighborhood per cardinal side")
	var center: FixturePatch = patches[(GRID_WIDTH / 2) * GRID_HEIGHT + (GRID_HEIGHT / 2)] as FixturePatch
	_expect(center.neighbors.size() == 4, "interior grid patch binds all four cardinal neighbors")
	holder.queue_free()
	await process_frame
	await process_frame

func _test_tolerance_bucket_boundaries_and_preflight_preservation() -> void:
	var holder := Node3D.new()
	holder.name = "SpatialIndexToleranceFixture"
	root.add_child(holder)
	var left := FixturePatch.new()
	left.name = "Left"
	left.position = Vector3(-0.001, 0.0, 0.0)
	var right := FixturePatch.new()
	right.name = "Right"
	right.position = Vector3(2.001, 0.0, 0.0)
	holder.add_child(left)
	holder.add_child(right)
	await process_frame
	var stable_ids: Dictionary = {
		left.get_instance_id(): "spatial/tolerance/left",
		right.get_instance_id(): "spatial/tolerance/right"
	}
	var valid_report: Dictionary = BinderScript.bind_patches([left, right], stable_ids)
	_expect(bool(valid_report.get("ok", false)) and int(valid_report.get("pair_count", -1)) == 1, "adjacency within the 0.01 tolerance is found across neighboring spatial buckets")
	_expect(left.neighbors.get("east") == right and right.neighbors.get("west") == left, "tolerance-boundary adjacency binds both reciprocal sides")

	var duplicate := FixturePatch.new()
	duplicate.name = "NearDuplicate"
	duplicate.position = left.position + Vector3(0.005, 0.0, 0.0)
	holder.add_child(duplicate)
	await process_frame
	var extended_ids: Dictionary = stable_ids.duplicate()
	extended_ids[duplicate.get_instance_id()] = "spatial/tolerance/duplicate"
	var duplicate_report: Dictionary = BinderScript.bind_patches([left, right, duplicate], extended_ids)
	_expect(not bool(duplicate_report.get("ok", true)) and str(duplicate_report.get("error", "")) == "duplicate_position", "near-duplicate positions across a bucket boundary are rejected")
	_expect(left.neighbors.get("east") == right and right.neighbors.get("west") == left, "duplicate-position preflight preserves existing live adjacency")
	holder.queue_free()
	await process_frame
	await process_frame

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const TerrainPatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const MineralNodeScript = preload("res://systems/MineralMiningNode.gd")
const CropPlotScript = preload("res://systems/CropPlotVisual.gd")
const StatefulPropScript = preload("res://systems/WorldObjectStatefulProp.gd")
const RADII: Array[int] = [1, 2, 3, 4, 8]
const MAX_REQUEST_FRAMES: int = 7200
const RELEASE_WAIT_FRAMES: int = 2
const SURFACE_PREFIX: String = "surface/"

var failures: Array[String] = []
var _delegate_factory: Callable
var _factory_build_usec: int = 0
var _factory_calls: int = 0
var _benchmark_fixture_center: Vector2i = Vector2i.ZERO
var _benchmark_corner_fixture_injected: bool = false
var _chunk_content_scan_comparison: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := WorldScene.instantiate() as Node3D
	if world == null:
		_expect(false, "production SurfaceWorld scene instantiates")
		await _finish(null)
		return
	root.add_child(world)
	await process_frame
	await physics_frame

	var controller := world.get("chunk_controller") as Node
	var director := world.get("director") as Node
	_expect(controller != null and director != null, "production SurfaceWorld exposes its real chunk controller and streaming director")
	if controller == null or director == null:
		await _finish(world)
		return
	var typed_controller: MineralChunkController = controller as MineralChunkController
	_expect(typed_controller != null, "production Controller exposes the MineralChunkController collector methods")
	if typed_controller == null:
		await _finish(world)
		return
	_chunk_content_scan_comparison = _run_chunk_content_scan_comparison(typed_controller)
	var async_profile_api_available: bool = director.has_method("set_async_phase_profiling_enabled") and director.has_method("is_async_phase_profiling_enabled")
	_expect(async_profile_api_available, "production Director exposes opt-in async phase profiling")
	if async_profile_api_available:
		_expect(not bool(director.call("is_async_phase_profiling_enabled")), "async phase profiling is disabled by default in production")
		director.call("set_async_phase_profiling_enabled", true)
	var profiling_api_available: bool = controller.has_method("set_terrain_adjacency_profiling_enabled") and controller.has_method("get_last_terrain_adjacency_profile")
	_expect(profiling_api_available, "production controller exposes opt-in terrain adjacency phase profiling")
	if profiling_api_available:
		var initial_profile: Dictionary = controller.call("get_last_terrain_adjacency_profile")
		_expect(initial_profile.is_empty(), "terrain adjacency profiling is disabled by default")
		controller.call("set_terrain_adjacency_profiling_enabled", true)

	var initial_ids: PackedStringArray = _surface_ids(controller)
	_expect(initial_ids.size() == 9, "production SurfaceWorld starts with its real 3x3 surface window")
	var initial_managed_ids: PackedStringArray = director.call("get_managed_chunk_ids")
	_expect(initial_managed_ids.size() == 9, "production director owns the same initial nine surface chunks")

	_delegate_factory = director.get("chunk_factory")
	_expect(_delegate_factory.is_valid(), "production SurfaceWorld exposes its real SurfaceChunkFactory callable")
	if not _delegate_factory.is_valid():
		await _finish(world)
		return
	director.set("chunk_factory", Callable(self, "_profiled_chunk_factory"))
	var installed_factory: Callable = director.get("chunk_factory")
	_expect(installed_factory.is_valid() and str(installed_factory.get_method()) == "_profiled_chunk_factory", "benchmark wrapper is installed without replacing the production factory")

	var previous_surface_count: int = initial_ids.size()
	for radius in RADII:
		var index: int = RADII.find(radius)
		var target := Vector3(
			10000.0 + float(index) * 10000.0 + 5.0,
			0.0,
			20000.0 + float(index) * 10000.0 + 5.0
		)
		_benchmark_fixture_center = director.call("get_grid_coordinate", target)
		_benchmark_corner_fixture_injected = false
		var expansion_center: Vector2i = _benchmark_fixture_center
		var expansion_center_id: String = "surface/chunk_%d_%d" % [expansion_center.x, expansion_center.y]
		var old_root_refs: Array[WeakRef] = _capture_surface_root_refs(controller)
		director.set("load_radius", radius)
		world.set("_stream_clock_unix", int(Time.get_unix_time_from_system()))
		_reset_factory_metrics()
		var expansion_rebuilds_before: int = int(controller.call("get_terrain_adjacency_rebuild_count"))
		var expansion: Dictionary = await _run_async_request(director, target)
		var expansion_diagnostic: Dictionary = expansion.get("diagnostic", {})
		if not bool(expansion.get("ok", false)):
			_expect(false, "radius %d production expansion completes: %s" % [radius, str(expansion.get("error", expansion_diagnostic.get("phase", "unknown")))])
			break

		_expect(_benchmark_corner_fixture_injected, "radius %d production factory injects the deterministic 2x2 corner-cap fixture into its center chunk" % radius)
		var expansion_rebuild_delta: int = int(controller.call("get_terrain_adjacency_rebuild_count")) - expansion_rebuilds_before
		_expect(expansion_rebuild_delta == 1, "radius %d expansion commits one terrain adjacency rebuild instead of one per chunk" % radius)
		var expected_count: int = (radius * 2 + 1) * (radius * 2 + 1)
		var active_ids: PackedStringArray = _surface_ids(controller)
		_expect(active_ids.size() == expected_count, "radius %d commits exactly %d production surface chunks" % [radius, expected_count])
		var expansion_managed_ids: PackedStringArray = director.call("get_managed_chunk_ids")
		_expect(expansion_managed_ids == active_ids, "radius %d keeps Director and production Controller IDs aligned" % radius)
		_expect(int(expansion_diagnostic.get("desired_count", -1)) == expected_count, "radius %d reports the expected desired window size" % radius)
		_expect(int(expansion_diagnostic.get("staged_count", -1)) == expected_count, "radius %d stages every newly required production root" % radius)
		_expect(int(expansion_diagnostic.get("newly_loaded_count", -1)) == expected_count, "radius %d commits every staged production root" % radius)
		_expect(_factory_calls == expected_count, "radius %d invokes the real production factory once per new chunk" % radius)
		_expect(int(expansion_diagnostic.get("unloaded_stale_count", -1)) == previous_surface_count, "radius %d retires the complete previous surface window" % radius)

		await _wait_frames(RELEASE_WAIT_FRAMES)
		_expect(_all_refs_released(old_root_refs), "radius %d expansion releases all departed production roots" % radius)
		_emit_metrics("expand_stage_commit", radius, expected_count, expansion_diagnostic, expansion.get("frame_samples_ms", []), controller)

		var radius8_corner_fixture_refs: Array[WeakRef] = []
		if radius == 8:
			radius8_corner_fixture_refs = _capture_benchmark_corner_fixture_refs(controller, expansion_center_id)
			_expect(radius8_corner_fixture_refs.size() == 4, "radius 8 fixture captures all four production-controller corner patches before the boundary shift")
		var reuse_fixture: Dictionary = {}
		if radius == 1:
			_reset_factory_metrics()
			reuse_fixture = _seed_production_transition_reuse_fixture(controller, director, target)
			_expect(bool(reuse_fixture.get("ok", false)), "radius 1 production fixture creates and reuses a real factory transition seam: %s" % str(reuse_fixture.get("error", "")))
			_expect(int(reuse_fixture.get("active_edge_count", 0)) > 0, "radius 1 production fixture has at least one active transition edge")
			_expect(int(reuse_fixture.get("reused_edge_count", 0)) == int(reuse_fixture.get("active_edge_count", -1)), "radius 1 same-world sync reuses every production transition edge")
			_expect(int(reuse_fixture.get("reactivated_edge_count", 0)) == int(reuse_fixture.get("reused_edge_count", -1)), "radius 1 same-world sync reactivates endpoint segmentation after binder clearing")
			_expect(int(reuse_fixture.get("staged_edge_count", -1)) == 0 and bool(reuse_fixture.get("body_identity_preserved", false)), "radius 1 same-world sync stages no replacement and preserves the production collider body")
			_emit_metrics("resource_reuse_same_world_sync", radius, expected_count, {"duration_usec": 0}, [], controller)

		# Measure the normal one-chunk eastward boundary crossing separately from
		# the intentionally expensive full-window replacement stress case above.
		var boundary_chunk_size_x: float = float(director.get("chunk_size_x"))
		if not is_finite(boundary_chunk_size_x) or boundary_chunk_size_x <= 0.0:
			_expect(false, "production director exposes a finite positive X chunk size")
			break
		var boundary_target: Vector3 = target + Vector3(boundary_chunk_size_x, 0.0, 0.0)
		var boundary_center: Vector2i = director.call("get_grid_coordinate", boundary_target)
		var expected_boundary_ids: PackedStringArray = _expected_surface_ids(boundary_center, radius)
		var previous_boundary_ids: PackedStringArray = _surface_ids(controller)
		var departing_ids: Array[String] = []
		var retained_ids: Array[String] = []
		for current_id in previous_boundary_ids:
			if expected_boundary_ids.has(str(current_id)):
				retained_ids.append(str(current_id))
			else:
				departing_ids.append(str(current_id))
		var expected_boundary_delta: int = radius * 2 + 1
		_expect(departing_ids.size() == expected_boundary_delta, "radius %d boundary shift identifies exactly %d departing roots" % [radius, expected_boundary_delta])
		_expect(retained_ids.size() == expected_count - expected_boundary_delta, "radius %d boundary shift retains every overlapping root" % radius)
		var departing_refs: Array[WeakRef] = _capture_surface_root_refs_for_ids(controller, departing_ids)
		var retained_refs: Array[WeakRef] = _capture_surface_root_refs_for_ids(controller, retained_ids)
		_reset_factory_metrics()
		var boundary_rebuilds_before: int = int(controller.call("get_terrain_adjacency_rebuild_count"))
		var boundary_result: Dictionary = await _run_async_request(director, boundary_target, 1)
		var boundary_diagnostic: Dictionary = boundary_result.get("diagnostic", {})
		if not bool(boundary_result.get("ok", false)):
			_expect(false, "radius %d one-chunk boundary crossing completes: %s" % [radius, str(boundary_result.get("error", boundary_diagnostic.get("phase", "unknown")))])
			break
		var boundary_rebuild_delta: int = int(controller.call("get_terrain_adjacency_rebuild_count")) - boundary_rebuilds_before
		_expect(boundary_rebuild_delta == 1, "radius %d boundary crossing commits one terrain adjacency rebuild instead of one per incoming chunk" % radius)
		var boundary_ids: PackedStringArray = _surface_ids(controller)
		_expect(boundary_ids == expected_boundary_ids, "radius %d boundary crossing commits the exact shifted window" % radius)
		_expect(boundary_ids.size() == expected_count, "radius %d boundary crossing preserves the expected active count" % radius)
		var boundary_managed_ids: PackedStringArray = director.call("get_managed_chunk_ids")
		_expect(boundary_managed_ids == boundary_ids, "radius %d boundary crossing keeps Director and Controller IDs aligned" % radius)
		_expect(int(boundary_diagnostic.get("desired_count", -1)) == expected_count, "radius %d boundary crossing reports the expected desired count" % radius)
		_expect(int(boundary_diagnostic.get("staged_count", -1)) == expected_boundary_delta, "radius %d boundary crossing stages exactly %d new roots" % [radius, expected_boundary_delta])
		_expect(int(boundary_diagnostic.get("newly_loaded_count", -1)) == expected_boundary_delta, "radius %d boundary crossing commits exactly %d new roots" % [radius, expected_boundary_delta])
		_expect(int(boundary_diagnostic.get("unloaded_stale_count", -1)) == expected_boundary_delta, "radius %d boundary crossing retires exactly %d stale roots" % [radius, expected_boundary_delta])
		_expect(int(boundary_diagnostic.get("max_staged_per_frame", -1)) == 1 and int(boundary_diagnostic.get("frame_yield_count", -1)) == expected_boundary_delta, "radius %d one-root staging budget records one yield per incoming root" % radius)
		_expect(_factory_calls == expected_boundary_delta, "radius %d boundary crossing calls the real factory exactly %d times" % [radius, expected_boundary_delta])
		await _wait_frames(RELEASE_WAIT_FRAMES)
		_expect(_all_refs_released(departing_refs), "radius %d boundary crossing releases every departing root" % radius)
		_expect(_all_refs_alive(retained_refs), "radius %d boundary crossing preserves every overlapping root" % radius)
		_emit_metrics("boundary_cross_east", radius, expected_count, boundary_diagnostic, boundary_result.get("frame_samples_ms", []), controller)
		if radius == 8:
			var radius8_boundary_profile: Dictionary = controller.call("get_last_terrain_adjacency_profile")
			_expect(int(radius8_boundary_profile.get("transition_collider_count", 0)) >= 4, "radius 8 production Controller retains four real transition Edge bodies")
			_expect(int(radius8_boundary_profile.get("corner_cap_count", 0)) >= 4, "radius 8 production Controller retains four real Corner Cap bodies")
			_expect(int(radius8_boundary_profile.get("collider_reused_edge_count", 0)) >= 4, "radius 8 incremental boundary shift reuses all four fixture Edge bodies")
			_expect(int(radius8_boundary_profile.get("collider_reused_corner_cap_count", 0)) >= 4, "radius 8 incremental boundary shift reuses all four fixture Corner Cap bodies")
			_expect(int(radius8_boundary_profile.get("collider_staged_edge_count", 0)) == 0 and int(radius8_boundary_profile.get("collider_retired_edge_count", 0)) == 0, "radius 8 preserved fixture does not stage or retire unrelated Edge bodies")
			_expect(int(radius8_boundary_profile.get("collider_staged_corner_cap_count", 0)) == 0 and int(radius8_boundary_profile.get("collider_retired_corner_cap_count", 0)) == 0, "radius 8 preserved fixture does not stage or retire unrelated Corner Cap bodies")
			_expect(_all_refs_alive(radius8_corner_fixture_refs), "radius 8 boundary shift preserves all four fixture Patch Node instances")
		if radius == 1:
			var boundary_profile: Dictionary = controller.call("get_last_terrain_adjacency_profile")
			_expect(int(boundary_profile.get("collider_reused_edge_count", 0)) > 0, "radius 1 production boundary shift preserves the seeded transition collider")
			var preserved_edge_key: String = str(reuse_fixture.get("edge_key", ""))
			var preserved_body: StaticBody3D = reuse_fixture.get("body") as StaticBody3D
			var preserved_descriptor: Dictionary = controller.call("get_terrain_transition_descriptors").get(preserved_edge_key, {})
			var first_patch: Node3D = _find_terrain_patch_by_stable_id(controller, str(preserved_descriptor.get("first_stable_id", "")))
			var second_patch: Node3D = _find_terrain_patch_by_stable_id(controller, str(preserved_descriptor.get("second_stable_id", "")))
			var first_side: String = str(preserved_descriptor.get("first_side", ""))
			var second_side: String = str(preserved_descriptor.get("second_side", ""))
			var endpoint_links_preserved: bool = (
				is_instance_valid(first_patch)
				and is_instance_valid(second_patch)
				and not first_side.is_empty()
				and not second_side.is_empty()
				and first_patch.call("get_bound_neighbor_patch", first_side) == second_patch
				and second_patch.call("get_bound_neighbor_patch", second_side) == first_patch
			)
			_expect(int(boundary_profile.get("collider_reused_edge_count", 0)) > 0, "radius 1 incremental boundary shift reuses the preserved production collider")
			_expect(int(boundary_profile.get("collider_reactivated_edge_count", 0)) == 0, "radius 1 incremental boundary shift preserves endpoint bindings without a full reactivation pass")
			_expect(is_instance_valid(preserved_body) and controller.call("get_terrain_transition_collider", preserved_edge_key) == preserved_body, "radius 1 incremental boundary shift preserves the exact seeded collider body")
			_expect(endpoint_links_preserved, "radius 1 incremental boundary shift preserves reciprocal seam endpoint bindings")
		target = boundary_target

		# Collect eight additional same-runner radius-8 boundary samples. Alternating
		# west/east keeps each transaction to one chunk, provides three samples per
		# staging budget, and ends back on the east boundary center before contraction.
		if radius == 8:
			var repeat_sequence_ok: bool = true
			var repeat_budgets: Array[int] = [2, 4, 1, 2, 4, 1, 2, 4]
			for repeat_index in range(repeat_budgets.size()):
				var repeat_direction: float = -1.0 if repeat_index % 2 == 0 else 1.0
				var repeat_direction_name: String = "west" if repeat_direction < 0.0 else "east"
				var repeat_target: Vector3 = target + Vector3(boundary_chunk_size_x * repeat_direction, 0.0, 0.0)
				var repeat_center: Vector2i = director.call("get_grid_coordinate", repeat_target)
				var expected_repeat_ids: PackedStringArray = _expected_surface_ids(repeat_center, radius)
				var previous_repeat_ids: PackedStringArray = _surface_ids(controller)
				var repeat_departing_ids: Array[String] = []
				var repeat_retained_ids: Array[String] = []
				for current_repeat_id in previous_repeat_ids:
					if expected_repeat_ids.has(str(current_repeat_id)):
						repeat_retained_ids.append(str(current_repeat_id))
					else:
						repeat_departing_ids.append(str(current_repeat_id))
				var expected_repeat_delta: int = radius * 2 + 1
				_expect(repeat_departing_ids.size() == expected_repeat_delta, "radius %d repeat %d %s identifies exactly %d departing roots" % [radius, repeat_index + 1, repeat_direction_name, expected_repeat_delta])
				_expect(repeat_retained_ids.size() == expected_count - expected_repeat_delta, "radius %d repeat %d %s retains every overlapping root" % [radius, repeat_index + 1, repeat_direction_name])
				var repeat_departing_refs: Array[WeakRef] = _capture_surface_root_refs_for_ids(controller, repeat_departing_ids)
				var repeat_retained_refs: Array[WeakRef] = _capture_surface_root_refs_for_ids(controller, repeat_retained_ids)
				_reset_factory_metrics()
				var repeat_budget: int = repeat_budgets[repeat_index]
				var repeat_rebuilds_before: int = int(controller.call("get_terrain_adjacency_rebuild_count"))
				var repeat_result: Dictionary = await _run_async_request(director, repeat_target, repeat_budget)
				var repeat_diagnostic: Dictionary = repeat_result.get("diagnostic", {})
				if not bool(repeat_result.get("ok", false)):
					_expect(false, "radius %d repeat %d %s boundary crossing completes: %s" % [radius, repeat_index + 1, repeat_direction_name, str(repeat_result.get("error", repeat_diagnostic.get("phase", "unknown")))])
					repeat_sequence_ok = false
					break
				var repeat_rebuild_delta: int = int(controller.call("get_terrain_adjacency_rebuild_count")) - repeat_rebuilds_before
				_expect(repeat_rebuild_delta == 1, "radius %d repeat %d %s commits one terrain adjacency rebuild" % [radius, repeat_index + 1, repeat_direction_name])
				var repeat_ids: PackedStringArray = _surface_ids(controller)
				_expect(repeat_ids == expected_repeat_ids, "radius %d repeat %d %s commits the exact shifted window" % [radius, repeat_index + 1, repeat_direction_name])
				_expect(repeat_ids.size() == expected_count, "radius %d repeat %d %s preserves the active chunk count" % [radius, repeat_index + 1, repeat_direction_name])
				var repeat_managed_ids: PackedStringArray = director.call("get_managed_chunk_ids")
				_expect(repeat_managed_ids == repeat_ids, "radius %d repeat %d %s keeps Director and Controller IDs aligned" % [radius, repeat_index + 1, repeat_direction_name])
				_expect(int(repeat_diagnostic.get("staged_count", -1)) == expected_repeat_delta, "radius %d repeat %d %s stages exactly %d new roots" % [radius, repeat_index + 1, repeat_direction_name, expected_repeat_delta])
				_expect(int(repeat_diagnostic.get("newly_loaded_count", -1)) == expected_repeat_delta, "radius %d repeat %d %s commits exactly %d new roots" % [radius, repeat_index + 1, repeat_direction_name, expected_repeat_delta])
				_expect(int(repeat_diagnostic.get("unloaded_stale_count", -1)) == expected_repeat_delta, "radius %d repeat %d %s retires exactly %d stale roots" % [radius, repeat_index + 1, repeat_direction_name, expected_repeat_delta])
				var expected_repeat_yields: int = floori(float(expected_repeat_delta) / float(repeat_budget))
				_expect(int(repeat_diagnostic.get("max_staged_per_frame", -1)) == repeat_budget and int(repeat_diagnostic.get("frame_yield_count", -1)) == expected_repeat_yields, "radius %d repeat %d %s records budget %d and %d intentional frame yields" % [radius, repeat_index + 1, repeat_direction_name, repeat_budget, expected_repeat_yields])
				_expect(_factory_calls == expected_repeat_delta, "radius %d repeat %d %s calls the production factory exactly %d times" % [radius, repeat_index + 1, repeat_direction_name, expected_repeat_delta])
				await _wait_frames(RELEASE_WAIT_FRAMES)
				_expect(_all_refs_released(repeat_departing_refs), "radius %d repeat %d %s releases all departing roots" % [radius, repeat_index + 1, repeat_direction_name])
				_expect(_all_refs_alive(repeat_retained_refs), "radius %d repeat %d %s preserves all overlapping roots" % [radius, repeat_index + 1, repeat_direction_name])
				_emit_metrics("boundary_cross_repeat_%d_%s" % [repeat_index + 1, repeat_direction_name], radius, expected_count, repeat_diagnostic, repeat_result.get("frame_samples_ms", []), controller)
				target = repeat_target
			if not repeat_sequence_ok:
				break

		var center: Vector2i = boundary_center
		var center_id: String = "surface/chunk_%d_%d" % [center.x, center.y]
		var departed_refs: Array[WeakRef] = _capture_surface_root_refs(controller, center_id)
		_expect(departed_refs.size() == expected_count - 1, "radius %d contraction fixture captures every non-center root" % radius)
		director.set("load_radius", 0)
		_reset_factory_metrics()
		var contraction_rebuilds_before: int = int(controller.call("get_terrain_adjacency_rebuild_count"))
		var contraction: Dictionary = await _run_async_request(director, target)
		var contraction_diagnostic: Dictionary = contraction.get("diagnostic", {})
		if not bool(contraction.get("ok", false)):
			_expect(false, "radius %d production contraction completes: %s" % [radius, str(contraction.get("error", contraction_diagnostic.get("phase", "unknown")))])
			break

		var contraction_rebuild_delta: int = int(controller.call("get_terrain_adjacency_rebuild_count")) - contraction_rebuilds_before
		_expect(contraction_rebuild_delta == 1, "radius %d contraction commits one terrain adjacency rebuild instead of one per unloaded chunk" % radius)
		var contracted_ids: PackedStringArray = _surface_ids(controller)
		_expect(contracted_ids.size() == 1 and contracted_ids.has(center_id), "radius %d contracts to the retained center chunk" % radius)
		var contraction_managed_ids: PackedStringArray = director.call("get_managed_chunk_ids")
		_expect(contraction_managed_ids == contracted_ids, "radius %d keeps ownership maps aligned after contraction" % radius)
		_expect(int(contraction_diagnostic.get("staged_count", -1)) == 0, "radius %d contraction creates no unnecessary roots" % radius)
		_expect(int(contraction_diagnostic.get("newly_loaded_count", -1)) == 0, "radius %d contraction commits no new roots" % radius)
		_expect(_factory_calls == 0, "radius %d contraction does not invoke the production factory" % radius)
		_expect(int(contraction_diagnostic.get("unloaded_stale_count", -1)) == expected_count - 1, "radius %d unloads exactly %d departed roots" % [radius, expected_count - 1])
		await _wait_frames(RELEASE_WAIT_FRAMES)
		_expect(_all_refs_released(departed_refs), "radius %d contraction releases all non-center roots" % radius)
		_expect(controller.call("get_chunk_root", center_id) != null, "radius %d preserves the retained center root" % radius)
		_emit_metrics("contract_unload", radius, 1, contraction_diagnostic, contraction.get("frame_samples_ms", []), controller)
		if radius == 1:
			var contraction_profile: Dictionary = controller.call("get_last_terrain_adjacency_profile")
			_expect(int(contraction_profile.get("collider_retired_edge_count", 0)) > 0, "radius 1 contraction retires the seeded production transition collider")
			_expect(int(contraction_profile.get("collider_retired_corner_cap_count", 0)) >= 4, "radius 1 contraction retires all four production corner caps")
		if radius == 8:
			var radius8_contraction_profile: Dictionary = controller.call("get_last_terrain_adjacency_profile")
			_expect(int(radius8_contraction_profile.get("collider_retired_edge_count", 0)) >= 4, "radius 8 contraction retires all four production fixture Edge bodies")
			_expect(int(radius8_contraction_profile.get("collider_retired_corner_cap_count", 0)) >= 4, "radius 8 contraction retires all four production fixture Corner Cap bodies")
			_expect(_all_refs_released(radius8_corner_fixture_refs), "radius 8 contraction releases all four departing fixture Patch Node instances")
		previous_surface_count = 1

	director.set("chunk_factory", _delegate_factory)
	await _finish(world)

func _seed_production_transition_reuse_fixture(controller: Node, director: Node, target: Vector3) -> Dictionary:
	var center: Vector2i = director.call("get_grid_coordinate", target)
	var center_id: String = "surface/chunk_%d_%d" % [center.x, center.y]
	var center_root: Node3D = controller.call("get_chunk_root", center_id) as Node3D
	if not is_instance_valid(center_root):
		return {"ok": false, "error": "center_chunk_root_unavailable"}
	var lower_patch: Node3D = center_root.get_node_or_null("TerrainPatch_AdjacentWest") as Node3D
	var neighbor_patch: Node3D = center_root.get_node_or_null("TerrainPatch_AdjacentEast") as Node3D
	if not is_instance_valid(lower_patch) or not is_instance_valid(neighbor_patch):
		return {"ok": false, "error": "production_adjacent_patch_pair_unavailable"}
	var lower_state: Dictionary = lower_patch.call("get_world_object_state")
	var neighbor_state: Dictionary = neighbor_patch.call("get_world_object_state")
	var lower_level: int = int(lower_state.get("height_level", -1))
	var neighbor_level: int = int(neighbor_state.get("height_level", -1))
	if lower_level < 0 or lower_level > 2 or neighbor_level < 0 or neighbor_level > 2:
		return {"ok": false, "error": "production_patch_height_state_invalid"}
	if lower_level == neighbor_level:
		lower_state["height_level"] = 2 if neighbor_level == 0 else 0
		lower_state["revision"] = int(lower_state.get("revision", 0)) + 1
	if not bool(controller.call("begin_terrain_adjacency_batch")):
		return {"ok": false, "error": "production_transition_seed_batch_begin_failed"}
	if not bool(lower_patch.call("apply_world_object_state", lower_state)):
		controller.call("end_terrain_adjacency_batch")
		return {"ok": false, "error": "production_patch_height_seed_rejected"}
	var seed_result: Dictionary = controller.call("end_terrain_adjacency_batch")
	if not bool(seed_result.get("ok", false)):
		return {"ok": false, "error": "production_transition_seed_rebind_failed"}
	var descriptors: Dictionary = controller.call("get_terrain_transition_descriptors")
	if descriptors.is_empty():
		return {"ok": false, "error": "production_transition_seed_created_no_descriptors"}
	var edge_keys: Array = []
	for edge_key_value in descriptors.keys():
		var descriptor: Dictionary = descriptors[edge_key_value]
		if bool(descriptor.get("transition_required", false)):
			edge_keys.append(str(edge_key_value))
	if edge_keys.is_empty():
		return {"ok": false, "error": "production_transition_seed_created_no_unequal_height_descriptor"}
	edge_keys.sort()
	var edge_key: String = str(edge_keys[0])
	var body_before: StaticBody3D = controller.call("get_terrain_transition_collider", edge_key) as StaticBody3D
	if not is_instance_valid(body_before):
		return {"ok": false, "error": "production_transition_seed_body_missing:active=%d:transition_descriptors=%d" % [int(controller.call("get_terrain_transition_collider_count")), edge_keys.size()]}
	if not bool(controller.call("begin_terrain_adjacency_batch")):
		return {"ok": false, "error": "production_transition_reuse_batch_begin_failed"}
	var unchanged_state: Dictionary = lower_patch.call("get_world_object_state")
	if not bool(lower_patch.call("apply_world_object_state", unchanged_state)):
		controller.call("end_terrain_adjacency_batch")
		return {"ok": false, "error": "production_transition_reuse_signal_failed"}
	var reuse_result: Dictionary = controller.call("end_terrain_adjacency_batch")
	if not bool(reuse_result.get("ok", false)):
		return {"ok": false, "error": "production_transition_reuse_rebind_failed"}
	var profile: Dictionary = controller.call("get_last_terrain_adjacency_profile")
	var body_after: StaticBody3D = controller.call("get_terrain_transition_collider", edge_key) as StaticBody3D
	var active_edge_count: int = int(profile.get("transition_collider_count", 0))
	var reused_edge_count: int = int(profile.get("collider_reused_edge_count", 0))
	var reactivated_edge_count: int = int(profile.get("collider_reactivated_edge_count", 0))
	var staged_edge_count: int = int(profile.get("collider_staged_edge_count", 0))
	var retired_edge_count: int = int(profile.get("collider_retired_edge_count", 0))
	return {
		"ok": active_edge_count > 0 and reused_edge_count == active_edge_count and reactivated_edge_count == reused_edge_count and staged_edge_count == 0 and retired_edge_count == 0 and body_after == body_before,
		"active_edge_count": active_edge_count,
		"reused_edge_count": reused_edge_count,
		"reactivated_edge_count": reactivated_edge_count,
		"staged_edge_count": staged_edge_count,
		"retired_edge_count": retired_edge_count,
		"body_identity_preserved": body_after == body_before,
		"body": body_before,
		"edge_key": edge_key,
		"profile_usec": profile
	}


func _find_terrain_patch_by_stable_id(controller: Node, stable_id: String) -> Node3D:
	if stable_id.is_empty():
		return null
	var objects_by_chunk: Dictionary = controller.get("_chunk_objects")
	for objects_value in objects_by_chunk.values():
		if not (objects_value is Dictionary):
			continue
		var objects: Dictionary = objects_value
		if not objects.has(stable_id):
			continue
		var patch: Node3D = objects[stable_id] as Node3D
		if is_instance_valid(patch) and patch.has_method("get_bound_neighbor_patch"):
			return patch
	return null

func _inject_benchmark_corner_fixture(chunk_root: Node3D) -> bool:
	# Four real SurfaceTerrainPatch nodes form a 2x2 checkerboard at the
	# center of one production chunk. Their four unequal-height edges meet at
	# one Junction and produce four managed Corner Cap bodies.
	var patch_size: float = float(TerrainPatchScript.PATCH_SIZE)
	var specs: Array[Dictionary] = [
		{"suffix": "NW", "position": Vector3(6.0, 0.0, 4.0), "height": 0},
		{"suffix": "NE", "position": Vector3(6.0 + patch_size, 0.0, 4.0), "height": 2},
		{"suffix": "SW", "position": Vector3(6.0, 0.0, 4.0 + patch_size), "height": 2},
		{"suffix": "SE", "position": Vector3(6.0 + patch_size, 0.0, 4.0 + patch_size), "height": 0}
	]
	var created: Array[Node3D] = []
	for spec in specs:
		var patch: Node3D = TerrainPatchScript.new() as Node3D
		if not is_instance_valid(patch):
			for previous in created:
				chunk_root.remove_child(previous)
				previous.free()
			return false
		patch.name = "TerrainPatch_BenchmarkCorner_" + str(spec.get("suffix", ""))
		patch.position = spec.get("position", Vector3.ZERO)
		# Seed the serialized initial fields before the detached root enters the tree.
		# SurfaceTerrainPatch._ready() creates CollisionShape3D before geometry refresh.
		patch.set("_height_level", int(spec.get("height", 0)))
		patch.set("_revision", 1)
		chunk_root.add_child(patch)
		created.append(patch)
	_benchmark_corner_fixture_injected = created.size() == 4
	return _benchmark_corner_fixture_injected


func _capture_benchmark_corner_fixture_refs(controller: Node, chunk_id: String) -> Array[WeakRef]:
	var refs: Array[WeakRef] = []
	var chunk_root: Node3D = controller.call("get_chunk_root", chunk_id) as Node3D
	if not is_instance_valid(chunk_root):
		return refs
	for suffix in ["NW", "NE", "SW", "SE"]:
		var patch: Node3D = chunk_root.get_node_or_null("TerrainPatch_BenchmarkCorner_" + suffix) as Node3D
		if is_instance_valid(patch):
			refs.append(weakref(patch))
	return refs

func _profiled_chunk_factory(coord: Vector2i) -> Node3D:
	var started_usec: int = Time.get_ticks_usec()
	var candidate: Variant = _delegate_factory.call(coord)
	var candidate_root: Node3D = candidate as Node3D
	if is_instance_valid(candidate_root) and coord == _benchmark_fixture_center and not _benchmark_corner_fixture_injected:
		if not _inject_benchmark_corner_fixture(candidate_root):
			_expect(false, "production factory center chunk accepts the deterministic four-patch corner fixture")
	_factory_build_usec += Time.get_ticks_usec() - started_usec
	_factory_calls += 1
	return candidate_root

func _reset_factory_metrics() -> void:
	_factory_build_usec = 0
	_factory_calls = 0

func _run_async_request(director: Node, target: Vector3, max_staged_per_frame: int = 1) -> Dictionary:
	var request_id: int = int(director.call(
		"request_sync_to_world_position_async",
		target,
		int(Time.get_unix_time_from_system()),
		max_staged_per_frame
	))
	if request_id < 0:
		return {"ok": false, "error": "production async request was rejected", "diagnostic": {}, "frame_samples_ms": []}

	var frame_samples_ms: Array[float] = []
	var previous_usec: int = Time.get_ticks_usec()
	for frame_index in range(MAX_REQUEST_FRAMES):
		await process_frame
		var now_usec: int = Time.get_ticks_usec()
		frame_samples_ms.append(float(now_usec - previous_usec) / 1000.0)
		previous_usec = now_usec
		var diagnostic: Dictionary = director.call("get_async_request_diagnostics", request_id)
		if bool(diagnostic.get("terminal", false)):
			return {
				"ok": bool(diagnostic.get("success", false)),
				"diagnostic": diagnostic,
				"frame_samples_ms": frame_samples_ms
			}
	director.call("cancel_async_sync_request", request_id)
	return {
		"ok": false,
		"error": "request exceeded %d process frames" % MAX_REQUEST_FRAMES,
		"diagnostic": director.call("get_async_request_diagnostics", request_id),
		"frame_samples_ms": frame_samples_ms
	}

func _surface_ids(controller: Node) -> PackedStringArray:
	var result := PackedStringArray()
	var loaded_ids: PackedStringArray = controller.call("get_loaded_chunk_ids")
	for chunk_id in loaded_ids:
		if str(chunk_id).begins_with(SURFACE_PREFIX):
			result.append(str(chunk_id))
	result.sort()
	return result

func _expected_surface_ids(center: Vector2i, radius: int) -> PackedStringArray:
	var ids := PackedStringArray()
	for z in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			ids.append("surface/chunk_%d_%d" % [x, z])
	ids.sort()
	return ids

func _capture_surface_root_refs_for_ids(controller: Node, chunk_ids: Array[String]) -> Array[WeakRef]:
	var refs: Array[WeakRef] = []
	for chunk_id in chunk_ids:
		var chunk_root := controller.call("get_chunk_root", chunk_id) as Node3D
		if is_instance_valid(chunk_root):
			refs.append(weakref(chunk_root))
	return refs

func _all_refs_alive(refs: Array[WeakRef]) -> bool:
	for root_ref in refs:
		var candidate: Object = root_ref.get_ref()
		if candidate == null or not is_instance_valid(candidate):
			return false
	return true

func _capture_surface_root_refs(controller: Node, excluded_id: String = "") -> Array[WeakRef]:
	var refs: Array[WeakRef] = []
	for chunk_id in _surface_ids(controller):
		if str(chunk_id) == excluded_id:
			continue
		var chunk_root := controller.call("get_chunk_root", str(chunk_id)) as Node3D
		if is_instance_valid(chunk_root):
			refs.append(weakref(chunk_root))
	return refs

func _all_refs_released(refs: Array[WeakRef]) -> bool:
	for root_ref in refs:
		var candidate: Object = root_ref.get_ref()
		if candidate != null and is_instance_valid(candidate):
			return false
	return true

func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child in node.get_children():
		count += _count_nodes(child as Node)
	return count

func _count_surface_nodes(controller: Node) -> int:
	var count: int = 0
	for chunk_id in _surface_ids(controller):
		var chunk_root := controller.call("get_chunk_root", str(chunk_id)) as Node3D
		if is_instance_valid(chunk_root):
			count += _count_nodes(chunk_root)
	return count


func _run_chunk_content_scan_comparison(controller: MineralChunkController) -> Dictionary:
	# Compare the old three-pass path and the new combined path in the same process,
	# on the same synthetic tree, with alternating measurement order.
	var chunk_root := Node3D.new()
	chunk_root.name = "CollectorBenchmarkChunk"
	var category_counts := {"minerals": 0, "crops": 0, "world_objects": 0}
	for group_index in range(8):
		var group := Node3D.new()
		group.name = "Group_%02d" % group_index
		chunk_root.add_child(group)
		for child_index in range(64):
			var flat_index: int = group_index * 64 + child_index
			var child: Node3D
			if flat_index % 29 == 0:
				child = MineralNodeScript.new() as Node3D
				category_counts["minerals"] = int(category_counts["minerals"]) + 1
			elif flat_index % 31 == 0:
				child = CropPlotScript.new() as Node3D
				category_counts["crops"] = int(category_counts["crops"]) + 1
			elif flat_index % 37 == 0:
				child = StatefulPropScript.new() as Node3D
				category_counts["world_objects"] = int(category_counts["world_objects"]) + 1
			else:
				child = Node3D.new()
			child.name = "Node_%03d" % child_index
			group.add_child(child)

	var legacy_veins: Dictionary = {}
	var legacy_crops: Dictionary = {}
	var legacy_objects: Dictionary = {}
	var combined_veins: Dictionary = {}
	var combined_crops: Dictionary = {}
	var combined_objects: Dictionary = {}
	var legacy_ok: bool = (
		controller._collect_mineral_nodes(chunk_root, str(chunk_root.name), legacy_veins)
		and controller._collect_crop_plots(chunk_root, str(chunk_root.name), legacy_crops)
		and controller._collect_world_state_nodes(chunk_root, str(chunk_root.name), legacy_objects)
	)
	var combined_ok: bool = controller._collect_chunk_content_nodes(
		chunk_root,
		str(chunk_root.name),
		combined_veins,
		combined_crops,
		combined_objects
	)
	_expect(legacy_ok and combined_ok, "legacy and combined collectors accept the synthetic production-shaped Chunk tree")
	_expect(legacy_veins == combined_veins, "single-pass mineral discovery exactly matches the three-pass baseline")
	_expect(legacy_crops == combined_crops, "single-pass crop discovery exactly matches the three-pass baseline")
	_expect(legacy_objects == combined_objects, "single-pass world-object discovery exactly matches the three-pass baseline")
	_expect(legacy_veins.size() == int(category_counts["minerals"]), "collector benchmark discovers the expected mineral-node count")
	_expect(legacy_crops.size() == int(category_counts["crops"]), "collector benchmark discovers the expected crop-node count")
	_expect(legacy_objects.size() == int(category_counts["world_objects"]), "collector benchmark discovers the expected stateful-object count")

	var all_iterations_ok: bool = legacy_ok and combined_ok
	for warmup_index in range(5):
		legacy_ok = _run_legacy_chunk_content_collectors(controller, chunk_root)
		combined_ok = _run_single_pass_chunk_content_collector(controller, chunk_root)
		all_iterations_ok = all_iterations_ok and legacy_ok and combined_ok
	var legacy_samples_usec: Array[int] = []
	var single_pass_samples_usec: Array[int] = []
	for iteration in range(40):
		var legacy_elapsed_usec: int = 0
		var single_pass_elapsed_usec: int = 0
		var legacy_started_usec: int = 0
		var single_pass_started_usec: int = 0
		if iteration % 2 == 0:
			legacy_started_usec = Time.get_ticks_usec()
			legacy_ok = _run_legacy_chunk_content_collectors(controller, chunk_root)
			legacy_elapsed_usec = maxi(0, Time.get_ticks_usec() - legacy_started_usec)
			single_pass_started_usec = Time.get_ticks_usec()
			combined_ok = _run_single_pass_chunk_content_collector(controller, chunk_root)
			single_pass_elapsed_usec = maxi(0, Time.get_ticks_usec() - single_pass_started_usec)
		else:
			single_pass_started_usec = Time.get_ticks_usec()
			combined_ok = _run_single_pass_chunk_content_collector(controller, chunk_root)
			single_pass_elapsed_usec = maxi(0, Time.get_ticks_usec() - single_pass_started_usec)
			legacy_started_usec = Time.get_ticks_usec()
			legacy_ok = _run_legacy_chunk_content_collectors(controller, chunk_root)
			legacy_elapsed_usec = maxi(0, Time.get_ticks_usec() - legacy_started_usec)
		legacy_samples_usec.append(legacy_elapsed_usec)
		single_pass_samples_usec.append(single_pass_elapsed_usec)
		all_iterations_ok = all_iterations_ok and legacy_ok and combined_ok

	var legacy_summary: Dictionary = _summarize_usec_samples(legacy_samples_usec)
	var single_pass_summary: Dictionary = _summarize_usec_samples(single_pass_samples_usec)
	var legacy_median_usec: float = float(legacy_summary.get("median_usec", 0.0))
	var single_pass_median_usec: float = float(single_pass_summary.get("median_usec", 0.0))
	var ratio: float = single_pass_median_usec / legacy_median_usec if legacy_median_usec > 0.0 else 0.0
	_expect(all_iterations_ok, "all repeated legacy and single-pass collector measurements complete")
	_expect(legacy_samples_usec.size() == 40 and single_pass_samples_usec.size() == 40, "collector comparison records all 40 paired iterations")
	var result := {
		"valid": all_iterations_ok and legacy_samples_usec.size() == 40 and single_pass_samples_usec.size() == 40,
		"node_count": _count_nodes(chunk_root),
		"mineral_node_count": int(category_counts["minerals"]),
		"crop_node_count": int(category_counts["crops"]),
		"stateful_object_node_count": int(category_counts["world_objects"]),
		"warmup_iterations_per_algorithm": 5,
		"measured_iterations_per_algorithm": 40,
		"measurement_order": "alternating",
		"legacy_three_walks": legacy_summary,
		"single_pass_one_walk": single_pass_summary,
		"single_pass_to_legacy_median_ratio": ratio,
		"median_change_percent": (ratio - 1.0) * 100.0
	}
	chunk_root.free()
	return result

func _run_legacy_chunk_content_collectors(controller: MineralChunkController, chunk_root: Node) -> bool:
	var veins: Dictionary = {}
	var crops: Dictionary = {}
	var world_objects: Dictionary = {}
	return (
		controller._collect_mineral_nodes(chunk_root, str(chunk_root.name), veins)
		and controller._collect_crop_plots(chunk_root, str(chunk_root.name), crops)
		and controller._collect_world_state_nodes(chunk_root, str(chunk_root.name), world_objects)
	)

func _run_single_pass_chunk_content_collector(controller: MineralChunkController, chunk_root: Node) -> bool:
	var veins: Dictionary = {}
	var crops: Dictionary = {}
	var world_objects: Dictionary = {}
	return controller._collect_chunk_content_nodes(
		chunk_root,
		str(chunk_root.name),
		veins,
		crops,
		world_objects
	)

func _summarize_usec_samples(samples: Array[int]) -> Dictionary:
	var sorted_samples: Array[int] = samples.duplicate()
	sorted_samples.sort()
	var total_usec: int = 0
	for sample_usec in sorted_samples:
		total_usec += sample_usec
	var median_usec: float = 0.0
	var p95_usec: float = 0.0
	if not sorted_samples.is_empty():
		var middle: int = sorted_samples.size() / 2
		if sorted_samples.size() % 2 == 1:
			median_usec = float(sorted_samples[middle])
		else:
			median_usec = (float(sorted_samples[middle - 1]) + float(sorted_samples[middle])) * 0.5
		var p95_index: int = clampi(int(ceil(float(sorted_samples.size() - 1) * 0.95)), 0, sorted_samples.size() - 1)
		p95_usec = float(sorted_samples[p95_index])
	return {
		"count": sorted_samples.size(),
		"total_usec": total_usec,
		"min_usec": int(sorted_samples[0]) if not sorted_samples.is_empty() else 0,
		"median_usec": median_usec,
		"p95_usec": p95_usec,
		"max_usec": int(sorted_samples[sorted_samples.size() - 1]) if not sorted_samples.is_empty() else 0
	}

func _emit_metrics(
	phase: String,
	radius: int,
	desired_count: int,
	diagnostic: Dictionary,
	frame_samples_ms: Array,
	controller: Node
) -> void:
	var total_frame_ms: float = 0.0
	var sorted_samples: Array = frame_samples_ms.duplicate()
	for sample in sorted_samples:
		total_frame_ms += float(sample)
	sorted_samples.sort()
	var average_frame_ms: float = total_frame_ms / float(sorted_samples.size()) if not sorted_samples.is_empty() else 0.0
	var p95_frame_ms: float = 0.0
	if not sorted_samples.is_empty():
		var p95_index: int = clampi(int(ceil(float(sorted_samples.size() - 1) * 0.95)), 0, sorted_samples.size() - 1)
		p95_frame_ms = float(sorted_samples[p95_index])
	var max_frame_ms: float = float(sorted_samples[sorted_samples.size() - 1]) if not sorted_samples.is_empty() else 0.0
	var active_ids: PackedStringArray = _surface_ids(controller)
	var surface_node_count: int = _count_surface_nodes(controller)
	var display_server: String = DisplayServer.get_name()
	var render_objects: int = -1
	var render_primitives: int = -1
	var render_draw_calls: int = -1
	if display_server != "headless":
		render_objects = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		render_primitives = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		render_draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var async_total_ms: float = float(diagnostic.get("duration_usec", 0)) / 1000.0
	var factory_build_ms: float = float(_factory_build_usec) / 1000.0
	var adjacency_profile: Dictionary = controller.call("get_last_terrain_adjacency_profile") if controller.has_method("get_last_terrain_adjacency_profile") else {}
	var adjacency_batch_ms: float = float(adjacency_profile.get("batch_total_usec", 0)) / 1000.0
	var async_other_ms: float = maxf(0.0, async_total_ms - factory_build_ms - adjacency_batch_ms)
	var director_phase_keys: Array[String] = [
		"request_plan_usec",
		"dispatch_wait_usec",
		"planning_usec",
		"factory_build_usec",
		"staged_validation_usec",
		"frame_yield_wait_usec",
		"controller_registration_usec",
		"staged_map_erase_usec",
		"stale_unload_usec",
		"adjacency_finalize_call_usec"
	]
	var director_phase_profile: Dictionary = {}
	var director_phase_profile_valid: bool = bool(diagnostic.get("phase_profile_enabled", false))
	var director_phase_total_usec: int = 0
	if director_phase_profile_valid:
		for director_phase_key in director_phase_keys:
			if not diagnostic.has(director_phase_key) or int(diagnostic.get(director_phase_key, -1)) < 0:
				director_phase_profile_valid = false
				continue
			var phase_usec: int = int(diagnostic.get(director_phase_key, 0))
			director_phase_profile[director_phase_key] = phase_usec
			director_phase_total_usec += phase_usec
		var expected_yields: int = floori(float(int(diagnostic.get("staged_count", 0))) / float(maxi(1, int(diagnostic.get("max_staged_per_frame", 1)))))
		director_phase_profile_valid = director_phase_profile_valid and int(diagnostic.get("frame_yield_count", -1)) == expected_yields
		director_phase_profile_valid = director_phase_profile_valid and director_phase_total_usec <= int(diagnostic.get("duration_usec", 0))
		_expect(director_phase_profile_valid, "radius %d %s records non-overlapping Director phase timings and exact frame-yield count" % [radius, phase])
	var director_unattributed_ms: float = maxf(0.0, async_total_ms - float(director_phase_total_usec) / 1000.0) if director_phase_profile_valid else -1.0
	var registration_samples: Array = diagnostic.get("controller_registration_samples", [])
	var stale_unload_samples: Array = diagnostic.get("stale_unload_samples", [])
	var registration_sample_summary: Dictionary = {}
	var stale_unload_sample_summary: Dictionary = {}
	if director_phase_profile_valid:
		registration_sample_summary = _summarize_async_phase_samples(
			registration_samples,
			int(diagnostic.get("newly_loaded_count", 0)),
			int(diagnostic.get("controller_registration_usec", -1))
		)
		stale_unload_sample_summary = _summarize_async_phase_samples(
			stale_unload_samples,
			int(diagnostic.get("unloaded_stale_count", 0)),
			int(diagnostic.get("stale_unload_usec", -1))
		)
		_expect(bool(registration_sample_summary.get("valid", false)), "radius %d %s records one unique, duration-consistent Controller registration sample per loaded Chunk" % [radius, phase])
		_expect(bool(stale_unload_sample_summary.get("valid", false)), "radius %d %s records one unique, duration-consistent stale-unload sample per retired Chunk" % [radius, phase])
	var profile_keys: Array[String] = [
		"collect_loaded_patches_usec",
		"stable_id_map_usec",
		"binder_total_usec",
		"binder_validation_usec",
		"binder_adjacency_discovery_usec",
		"binder_edge_apply_usec",
		"collider_sync_total_usec",
		"collider_candidate_geometry_usec",
		"collider_corner_resolution_usec",
		"collider_resource_staging_usec",
		"collider_activation_commit_usec",
		"collider_reused_edge_count",
		"collider_reactivated_edge_count",
		"collider_staged_edge_count",
		"collider_retired_edge_count",
		"collider_reused_corner_cap_count",
		"collider_staged_corner_cap_count",
		"collider_retired_corner_cap_count",
		"controller_rebind_total_usec",
		"batch_total_usec"
	]
	var profile_valid: bool = not adjacency_profile.is_empty()
	for profile_key in profile_keys:
		if not adjacency_profile.has(profile_key) or int(adjacency_profile.get(profile_key, -1)) < 0:
			profile_valid = false
	var measured_rebind_usec: int = int(adjacency_profile.get("stable_id_map_usec", 0)) + int(adjacency_profile.get("binder_total_usec", 0)) + int(adjacency_profile.get("collider_sync_total_usec", 0))
	profile_valid = profile_valid and int(adjacency_profile.get("controller_rebind_total_usec", 0)) >= measured_rebind_usec
	profile_valid = profile_valid and int(adjacency_profile.get("collider_reused_edge_count", -1)) + int(adjacency_profile.get("collider_staged_edge_count", -1)) == int(adjacency_profile.get("transition_collider_count", -2))
	profile_valid = profile_valid and int(adjacency_profile.get("collider_reactivated_edge_count", -1)) <= int(adjacency_profile.get("collider_reused_edge_count", -2))
	profile_valid = profile_valid and int(adjacency_profile.get("collider_reused_corner_cap_count", -1)) + int(adjacency_profile.get("collider_staged_corner_cap_count", -1)) == int(adjacency_profile.get("corner_cap_count", -2))
	profile_valid = profile_valid and int(adjacency_profile.get("batch_total_usec", 0)) >= int(adjacency_profile.get("collect_loaded_patches_usec", 0)) + int(adjacency_profile.get("controller_rebind_total_usec", 0))
	_expect(profile_valid, "radius %d %s records valid non-negative phase timings with consistent totals" % [radius, phase])
	var coordinator_phase_keys: Array[String] = [
		"plan_delta_usec",
		"index_reservation_usec",
		"candidate_patch_map_usec",
		"candidate_descriptor_snapshot_usec",
		"collider_prepare_usec",
		"scoped_prepare_usec",
		"scoped_apply_usec",
		"collider_accept_usec",
		"index_publish_usec",
		"collider_commit_usec",
		"scoped_finalize_usec",
		"index_finalize_usec"
	]
	var coordinator_phase_profile_usec: Dictionary = {}
	var coordinator_phase_profile_valid: bool = false
	if bool(adjacency_profile.get("incremental", false)):
		coordinator_phase_profile_valid = bool(adjacency_profile.get("coordinator_phase_profile_valid", false))
		var coordinator_measured_usec: int = 0
		for coordinator_phase_key in coordinator_phase_keys:
			if not adjacency_profile.has("coordinator_" + coordinator_phase_key) or int(adjacency_profile.get("coordinator_" + coordinator_phase_key, -1)) < 0:
				coordinator_phase_profile_valid = false
				continue
			var coordinator_phase_usec: int = int(adjacency_profile.get("coordinator_" + coordinator_phase_key, 0))
			coordinator_phase_profile_usec[coordinator_phase_key] = coordinator_phase_usec
			coordinator_measured_usec += coordinator_phase_usec
		var coordinator_total_usec: int = int(adjacency_profile.get("coordinator_total_usec", -1))
		var coordinator_unattributed_usec: int = int(adjacency_profile.get("coordinator_unattributed_usec", -1))
		coordinator_phase_profile_valid = coordinator_phase_profile_valid and coordinator_total_usec > 0
		coordinator_phase_profile_valid = coordinator_phase_profile_valid and coordinator_measured_usec <= coordinator_total_usec
		coordinator_phase_profile_valid = coordinator_phase_profile_valid and coordinator_unattributed_usec == coordinator_total_usec - coordinator_measured_usec
		coordinator_phase_profile_valid = coordinator_phase_profile_valid and coordinator_total_usec <= int(adjacency_profile.get("controller_rebind_total_usec", -1))
		_expect(coordinator_phase_profile_valid, "radius %d %s records complete non-overlapping Coordinator phase timings" % [radius, phase])
	var plan_delta_phase_keys: Array[String] = [
		"candidate_copy_usec",
		"removal_apply_usec",
		"candidate_instance_set_usec",
		"addition_validation_usec",
		"neighbor_discovery_usec",
		"changed_descriptor_build_usec",
		"local_descriptor_build_usec",
		"changed_descriptor_projection_usec",
		"edge_diff_usec",
		"corner_graph_delta_usec",
		"closure_snapshot_usec",
		"plan_storage_usec"
	]
	var plan_delta_phase_profile_usec: Dictionary = {}
	var plan_delta_phase_profile_valid: bool = false
	var plan_delta_phase_total_usec: int = 0
	if bool(adjacency_profile.get("incremental", false)):
		var raw_plan_delta_profile: Dictionary = adjacency_profile.get("coordinator_plan_delta_profile_usec", {})
		plan_delta_phase_profile_valid = not raw_plan_delta_profile.is_empty()
		var plan_delta_measured_usec: int = 0
		for plan_delta_phase_key in plan_delta_phase_keys:
			if not raw_plan_delta_profile.has(plan_delta_phase_key) or int(raw_plan_delta_profile.get(plan_delta_phase_key, -1)) < 0:
				plan_delta_phase_profile_valid = false
				continue
			var plan_delta_phase_usec: int = int(raw_plan_delta_profile.get(plan_delta_phase_key, 0))
			plan_delta_phase_profile_usec[plan_delta_phase_key] = plan_delta_phase_usec
			plan_delta_measured_usec += plan_delta_phase_usec
		plan_delta_phase_total_usec = int(raw_plan_delta_profile.get("total_usec", -1))
		var plan_delta_unattributed_usec: int = int(raw_plan_delta_profile.get("unattributed_usec", -1))
		plan_delta_phase_profile_valid = plan_delta_phase_profile_valid and plan_delta_phase_total_usec > 0
		plan_delta_phase_profile_valid = plan_delta_phase_profile_valid and plan_delta_measured_usec <= plan_delta_phase_total_usec
		plan_delta_phase_profile_valid = plan_delta_phase_profile_valid and plan_delta_unattributed_usec == plan_delta_phase_total_usec - plan_delta_measured_usec
		plan_delta_phase_profile_valid = plan_delta_phase_profile_valid and plan_delta_phase_total_usec <= int(adjacency_profile.get("coordinator_plan_delta_usec", -1))
		plan_delta_phase_profile_usec["total_usec"] = plan_delta_phase_total_usec
		plan_delta_phase_profile_usec["unattributed_usec"] = plan_delta_unattributed_usec
		_expect(plan_delta_phase_profile_valid, "radius %d %s records complete non-overlapping Index plan_delta subphases" % [radius, phase])
	var record := {
		"phase": phase,
		"radius": radius,
		"desired_surface_chunks": desired_count,
		"active_surface_chunks": active_ids.size(),
		"surface_node_count": surface_node_count,
		"average_nodes_per_surface_chunk": float(surface_node_count) / float(maxi(1, active_ids.size())),
		"factory_calls": _factory_calls,
		"factory_build_ms": factory_build_ms,
		"async_total_ms": async_total_ms,
		"async_non_factory_ms": maxf(0.0, async_total_ms - factory_build_ms),
		"terrain_adjacency_batch_ms": adjacency_batch_ms,
		"async_other_ms": async_other_ms,
		"max_staged_per_frame": int(diagnostic.get("max_staged_per_frame", -1)),
		"frame_yield_count": int(diagnostic.get("frame_yield_count", 0)),
		"director_phase_profile_valid": director_phase_profile_valid,
		"director_phase_profile_usec": director_phase_profile,
		"director_profiled_phase_total_ms": float(director_phase_total_usec) / 1000.0,
		"director_unattributed_ms": director_unattributed_ms,
		"controller_registration_samples": registration_samples.duplicate(true),
		"controller_registration_sample_summary": registration_sample_summary,
		"stale_unload_samples": stale_unload_samples.duplicate(true),
		"stale_unload_sample_summary": stale_unload_sample_summary,
		"terrain_adjacency_profile_usec": adjacency_profile,
		"coordinator_phase_profile_valid": coordinator_phase_profile_valid,
		"coordinator_phase_profile_usec": coordinator_phase_profile_usec,
		"coordinator_phase_total_ms": float(adjacency_profile.get("coordinator_total_usec", 0)) / 1000.0,
		"plan_delta_phase_profile_valid": plan_delta_phase_profile_valid,
		"plan_delta_phase_profile_usec": plan_delta_phase_profile_usec,
		"plan_delta_phase_total_ms": float(plan_delta_phase_total_usec) / 1000.0,
		"reused_transition_edge_count": int(adjacency_profile.get("collider_reused_edge_count", 0)),
		"reactivated_transition_edge_count": int(adjacency_profile.get("collider_reactivated_edge_count", 0)),
		"staged_transition_edge_count": int(adjacency_profile.get("collider_staged_edge_count", 0)),
		"retired_transition_edge_count": int(adjacency_profile.get("collider_retired_edge_count", 0)),
		"reused_corner_cap_count": int(adjacency_profile.get("collider_reused_corner_cap_count", 0)),
		"staged_corner_cap_count": int(adjacency_profile.get("collider_staged_corner_cap_count", 0)),
		"retired_corner_cap_count": int(adjacency_profile.get("collider_retired_corner_cap_count", 0)),
		"staged_count": int(diagnostic.get("staged_count", 0)),
		"newly_loaded_count": int(diagnostic.get("newly_loaded_count", 0)),
		"unloaded_stale_count": int(diagnostic.get("unloaded_stale_count", 0)),
		"frame_sample_count": sorted_samples.size(),
		"average_frame_interval_ms": average_frame_ms,
		"p95_frame_interval_ms": p95_frame_ms,
		"max_frame_interval_ms": max_frame_ms,
		"process_static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"process_node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"render_objects_last_frame": render_objects,
		"render_primitives_last_frame": render_primitives,
		"render_draw_calls_last_frame": render_draw_calls,
		"display_server": display_server,
		"os": OS.get_name(),
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count()
	}
	if phase == "expand_stage_commit" and radius == 8:
		record["chunk_content_scan_comparison"] = _chunk_content_scan_comparison.duplicate(true)
	print("SURFACE_CHUNK_BENCHMARK_JSON:" + JSON.stringify(record))

func _summarize_async_phase_samples(samples: Array, expected_count: int, expected_total_usec: int) -> Dictionary:
	var valid: bool = samples.size() == expected_count
	var seen_chunk_ids: Dictionary = {}
	var durations_usec: Array[int] = []
	var total_usec: int = 0
	var slowest_chunk_id: String = ""
	var slowest_duration_usec: int = -1
	for sample_value in samples:
		if not sample_value is Dictionary:
			valid = false
			continue
		var sample: Dictionary = sample_value
		var chunk_id: String = str(sample.get("chunk_id", ""))
		var duration_usec: int = int(sample.get("duration_usec", -1))
		if chunk_id.is_empty() or seen_chunk_ids.has(chunk_id) or duration_usec < 0:
			valid = false
		seen_chunk_ids[chunk_id] = true
		var safe_duration_usec: int = maxi(0, duration_usec)
		durations_usec.append(safe_duration_usec)
		total_usec += safe_duration_usec
		if duration_usec > slowest_duration_usec:
			slowest_duration_usec = duration_usec
			slowest_chunk_id = chunk_id
	valid = valid and total_usec == expected_total_usec
	durations_usec.sort()
	var median_usec: float = 0.0
	var p95_usec: float = 0.0
	if not durations_usec.is_empty():
		var middle: int = durations_usec.size() / 2
		if durations_usec.size() % 2 == 1:
			median_usec = float(durations_usec[middle])
		else:
			median_usec = (float(durations_usec[middle - 1]) + float(durations_usec[middle])) * 0.5
		var p95_index: int = clampi(int(ceil(float(durations_usec.size() - 1) * 0.95)), 0, durations_usec.size() - 1)
		p95_usec = float(durations_usec[p95_index])
	return {
		"valid": valid,
		"count": samples.size(),
		"total_usec": total_usec,
		"min_usec": int(durations_usec[0]) if not durations_usec.is_empty() else 0,
		"median_usec": median_usec,
		"p95_usec": p95_usec,
		"max_usec": int(durations_usec[durations_usec.size() - 1]) if not durations_usec.is_empty() else 0,
		"slowest_chunk_id": slowest_chunk_id
	}


func _wait_frames(frame_count: int) -> void:
	for frame_index in range(frame_count):
		await process_frame

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func _finish(world: Node) -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
		await process_frame
		await process_frame
	if failures.is_empty():
		print("Surface chunk production benchmark completed.")
		quit(0)
	else:
		for failure in failures:
			push_error("BENCHMARK FAILURE: " + failure)
		quit(1)

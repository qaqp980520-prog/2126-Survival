extends SceneTree

const RuntimeScript = preload("res://systems/BackroomsMazeCellRuntime.gd")
const RoutePlannerScript = preload("res://systems/BackroomsCellRoutePlanner.gd")
const LayoutScript = preload("res://systems/BackroomsMazeLayout.gd")
const StreamStateScript = preload("res://systems/BackroomsMazeStreamState.gd")

const TEST_SEED: int = 20261118
const TEST_LEVEL: String = "Level 0"

var failures: Array[String] = []

func _initialize() -> void:
	_test_loaded_window_routes()
	_test_rejected_descriptors_and_budgets()
	_test_maximum_loaded_window_stress()
	if failures.is_empty():
		print("Backrooms loaded-cell route planner tests passed.")
		quit(0)
	else:
		for message in failures:
			push_error("FAIL: " + message)
		quit(1)

func _test_loaded_window_routes() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var runtime: Node3D = RuntimeScript.new() as Node3D
	runtime.set("force_metadata_only", true)
	host.add_child(runtime)
	var prepared: Dictionary = runtime.call(
		"prepare_destination",
		TEST_LEVEL,
		TEST_SEED,
		Vector3.ZERO,
		8.0,
		1
	)
	_expect(bool(prepared.get("ok", false)), "a deterministic 3x3 Level 0 window prepares for route planning")
	if not bool(prepared.get("ok", false)):
		host.free()
		return

	var inactive_route: Dictionary = runtime.call(
		"plan_route_between_loaded_cells",
		Vector2i(-1, 0),
		Vector2i(1, 0)
	)
	_expect(
		not bool(inactive_route.get("ok", false))
		and str(inactive_route.get("reason", "")) == "runtime_not_active",
		"prepared but hidden destinations cannot expose gameplay routes"
	)
	_expect(bool(runtime.call("activate_destination")), "the prepared route-planning destination activates")

	var before_save: Dictionary = runtime.call("to_save_dict")
	var route: Dictionary = runtime.call(
		"plan_route_between_loaded_cells",
		Vector2i(-1, 0),
		Vector2i(1, 0)
	)
	_expect(bool(route.get("ok", false)), "the planner finds a route between two loaded cells")
	if bool(route.get("ok", false)):
		var cells: Array = route.get("cell_path", [])
		var keys: Array = route.get("cell_keys", [])
		var directions: Array = route.get("edge_directions", [])
		_expect(cells.size() >= 3, "the route contains at least the start, connecting cell and goal")
		_expect(cells.front() == Vector2i(-1, 0), "the route begins at the requested start cell")
		_expect(cells.back() == Vector2i(1, 0), "the route ends at the requested goal cell")
		_expect(directions.size() == maxi(0, cells.size() - 1), "the route contains one edge direction per transition")
		_expect(keys.size() == cells.size(), "the route contains a stable key for every cell")
		var loaded_keys: Array = runtime.call("get_loaded_cell_keys")
		for index in range(cells.size()):
			var cell: Vector2i = cells[index]
			_expect(loaded_keys.has("%d,%d" % [cell.x, cell.y]), "every route cell is inside the currently loaded window")
			if index + 1 >= cells.size():
				continue
			var direction: Vector2i = directions[index]
			var next_cell: Vector2i = cells[index + 1]
			_expect(next_cell - cell == direction, "each route edge is a cardinal transition")
			_expect(LayoutScript.edge_is_open(cell, direction, TEST_SEED), "each route transition uses an open deterministic edge")
			_expect(
				LayoutScript.edge_is_open(next_cell, -direction, TEST_SEED),
				"the destination agrees that the shared edge is open"
			)

	var repeated: Dictionary = runtime.call(
		"plan_route_between_loaded_cells",
		Vector2i(-1, 0),
		Vector2i(1, 0)
	)
	_expect(
		bool(repeated.get("ok", false))
		and repeated.get("cell_path", []) == route.get("cell_path", []),
		"repeated route requests return the same deterministic path"
	)
	_expect(bool(runtime.call("is_route_snapshot_current", route)), "a route snapshot is current before the loaded window changes")
	var invalid_ok_type: Dictionary = route.duplicate(true)
	invalid_ok_type["ok"] = "true"
	_expect(not bool(runtime.call("is_route_snapshot_current", invalid_ok_type)), "route snapshots require a boolean success flag")
	var invalid_seed_type: Dictionary = route.duplicate(true)
	invalid_seed_type["world_seed"] = str(TEST_SEED)
	_expect(not bool(runtime.call("is_route_snapshot_current", invalid_seed_type)), "route snapshots reject string-encoded world seeds")
	var invalid_endpoint: Dictionary = route.duplicate(true)
	invalid_endpoint["start_cell"] = Vector2i.ZERO
	_expect(not bool(runtime.call("is_route_snapshot_current", invalid_endpoint)), "route snapshots reject endpoints that disagree with the cell path")
	var tampered_route: Dictionary = route.duplicate(true)
	var tampered_directions: Array = tampered_route.get("edge_directions", []).duplicate(true)
	if not tampered_directions.is_empty():
		tampered_directions[0] = Vector2i.ZERO
		tampered_route["edge_directions"] = tampered_directions
	_expect(not bool(runtime.call("is_route_snapshot_current", tampered_route)), "a modified route edge is rejected by snapshot validation")

	var same_cell: Dictionary = runtime.call(
		"plan_route_between_loaded_cells",
		Vector2i.ZERO,
		Vector2i.ZERO
	)
	_expect(
		bool(same_cell.get("ok", false))
		and same_cell.get("cell_path", []) == [Vector2i.ZERO]
		and same_cell.get("edge_directions", []).is_empty(),
		"a route from a cell to itself contains one cell and no edges"
	)

	var missing_goal: Dictionary = runtime.call(
		"plan_route_between_loaded_cells",
		Vector2i.ZERO,
		Vector2i(20, 20)
	)
	_expect(
		not bool(missing_goal.get("ok", false))
		and str(missing_goal.get("reason", "")) == "goal_cell_not_loaded",
		"routes fail closed when the requested goal is not loaded"
	)
	var missing_start: Dictionary = runtime.call(
		"plan_route_between_loaded_cells",
		Vector2i(20, 20),
		Vector2i.ZERO
	)
	_expect(
		not bool(missing_start.get("ok", false))
		and str(missing_start.get("reason", "")) == "start_cell_not_loaded",
		"routes fail closed when the requested start is not loaded"
	)
	_expect(runtime.call("to_save_dict") == before_save, "route planning does not mutate the maze save state")
	var shifted: Dictionary = runtime.call("sync_to_world_position", Vector3(24.0, 0.0, 0.0))
	_expect(bool(shifted.get("ok", false)), "the active runtime commits a new loaded window")
	_expect(not bool(runtime.call("is_route_snapshot_current", route)), "a route snapshot is rejected after the loaded-window generation changes")
	var fresh_route: Dictionary = runtime.call("plan_route_between_loaded_cells", Vector2i(3, 0), Vector2i(3, 0))
	_expect(bool(fresh_route.get("ok", false)) and bool(runtime.call("is_route_snapshot_current", fresh_route)), "a new route snapshot is accepted for the committed window")

	var stream_state: RefCounted = runtime.get("stream_state") as RefCounted
	var descriptors: Array = stream_state.call("get_loaded_cell_descriptors")
	var restricted_descriptors: Array = []
	for descriptor_value in descriptors:
		if descriptor_value is Dictionary:
			var descriptor: Dictionary = descriptor_value
			var cell_value: Variant = descriptor.get("cell", null)
			if cell_value == Vector2i(-1, 0) or cell_value == Vector2i(1, 0):
				restricted_descriptors.append(descriptor.duplicate(true))
	var disconnected: Dictionary = RoutePlannerScript.plan_route(
		Vector2i(-1, 0),
		Vector2i(1, 0),
		restricted_descriptors,
		TEST_LEVEL,
		TEST_SEED
	)
	_expect(
		not bool(disconnected.get("ok", false))
		and str(disconnected.get("reason", "")) == "no_route_in_loaded_window",
		"the planner does not invent a route through cells that are not loaded"
	)

	var adjacent_with_one_expansion: Dictionary = RoutePlannerScript.plan_route(
		Vector2i.ZERO,
		Vector2i(1, 0),
		descriptors,
		TEST_LEVEL,
		TEST_SEED,
		1
	)
	_expect(
		bool(adjacent_with_one_expansion.get("ok", false))
		and adjacent_with_one_expansion.get("cell_path", []) == [Vector2i.ZERO, Vector2i(1, 0)],
		"a goal discovered within the final allowed expansion is accepted"
	)

	var limited: Dictionary = RoutePlannerScript.plan_route(
		Vector2i(-1, 0),
		Vector2i(1, 0),
		descriptors,
		TEST_LEVEL,
		TEST_SEED,
		1
	)
	_expect(
		not bool(limited.get("ok", false))
		and str(limited.get("reason", "")) == "search_budget_exceeded",
		"the planner respects its explicit expansion budget"
	)

	runtime.call("deactivate_destination")
	host.free()

func _test_rejected_descriptors_and_budgets() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var runtime: Node3D = RuntimeScript.new() as Node3D
	runtime.set("force_metadata_only", true)
	host.add_child(runtime)
	var prepared: Dictionary = runtime.call(
		"prepare_destination",
		TEST_LEVEL,
		TEST_SEED,
		Vector3.ZERO,
		8.0,
		1
	)
	_expect(bool(prepared.get("ok", false)), "a second deterministic window prepares for descriptor validation")
	if not bool(prepared.get("ok", false)):
		host.free()
		return
	var stream_state: RefCounted = runtime.get("stream_state") as RefCounted
	var descriptors: Array = stream_state.call("get_loaded_cell_descriptors")

	var duplicate_descriptors: Array = descriptors.duplicate(true)
	duplicate_descriptors.append(duplicate_descriptors[0].duplicate(true))
	var duplicate_result: Dictionary = RoutePlannerScript.plan_route(
		Vector2i.ZERO,
		Vector2i(1, 0),
		duplicate_descriptors,
		TEST_LEVEL,
		TEST_SEED
	)
	_expect(
		not bool(duplicate_result.get("ok", false))
		and str(duplicate_result.get("reason", "")) == "cell_descriptor_duplicate",
		"duplicate loaded-cell descriptors are rejected"
	)

	var tampered_descriptors: Array = descriptors.duplicate(true)
	for index in range(tampered_descriptors.size()):
		var descriptor: Dictionary = tampered_descriptors[index]
		if descriptor.get("cell", null) == Vector2i.ZERO:
			var edges: Dictionary = descriptor.get("open_edges", {}).duplicate(true)
			edges["east"] = not bool(edges.get("east", false))
			descriptor["open_edges"] = edges
			tampered_descriptors[index] = descriptor
			break
	var tampered_result: Dictionary = RoutePlannerScript.plan_route(
		Vector2i.ZERO,
		Vector2i(1, 0),
		tampered_descriptors,
		TEST_LEVEL,
		TEST_SEED
	)
	_expect(
		not bool(tampered_result.get("ok", false))
		and str(tampered_result.get("reason", "")) == "cell_descriptor_topology_mismatch",
		"tampered open-edge metadata is rejected against the deterministic layout"
	)

	var seed_mismatch: Dictionary = RoutePlannerScript.plan_route(
		Vector2i.ZERO,
		Vector2i(1, 0),
		descriptors,
		TEST_LEVEL,
		TEST_SEED + 1
	)
	_expect(
		not bool(seed_mismatch.get("ok", false))
		and str(seed_mismatch.get("reason", "")) == "cell_descriptor_world_seed_mismatch",
		"descriptors from another world seed cannot be mixed into a route"
	)

	var invalid_budget: Dictionary = RoutePlannerScript.plan_route(
		Vector2i.ZERO,
		Vector2i(1, 0),
		descriptors,
		TEST_LEVEL,
		TEST_SEED,
		0
	)
	_expect(
		not bool(invalid_budget.get("ok", false))
		and str(invalid_budget.get("reason", "")) == "search_budget_invalid",
		"zero or negative expansion budgets are rejected"
	)
	host.free()


func _test_maximum_loaded_window_stress() -> void:
	var seeds: Array[int] = [0, 1, 42, 20261118, 2147483647]
	for seed in seeds:
		var stream_state: RefCounted = StreamStateScript.new()
		_expect(bool(stream_state.call("configure", TEST_LEVEL, seed, 8.0, 8)), "maximum-window stream configures for seed %d" % seed)
		var plan: Dictionary = stream_state.call("plan_window_at_cell", Vector2i.ZERO)
		_expect(bool(plan.get("ok", false)), "maximum-window plan succeeds for seed %d" % seed)
		if not bool(plan.get("ok", false)):
			continue
		var staged_keys: Array = plan.get("load_cell_keys", [])
		_expect(staged_keys.size() == 289, "the stream exposes exactly 289 cells at radius eight for seed %d" % seed)
		_expect(bool(stream_state.call("commit_window", plan, staged_keys)), "all 289 descriptors commit for seed %d" % seed)
		var descriptors: Array = stream_state.call("get_loaded_cell_descriptors")
		_expect(descriptors.size() == 289, "the committed maximum window returns 289 descriptors for seed %d" % seed)
		var route: Dictionary = RoutePlannerScript.plan_route(
			Vector2i(-8, -8), Vector2i(8, 8), descriptors, TEST_LEVEL, seed, 289
		)
		_expect(bool(route.get("ok", false)), "the planner connects opposite corners in the maximum window for seed %d" % seed)
		if not bool(route.get("ok", false)):
			continue
		var cells: Array = route.get("cell_path", [])
		var directions: Array = route.get("edge_directions", [])
		_expect(cells.size() <= 33, "BFS is no longer than the guaranteed 33-cell spanning-tree route for seed %d" % seed)
		_expect(int(route.get("expanded_count", 999)) <= 289, "BFS expansion count stays within the 289-cell budget for seed %d" % seed)
		_expect(directions.size() == cells.size() - 1, "maximum-window route edge count is consistent for seed %d" % seed)
		var seen_cells: Dictionary = {}
		for index in range(cells.size()):
			var cell_value: Variant = cells[index]
			if not (cell_value is Vector2i):
				_expect(false, "maximum-window route cells are typed for seed %d" % seed)
				continue
			var cell: Vector2i = cell_value
			var key: String = "%d,%d" % [cell.x, cell.y]
			_expect(not seen_cells.has(key), "maximum-window route contains no cycles for seed %d" % seed)
			seen_cells[key] = true
			_expect(abs(cell.x) <= 8 and abs(cell.y) <= 8, "maximum-window route remains inside the 17x17 window for seed %d" % seed)
			if index + 1 >= cells.size():
				continue
			var next_cell: Vector2i = cells[index + 1]
			var direction: Vector2i = directions[index]
			_expect(next_cell - cell == direction, "maximum-window transitions are cardinal for seed %d" % seed)
			_expect(LayoutScript.edge_is_open(cell, direction, seed), "maximum-window source edge is open for seed %d" % seed)
			_expect(LayoutScript.edge_is_open(next_cell, -direction, seed), "maximum-window destination edge is reciprocal for seed %d" % seed)
		var repeated: Dictionary = RoutePlannerScript.plan_route(
			Vector2i(-8, -8), Vector2i(8, 8), descriptors, TEST_LEVEL, seed, 289
		)
		_expect(
			bool(repeated.get("ok", false)) and repeated.get("cell_path", []) == cells,
			"maximum-window route is deterministic across repeated requests for seed %d" % seed
		)
		if seed == seeds[0]:
			var oversized: Array = descriptors.duplicate(true)
			oversized.append(descriptors[0].duplicate(true))
			var oversized_result: Dictionary = RoutePlannerScript.plan_route(
				Vector2i(-8, -8), Vector2i(8, 8), oversized, TEST_LEVEL, seed, 289
			)
			_expect(
				not bool(oversized_result.get("ok", false))
				and str(oversized_result.get("reason", "")) == "loaded_cell_descriptor_count_invalid",
				"the planner rejects a 290th loaded-cell descriptor"
			)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)

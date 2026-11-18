extends Node3D
class_name BackroomsMazeCellRuntime

## SurfaceWorld-owned scene runtime for the renderer-independent Backrooms maze stream contract.
## New cell roots are built detached, the logical window is committed, then old roots are retired.
const StreamStateScript = preload("res://systems/BackroomsMazeStreamState.gd")
const EntityDirectorScript = preload("res://systems/BackroomsEntityDirector.gd")
const VisualFactoryScript = preload("res://systems/BackroomsEntityVisualFactory.gd")
const EntityBrainScript = preload("res://systems/BackroomsEntityBrain.gd")
const LightingProfileScript = preload("res://systems/BackroomsLightingProfile.gd")
const CollisionFactoryScript = preload("res://systems/BackroomsEntityCollisionFactory.gd")
const EntityRuntimeStateScript = preload("res://systems/BackroomsEntityRuntimeState.gd")
const CellRoutePlannerScript = preload("res://systems/BackroomsCellRoutePlanner.gd")
const OwnershipLedgerScript = preload("res://systems/BackroomsEntityOwnershipLedger.gd")
const LayoutScript = preload("res://systems/BackroomsMazeLayout.gd")

const ENTITY_SAFE_CELL_MARGIN: float = 0.65
const ENTITY_COLLISION_SAFE_MARGIN: float = 0.02
const ENTITY_TRANSFER_EDGE_TOLERANCE: float = 0.25

const FLOOR_THICKNESS: float = 0.2
const WALL_THICKNESS: float = 0.18
const WALL_HEIGHT: float = 3.2
const WORLD_GEOMETRY_LAYER: int = 1

var stream_state: RefCounted = StreamStateScript.new()
var ownership_ledger: RefCounted = OwnershipLedgerScript.new()
var cell_roots: Dictionary = {}
var prepared: bool = false
var active: bool = false
var force_metadata_only: bool = false
var last_error: String = ""

var _cell_builder_override: Callable = Callable()
var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D

func _ready() -> void:
	visible = false

## Prepare a hidden destination. The current runtime is left untouched if configuration,
## staging, or the logical stream commit fails.
func prepare_destination(
	destination_level: String,
	layout_seed: int,
	entry_position: Vector3,
	requested_cell_size: float = 8.0,
	requested_stream_radius: int = 1
) -> Dictionary:
	last_error = ""
	if active:
		return _failure("runtime_already_active")
	if not _is_finite_vector3(entry_position):
		return _failure("entry_position_invalid")
	var candidate: RefCounted = StreamStateScript.new()
	if not bool(candidate.call("configure", destination_level, layout_seed, requested_cell_size, requested_stream_radius)):
		return _failure("stream_configuration_rejected")
	var plan_value: Variant = candidate.call("plan_window_for_position", entry_position)
	if not (plan_value is Dictionary) or not bool(plan_value.get("ok", false)):
		return _failure(str(plan_value.get("reason", "initial_window_plan_rejected")) if plan_value is Dictionary else "initial_window_plan_invalid")
	var plan: Dictionary = plan_value
	var expected_generation: int = int(candidate.call("get_generation")) + 1
	var ownership_setup: Dictionary = _create_ownership_ledger(
		candidate, plan, expected_generation, int(candidate.call("get_configuration_revision")), {}
	)
	if not bool(ownership_setup.get("ok", false)):
		return _failure(str(ownership_setup.get("reason", "ownership_ledger_prepare_failed")))
	var candidate_ledger: RefCounted = ownership_setup.get("ledger") as RefCounted
	var ownership_records: Array = candidate_ledger.call("get_records")
	var staged_result: Dictionary = _stage_cell_roots(candidate, plan, ownership_records, [])
	if not bool(staged_result.get("ok", false)):
		return _failure(str(staged_result.get("reason", "cell_staging_failed")))
	var staged_roots: Dictionary = staged_result.get("roots", {})
	var staged_keys: Array = plan.get("load_cell_keys", [])
	if not bool(candidate.call("commit_window", plan, staged_keys)):
		_dispose_staged_roots(staged_roots)
		return _failure("initial_stream_commit_rejected")
	if not bool(candidate.call("set_entity_ownership_ledger_state", ownership_setup.get("save", {}))):
		_dispose_staged_roots(staged_roots)
		return _failure("initial_ownership_ledger_save_state_rejected")
	_replace_all_cell_roots(staged_roots)
	stream_state = candidate
	ownership_ledger = candidate_ledger
	prepared = true
	active = false
	visible = false
	_set_collision_enabled(false)
	return {
		"ok": true,
		"event": "destination_prepared",
		"level_id": destination_level,
		"layout_seed": layout_seed,
		"loaded_cell_count": get_loaded_cell_count(),
		"metadata_only": _is_metadata_only()
	}

## Shift the loaded window without dropping the old roots until every new root is staged
## and the exact logical plan has committed successfully.
func sync_to_world_position(world_position: Vector3) -> Dictionary:
	last_error = ""
	if not prepared:
		return _failure("destination_not_prepared")
	if not _is_finite_vector3(world_position):
		return _failure("world_position_invalid")
	var candidate: RefCounted = stream_state.call("clone_for_transaction")
	if candidate == null or not bool(candidate.get("configured")):
		return _failure("stream_state_clone_failed")
	var plan_value: Variant = candidate.call("plan_window_for_position", world_position)
	if not (plan_value is Dictionary) or not bool(plan_value.get("ok", false)):
		return _failure(str(plan_value.get("reason", "window_plan_rejected")) if plan_value is Dictionary else "window_plan_invalid")
	var plan: Dictionary = plan_value
	var state_collection: Dictionary = _collect_entity_runtime_states(
		candidate,
		plan.get("center_cell", candidate.get("center_cell"))
	)
	if not bool(state_collection.get("ok", false)):
		return _failure(str(state_collection.get("reason", "entity_runtime_state_capture_failed")))
	if not bool(candidate.call("set_entity_runtime_states", state_collection.get("records", []))):
		return _failure("entity_runtime_state_validation_failed")
	var expected_generation: int = int(candidate.call("get_generation")) + 1
	var current_ownership_save: Dictionary = _get_ownership_ledger_save(stream_state, ownership_ledger)
	if current_ownership_save.is_empty():
		return _failure("current_ownership_ledger_snapshot_invalid")
	var ownership_setup: Dictionary = _create_ownership_ledger(
		candidate, plan, expected_generation, int(candidate.call("get_configuration_revision")), current_ownership_save
	)
	if not bool(ownership_setup.get("ok", false)):
		return _failure(str(ownership_setup.get("reason", "ownership_ledger_window_update_failed")))
	var candidate_ledger: RefCounted = ownership_setup.get("ledger") as RefCounted
	var ownership_records: Array = candidate_ledger.call("get_records")
	var entity_state_records: Array = candidate.call("get_entity_runtime_states")
	var staged_result: Dictionary = _stage_cell_roots(candidate, plan, ownership_records, entity_state_records)
	if not bool(staged_result.get("ok", false)):
		return _failure(str(staged_result.get("reason", "cell_staging_failed")))
	var staged_roots: Dictionary = staged_result.get("roots", {})
	if not _restore_entity_runtime_states(staged_roots, entity_state_records, ownership_records):
		_dispose_staged_roots(staged_roots)
		return _failure("staged_entity_runtime_state_restore_failed")
	var staged_keys: Array = plan.get("load_cell_keys", [])
	if not bool(candidate.call("commit_window", plan, staged_keys)):
		_dispose_staged_roots(staged_roots)
		return _failure("stream_commit_rejected")
	if not bool(candidate.call("set_entity_ownership_ledger_state", ownership_setup.get("save", {}))):
		_dispose_staged_roots(staged_roots)
		return _failure("stream_ownership_ledger_state_rejected")
	for key_value in staged_roots.keys():
		var key: String = str(key_value)
		var cell_root: Node3D = staged_roots[key] as Node3D
		add_child(cell_root)
		cell_roots[key] = cell_root
	for key_value in plan.get("unload_cell_keys", []):
		_retire_cell_root(str(key_value))
	stream_state = candidate
	ownership_ledger = candidate_ledger
	_set_collision_enabled(active)
	return {
		"ok": true,
		"event": "window_committed",
		"center_cell": stream_state.get("center_cell"),
		"loaded_cell_count": get_loaded_cell_count(),
		"load_count": staged_roots.size(),
		"keep_count": plan.get("keep_cell_keys", []).size(),
		"unload_count": plan.get("unload_cell_keys", []).size(),
		"retained_entity_state_count": stream_state.call("get_entity_runtime_states").size(),
		"ownership_record_count": ownership_ledger.call("get_records").size(),
		"evicted_ownership_record_count": int(ownership_setup.get("evicted_count", 0))
	}

func activate_destination() -> bool:
	if not prepared or get_loaded_cell_count() <= 0:
		return false
	active = true
	visible = true
	_set_collision_enabled(true)
	return true

func deactivate_destination() -> bool:
	if not prepared and cell_roots.is_empty():
		return false
	active = false
	visible = false
	_set_collision_enabled(false)
	for key_value in cell_roots.keys().duplicate():
		_retire_cell_root(str(key_value))
	stream_state = StreamStateScript.new()
	ownership_ledger = OwnershipLedgerScript.new()
	prepared = false
	return true

func to_save_dict() -> Dictionary:
	if not prepared:
		return {}
	var state_collection: Dictionary = _collect_entity_runtime_states(
		stream_state,
		stream_state.get("center_cell")
	)
	if not bool(state_collection.get("ok", false)):
		last_error = str(state_collection.get("reason", "entity_runtime_state_capture_failed"))
		return {}
	if not bool(stream_state.call("set_entity_runtime_states", state_collection.get("records", []))):
		last_error = "entity_runtime_state_validation_failed"
		return {}
	var ownership_save: Dictionary = _get_ownership_ledger_save(stream_state, ownership_ledger)
	if ownership_save.is_empty():
		last_error = "entity_ownership_ledger_snapshot_invalid"
		return {}
	if not bool(stream_state.call("set_entity_ownership_ledger_state", ownership_save)):
		last_error = "entity_ownership_ledger_state_rejected"
		return {}
	last_error = ""
	return stream_state.call("to_save_dict")

## Restore into a detached candidate state and candidate roots. Existing live roots/state
## are replaced only after the entire candidate window has staged and committed.
func load_save_dict(payload: Dictionary) -> bool:
	last_error = ""
	if active:
		return _reject("runtime_active")
	var candidate: RefCounted = StreamStateScript.new()
	if not bool(candidate.call("load_save_dict", payload)):
		return _reject(str(candidate.get("last_load_error")))
	var plan_value: Variant = candidate.call("plan_window_at_cell", candidate.get("center_cell"))
	if not (plan_value is Dictionary) or not bool(plan_value.get("ok", false)):
		return _reject("restore_window_plan_rejected")
	var plan: Dictionary = plan_value
	var expected_generation: int = int(candidate.call("get_generation")) + 1
	var saved_ownership_state: Dictionary = candidate.call("get_entity_ownership_ledger_state")
	var ownership_setup: Dictionary = _create_ownership_ledger(
		candidate, plan, expected_generation, int(candidate.call("get_configuration_revision")), saved_ownership_state
	)
	if not bool(ownership_setup.get("ok", false)):
		return _reject(str(ownership_setup.get("reason", "restore_ownership_ledger_failed")))
	var candidate_ledger: RefCounted = ownership_setup.get("ledger") as RefCounted
	var ownership_records: Array = candidate_ledger.call("get_records")
	var entity_state_records: Array = candidate.call("get_entity_runtime_states")
	var staged_result: Dictionary = _stage_cell_roots(candidate, plan, ownership_records, entity_state_records)
	if not bool(staged_result.get("ok", false)):
		return _reject(str(staged_result.get("reason", "restore_cell_staging_failed")))
	var staged_roots: Dictionary = staged_result.get("roots", {})
	if not _restore_entity_runtime_states(staged_roots, entity_state_records, ownership_records):
		_dispose_staged_roots(staged_roots)
		return _reject("restore_entity_runtime_state_failed")
	if not bool(candidate.call("commit_window", plan, plan.get("load_cell_keys", []))):
		_dispose_staged_roots(staged_roots)
		return _reject("restore_stream_commit_rejected")
	if not bool(candidate.call("set_entity_ownership_ledger_state", ownership_setup.get("save", {}))):
		_dispose_staged_roots(staged_roots)
		return _reject("restore_ownership_ledger_state_rejected")
	_replace_all_cell_roots(staged_roots)
	stream_state = candidate
	ownership_ledger = candidate_ledger
	prepared = true
	active = false
	visible = false
	_set_collision_enabled(false)
	return true


func get_loaded_cell_count() -> int:
	return int(stream_state.call("get_loaded_cell_count"))

func get_loaded_cell_keys() -> Array:
	return stream_state.call("get_loaded_cell_keys")

## Plan a deterministic route through the active loaded-cell graph.
## This is read-only and deliberately rejects cells outside the current stream window.
func plan_route_between_loaded_cells(start_cell: Vector2i, goal_cell: Vector2i) -> Dictionary:
	if not prepared:
		return {"ok": false, "reason": "runtime_not_prepared"}
	if not active:
		return {"ok": false, "reason": "runtime_not_active"}
	if stream_state == null or not stream_state.has_method("get_loaded_cell_descriptors"):
		return {"ok": false, "reason": "loaded_cell_descriptor_contract_unavailable"}
	var descriptors_value: Variant = stream_state.call("get_loaded_cell_descriptors")
	if not (descriptors_value is Array):
		return {"ok": false, "reason": "loaded_cell_descriptors_invalid"}
	var result: Dictionary = CellRoutePlannerScript.plan_route(
		start_cell,
		goal_cell,
		descriptors_value,
		str(stream_state.get("level_id")),
		int(stream_state.get("world_seed"))
	)
	if bool(result.get("ok", false)):
		result["stream_center_cell"] = stream_state.get("center_cell")
		result["loaded_cell_count"] = descriptors_value.size()
		result["stream_generation"] = int(stream_state.call("get_generation"))
		result["configuration_revision"] = int(stream_state.call("get_configuration_revision"))
	return result

## A route is a snapshot of one committed loaded window. Reject stale or modified
## snapshots before a movement/navigation consumer acts on them.
func is_route_snapshot_current(route: Dictionary) -> bool:
	if not prepared or not active or stream_state == null:
		return false
	var ok_value: Variant = route.get("ok", null)
	if not (ok_value is bool) or not bool(ok_value):
		return false
	var snapshot_version_value: Variant = route.get("route_snapshot_version", null)
	if not (snapshot_version_value is int) or int(snapshot_version_value) != CellRoutePlannerScript.ROUTE_SNAPSHOT_VERSION:
		return false
	var generation_value: Variant = route.get("stream_generation", null)
	var revision_value: Variant = route.get("configuration_revision", null)
	if not (generation_value is int) or int(generation_value) != int(stream_state.call("get_generation")):
		return false
	if not (revision_value is int) or int(revision_value) != int(stream_state.call("get_configuration_revision")):
		return false
	var level_value: Variant = route.get("level_id", null)
	var world_seed_value: Variant = route.get("world_seed", null)
	var layout_version_value: Variant = route.get("layout_algorithm_version", null)
	if not (level_value is String) or str(level_value) != str(stream_state.get("level_id")):
		return false
	if not (world_seed_value is int) or int(world_seed_value) != int(stream_state.get("world_seed")):
		return false
	if not (layout_version_value is int) or int(layout_version_value) != LayoutScript.ALGORITHM_VERSION:
		return false
	var center_value: Variant = route.get("stream_center_cell", null)
	if not (center_value is Vector2i) or center_value != stream_state.get("center_cell"):
		return false
	var loaded_count_value: Variant = route.get("loaded_cell_count", null)
	if not (loaded_count_value is int) or int(loaded_count_value) != int(stream_state.call("get_loaded_cell_count")):
		return false
	var cells_value: Variant = route.get("cell_path", null)
	var keys_value: Variant = route.get("cell_keys", null)
	var directions_value: Variant = route.get("edge_directions", null)
	if not (cells_value is Array) or not (keys_value is Array) or not (directions_value is Array):
		return false
	var cells: Array = cells_value
	var cell_keys: Array = keys_value
	var directions: Array = directions_value
	if cells.is_empty() or cells.size() > 289 or cell_keys.size() != cells.size() or directions.size() != cells.size() - 1:
		return false
	var start_value: Variant = route.get("start_cell", null)
	var goal_value: Variant = route.get("goal_cell", null)
	var route_count_value: Variant = route.get("route_cell_count", null)
	var expanded_value: Variant = route.get("expanded_count", null)
	if not (start_value is Vector2i) or not (goal_value is Vector2i):
		return false
	if start_value != cells.front() or goal_value != cells.back():
		return false
	if not (route_count_value is int) or int(route_count_value) != cells.size():
		return false
	if not (expanded_value is int) or int(expanded_value) < 1 or int(expanded_value) > 289:
		return false
	var seen: Dictionary = {}
	var world_seed: int = int(stream_state.get("world_seed"))
	for index in range(cells.size()):
		var cell_value: Variant = cells[index]
		if not (cell_value is Vector2i):
			return false
		var cell: Vector2i = cell_value
		var cell_key: String = "%d,%d" % [cell.x, cell.y]
		if not (cell_keys[index] is String) or str(cell_keys[index]) != cell_key or seen.has(cell_key):
			return false
		if not bool(stream_state.call("is_cell_loaded", cell)):
			return false
		seen[cell_key] = true
		if index + 1 >= cells.size():
			continue
		var next_value: Variant = cells[index + 1]
		var direction_value: Variant = directions[index]
		if not (next_value is Vector2i) or not (direction_value is Vector2i):
			return false
		var next_cell: Vector2i = next_value
		var direction: Vector2i = direction_value
		if absi(direction.x) + absi(direction.y) != 1 or next_cell - cell != direction:
			return false
		if not LayoutScript.edge_is_open(cell, direction, world_seed):
			return false
		if not LayoutScript.edge_is_open(next_cell, -direction, world_seed):
			return false
	return true

func get_cell_root(cell_key: String) -> Node3D:
	var value: Variant = cell_roots.get(cell_key, null)
	if value is Node3D and is_instance_valid(value):
		return value as Node3D
	return null

## Submit a validated perception snapshot to one loaded entity.
## The owning SurfaceWorld/perception driver supplies sensors; this runtime gates
## decisions so hidden or inactive Backrooms destinations cannot run entity logic.
func submit_entity_perception(
	cell_key: String,
	requested_entity_id: String,
	perception: Dictionary,
	delta_seconds: float = 0.0,
	requested_spawn_cell_key: String = ""
) -> Dictionary:
	if not active:
		return {"ok": false, "reason": "destination_not_active"}
	if cell_key.is_empty() or requested_entity_id.is_empty():
		return {"ok": false, "reason": "entity_identity_invalid"}
	var cell_root: Node3D = get_cell_root(cell_key)
	if cell_root == null:
		return {"ok": false, "reason": "cell_not_loaded"}
	var entity_root: Node3D = null
	var matching_count: int = 0
	for child in cell_root.get_children():
		if not (child is Node3D) or child.get_meta("backrooms_entity_id", "") != requested_entity_id:
			continue
		var spawn_cell_value: Variant = child.get_meta("spawn_cell", null)
		if not (spawn_cell_value is Vector2i):
			return {"ok": false, "reason": "entity_spawn_identity_invalid"}
		var spawn_cell: Vector2i = spawn_cell_value
		var candidate_spawn_key: String = "%d,%d" % [spawn_cell.x, spawn_cell.y]
		if not requested_spawn_cell_key.is_empty() and candidate_spawn_key != requested_spawn_cell_key:
			continue
		entity_root = child as Node3D
		matching_count += 1
	if matching_count <= 0 or entity_root == null:
		return {"ok": false, "reason": "entity_not_loaded"}
	if matching_count > 1:
		return {"ok": false, "reason": "entity_identity_ambiguous"}
	var brain: Node = entity_root.get_node_or_null("AI")
	if brain == null or not brain.has_method("evaluate_perception"):
		return {"ok": false, "reason": "entity_brain_unavailable"}
	var decision_value: Variant = brain.call("evaluate_perception", perception.duplicate(true), delta_seconds)
	if decision_value is Dictionary:
		return decision_value
	return {"ok": false, "reason": "entity_brain_result_invalid"}

func is_active() -> bool:
	return active

func is_prepared() -> bool:
	return prepared

func get_last_error() -> String:
	return last_error

## Dependency injection is intentionally limited to tests so staging failure can be
## exercised without manufacturing a renderer or corrupting the production state.
func set_cell_builder_for_testing(builder: Callable) -> void:
	_cell_builder_override = builder

func clear_cell_builder_for_testing() -> void:
	_cell_builder_override = Callable()

func _stage_cell_roots(
	candidate: RefCounted,
	plan: Dictionary,
	ownership_records: Array = [],
	entity_state_records: Array = []
) -> Dictionary:
	var descriptors_value: Variant = plan.get("cell_descriptors", [])
	if not (descriptors_value is Array):
		return {"ok": false, "reason": "cell_descriptors_invalid"}
	var descriptors_by_key: Dictionary = {}
	for descriptor_value in descriptors_value:
		if not (descriptor_value is Dictionary):
			return {"ok": false, "reason": "cell_descriptor_invalid"}
		var key: String = str(descriptor_value.get("cell_key", ""))
		if key.is_empty() or descriptors_by_key.has(key):
			return {"ok": false, "reason": "cell_descriptor_key_invalid"}
		descriptors_by_key[key] = descriptor_value
	var staged_roots: Dictionary = {}
	for key_value in plan.get("load_cell_keys", []):
		var key: String = str(key_value)
		if not descriptors_by_key.has(key):
			_dispose_staged_roots(staged_roots)
			return {"ok": false, "reason": "cell_descriptor_missing"}
		var root_value: Variant = _build_cell_root(
			descriptors_by_key[key],
			float(candidate.get("cell_size")),
			int(candidate.get("entity_spawn_algorithm_version")),
			ownership_records,
			entity_state_records
		)
		if not (root_value is Node3D) or root_value.get_parent() != null:
			if root_value is Node3D and is_instance_valid(root_value):
				root_value.free()
			_dispose_staged_roots(staged_roots)
			return {"ok": false, "reason": "cell_root_build_failed"}
		staged_roots[key] = root_value
	return {"ok": true, "roots": staged_roots}

func _build_cell_root(
	descriptor: Dictionary,
	cell_size: float,
	spawn_algorithm_version: int,
	ownership_records: Array,
	entity_state_records: Array
) -> Node3D:
	if not EntityDirectorScript.is_spawn_algorithm_version_supported(spawn_algorithm_version):
		return null
	if int(descriptor.get("entity_spawn_algorithm_version", 0)) != spawn_algorithm_version:
		return null
	if _cell_builder_override.is_valid():
		var injected: Variant = _cell_builder_override.call(descriptor.duplicate(true), _is_metadata_only())
		return injected as Node3D if injected is Node3D else null
	var cell_value: Variant = descriptor.get("cell", null)
	var origin_value: Variant = descriptor.get("world_origin", null)
	var edges_value: Variant = descriptor.get("open_edges", null)
	if not (cell_value is Vector2i) or not (origin_value is Vector3) or not (edges_value is Dictionary):
		return null
	var cell: Vector2i = cell_value
	var root := Node3D.new()
	root.name = "MazeCell_%d_%d" % [cell.x, cell.y]
	root.position = origin_value
	root.set_meta("backrooms_cell_key", str(descriptor.get("cell_key", "")))
	root.set_meta("backrooms_cell", cell)
	root.set_meta("backrooms_cell_size", cell_size)
	root.set_meta("backrooms_level_id", str(descriptor.get("level_id", "")))
	root.set_meta("backrooms_world_seed", int(descriptor.get("world_seed", 0)))
	root.set_meta("backrooms_layout_algorithm_version", int(descriptor.get("layout_algorithm_version", 0)))
	root.set_meta("backrooms_entity_spawn_algorithm_version", spawn_algorithm_version)
	root.set_meta("backrooms_open_edges", edges_value.duplicate(true))
	var lighting_descriptor: Dictionary = LightingProfileScript.get_cell_light_descriptor(
		str(descriptor.get("level_id", "")),
		cell,
		int(descriptor.get("world_seed", 0)),
		WALL_HEIGHT
	)
	if lighting_descriptor.is_empty():
		root.free()
		return null
	root.set_meta("backrooms_light_descriptor", lighting_descriptor.duplicate(true))
	root.set_meta("backrooms_graphical_lighting_expected", not _is_metadata_only())
	if not _build_cell_entity_roots(
		root,
		cell,
		str(descriptor.get("level_id", "")),
		int(descriptor.get("world_seed", 0)),
		cell_size,
		edges_value,
		spawn_algorithm_version,
		ownership_records,
		entity_state_records
	):
		root.free()
		return null
	if _is_metadata_only():
		return root
	_build_cell_geometry(root, edges_value, cell_size, lighting_descriptor)
	return root

func _build_cell_entity_roots(
	cell_root: Node3D,
	cell: Vector2i,
	level_id: String,
	world_seed: int,
	cell_size: float,
	open_edges: Dictionary,
	spawn_algorithm_version: int,
	ownership_records: Array,
	entity_state_records: Array
) -> bool:
	var owner_cell_key: String = str(cell_root.get_meta("backrooms_cell_key", ""))
	var ownership_by_key: Dictionary = {}
	for record_value in ownership_records:
		if not (record_value is Dictionary):
			return false
		var record: Dictionary = record_value
		var identity_key: String = OwnershipLedgerScript.get_state_key(
			str(record.get("spawn_cell_key", "")), str(record.get("entity_id", ""))
		)
		if identity_key.is_empty() or ownership_by_key.has(identity_key):
			return false
		ownership_by_key[identity_key] = record
	var state_by_key: Dictionary = {}
	for state_value in entity_state_records:
		if not (state_value is Dictionary):
			return false
		var state_record: Dictionary = state_value
		var state_key: String = EntityRuntimeStateScript.get_state_key(state_record)
		if state_key.is_empty() or state_by_key.has(state_key):
			return false
		state_by_key[state_key] = state_record
	var descriptors: Array[Dictionary] = EntityDirectorScript.get_cell_spawn_descriptors(
		level_id, cell, cell_size, open_edges, spawn_algorithm_version
	)
	var allowed_entities: Array[String] = EntityDirectorScript.get_allowed_entities(level_id)
	var seen: Dictionary = {}
	var spawn_ids: Array[String] = []
	var identity_keys: Array[String] = []
	var spawn_cell_key: String = "%d,%d" % [cell.x, cell.y]
	for descriptor in descriptors:
		var entity_id: String = str(descriptor.get("entity_id", ""))
		var descriptor_cell: Variant = descriptor.get("cell", null)
		if entity_id.is_empty() or not allowed_entities.has(entity_id):
			return false
		if int(descriptor.get("spawn_algorithm_version", 0)) != spawn_algorithm_version:
			return false
		if not (descriptor_cell is Vector2i) or descriptor_cell != cell:
			return false
		var identity_key: String = OwnershipLedgerScript.get_state_key(spawn_cell_key, entity_id)
		if seen.has(identity_key):
			return false
		seen[identity_key] = true
		var owner_record: Dictionary = ownership_by_key.get(identity_key, {})
		var actual_owner_key: String = str(owner_record.get("owner_cell_key", spawn_cell_key))
		if actual_owner_key != owner_cell_key:
			continue
		var initial_position_value: Variant = descriptor.get("local_position", null)
		if not (initial_position_value is Vector3):
			return false
		var entity_root: CharacterBody3D = _create_entity_root_from_descriptor(
			descriptor, owner_cell_key, initial_position_value,
			int(owner_record.get("owner_revision", 0)), level_id, world_seed
		)
		if entity_root == null:
			return false
		cell_root.add_child(entity_root)
		spawn_ids.append(entity_id)
		identity_keys.append(identity_key)
	for record_value in ownership_records:
		var record: Dictionary = record_value
		var actual_owner_key: String = str(record.get("owner_cell_key", ""))
		var original_spawn_key: String = str(record.get("spawn_cell_key", ""))
		if actual_owner_key != owner_cell_key or original_spawn_key == owner_cell_key:
			continue
		var entity_id: String = str(record.get("entity_id", ""))
		var identity_key: String = OwnershipLedgerScript.get_state_key(original_spawn_key, entity_id)
		if seen.has(identity_key) or not state_by_key.has(identity_key):
			return false
		var spawn_parse: Dictionary = EntityRuntimeStateScript.parse_cell_key(original_spawn_key)
		if not bool(spawn_parse.get("ok", false)):
			return false
		var spawn_cell: Vector2i = spawn_parse["cell"]
		var spawn_edges := {
			"north": LayoutScript.edge_is_open(spawn_cell, Vector2i(0, -1), world_seed),
			"east": LayoutScript.edge_is_open(spawn_cell, Vector2i(1, 0), world_seed),
			"south": LayoutScript.edge_is_open(spawn_cell, Vector2i(0, 1), world_seed),
			"west": LayoutScript.edge_is_open(spawn_cell, Vector2i(-1, 0), world_seed)
		}
		var spawn_descriptor: Dictionary = _find_spawn_descriptor(
			level_id, spawn_cell, cell_size, spawn_edges, spawn_algorithm_version, entity_id
		)
		if spawn_descriptor.is_empty():
			return false
		var migrated_root: CharacterBody3D = _create_entity_root_from_descriptor(
			spawn_descriptor, owner_cell_key, Vector3.ZERO,
			int(record.get("owner_revision", 0)), level_id, world_seed
		)
		if migrated_root == null:
			return false
		cell_root.add_child(migrated_root)
		seen[identity_key] = true
		spawn_ids.append(entity_id)
		identity_keys.append(identity_key)
	cell_root.set_meta("backrooms_entity_spawn_ids", spawn_ids.duplicate())
	cell_root.set_meta("backrooms_entity_identity_keys", identity_keys.duplicate())
	cell_root.set_meta("backrooms_entity_spawn_algorithm_version", spawn_algorithm_version)
	return true

func _create_entity_root_from_descriptor(
	descriptor: Dictionary,
	owner_cell_key: String,
	initial_position: Vector3,
	owner_revision: int,
	level_id: String,
	world_seed: int
) -> CharacterBody3D:
	var entity_id: String = str(descriptor.get("entity_id", ""))
	var spawn_cell_value: Variant = descriptor.get("cell", null)
	var wall_value: Variant = descriptor.get("wall_direction", null)
	var spawn_version: int = int(descriptor.get("spawn_algorithm_version", 0))
	if (
		entity_id.is_empty()
		or not (spawn_cell_value is Vector2i)
		or not (wall_value is Vector2i)
		or not _is_finite_vector3(initial_position)
		or world_seed < 0
		or not EntityDirectorScript.is_spawn_algorithm_version_supported(spawn_version)
	):
		return null
	var spawn_cell: Vector2i = spawn_cell_value
	var entity_root := CharacterBody3D.new()
	entity_root.name = "Entity_" + entity_id + "_" + str(spawn_cell.x) + "_" + str(spawn_cell.y)
	entity_root.position = initial_position
	entity_root.set_meta("backrooms_entity_id", entity_id)
	entity_root.set_meta("spawn_cell", spawn_cell)
	entity_root.set_meta("spawn_world_seed", world_seed)
	entity_root.set_meta("spawn_level_id", level_id)
	entity_root.set_meta("spawn_algorithm_version", spawn_version)
	entity_root.set_meta("backrooms_owner_cell_key", owner_cell_key)
	entity_root.set_meta("backrooms_owner_revision", owner_revision)
	entity_root.set_meta("backrooms_wall_direction", wall_value)
	entity_root.set_meta("backrooms_entity_visual_state", "not_attached")
	if not CollisionFactoryScript.attach_collision(entity_root, entity_id, active):
		entity_root.free()
		return null
	if not _is_metadata_only() and not VisualFactoryScript.attach_visuals(entity_root):
		entity_root.free()
		return null
	var brain: Node = EntityBrainScript.new()
	brain.name = "AI"
	if not bool(brain.call("configure", entity_id, level_id, spawn_cell, world_seed)):
		brain.free()
		entity_root.free()
		return null
	entity_root.set_meta("backrooms_entity_behavior_version", EntityBrainScript.BEHAVIOR_VERSION)
	entity_root.add_child(brain)
	return entity_root

func _find_spawn_descriptor(
	level_id: String,
	spawn_cell: Vector2i,
	cell_size: float,
	open_edges: Dictionary,
	spawn_algorithm_version: int,
	entity_id: String
) -> Dictionary:
	var descriptors: Array[Dictionary] = EntityDirectorScript.get_cell_spawn_descriptors(
		level_id, spawn_cell, cell_size, open_edges, spawn_algorithm_version
	)
	for descriptor in descriptors:
		if str(descriptor.get("entity_id", "")) == entity_id:
			return descriptor.duplicate(true)
	return {}

func _build_cell_geometry(
	root: Node3D,
	open_edges: Dictionary,
	cell_size: float,
	lighting_descriptor: Dictionary
) -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(cell_size, FLOOR_THICKNESS, cell_size)
	floor_mesh.mesh = floor_box
	floor_mesh.position = Vector3(0.0, -FLOOR_THICKNESS * 0.5, 0.0)
	floor_mesh.material_override = _get_floor_material()
	root.add_child(floor_mesh)

	if bool(lighting_descriptor.get("enabled", false)):
		var ceiling_light := OmniLight3D.new()
		ceiling_light.name = "BackroomsCeilingLight"
		var light_position: Vector3 = lighting_descriptor.get("local_position", Vector3(0.0, WALL_HEIGHT - 0.22, 0.0))
		var light_color: Color = lighting_descriptor.get("color", Color.WHITE)
		ceiling_light.position = light_position
		ceiling_light.light_color = light_color
		ceiling_light.light_energy = float(lighting_descriptor.get("energy", 0.0))
		ceiling_light.omni_range = float(lighting_descriptor.get("range", 0.0))
		ceiling_light.shadow_enabled = false
		root.add_child(ceiling_light)

	var collision := StaticBody3D.new()
	collision.name = "WorldCollision"
	collision.collision_layer = WORLD_GEOMETRY_LAYER if active else 0
	collision.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	var floor_box_shape := BoxShape3D.new()
	floor_box_shape.size = Vector3(cell_size, FLOOR_THICKNESS, cell_size)
	floor_shape.shape = floor_box_shape
	floor_shape.position = floor_mesh.position
	collision.add_child(floor_shape)

	var half: float = cell_size * 0.5
	var inset: float = WALL_THICKNESS * 0.5
	for edge in ["north", "east", "south", "west"]:
		if bool(open_edges.get(edge, false)):
			continue
		var wall_size: Vector3
		var wall_position: Vector3
		match edge:
			"north":
				wall_size = Vector3(cell_size, WALL_HEIGHT, WALL_THICKNESS)
				wall_position = Vector3(0.0, WALL_HEIGHT * 0.5, -half + inset)
			"south":
				wall_size = Vector3(cell_size, WALL_HEIGHT, WALL_THICKNESS)
				wall_position = Vector3(0.0, WALL_HEIGHT * 0.5, half - inset)
			"east":
				wall_size = Vector3(WALL_THICKNESS, WALL_HEIGHT, cell_size)
				wall_position = Vector3(half - inset, WALL_HEIGHT * 0.5, 0.0)
			_:
				wall_size = Vector3(WALL_THICKNESS, WALL_HEIGHT, cell_size)
				wall_position = Vector3(-half + inset, WALL_HEIGHT * 0.5, 0.0)
		var wall_mesh := MeshInstance3D.new()
		wall_mesh.name = "Wall_" + edge.capitalize()
		var wall_box := BoxMesh.new()
		wall_box.size = wall_size
		wall_mesh.mesh = wall_box
		wall_mesh.position = wall_position
		wall_mesh.material_override = _get_wall_material()
		root.add_child(wall_mesh)
		var wall_shape := CollisionShape3D.new()
		var wall_box_shape := BoxShape3D.new()
		wall_box_shape.size = wall_size
		wall_shape.shape = wall_box_shape
		wall_shape.position = wall_position
		collision.add_child(wall_shape)
	root.add_child(collision)

func _get_floor_material() -> StandardMaterial3D:
	if _floor_material == null:
		_floor_material = StandardMaterial3D.new()
		_floor_material.albedo_color = Color(0.64, 0.59, 0.43)
		_floor_material.roughness = 0.95
	return _floor_material

func _get_wall_material() -> StandardMaterial3D:
	if _wall_material == null:
		_wall_material = StandardMaterial3D.new()
		_wall_material.albedo_color = Color(0.76, 0.72, 0.51)
		_wall_material.roughness = 0.9
	return _wall_material

func _is_metadata_only() -> bool:
	return force_metadata_only or DisplayServer.get_name() == "headless"

func _is_finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _set_collision_enabled(enabled: bool) -> void:
	for root_value in cell_roots.values():
		if not (root_value is Node3D) or not is_instance_valid(root_value):
			continue
		var collision := root_value.get_node_or_null("WorldCollision") as StaticBody3D
		if collision != null:
			collision.collision_layer = WORLD_GEOMETRY_LAYER if enabled else 0
		for child in root_value.get_children():
			if child is CharacterBody3D and child.has_meta("backrooms_entity_id"):
				CollisionFactoryScript.set_collision_enabled(child as CharacterBody3D, enabled)

func _collect_entity_runtime_states(state: RefCounted, requested_center: Vector2i) -> Dictionary:
	var merged: Dictionary = {}
	var archived_value: Variant = state.call("get_entity_runtime_states")
	if not (archived_value is Array):
		return {"ok": false, "reason": "entity_runtime_archive_invalid"}
	for record_value in archived_value:
		if not (record_value is Dictionary):
			return {"ok": false, "reason": "entity_runtime_archive_record_invalid"}
		var record: Dictionary = record_value
		var key: String = EntityRuntimeStateScript.get_state_key(record)
		if key.is_empty() or merged.has(key):
			return {"ok": false, "reason": "entity_runtime_archive_key_invalid"}
		merged[key] = record.duplicate(true)
	for cell_root_value in cell_roots.values():
		if not (cell_root_value is Node3D) or not is_instance_valid(cell_root_value):
			continue
		var capture: Dictionary = EntityRuntimeStateScript.capture_cell_states(cell_root_value as Node3D)
		if not bool(capture.get("ok", false)):
			return {"ok": false, "reason": str(capture.get("reason", "entity_runtime_capture_failed"))}
		for record_value in capture.get("records", []):
			if not (record_value is Dictionary):
				return {"ok": false, "reason": "entity_runtime_capture_record_invalid"}
			var record: Dictionary = record_value
			var key: String = EntityRuntimeStateScript.get_state_key(record)
			if key.is_empty():
				return {"ok": false, "reason": "entity_runtime_capture_key_invalid"}
			merged[key] = record.duplicate(true)
	var retention_radius: int = int(state.get("stream_radius")) + 1
	for key_value in merged.keys().duplicate():
		var record: Dictionary = merged[key_value]
		var parsed: Dictionary = EntityRuntimeStateScript.parse_cell_key(str(record.get("cell_key", "")))
		if not bool(parsed.get("ok", false)):
			return {"ok": false, "reason": "entity_runtime_cell_key_invalid"}
		var cell: Vector2i = parsed["cell"]
		if absi(cell.x - requested_center.x) > retention_radius or absi(cell.y - requested_center.y) > retention_radius:
			merged.erase(key_value)
	var records: Array[Dictionary] = []
	for record_value in merged.values():
		if record_value is Dictionary:
			records.append(record_value.duplicate(true))
	return EntityRuntimeStateScript.validate_records(
		records,
		str(state.get("level_id")),
		int(state.get("world_seed")),
		float(state.get("cell_size")),
		int(state.get("entity_spawn_algorithm_version"))
	)

func _restore_entity_runtime_states(staged_roots: Dictionary, records: Array, ownership_records: Array = []) -> bool:
	var by_key: Dictionary = {}
	for record_value in records:
		if not (record_value is Dictionary):
			return false
		var record: Dictionary = record_value
		var key: String = EntityRuntimeStateScript.get_state_key(record)
		if key.is_empty() or by_key.has(key):
			return false
		by_key[key] = record
	var ownership_by_key: Dictionary = {}
	for ownership_value in ownership_records:
		if not (ownership_value is Dictionary):
			return false
		var ownership_record: Dictionary = ownership_value
		var ownership_key: String = OwnershipLedgerScript.get_state_key(
			str(ownership_record.get("spawn_cell_key", "")),
			str(ownership_record.get("entity_id", ""))
		)
		if ownership_key.is_empty() or ownership_by_key.has(ownership_key):
			return false
		ownership_by_key[ownership_key] = ownership_record
	var restored_keys: Dictionary = {}
	var live_identity_keys: Dictionary = {}
	for cell_key_value in staged_roots.keys():
		var cell_key: String = str(cell_key_value)
		var cell_root: Variant = staged_roots[cell_key_value]
		if not (cell_root is Node3D):
			return false
		for child in (cell_root as Node3D).get_children():
			if not (child is CharacterBody3D) or not child.has_meta("backrooms_entity_id"):
				continue
			var entity_id: String = str(child.get_meta("backrooms_entity_id", ""))
			if not EntityRuntimeStateScript.MOBILE_ENTITY_IDS.has(entity_id):
				continue
			var spawn_cell_value: Variant = child.get_meta("spawn_cell", null)
			if not (spawn_cell_value is Vector2i):
				return false
			var spawn_cell: Vector2i = spawn_cell_value
			var identity_record := {
				"spawn_cell_key": "%d,%d" % [spawn_cell.x, spawn_cell.y],
				"entity_id": entity_id
			}
			var key: String = EntityRuntimeStateScript.get_state_key(identity_record)
			if key.is_empty() or live_identity_keys.has(key):
				return false
			live_identity_keys[key] = true
			if not ownership_by_key.has(key):
				return false
			var ownership_record: Dictionary = ownership_by_key[key]
			if str(ownership_record.get("owner_cell_key", "")) != cell_key:
				return false
			child.set_meta("backrooms_owner_cell_key", cell_key)
			child.set_meta("backrooms_owner_revision", int(ownership_record.get("owner_revision", 0)))
			if not by_key.has(key):
				continue
			if not EntityRuntimeStateScript.restore_entity_state(cell_root as Node3D, child as CharacterBody3D, by_key[key]):
				return false
			restored_keys[key] = true
	for ownership_key_value in ownership_by_key.keys():
		var ownership_record: Dictionary = ownership_by_key[ownership_key_value]
		var owner_cell_key: String = str(ownership_record.get("owner_cell_key", ""))
		if staged_roots.has(owner_cell_key) and not live_identity_keys.has(str(ownership_key_value)):
			return false
	for key_value in by_key.keys():
		var record: Dictionary = by_key[key_value]
		var owner_cell_key: String = str(record.get("cell_key", ""))
		if staged_roots.has(owner_cell_key) and not restored_keys.has(key_value):
			return false
	return true

func _replace_all_cell_roots(replacements: Dictionary) -> void:
	for key_value in cell_roots.keys().duplicate():
		_retire_cell_root(str(key_value))
	for key_value in replacements.keys():
		var key: String = str(key_value)
		var root: Node3D = replacements[key] as Node3D
		add_child(root)
		cell_roots[key] = root

func _retire_cell_root(key: String) -> void:
	var value: Variant = cell_roots.get(key, null)
	if not (value is Node3D) or not is_instance_valid(value):
		cell_roots.erase(key)
		return
	var cell_root: Node3D = value
	cell_roots.erase(key)
	if cell_root.get_parent() == self:
		remove_child(cell_root)
	cell_root.free()

func _dispose_staged_roots(staged_roots: Dictionary) -> void:
	for root_value in staged_roots.values():
		if root_value is Node3D and is_instance_valid(root_value):
			if root_value.get_parent() != null:
				root_value.get_parent().remove_child(root_value)
			root_value.free()

func _get_retained_owner_cell_keys(center: Vector2i, stream_radius: int) -> Array[String]:
	var maximum: int = LayoutScript.MAX_ABS_CELL_COORD
	var minimum_x: int = maxi(-maximum, center.x - stream_radius - 1)
	var maximum_x: int = mini(maximum, center.x + stream_radius + 1)
	var minimum_z: int = maxi(-maximum, center.y - stream_radius - 1)
	var maximum_z: int = mini(maximum, center.y + stream_radius + 1)
	var keys: Array[String] = []
	for z in range(minimum_z, maximum_z + 1):
		for x in range(minimum_x, maximum_x + 1):
			keys.append("%d,%d" % [x, z])
	return keys

func _get_ownership_ledger_save(state: RefCounted, ledger: RefCounted) -> Dictionary:
	if state == null or ledger == null or not bool(ledger.get("configured")):
		return {}
	var retained: Array[String] = _get_retained_owner_cell_keys(
		state.call("get_center_cell"),
		int(state.get("stream_radius"))
	)
	return ledger.call(
		"to_save_dict",
		retained,
		int(state.call("get_generation")),
		int(state.call("get_configuration_revision"))
	)

func _create_ownership_ledger(
	state: RefCounted,
	plan: Dictionary,
	expected_stream_generation: int,
	expected_configuration_revision: int,
	saved_payload: Dictionary
) -> Dictionary:
	if state == null or not bool(state.get("configured")):
		return {"ok": false, "reason": "ownership_stream_state_unconfigured"}
	var loaded_value: Variant = plan.get("desired_cell_keys", null)
	var center_value: Variant = plan.get("center_cell", null)
	if not (loaded_value is Array) or not (center_value is Vector2i):
		return {"ok": false, "reason": "ownership_window_plan_invalid"}
	var retained: Array[String] = _get_retained_owner_cell_keys(center_value, int(state.get("stream_radius")))
	var retained_lookup: Dictionary = {}
	for key in retained:
		retained_lookup[key] = true
	var ledger: RefCounted = OwnershipLedgerScript.new()
	if not bool(ledger.call(
		"configure",
		str(state.get("level_id")),
		int(state.get("world_seed")),
		float(state.get("cell_size")),
		int(state.get("entity_spawn_algorithm_version")),
		expected_stream_generation,
		expected_configuration_revision,
		loaded_value
	)):
		return {"ok": false, "reason": "ownership_ledger_configuration_rejected"}
	var evicted_count: int = 0
	if not saved_payload.is_empty():
		var payload: Dictionary = saved_payload.duplicate(true)
		var records_value: Variant = payload.get("records", null)
		if not (records_value is Array):
			return {"ok": false, "reason": "ownership_ledger_records_invalid"}
		var filtered_records: Array = []
		for record_value in records_value:
			if not (record_value is Dictionary):
				return {"ok": false, "reason": "ownership_ledger_record_invalid"}
			var record: Dictionary = record_value
			var owner_cell_key: String = str(record.get("owner_cell_key", ""))
			if not bool(EntityRuntimeStateScript.parse_cell_key(owner_cell_key).get("ok", false)):
				return {"ok": false, "reason": "ownership_ledger_owner_cell_invalid"}
			if retained_lookup.has(owner_cell_key):
				filtered_records.append(record.duplicate(true))
			else:
				evicted_count += 1
		payload["records"] = filtered_records
		if not bool(ledger.call(
			"load_save_dict", payload, retained,
			expected_stream_generation, expected_configuration_revision
		)):
			return {"ok": false, "reason": "ownership_ledger_restore_rejected"}
	var registration: Dictionary = ledger.call("register_deterministic_spawns")
	if not bool(registration.get("ok", false)):
		return {"ok": false, "reason": str(registration.get("reason", "ownership_spawn_registration_failed"))}
	var pruning: Dictionary = ledger.call(
		"prune_to_retained_owner_cells", retained,
		expected_stream_generation, expected_configuration_revision
	)
	if not bool(pruning.get("ok", false)):
		return {"ok": false, "reason": str(pruning.get("reason", "ownership_pruning_failed"))}
	var save_value: Dictionary = ledger.call(
		"to_save_dict", retained,
		expected_stream_generation, expected_configuration_revision
	)
	if save_value.is_empty():
		return {"ok": false, "reason": "ownership_ledger_snapshot_invalid"}
	return {
		"ok": true,
		"ledger": ledger,
		"save": save_value,
		"evicted_count": evicted_count + int(pruning.get("removed_count", 0))
	}

func transfer_entity_to_next_cell(
	spawn_cell_key: String,
	entity_id: String,
	route_snapshot: Dictionary
) -> Dictionary:
	if not active or ownership_ledger == null or not bool(ownership_ledger.get("configured")):
		return {"ok": false, "reason": "ownership_runtime_inactive"}
	if not is_route_snapshot_current(route_snapshot):
		return {"ok": false, "reason": "route_snapshot_stale"}
	var keys_value: Variant = route_snapshot.get("cell_keys", null)
	var directions_value: Variant = route_snapshot.get("edge_directions", null)
	if not (keys_value is Array) or keys_value.size() < 2 or not (directions_value is Array) or directions_value.is_empty():
		return {"ok": false, "reason": "route_first_hop_invalid"}
	var from_owner_key: String = str(keys_value[0])
	var to_owner_key: String = str(keys_value[1])
	var direction_value: Variant = directions_value[0]
	if not (direction_value is Vector2i):
		return {"ok": false, "reason": "route_direction_invalid"}
	var direction: Vector2i = direction_value
	var owner_record: Dictionary = ownership_ledger.call("get_record", spawn_cell_key, entity_id)
	if owner_record.is_empty() or str(owner_record.get("owner_cell_key", "")) != from_owner_key:
		return {"ok": false, "reason": "entity_owner_record_mismatch"}
	var owner_revision: int = int(owner_record.get("owner_revision", -1))
	if owner_revision < 0:
		return {"ok": false, "reason": "entity_owner_revision_invalid"}
	var source_root: Node3D = get_cell_root(from_owner_key)
	var target_root: Node3D = get_cell_root(to_owner_key)
	if source_root == null or target_root == null:
		return {"ok": false, "reason": "transfer_cell_root_unavailable"}
	if (
		str(source_root.get_meta("backrooms_cell_key", "")) != from_owner_key
		or str(target_root.get_meta("backrooms_cell_key", "")) != to_owner_key
	):
		return {"ok": false, "reason": "transfer_cell_root_identity_mismatch"}
	if not _validate_cell_entity_identity_metadata(source_root) or not _validate_cell_entity_identity_metadata(target_root):
		return {"ok": false, "reason": "transfer_cell_identity_metadata_invalid"}
	var entity_root: CharacterBody3D = null
	for child in source_root.get_children():
		if not (child is CharacterBody3D) or str(child.get_meta("backrooms_entity_id", "")) != entity_id:
			continue
		var spawn_value: Variant = child.get_meta("spawn_cell", null)
		if not (spawn_value is Vector2i):
			return {"ok": false, "reason": "transfer_entity_spawn_identity_invalid"}
		var spawn_cell: Vector2i = spawn_value
		if ("%d,%d" % [spawn_cell.x, spawn_cell.y]) == spawn_cell_key:
			if entity_root != null:
				return {"ok": false, "reason": "transfer_entity_identity_ambiguous"}
			entity_root = child as CharacterBody3D
	if entity_root == null or entity_root.get_parent() != source_root:
		return {"ok": false, "reason": "transfer_entity_not_owned_by_source"}
	if str(entity_root.get_meta("backrooms_owner_cell_key", "")) != from_owner_key:
		return {"ok": false, "reason": "transfer_entity_owner_metadata_mismatch"}
	if int(entity_root.get_meta("backrooms_owner_revision", -1)) != owner_revision:
		return {"ok": false, "reason": "transfer_entity_owner_revision_mismatch"}
	var spawn_parse: Dictionary = EntityRuntimeStateScript.parse_cell_key(spawn_cell_key)
	if not bool(spawn_parse.get("ok", false)):
		return {"ok": false, "reason": "transfer_entity_spawn_key_invalid"}
	if (
		str(entity_root.get_meta("spawn_level_id", "")) != str(stream_state.get("level_id"))
		or int(entity_root.get_meta("spawn_world_seed", -1)) != int(stream_state.get("world_seed"))
		or int(entity_root.get_meta("spawn_algorithm_version", 0)) != int(stream_state.get("entity_spawn_algorithm_version"))
	):
		return {"ok": false, "reason": "transfer_entity_spawn_metadata_mismatch"}
	var identity_key: String = OwnershipLedgerScript.get_state_key(spawn_cell_key, entity_id)
	var source_identity_keys_value: Variant = source_root.get_meta("backrooms_entity_identity_keys", null)
	var source_spawn_ids_value: Variant = source_root.get_meta("backrooms_entity_spawn_ids", null)
	var target_identity_keys_value: Variant = target_root.get_meta("backrooms_entity_identity_keys", null)
	var target_spawn_ids_value: Variant = target_root.get_meta("backrooms_entity_spawn_ids", null)
	if (
		not (source_identity_keys_value is Array)
		or not (source_spawn_ids_value is Array)
		or not (target_identity_keys_value is Array)
		or not (target_spawn_ids_value is Array)
		or source_identity_keys_value.size() != source_spawn_ids_value.size()
		or target_identity_keys_value.size() != target_spawn_ids_value.size()
	):
		return {"ok": false, "reason": "transfer_cell_identity_metadata_invalid"}
	var source_identity_index: int = source_identity_keys_value.find(identity_key)
	if (
		source_identity_index < 0
		or source_identity_index >= source_spawn_ids_value.size()
		or str(source_spawn_ids_value[source_identity_index]) != entity_id
		or target_identity_keys_value.has(identity_key)
	):
		return {"ok": false, "reason": "transfer_cell_identity_metadata_invalid"}
	var source_cell_size: float = float(source_root.get_meta("backrooms_cell_size", 0.0))
	var target_cell_size: float = float(target_root.get_meta("backrooms_cell_size", 0.0))
	var configured_cell_size: float = float(stream_state.get("cell_size"))
	if (
		not is_finite(source_cell_size)
		or not is_finite(target_cell_size)
		or not is_finite(configured_cell_size)
		or source_cell_size <= ENTITY_SAFE_CELL_MARGIN * 2.0
		or not is_equal_approx(source_cell_size, target_cell_size)
		or not is_equal_approx(source_cell_size, configured_cell_size)
	):
		return {"ok": false, "reason": "transfer_cell_size_invalid"}
	var safe_extent: float = source_cell_size * 0.5 - ENTITY_SAFE_CELL_MARGIN
	var source_local: Vector3 = source_root.to_local(entity_root.global_position)
	if not _is_finite_vector3(source_local):
		return {"ok": false, "reason": "transfer_entity_position_invalid"}
	var edge_coordinate: float = source_local.x if direction.x != 0 else source_local.z
	var expected_edge_coordinate: float = float(direction.x) * safe_extent if direction.x != 0 else float(direction.y) * safe_extent
	if absf(edge_coordinate - expected_edge_coordinate) > ENTITY_TRANSFER_EDGE_TOLERANCE:
		return {"ok": false, "reason": "transfer_entity_not_at_cell_edge"}
	var transfer_setup: Dictionary = ownership_ledger.call(
		"plan_transfer", spawn_cell_key, entity_id, to_owner_key, route_snapshot
	)
	if not bool(transfer_setup.get("ok", false)):
		return {"ok": false, "reason": str(transfer_setup.get("reason", "transfer_plan_rejected"))}
	var plan: Dictionary = transfer_setup.get("plan", {})
	var previous_transform: Transform3D = entity_root.global_transform
	var previous_owner_key: String = str(entity_root.get_meta("backrooms_owner_cell_key", from_owner_key))
	var previous_owner_revision: int = int(entity_root.get_meta("backrooms_owner_revision", owner_revision))
	entity_root.reparent(target_root, true)
	if entity_root.get_parent() != target_root:
		ownership_ledger.call("rollback_transfer", plan)
		return {"ok": false, "reason": "transfer_reparent_failed"}
	var target_local: Vector3 = target_root.to_local(entity_root.global_position)
	if direction.x != 0:
		target_local.x = -float(direction.x) * safe_extent
	else:
		target_local.z = -float(direction.y) * safe_extent
	target_local.x = clampf(target_local.x, -safe_extent, safe_extent)
	target_local.z = clampf(target_local.z, -safe_extent, safe_extent)
	var desired_world_position: Vector3 = target_root.to_global(target_local)
	var motion: Vector3 = desired_world_position - entity_root.global_position
	var collision: KinematicCollision3D = entity_root.move_and_collide(
		motion, false, ENTITY_COLLISION_SAFE_MARGIN, false
	)
	if collision != null or entity_root.global_position.distance_to(desired_world_position) > 0.05:
		entity_root.reparent(source_root, true)
		entity_root.global_transform = previous_transform
		entity_root.set_meta("backrooms_owner_cell_key", previous_owner_key)
		entity_root.set_meta("backrooms_owner_revision", previous_owner_revision)
		ownership_ledger.call("rollback_transfer", plan)
		return {"ok": false, "reason": "transfer_physics_handoff_blocked"}
	var commit: Dictionary = ownership_ledger.call("commit_transfer", plan)
	if not bool(commit.get("ok", false)):
		entity_root.reparent(source_root, true)
		entity_root.global_transform = previous_transform
		entity_root.set_meta("backrooms_owner_cell_key", previous_owner_key)
		entity_root.set_meta("backrooms_owner_revision", previous_owner_revision)
		ownership_ledger.call("rollback_transfer", plan)
		return {"ok": false, "reason": str(commit.get("reason", "transfer_commit_rejected"))}
	var committed_record: Dictionary = commit.get("record", {})
	var source_identity_keys: Array = source_identity_keys_value.duplicate()
	var source_spawn_ids: Array = source_spawn_ids_value.duplicate()
	var target_identity_keys: Array = target_identity_keys_value.duplicate()
	var target_spawn_ids: Array = target_spawn_ids_value.duplicate()
	source_identity_keys.remove_at(source_identity_index)
	source_spawn_ids.remove_at(source_identity_index)
	target_identity_keys.append(identity_key)
	target_spawn_ids.append(entity_id)
	source_root.set_meta("backrooms_entity_identity_keys", source_identity_keys)
	source_root.set_meta("backrooms_entity_spawn_ids", source_spawn_ids)
	target_root.set_meta("backrooms_entity_identity_keys", target_identity_keys)
	target_root.set_meta("backrooms_entity_spawn_ids", target_spawn_ids)
	entity_root.set_meta("backrooms_owner_cell_key", to_owner_key)
	entity_root.set_meta("backrooms_owner_revision", int(committed_record.get("owner_revision", 0)))
	return {
		"ok": true,
		"spawn_cell_key": spawn_cell_key,
		"entity_id": entity_id,
		"from_owner_cell_key": from_owner_key,
		"to_owner_cell_key": to_owner_key,
		"owner_revision": int(committed_record.get("owner_revision", 0)),
		"position": entity_root.global_position
	}

func _validate_cell_entity_identity_metadata(cell_root: Node3D) -> bool:
	if cell_root == null or not is_instance_valid(cell_root):
		return false
	var identity_keys_value: Variant = cell_root.get_meta("backrooms_entity_identity_keys", null)
	var spawn_ids_value: Variant = cell_root.get_meta("backrooms_entity_spawn_ids", null)
	if (
		not (identity_keys_value is Array)
		or not (spawn_ids_value is Array)
		or identity_keys_value.size() != spawn_ids_value.size()
	):
		return false
	var live_identity_by_key: Dictionary = {}
	for child in cell_root.get_children():
		if not (child is CharacterBody3D) or not child.has_meta("backrooms_entity_id"):
			continue
		var live_entity_id: String = str(child.get_meta("backrooms_entity_id", ""))
		var live_spawn_value: Variant = child.get_meta("spawn_cell", null)
		if not (live_spawn_value is Vector2i) or not EntityBrainScript.SUPPORTED_ENTITY_IDS.has(live_entity_id):
			return false
		var live_spawn_cell: Vector2i = live_spawn_value
		var live_key: String = OwnershipLedgerScript.get_state_key(
			"%d,%d" % [live_spawn_cell.x, live_spawn_cell.y], live_entity_id
		)
		if live_key.is_empty() or live_identity_by_key.has(live_key):
			return false
		live_identity_by_key[live_key] = live_entity_id
	if live_identity_by_key.size() != identity_keys_value.size():
		return false
	var seen: Dictionary = {}
	for index in range(identity_keys_value.size()):
		var identity_value: Variant = identity_keys_value[index]
		var spawn_id_value: Variant = spawn_ids_value[index]
		if not (identity_value is String) or not (spawn_id_value is String):
			return false
		var identity_key: String = str(identity_value)
		var spawn_id: String = str(spawn_id_value)
		var parts: PackedStringArray = identity_key.split("|", false)
		if (
			identity_key.is_empty()
			or not EntityBrainScript.SUPPORTED_ENTITY_IDS.has(spawn_id)
			or parts.size() != 2
			or identity_key != parts[0] + "|" + parts[1]
			or parts[1] != spawn_id
			or not bool(EntityRuntimeStateScript.parse_cell_key(parts[0]).get("ok", false))
			or seen.has(identity_key)
			or not live_identity_by_key.has(identity_key)
			or str(live_identity_by_key.get(identity_key, "")) != spawn_id
		):
			return false
		seen[identity_key] = true
	return true

func get_entity_owner_record(spawn_cell_key: String, entity_id: String) -> Dictionary:
	if ownership_ledger == null or not bool(ownership_ledger.get("configured")):
		return {}
	return ownership_ledger.call("get_record", spawn_cell_key, entity_id)

func _failure(reason: String) -> Dictionary:
	last_error = reason
	return {"ok": false, "reason": reason}

func _reject(reason: String) -> bool:
	last_error = reason
	return false

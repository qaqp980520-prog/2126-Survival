extends Node3D
class_name BackroomsMazeCellRuntime

## SurfaceWorld-owned scene runtime for the renderer-independent Backrooms maze stream contract.
## New cell roots are built detached, the logical window is committed, then old roots are retired.
const StreamStateScript = preload("res://systems/BackroomsMazeStreamState.gd")

const FLOOR_THICKNESS: float = 0.2
const WALL_THICKNESS: float = 0.18
const WALL_HEIGHT: float = 3.2
const WORLD_GEOMETRY_LAYER: int = 1

var stream_state: RefCounted = StreamStateScript.new()
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
	var candidate: RefCounted = StreamStateScript.new()
	if not bool(candidate.call("configure", destination_level, layout_seed, requested_cell_size, requested_stream_radius)):
		return _failure("stream_configuration_rejected")
	var plan_value: Variant = candidate.call("plan_window_for_position", entry_position)
	if not (plan_value is Dictionary) or not bool(plan_value.get("ok", false)):
		return _failure(str(plan_value.get("reason", "initial_window_plan_rejected")) if plan_value is Dictionary else "initial_window_plan_invalid")
	var plan: Dictionary = plan_value
	var staged_result: Dictionary = _stage_cell_roots(candidate, plan)
	if not bool(staged_result.get("ok", false)):
		return _failure(str(staged_result.get("reason", "cell_staging_failed")))
	var staged_roots: Dictionary = staged_result.get("roots", {})
	var staged_keys: Array = plan.get("load_cell_keys", [])
	if not bool(candidate.call("commit_window", plan, staged_keys)):
		_dispose_staged_roots(staged_roots)
		return _failure("initial_stream_commit_rejected")
	_replace_all_cell_roots(staged_roots)
	stream_state = candidate
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
	var plan_value: Variant = stream_state.call("plan_window_for_position", world_position)
	if not (plan_value is Dictionary) or not bool(plan_value.get("ok", false)):
		return _failure(str(plan_value.get("reason", "window_plan_rejected")) if plan_value is Dictionary else "window_plan_invalid")
	var plan: Dictionary = plan_value
	var staged_result: Dictionary = _stage_cell_roots(stream_state, plan)
	if not bool(staged_result.get("ok", false)):
		return _failure(str(staged_result.get("reason", "cell_staging_failed")))
	var staged_roots: Dictionary = staged_result.get("roots", {})
	var staged_keys: Array = plan.get("load_cell_keys", [])
	if not bool(stream_state.call("commit_window", plan, staged_keys)):
		_dispose_staged_roots(staged_roots)
		return _failure("stream_commit_rejected")
	for key_value in staged_roots.keys():
		var key: String = str(key_value)
		var cell_root: Node3D = staged_roots[key] as Node3D
		add_child(cell_root)
		cell_roots[key] = cell_root
	for key_value in plan.get("unload_cell_keys", []):
		_retire_cell_root(str(key_value))
	_set_collision_enabled(active)
	return {
		"ok": true,
		"event": "window_committed",
		"center_cell": stream_state.get("center_cell"),
		"loaded_cell_count": get_loaded_cell_count(),
		"load_count": staged_roots.size(),
		"keep_count": plan.get("keep_cell_keys", []).size(),
		"unload_count": plan.get("unload_cell_keys", []).size()
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
	prepared = false
	return true

func to_save_dict() -> Dictionary:
	if not prepared:
		return {}
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
	var staged_result: Dictionary = _stage_cell_roots(candidate, plan)
	if not bool(staged_result.get("ok", false)):
		return _reject(str(staged_result.get("reason", "restore_cell_staging_failed")))
	var staged_roots: Dictionary = staged_result.get("roots", {})
	if not bool(candidate.call("commit_window", plan, plan.get("load_cell_keys", []))):
		_dispose_staged_roots(staged_roots)
		return _reject("restore_stream_commit_rejected")
	_replace_all_cell_roots(staged_roots)
	stream_state = candidate
	prepared = true
	active = false
	visible = false
	_set_collision_enabled(false)
	return true

func get_loaded_cell_count() -> int:
	return int(stream_state.call("get_loaded_cell_count"))

func get_loaded_cell_keys() -> Array:
	return stream_state.call("get_loaded_cell_keys")

func get_cell_root(cell_key: String) -> Node3D:
	var value: Variant = cell_roots.get(cell_key, null)
	if value is Node3D and is_instance_valid(value):
		return value as Node3D
	return null

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

func _stage_cell_roots(candidate: RefCounted, plan: Dictionary) -> Dictionary:
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
			float(candidate.get("cell_size"))
		)
		if not (root_value is Node3D) or root_value.get_parent() != null:
			if root_value is Node3D and is_instance_valid(root_value):
				root_value.free()
			_dispose_staged_roots(staged_roots)
			return {"ok": false, "reason": "cell_root_build_failed"}
		staged_roots[key] = root_value
	return {"ok": true, "roots": staged_roots}

func _build_cell_root(descriptor: Dictionary, cell_size: float) -> Node3D:
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
	root.set_meta("backrooms_level_id", str(descriptor.get("level_id", "")))
	root.set_meta("backrooms_world_seed", int(descriptor.get("world_seed", 0)))
	root.set_meta("backrooms_layout_algorithm_version", int(descriptor.get("layout_algorithm_version", 0)))
	root.set_meta("backrooms_open_edges", edges_value.duplicate(true))
	if _is_metadata_only():
		return root
	_build_cell_geometry(root, edges_value, cell_size)
	return root

func _build_cell_geometry(root: Node3D, open_edges: Dictionary, cell_size: float) -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(cell_size, FLOOR_THICKNESS, cell_size)
	floor_mesh.mesh = floor_box
	floor_mesh.position = Vector3(0.0, -FLOOR_THICKNESS * 0.5, 0.0)
	floor_mesh.material_override = _get_floor_material()
	root.add_child(floor_mesh)

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

func _set_collision_enabled(enabled: bool) -> void:
	for root_value in cell_roots.values():
		if not (root_value is Node3D) or not is_instance_valid(root_value):
			continue
		var collision := root_value.get_node_or_null("WorldCollision") as StaticBody3D
		if collision != null:
			collision.collision_layer = WORLD_GEOMETRY_LAYER if enabled else 0

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

func _failure(reason: String) -> Dictionary:
	last_error = reason
	return {"ok": false, "reason": reason}

func _reject(reason: String) -> bool:
	last_error = reason
	return false

extends Node
class_name UndergroundMineDirector

## Owns a bounded spatial window for one active underground depth.
## Layer zero keeps the legacy chunk IDs; deeper layers use an explicit namespace.
signal sync_failed(report: Dictionary)

const MAX_SAFE_GRID_COORDINATE: float = 1000000000.0
const DEFAULT_CHUNK_SIZE: float = 10.0
const LAYER_SPACING: float = 20.0
const BASE_FLOOR_Y: float = -8.25
const MAX_LAYER_INDEX: int = 8

@export_range(1.0, 256.0, 1.0) var chunk_size: float = DEFAULT_CHUNK_SIZE
@export_range(0, 8, 1) var load_radius: int = 1

var chunk_controller: Node3D
var chunk_factory: Callable
var _managed_chunk_ids: Dictionary = {} # chunk ID -> {coord: Vector2i, layer: int}
var _last_sync_report: Dictionary = {}

func bind_controller(candidate: Node3D) -> bool:
	if candidate == null:
		return false
	for method_name in ["load_chunk", "unload_chunk", "is_chunk_loaded", "get_loaded_chunk_ids"]:
		if not candidate.has_method(method_name):
			return false
	if not _managed_chunk_ids.is_empty() and chunk_controller != candidate:
		return false
	chunk_controller = candidate
	return _reconcile_controller_ids()

func bind_chunk_factory(factory: Callable) -> bool:
	if not factory.is_valid():
		return false
	chunk_factory = factory
	return true

func sync_to_world_position(world_position: Vector3, now_unix: int = -1) -> bool:
	if chunk_controller == null or not is_instance_valid(chunk_controller) or not chunk_factory.is_valid():
		_set_report(false, "validation", "Controller or underground chunk factory is unavailable.", true)
		return false
	if not _is_safe_world_position(world_position):
		_set_report(false, "validation", "Underground position, depth or grid settings are invalid.", true)
		return false
	if not _reconcile_controller_ids():
		_set_report(false, "reconcile", "Loaded underground mine IDs cannot be reconciled safely.", false)
		return false

	var now: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	if now <= 0:
		_set_report(false, "validation", "A positive Unix timestamp is required.", true)
		return false
	var previous_managed: Dictionary = _managed_chunk_ids.duplicate(true)
	var registry_snapshot: Dictionary = _capture_registry_snapshot()
	if registry_snapshot.is_empty():
		_set_report(false, "snapshot", "Could not snapshot the mineral registry before underground streaming.", true)
		return false

	var center: Vector2i = get_grid_coordinate(world_position)
	var target_layer: int = get_layer_index(world_position)
	var desired: Array[Vector2i] = []
	for z in range(center.y - load_radius, center.y + load_radius + 1):
		for x in range(center.x - load_radius, center.x + load_radius + 1):
			desired.append(Vector2i(x, z))
	desired.sort_custom(_coordinate_less)

	var desired_ids: Dictionary = {}
	for coord in desired:
		var id: String = _chunk_id(coord, target_layer)
		desired_ids[id] = {"coord": coord, "layer": target_layer}

	var newly_loaded: Array[String] = []
	for coord in desired:
		var id: String = _chunk_id(coord, target_layer)
		if chunk_controller.is_chunk_loaded(id):
			_managed_chunk_ids[id] = {"coord": coord, "layer": target_layer}
			continue
		var candidate: Variant = chunk_factory.call(coord, target_layer, now)
		if not is_instance_valid(candidate) or not (candidate is Node3D) or candidate.get_parent() != null:
			_free_unowned_root(candidate)
			var rollback_ok: bool = _rollback_transaction(newly_loaded, [], previous_managed, registry_snapshot, now)
			_set_report(false, "load_factory", "Underground factory returned an invalid chunk root.", rollback_ok, {
				"failed_chunk_id": id,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"rollback_complete": rollback_ok
			})
			return false
		if not bool(chunk_controller.call("load_chunk", id, candidate, now)):
			_free_unowned_root(candidate)
			var rollback_ok: bool = _rollback_transaction(newly_loaded, [], previous_managed, registry_snapshot, now)
			_set_report(false, "load_registration", "Chunk controller rejected an underground chunk.", rollback_ok, {
				"failed_chunk_id": id,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"rollback_complete": rollback_ok
			})
			return false
		_managed_chunk_ids[id] = {"coord": coord, "layer": target_layer}
		newly_loaded.append(id)

	var stale_ids: Array[String] = []
	for id_value in _managed_chunk_ids.keys():
		var id: String = str(id_value)
		if not desired_ids.has(id):
			stale_ids.append(id)
	stale_ids.sort()
	var unloaded_stale: Array[Dictionary] = []
	for id in stale_ids:
		var stale_entry: Dictionary = _managed_chunk_ids[id]
		if not bool(chunk_controller.call("unload_chunk", id, now)):
			var rollback_ok: bool = _rollback_transaction(newly_loaded, unloaded_stale, previous_managed, registry_snapshot, now)
			_set_report(false, "stale_unload", "An obsolete underground chunk could not be unloaded.", rollback_ok, {
				"failed_chunk_id": id,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"unloaded_stale_ids": _entry_ids(unloaded_stale),
				"rollback_complete": rollback_ok
			})
			return false
		unloaded_stale.append({
			"id": id,
			"coord": stale_entry.get("coord", Vector2i.ZERO),
			"layer": int(stale_entry.get("layer", 0))
		})
		_managed_chunk_ids.erase(id)

	_set_report(true, "complete", "", true, {
		"center": center,
		"layer_index": target_layer,
		"desired_count": desired.size(),
		"newly_loaded_ids": newly_loaded.duplicate(),
		"unloaded_stale_ids": _entry_ids(unloaded_stale)
	})
	return true

## Rebuild the director's view from the controller after a restore or recovery.
## It owns both legacy layer-zero IDs and the explicit deeper-layer namespace.
func recover_to_world_position(world_position: Vector3, now_unix: int = -1) -> bool:
	if not _is_safe_world_position(world_position):
		_set_report(false, "recovery_validation", "Underground recovery position is invalid.", false)
		return false
	return sync_to_world_position(world_position, now_unix)

func get_grid_coordinate(world_position: Vector3) -> Vector2i:
	if not _is_safe_world_position(world_position):
		return Vector2i.ZERO
	return Vector2i(floori(world_position.x / chunk_size), floori(world_position.z / chunk_size))

func get_layer_index(world_position: Vector3) -> int:
	if not is_finite(world_position.y):
		return -1
	var depth_value: float = maxf(0.0, (-world_position.y - absf(BASE_FLOOR_Y)) / LAYER_SPACING)
	var layer_index: int = roundi(depth_value)
	if layer_index < 0 or layer_index > MAX_LAYER_INDEX:
		return -1
	return layer_index

func get_layer_floor_y(layer_index: int) -> float:
	if layer_index < 0 or layer_index > MAX_LAYER_INDEX:
		return NAN
	return BASE_FLOOR_Y - float(layer_index) * LAYER_SPACING

func get_chunk_id(coord: Vector2i, layer_index: int = 0) -> String:
	if layer_index < 0 or layer_index > MAX_LAYER_INDEX:
		return ""
	return _chunk_id(coord, layer_index)

func get_managed_chunk_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id in _managed_chunk_ids.keys():
		ids.append(str(id))
	ids.sort()
	return ids

func get_last_sync_report() -> Dictionary:
	return _last_sync_report.duplicate(true)

func _reconcile_controller_ids() -> bool:
	var raw_ids: Variant = chunk_controller.call("get_loaded_chunk_ids")
	if not (raw_ids is Array or raw_ids is PackedStringArray):
		return false
	var reconciled: Dictionary = {}
	for raw_id in raw_ids:
		var id: String = str(raw_id)
		if not id.begins_with("underground/"):
			continue
		var parsed: Dictionary = _parse_chunk_id(id)
		if not bool(parsed.get("valid", false)):
			return false
		reconciled[id] = {
			"coord": parsed["coordinate"],
			"layer": int(parsed.get("layer", 0))
		}
	_managed_chunk_ids = reconciled
	return true

func _parse_chunk_id(id: String) -> Dictionary:
	var layer_index: int = 0
	var chunk_part: String = ""
	if id.begins_with("underground/mine_"):
		chunk_part = id.substr("underground/".length())
	elif id.begins_with("underground/layer_"):
		var layer_parts: PackedStringArray = id.substr("underground/".length()).split("/", false)
		if layer_parts.size() != 2 or not layer_parts[0].begins_with("layer_"):
			return {"valid": false, "coordinate": Vector2i.ZERO, "layer": -1}
		var layer_text: String = layer_parts[0].substr("layer_".length())
		if not layer_text.is_valid_int():
			return {"valid": false, "coordinate": Vector2i.ZERO, "layer": -1}
		layer_index = layer_text.to_int()
		chunk_part = layer_parts[1]
	else:
		return {"valid": false, "coordinate": Vector2i.ZERO, "layer": -1}
	if layer_index < 0 or layer_index > MAX_LAYER_INDEX or not chunk_part.begins_with("mine_"):
		return {"valid": false, "coordinate": Vector2i.ZERO, "layer": -1}
	var coordinate_parts: PackedStringArray = chunk_part.substr("mine_".length()).split("_", false)
	if coordinate_parts.size() != 2 or not coordinate_parts[0].is_valid_int() or not coordinate_parts[1].is_valid_int():
		return {"valid": false, "coordinate": Vector2i.ZERO, "layer": -1}
	var coord := Vector2i(coordinate_parts[0].to_int(), coordinate_parts[1].to_int())
	if _chunk_id(coord, layer_index) != id:
		return {"valid": false, "coordinate": Vector2i.ZERO, "layer": -1}
	if absf(float(coord.x)) > MAX_SAFE_GRID_COORDINATE or absf(float(coord.y)) > MAX_SAFE_GRID_COORDINATE:
		return {"valid": false, "coordinate": Vector2i.ZERO, "layer": -1}
	return {"valid": true, "coordinate": coord, "layer": layer_index}

func _capture_registry_snapshot() -> Dictionary:
	var mineral_registry: Variant = chunk_controller.get("registry")
	if mineral_registry == null or not is_instance_valid(mineral_registry) or not mineral_registry.has_method("to_save_dict") or not mineral_registry.has_method("restore_snapshot_exact"):
		return {}
	var mineral_snapshot: Variant = mineral_registry.call("to_save_dict")
	if not (mineral_snapshot is Dictionary) or not mineral_snapshot.has("schema_version") or not mineral_snapshot.has("veins"):
		return {}
	var object_registry: Variant = chunk_controller.get("object_state_registry")
	if object_registry == null or not is_instance_valid(object_registry) or not object_registry.has_method("to_save_dict") or not object_registry.has_method("restore_save_dict"):
		return {}
	var object_snapshot: Variant = object_registry.call("to_save_dict")
	if not (object_snapshot is Dictionary) or not object_snapshot.has("schema_version") or not object_snapshot.has("objects"):
		return {}
	return {
		"mineral": mineral_snapshot.duplicate(true),
		"objects": object_snapshot.duplicate(true)
	}

func _rollback_transaction(new_ids: Array[String], unloaded: Array[Dictionary], previous_managed: Dictionary, registry_snapshot: Dictionary, now_unix: int) -> bool:
	var new_ok: bool = _rollback_new_loads(new_ids, now_unix)
	var mineral_registry: Variant = chunk_controller.get("registry")
	var object_registry: Variant = chunk_controller.get("object_state_registry")
	var mineral_snapshot: Dictionary = registry_snapshot.get("mineral", {})
	var object_snapshot: Dictionary = registry_snapshot.get("objects", {})
	var mineral_ok: bool = mineral_registry != null and is_instance_valid(mineral_registry) and mineral_registry.has_method("restore_snapshot_exact") and bool(mineral_registry.call("restore_snapshot_exact", mineral_snapshot, now_unix))
	var objects_ok: bool = object_registry != null and is_instance_valid(object_registry) and object_registry.has_method("restore_save_dict") and bool(object_registry.call("restore_save_dict", object_snapshot))
	var old_ok: bool = _restore_unloaded_chunks(unloaded, now_unix) if mineral_ok and objects_ok else false
	var final_mineral_ok: bool = false
	var final_objects_ok: bool = false
	if old_ok and mineral_registry != null and is_instance_valid(mineral_registry) and mineral_registry.has_method("restore_snapshot_exact"):
		# Re-apply exact snapshots after reloading stale roots; registration can update both registries.
		final_mineral_ok = bool(mineral_registry.call("restore_snapshot_exact", mineral_snapshot, now_unix))
	if old_ok and object_registry != null and is_instance_valid(object_registry) and object_registry.has_method("restore_save_dict"):
		final_objects_ok = bool(object_registry.call("restore_save_dict", object_snapshot))
	var rollback_complete: bool = new_ok and mineral_ok and objects_ok and old_ok and final_mineral_ok and final_objects_ok
	_managed_chunk_ids = previous_managed.duplicate(true) if rollback_complete else _actual_managed_map()
	return rollback_complete

func _rollback_new_loads(ids: Array[String], now_unix: int) -> bool:
	var success := true
	for i in range(ids.size() - 1, -1, -1):
		var id: String = ids[i]
		if not chunk_controller.is_chunk_loaded(id):
			continue
		if not bool(chunk_controller.call("unload_chunk", id, now_unix)):
			success = false
	return success

func _restore_unloaded_chunks(entries: Array[Dictionary], now_unix: int) -> bool:
	var success := true
	for entry in entries:
		var id: String = str(entry.get("id", ""))
		var coord: Vector2i = entry.get("coord", Vector2i.ZERO)
		var layer_index: int = int(entry.get("layer", 0))
		var candidate: Variant = chunk_factory.call(coord, layer_index, now_unix)
		if not is_instance_valid(candidate) or not (candidate is Node3D) or candidate.get_parent() != null:
			_free_unowned_root(candidate)
			success = false
			continue
		if not bool(chunk_controller.call("load_chunk", id, candidate, now_unix)):
			_free_unowned_root(candidate)
			success = false
	return success

func _actual_managed_map() -> Dictionary:
	var result: Dictionary = {}
	if chunk_controller == null or not is_instance_valid(chunk_controller):
		return result
	var raw_ids: Variant = chunk_controller.call("get_loaded_chunk_ids")
	if raw_ids is Array or raw_ids is PackedStringArray:
		for raw_id in raw_ids:
			var id: String = str(raw_id)
			if id.begins_with("underground/"):
				var parsed: Dictionary = _parse_chunk_id(id)
				if bool(parsed.get("valid", false)):
					result[id] = {"coord": parsed["coordinate"], "layer": int(parsed.get("layer", 0))}
	return result

func _free_unowned_root(candidate: Variant) -> void:
	if candidate is Node and is_instance_valid(candidate) and candidate.get_parent() == null:
		candidate.free()

func _entry_ids(entries: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for entry in entries:
		ids.append(str(entry.get("id", "")))
	return ids

func _coordinate_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y == b.y:
		return a.x < b.x
	return a.y < b.y

func _chunk_id(coord: Vector2i, layer_index: int = 0) -> String:
	if layer_index <= 0:
		return "underground/mine_%d_%d" % [coord.x, coord.y]
	return "underground/layer_%d/mine_%d_%d" % [layer_index, coord.x, coord.y]

func _is_safe_world_position(position: Vector3) -> bool:
	return is_finite(position.x) and is_finite(position.y) and is_finite(position.z) and is_finite(chunk_size) and chunk_size > 0.0 and load_radius >= 0 and absf(position.x / chunk_size) <= MAX_SAFE_GRID_COORDINATE and absf(position.z / chunk_size) <= MAX_SAFE_GRID_COORDINATE and get_layer_index(position) >= 0

func _set_report(success: bool, phase: String, message: String, rollback_complete: bool, details: Dictionary = {}) -> void:
	_last_sync_report = {
		"success": success,
		"phase": phase,
		"message": message,
		"rollback_complete": rollback_complete,
		"details": details.duplicate(true)
	}
	if not success:
		sync_failed.emit(_last_sync_report.duplicate(true))

extends Node
class_name UndergroundMineDirector

## Owns the spatial window of independently streamed underground mine chunks.
## The surface director deliberately does not own these IDs.
signal sync_failed(report: Dictionary)

const MAX_SAFE_GRID_COORDINATE: float = 1000000000.0
const DEFAULT_CHUNK_SIZE: float = 10.0

@export_range(1.0, 256.0, 1.0) var chunk_size: float = DEFAULT_CHUNK_SIZE
@export_range(0, 8, 1) var load_radius: int = 1

var chunk_controller: Node3D
var chunk_factory: Callable
var _managed_chunk_ids: Dictionary = {} # underground/mine_x_z -> Vector2i
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
		_set_report(false, "validation", "Underground position or grid settings are invalid.", true)
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
	var desired: Array[Vector2i] = []
	for z in range(center.y - load_radius, center.y + load_radius + 1):
		for x in range(center.x - load_radius, center.x + load_radius + 1):
			desired.append(Vector2i(x, z))
	desired.sort_custom(_coordinate_less)

	var desired_ids: Dictionary = {}
	for coord in desired:
		desired_ids[_chunk_id(coord)] = coord

	var newly_loaded: Array[String] = []
	for coord in desired:
		var id: String = _chunk_id(coord)
		if chunk_controller.is_chunk_loaded(id):
			_managed_chunk_ids[id] = coord
			continue
		var candidate: Variant = chunk_factory.call(coord, now)
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
		_managed_chunk_ids[id] = coord
		newly_loaded.append(id)

	var stale_ids: Array[String] = []
	for id_value in _managed_chunk_ids.keys():
		var id: String = str(id_value)
		if not desired_ids.has(id):
			stale_ids.append(id)
	stale_ids.sort()
	var unloaded_stale: Array[Dictionary] = []
	for id in stale_ids:
		var stale_coord: Vector2i = _managed_chunk_ids[id]
		if not bool(chunk_controller.call("unload_chunk", id, now)):
			var rollback_ok: bool = _rollback_transaction(newly_loaded, unloaded_stale, previous_managed, registry_snapshot, now)
			_set_report(false, "stale_unload", "An obsolete underground chunk could not be unloaded.", rollback_ok, {
				"failed_chunk_id": id,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"unloaded_stale_ids": _entry_ids(unloaded_stale),
				"rollback_complete": rollback_ok
			})
			return false
		unloaded_stale.append({"id": id, "coord": stale_coord})
		_managed_chunk_ids.erase(id)

	_set_report(true, "complete", "", true, {
		"center": center,
		"desired_count": desired.size(),
		"newly_loaded_ids": newly_loaded.duplicate(),
		"unloaded_stale_ids": _entry_ids(unloaded_stale)
	})
	return true

## Rebuild the director's view from the controller after a restore or recovery.
## Only the exact underground/mine_x_z namespace is owned here.
func recover_to_world_position(world_position: Vector3, now_unix: int = -1) -> bool:
	if not _is_safe_world_position(world_position):
		_set_report(false, "recovery_validation", "Underground recovery position is invalid.", false)
		return false
	return sync_to_world_position(world_position, now_unix)

func get_grid_coordinate(world_position: Vector3) -> Vector2i:
	if not _is_safe_world_position(world_position):
		return Vector2i.ZERO
	return Vector2i(floori(world_position.x / chunk_size), floori(world_position.z / chunk_size))

func get_chunk_id(coord: Vector2i) -> String:
	return _chunk_id(coord)

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
		if not id.begins_with("underground/mine_"):
			continue
		var parsed: Dictionary = _parse_chunk_id(id)
		if not bool(parsed.get("valid", false)):
			return false
		reconciled[id] = parsed["coordinate"]
	_managed_chunk_ids = reconciled
	return true

func _parse_chunk_id(id: String) -> Dictionary:
	const prefix: String = "underground/mine_"
	if not id.begins_with(prefix):
		return {"valid": false, "coordinate": Vector2i.ZERO}
	var parts: PackedStringArray = id.substr(prefix.length()).split("_", false)
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return {"valid": false, "coordinate": Vector2i.ZERO}
	var coord := Vector2i(parts[0].to_int(), parts[1].to_int())
	if _chunk_id(coord) != id:
		return {"valid": false, "coordinate": Vector2i.ZERO}
	if absf(float(coord.x)) > MAX_SAFE_GRID_COORDINATE or absf(float(coord.y)) > MAX_SAFE_GRID_COORDINATE:
		return {"valid": false, "coordinate": Vector2i.ZERO}
	return {"valid": true, "coordinate": coord}

func _capture_registry_snapshot() -> Dictionary:
	var candidate: Variant = chunk_controller.get("registry")
	if candidate == null or not is_instance_valid(candidate) or not candidate.has_method("to_save_dict") or not candidate.has_method("restore_snapshot_exact"):
		return {}
	var snapshot: Variant = candidate.call("to_save_dict")
	if not (snapshot is Dictionary) or not snapshot.has("schema_version") or not snapshot.has("veins"):
		return {}
	return snapshot.duplicate(true)

func _rollback_transaction(new_ids: Array[String], unloaded: Array[Dictionary], previous_managed: Dictionary, registry_snapshot: Dictionary, now_unix: int) -> bool:
	var new_ok: bool = _rollback_new_loads(new_ids, now_unix)
	var registry_ok: bool = false
	var registry: Variant = chunk_controller.get("registry")
	if registry != null and is_instance_valid(registry) and registry.has_method("restore_snapshot_exact"):
		registry_ok = bool(registry.call("restore_snapshot_exact", registry_snapshot, now_unix))
	var old_ok: bool = _restore_unloaded_chunks(unloaded, now_unix) if registry_ok else false
	var final_registry_ok: bool = false
	if old_ok and registry != null and is_instance_valid(registry) and registry.has_method("restore_snapshot_exact"):
		# Re-apply the exact snapshot after reloading stale roots, because normal
		# chunk registration may perform elapsed-time catch-up during load.
		final_registry_ok = bool(registry.call("restore_snapshot_exact", registry_snapshot, now_unix))
	_managed_chunk_ids = previous_managed.duplicate(true) if new_ok and registry_ok and old_ok and final_registry_ok else _actual_managed_map()
	return new_ok and registry_ok and old_ok and final_registry_ok

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
		var candidate: Variant = chunk_factory.call(coord, now_unix)
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
			if id.begins_with("underground/mine_"):
				var parsed: Dictionary = _parse_chunk_id(id)
				if bool(parsed.get("valid", false)):
					result[id] = parsed["coordinate"]
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

func _chunk_id(coord: Vector2i) -> String:
	return "underground/mine_%d_%d" % [coord.x, coord.y]

func _is_safe_world_position(position: Vector3) -> bool:
	return is_finite(position.x) and is_finite(position.y) and is_finite(position.z) and is_finite(chunk_size) and chunk_size > 0.0 and load_radius >= 0 and absf(position.x / chunk_size) <= MAX_SAFE_GRID_COORDINATE and absf(position.z / chunk_size) <= MAX_SAFE_GRID_COORDINATE

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

extends Node
class_name MineralGridStreamingDirector

## Spatial streaming coordinator for chunks supplied by a generator callback.
## It selects a square grid around a world position and delegates chunk ownership to
## MineralChunkController. It does not generate terrain or perform async loading itself.
signal sync_failed(report: Dictionary)

const ControllerScript = preload("res://systems/MineralChunkController.gd")
const MAX_SAFE_GRID_COORDINATE: float = 1000000000.0

@export_range(1.0, 4096.0, 1.0) var chunk_size_x: float = 64.0
@export_range(1.0, 4096.0, 1.0) var chunk_size_z: float = 64.0
@export_range(0, 8, 1) var load_radius: int = 1

var chunk_controller: Node3D
var chunk_factory: Callable
var _managed_chunk_ids: Dictionary = {} # chunk ID -> Vector2i coordinate
var _last_sync_report: Dictionary = {}

func bind_controller(candidate: Node3D) -> bool:
	if candidate == null:
		return false
	for method_name in ["load_chunk", "unload_chunk", "is_chunk_loaded"]:
		if not candidate.has_method(method_name):
			return false
	if not _managed_chunk_ids.is_empty() and chunk_controller != candidate:
		return false
	chunk_controller = candidate
	return true

## The factory receives a grid coordinate and must return a new, unparented Node3D root.
## Return null to signal generation failure. The director takes ownership only after load succeeds.
func bind_chunk_factory(factory: Callable) -> bool:
	if not factory.is_valid():
		return false
	chunk_factory = factory
	return true

func sync_to_world_position(world_position: Vector3, now_unix: int = -1) -> bool:
	if chunk_controller == null or not is_instance_valid(chunk_controller) or not chunk_factory.is_valid():
		_set_sync_report(false, "validation", "Controller or chunk factory is unavailable.", true)
		return false
	if not _is_finite_world_position(world_position):
		_set_sync_report(false, "validation", "World position must contain only finite coordinates.", true)
		return false
	if not is_finite(chunk_size_x) or not is_finite(chunk_size_z) or chunk_size_x <= 0.0 or chunk_size_z <= 0.0 or load_radius < 0:
		_set_sync_report(false, "validation", "Chunk dimensions and load radius must be valid.", true)
		return false
	if not _is_safe_grid_position(world_position):
		_set_sync_report(false, "validation", "World position is outside supported grid-coordinate bounds.", true)
		return false

	var center := Vector2i(
		floori(world_position.x / chunk_size_x),
		floori(world_position.z / chunk_size_z)
	)
	var desired: Array[Vector2i] = []
	for z in range(center.y - load_radius, center.y + load_radius + 1):
		for x in range(center.x - load_radius, center.x + load_radius + 1):
			desired.append(Vector2i(x, z))
	desired.sort_custom(_coordinate_less)

	var desired_ids: Dictionary = {}
	for coord in desired:
		desired_ids[_chunk_id(coord)] = coord

	# Load first. If any generation or registration fails, preserve the previous active set.
	var newly_loaded: Array[String] = []
	for coord in desired:
		var id := _chunk_id(coord)
		if _managed_chunk_ids.has(id) and chunk_controller.is_chunk_loaded(id):
			continue
		var candidate: Variant = chunk_factory.call(coord)
		if not is_instance_valid(candidate) or not (candidate is Node3D) or candidate.get_parent() != null:
			_free_unowned_root(candidate)
			var rollback_ok: bool = _rollback_new_loads(newly_loaded, now_unix)
			_set_sync_report(false, "load_factory", "Chunk factory returned an invalid root.", rollback_ok, {
				"failed_chunk_id": id,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"new_loads_rollback_ok": rollback_ok
			})
			if not rollback_ok:
				push_warning("Mineral grid streaming rollback was incomplete after invalid chunk factory output.")
			return false
		if not chunk_controller.load_chunk(id, candidate, now_unix):
			_free_unowned_root(candidate)
			var rollback_ok: bool = _rollback_new_loads(newly_loaded, now_unix)
			_set_sync_report(false, "load_registration", "Chunk controller rejected a new chunk.", rollback_ok, {
				"failed_chunk_id": id,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"new_loads_rollback_ok": rollback_ok
			})
			if not rollback_ok:
				push_warning("Mineral grid streaming rollback was incomplete after chunk registration failure.")
			return false
		_managed_chunk_ids[id] = coord
		newly_loaded.append(id)

	# Only unload stale chunks after every desired chunk has loaded successfully.
	var stale_ids: Array[String] = []
	for id in _managed_chunk_ids.keys():
		if not desired_ids.has(id):
			stale_ids.append(str(id))
	stale_ids.sort()
	var unloaded_stale: Array[Dictionary] = []
	for id in stale_ids:
		var stale_coord: Vector2i = _managed_chunk_ids[id]
		if not chunk_controller.unload_chunk(id, now_unix):
			# Unloading can fail after earlier stale chunks have already been removed.
			# Restore the previous active set instead of leaving a half-shifted window.
			var new_loads_restored: bool = _rollback_new_loads(newly_loaded, now_unix)
			var old_chunks_restored: bool = _restore_unloaded_chunks(unloaded_stale, now_unix)
			var rollback_complete: bool = new_loads_restored and old_chunks_restored
			var unloaded_ids: Array[String] = []
			for entry in unloaded_stale:
				unloaded_ids.append(str(entry.get("id", "")))
			_set_sync_report(false, "stale_unload", "Controller failed to unload a stale chunk.", rollback_complete, {
				"failed_chunk_id": id,
				"newly_loaded_ids": newly_loaded.duplicate(),
				"unloaded_stale_ids": unloaded_ids,
				"new_loads_rollback_ok": new_loads_restored,
				"stale_restore_ok": old_chunks_restored
			})
			if not rollback_complete:
				push_warning("Mineral grid streaming rollback was incomplete after stale chunk unload failure; inspect get_last_sync_report().")
			return false
		unloaded_stale.append({"id": id, "coord": stale_coord})
		_managed_chunk_ids.erase(id)

	_set_sync_report(true, "complete", "", true, {
		"center": center,
		"desired_count": desired.size(),
		"newly_loaded_ids": newly_loaded.duplicate()
	})
	return true

## Reconcile the managed map from the controller's actual IDs, then retry the target window.
## This is intended for recovery after a previous sync reported an incomplete rollback.
## Unknown ID formats are rejected before changing the director's current managed map.
func recover_to_world_position(world_position: Vector3, now_unix: int = -1) -> bool:
	if not _is_finite_world_position(world_position):
		_set_sync_report(false, "recovery_validation", "World position must contain only finite coordinates.", false)
		return false
	if not _is_safe_grid_position(world_position):
		_set_sync_report(false, "recovery_validation", "World position is outside supported grid-coordinate bounds.", false)
		return false
	if chunk_controller == null or not is_instance_valid(chunk_controller) or not chunk_controller.has_method("get_loaded_chunk_ids"):
		_set_sync_report(false, "recovery_validation", "Controller cannot provide its actual loaded chunk IDs.", false)
		return false
	var raw_ids: Variant = chunk_controller.call("get_loaded_chunk_ids")
	if not (raw_ids is Array or raw_ids is PackedStringArray):
		_set_sync_report(false, "recovery_validation", "Controller returned an invalid loaded-ID collection.", false)
		return false
	var reconciled: Dictionary = {}
	var invalid_ids: Array[String] = []
	for raw_id in raw_ids:
		var chunk_id: String = str(raw_id)
		var parsed: Dictionary = _parse_grid_chunk_id(chunk_id)
		if not bool(parsed.get("valid", false)):
			invalid_ids.append(chunk_id)
			continue
		reconciled[chunk_id] = parsed["coordinate"]
	if not invalid_ids.is_empty():
		_set_sync_report(false, "recovery_validation", "Controller contains IDs that cannot be mapped to grid coordinates.", false, {
			"unrecognized_chunk_ids": invalid_ids
		})
		return false
	_managed_chunk_ids = reconciled
	return sync_to_world_position(world_position, now_unix)

func _parse_grid_chunk_id(chunk_id: String) -> Dictionary:
	const prefix: String = "surface/chunk_"
	if not chunk_id.begins_with(prefix):
		return {"valid": false, "coordinate": Vector2i.ZERO}
	var parts: PackedStringArray = chunk_id.substr(prefix.length()).split("_", false)
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return {"valid": false, "coordinate": Vector2i.ZERO}
	var coordinate := Vector2i(parts[0].to_int(), parts[1].to_int())
	if _chunk_id(coordinate) != chunk_id:
		return {"valid": false, "coordinate": Vector2i.ZERO}
	return {"valid": true, "coordinate": coordinate}
## Returns a snapshot of the last sync outcome, including actual active IDs from both owners.
## On failure, callers can inspect phase/details or subscribe to sync_failed(report).
func get_last_sync_report() -> Dictionary:
	return _last_sync_report.duplicate(true)

func get_managed_chunk_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id in _managed_chunk_ids.keys():
		ids.append(str(id))
	ids.sort()
	return ids

func get_grid_coordinate(world_position: Vector3) -> Vector2i:
	if not _is_safe_grid_position(world_position):
		return Vector2i.ZERO
	return Vector2i(floori(world_position.x / chunk_size_x), floori(world_position.z / chunk_size_z))

func _is_safe_grid_position(world_position: Vector3) -> bool:
	if not _is_finite_world_position(world_position):
		return false
	if not is_finite(chunk_size_x) or not is_finite(chunk_size_z) or chunk_size_x <= 0.0 or chunk_size_z <= 0.0 or load_radius < 0:
		return false
	var grid_x: float = world_position.x / chunk_size_x
	var grid_z: float = world_position.z / chunk_size_z
	return is_finite(grid_x) and is_finite(grid_z) and absf(grid_x) <= MAX_SAFE_GRID_COORDINATE and absf(grid_z) <= MAX_SAFE_GRID_COORDINATE

func _is_finite_world_position(world_position: Vector3) -> bool:
	return is_finite(world_position.x) and is_finite(world_position.y) and is_finite(world_position.z)

func _chunk_id(coord: Vector2i) -> String:
	return "surface/chunk_%d_%d" % [coord.x, coord.y]

func _rollback_new_loads(ids: Array[String], now_unix: int) -> bool:
	var success := true
	for i in range(ids.size() - 1, -1, -1):
		var id: String = ids[i]
		if not chunk_controller.is_chunk_loaded(id):
			_managed_chunk_ids.erase(id)
			continue
		if chunk_controller.unload_chunk(id, now_unix):
			_managed_chunk_ids.erase(id)
		else:
			success = false
	return success

func _restore_unloaded_chunks(chunks: Array[Dictionary], now_unix: int) -> bool:
	var success := true
	for entry in chunks:
		var id: String = str(entry.get("id", ""))
		var coord: Vector2i = entry["coord"]
		var candidate: Variant = chunk_factory.call(coord)
		if not is_instance_valid(candidate) or not (candidate is Node3D) or candidate.get_parent() != null:
			_free_unowned_root(candidate)
			success = false
			continue
		if not chunk_controller.load_chunk(id, candidate, now_unix):
			_free_unowned_root(candidate)
			success = false
			continue
		_managed_chunk_ids[id] = coord
	return success

func _free_unowned_root(candidate: Variant) -> void:
	if is_instance_valid(candidate) and candidate is Node3D and candidate.get_parent() == null:
		candidate.free()

func _set_sync_report(success: bool, phase: String, message: String, rollback_complete: bool, details: Dictionary = {}) -> void:
	_last_sync_report = {
		"success": success,
		"phase": phase,
		"message": message,
		"rollback_complete": rollback_complete,
		"details": details.duplicate(true),
		"managed_chunk_ids": get_managed_chunk_ids(),
		"controller_chunk_ids": _get_controller_loaded_ids()
	}
	if not success:
		sync_failed.emit(_last_sync_report.duplicate(true))

func _get_controller_loaded_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if chunk_controller != null and is_instance_valid(chunk_controller) and chunk_controller.has_method("get_loaded_chunk_ids"):
		var raw_ids: Variant = chunk_controller.call("get_loaded_chunk_ids")
		if raw_ids is Array or raw_ids is PackedStringArray:
			for item in raw_ids:
				ids.append(str(item))
	ids.sort()
	return ids

static func _coordinate_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y == b.y:
		return a.x < b.x
	return a.y < b.y

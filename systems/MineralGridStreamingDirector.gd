extends Node
class_name MineralGridStreamingDirector

## Spatial streaming coordinator for chunks supplied by a generator callback.
## It selects a square grid around a world position and delegates chunk ownership to
## MineralChunkController. It does not generate terrain or perform async loading itself.
const ControllerScript = preload("res://systems/MineralChunkController.gd")

@export_range(1.0, 4096.0, 1.0) var chunk_size_x: float = 64.0
@export_range(1.0, 4096.0, 1.0) var chunk_size_z: float = 64.0
@export_range(0, 8, 1) var load_radius: int = 1

var chunk_controller: Node3D
var chunk_factory: Callable
var _managed_chunk_ids: Dictionary = {} # chunk ID -> Vector2i coordinate

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
		return false
	if chunk_size_x <= 0.0 or chunk_size_z <= 0.0 or load_radius < 0:
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
			if not _rollback_new_loads(newly_loaded, now_unix):
				push_error("Mineral grid streaming rollback was incomplete after invalid chunk factory output.")
			return false
		if not chunk_controller.load_chunk(id, candidate, now_unix):
			_free_unowned_root(candidate)
			_rollback_new_loads(newly_loaded, now_unix)
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
			if not new_loads_restored or not old_chunks_restored:
				push_error("Mineral grid streaming rollback was incomplete after stale chunk unload failure.")
			return false
		unloaded_stale.append({"id": id, "coord": stale_coord})
		_managed_chunk_ids.erase(id)
	return true

func get_managed_chunk_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id in _managed_chunk_ids.keys():
		ids.append(str(id))
	ids.sort()
	return ids

func get_grid_coordinate(world_position: Vector3) -> Vector2i:
	return Vector2i(floori(world_position.x / chunk_size_x), floori(world_position.z / chunk_size_z))

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

static func _coordinate_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y == b.y:
		return a.x < b.x
	return a.y < b.y

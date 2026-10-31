extends Node
class_name MineralChunkLifecycleAdapter

## Adapter for a future world/chunk streamer. The world owner calls load_chunk()
## after creating a chunk's mineral nodes and unload_chunk() before freeing them.
const MiningNode = preload("res://systems/MineralMiningNode.gd")

var registry: Node
var _loaded_chunks: Dictionary = {} # chunk ID -> { local vein ID -> MineralMiningNode }

func bind_registry(candidate: Node) -> bool:
	if candidate == null or not candidate.has_method("register_vein") or not candidate.has_method("unregister_vein") or not candidate.has_method("get_registered_ids"):
		return false
	registry = candidate
	return true

func load_chunk(chunk_id: String, veins_by_local_id: Dictionary, now_unix: int = -1) -> bool:
	if registry == null or not _valid_id(chunk_id) or veins_by_local_id.is_empty():
		return false
	if _loaded_chunks.has(chunk_id):
		return _same_chunk_nodes(_loaded_chunks[chunk_id], veins_by_local_id)

	var stable_ids: Dictionary = {}
	var registered_ids: PackedStringArray = registry.get_registered_ids()
	for local_id in veins_by_local_id.keys():
		if not (local_id is String) or not _valid_id(local_id):
			return false
		var vein: Variant = veins_by_local_id[local_id]
		if not is_instance_valid(vein) or not (vein is MiningNode):
			return false
		if not vein.has_method("can_register") or not bool(vein.call("can_register")):
			return false
		var stable_id: String = make_stable_id(chunk_id, local_id)
		if stable_ids.has(stable_id) or registered_ids.has(stable_id):
			return false
		stable_ids[stable_id] = vein

	var added: Array[String] = []
	for stable_id in stable_ids.keys():
		if not registry.register_vein(stable_id, stable_ids[stable_id], now_unix):
			for rollback_id in added:
				registry.unregister_vein(rollback_id, stable_ids[rollback_id], now_unix)
			return false
		added.append(stable_id)

	_loaded_chunks[chunk_id] = veins_by_local_id.duplicate()
	return true

func unload_chunk(chunk_id: String, now_unix: int = -1) -> bool:
	if registry == null or not _loaded_chunks.has(chunk_id):
		return false
	var local_veins: Dictionary = _loaded_chunks[chunk_id]
	for local_id in local_veins.keys():
		if not is_instance_valid(local_veins[local_id]):
			return false

	var removed: Array[String] = []
	for local_id in local_veins.keys():
		var stable_id: String = make_stable_id(chunk_id, str(local_id))
		if not registry.unregister_vein(stable_id, local_veins[local_id], now_unix):
			# Best-effort rollback so a failed unload does not leave a half-unregistered chunk.
			for restore_id in removed:
				var restore_local_id: String = restore_id.substr((chunk_id + "/vein/").length())
				registry.register_vein(restore_id, local_veins[restore_local_id], now_unix)
			return false
		removed.append(stable_id)

	_loaded_chunks.erase(chunk_id)
	return true

func is_chunk_loaded(chunk_id: String) -> bool:
	return _loaded_chunks.has(chunk_id)

func get_loaded_chunk_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for chunk_id in _loaded_chunks.keys():
		ids.append(str(chunk_id))
	ids.sort()
	return ids

static func make_stable_id(chunk_id: String, local_vein_id: String) -> String:
	if not _valid_id(chunk_id) or not _valid_id(local_vein_id):
		return ""
	return chunk_id + "/vein/" + local_vein_id

static func _valid_id(value: String) -> bool:
	return not value.is_empty() and value == value.strip_edges() and not value.contains("//")

func _same_chunk_nodes(existing: Dictionary, incoming: Dictionary) -> bool:
	if existing.size() != incoming.size():
		return false
	for local_id in existing.keys():
		if not incoming.has(local_id) or incoming[local_id] != existing[local_id]:
			return false
	return true

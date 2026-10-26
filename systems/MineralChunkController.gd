extends Node3D
class_name MineralChunkController

## Owns instantiated world chunk roots and connects their mineral nodes to the stable-ID registry.
## The world generator remains responsible for constructing a chunk root; this controller owns
## registration, persistence delegation, unload ordering, and root lifetime.
const MiningNode = preload("res://systems/MineralMiningNode.gd")
const AdapterScript = preload("res://systems/MineralChunkLifecycleAdapter.gd")

var registry: Node
var adapter: Node
var _chunk_roots: Dictionary = {} # chunk ID -> Node3D root
var _chunk_veins: Dictionary = {} # chunk ID -> local vein ID -> MineralMiningNode

func bind_registry(candidate: Node) -> bool:
	if candidate == null:
		return false
	for method_name in ["register_vein", "unregister_vein", "get_registered_ids", "to_save_dict", "restore_save_dict"]:
		if not candidate.has_method(method_name):
			return false
	if not _chunk_roots.is_empty() and registry != candidate:
		return false
	if adapter == null:
		var new_adapter: Node = AdapterScript.new()
		new_adapter.name = "MineralChunkLifecycleAdapter"
		add_child(new_adapter)
		adapter = new_adapter
	if not bool(adapter.bind_registry(candidate)):
		return false
	registry = candidate
	return true

## Accepts an instantiated, unparented chunk root. Chunks without minerals are valid too.
## Stable local IDs are derived from scene node names and their hierarchy.
func load_chunk(chunk_id: String, chunk_root: Node3D, now_unix: int = -1) -> bool:
	if registry == null or adapter == null or not is_instance_valid(chunk_root):
		return false
	if AdapterScript.make_stable_id(chunk_id, "probe").is_empty():
		return false
	if _chunk_roots.has(chunk_id) or chunk_root.get_parent() != null:
		return false

	var veins: Dictionary = {}
	if not _collect_mineral_nodes(chunk_root, str(chunk_root.name), veins):
		return false
	add_child(chunk_root)
	if not veins.is_empty() and not bool(adapter.load_chunk(chunk_id, veins, now_unix)):
		# A failed registration must not consume the caller's scene. Detach it so the
		# generator can inspect, repair, or retry the same root without reconstructing it.
		remove_child(chunk_root)
		return false

	_chunk_roots[chunk_id] = chunk_root
	_chunk_veins[chunk_id] = veins
	return true

## Captures mineral state before detaching/freeing the chunk root.
## If registry unregistration fails, the root remains owned and available for retry.
func unload_chunk(chunk_id: String, now_unix: int = -1) -> bool:
	if registry == null or not _chunk_roots.has(chunk_id):
		return false
	var chunk_root: Node3D = _chunk_roots[chunk_id] as Node3D
	if not is_instance_valid(chunk_root):
		return false
	var veins: Dictionary = _chunk_veins[chunk_id]
	if not veins.is_empty() and not bool(adapter.unload_chunk(chunk_id, now_unix)):
		return false

	_chunk_roots.erase(chunk_id)
	_chunk_veins.erase(chunk_id)
	remove_child(chunk_root)
	chunk_root.queue_free()
	return true

func get_chunk_root(chunk_id: String) -> Node3D:
	if not _chunk_roots.has(chunk_id):
		return null
	var chunk_root: Node3D = _chunk_roots[chunk_id] as Node3D
	return chunk_root if is_instance_valid(chunk_root) else null

func is_chunk_loaded(chunk_id: String) -> bool:
	return _chunk_roots.has(chunk_id) and is_instance_valid(_chunk_roots[chunk_id])

func get_loaded_chunk_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for chunk_id in _chunk_roots.keys():
		if is_instance_valid(_chunk_roots[chunk_id]):
			ids.append(str(chunk_id))
	ids.sort()
	return ids

func to_save_dict() -> Dictionary:
	if registry == null:
		return {}
	return registry.to_save_dict()

## Registry validates the complete payload before applying it to live nodes or saved records.
func restore_save_dict(payload: Dictionary, now_unix: int = -1) -> bool:
	if registry == null:
		return false
	return bool(registry.restore_save_dict(payload, now_unix))

func _collect_mineral_nodes(node: Node, path_prefix: String, output: Dictionary) -> bool:
	if node is MiningNode:
		var local_id: String = path_prefix
		if local_id.is_empty() or local_id != local_id.strip_edges() or local_id.contains("//"):
			return false
		if output.has(local_id):
			return false
		output[local_id] = node

	for child: Node in node.get_children():
		var child_path: String = str(child.name) if path_prefix.is_empty() else path_prefix + "/" + str(child.name)
		if not _collect_mineral_nodes(child, child_path, output):
			return false
	return true

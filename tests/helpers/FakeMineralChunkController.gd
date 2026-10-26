extends Node3D

var _loaded: Dictionary = {}
var unload_calls: int = 0
var fail_on_unload_call: int = -1

func load_chunk(chunk_id: String, chunk_root: Node3D, _now_unix: int = -1) -> bool:
	if _loaded.has(chunk_id) or not is_instance_valid(chunk_root) or chunk_root.get_parent() != null:
		return false
	add_child(chunk_root)
	_loaded[chunk_id] = chunk_root
	return true

func unload_chunk(chunk_id: String, _now_unix: int = -1) -> bool:
	unload_calls += 1
	if fail_on_unload_call > 0 and unload_calls == fail_on_unload_call:
		fail_on_unload_call = -1
		return false
	if not _loaded.has(chunk_id):
		return false
	var chunk_root: Node3D = _loaded[chunk_id] as Node3D
	_loaded.erase(chunk_id)
	remove_child(chunk_root)
	chunk_root.queue_free()
	return true

func is_chunk_loaded(chunk_id: String) -> bool:
	return _loaded.has(chunk_id)

func get_loaded_chunk_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for chunk_id in _loaded.keys():
		ids.append(str(chunk_id))
	ids.sort()
	return ids

extends Node3D

var _loaded: Dictionary = {}
var load_calls: int = 0
var unload_calls: int = 0
var fail_on_unload_call: int = -1
var detach_on_next_load: bool = false
var detach_on_load_call: int = -1
var queue_on_load_call: int = -1
var fail_after_register_on_load_call: int = -1
var return_success_without_register_on_load_call: int = -1

func load_chunk(chunk_id: String, chunk_root: Node3D, _now_unix: int = -1) -> bool:
	load_calls += 1
	if _loaded.has(chunk_id) or not is_instance_valid(chunk_root) or chunk_root.get_parent() != null:
		return false
	if load_calls == return_success_without_register_on_load_call:
		return_success_without_register_on_load_call = -1
		add_child(chunk_root)
		return true
	add_child(chunk_root)
	_loaded[chunk_id] = chunk_root
	if detach_on_next_load or load_calls == detach_on_load_call:
		detach_on_next_load = false
		detach_on_load_call = -1
		var current_parent: Node = get_parent()
		if current_parent != null:
			current_parent.remove_child(self)
	if load_calls == queue_on_load_call:
		queue_on_load_call = -1
		queue_free()
	if load_calls == fail_after_register_on_load_call:
		fail_after_register_on_load_call = -1
		return false
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

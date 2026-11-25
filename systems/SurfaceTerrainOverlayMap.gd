extends RefCounted

## Persistent, shallow overlay map for transaction candidates.
## The root owns a shallow copy of the initial Dictionary. fork() seals the current
## snapshot and creates an O(1) child containing only writes and tombstones.
## Reads walk at most MAX_OVERLAY_DEPTH layers; size() is O(1).
## keys()/materialize()/compact() are explicitly O(N) operations.
const MAX_OVERLAY_DEPTH: int = 8

var _base: Dictionary = {}
var _parent: RefCounted = null
var _writes: Dictionary = {}
var _removed: Dictionary = {}
var _visible_size: int = 0
var _depth: int = 0
var _sealed: bool = false
var _base_keys_copied: int = 0
var _materialize_calls: int = 0
var _materialized_keys: int = 0


func _init(base: Dictionary = {}, copy_base: bool = true) -> void:
	if copy_base:
		_base = base.duplicate(false)
		_base_keys_copied = base.size()
	else:
		# Internal ownership-transfer path used only by compact().
		_base = base
		_base_keys_copied = 0
	_visible_size = _base.size()


## Creates a writable child without enumerating or copying the visible key set.
## The current snapshot becomes immutable before the child is returned.
func fork() -> RefCounted:
	seal()
	var parent: RefCounted = self
	if _depth >= MAX_OVERLAY_DEPTH:
		parent = compact()
		parent.call("seal")
	var child: RefCounted = get_script().new()
	child.call("_initialize_child", parent)
	return child


func _initialize_child(parent: RefCounted) -> void:
	_parent = parent
	_depth = int(parent.call("get_depth")) + 1
	_visible_size = int(parent.call("size"))


func seal() -> void:
	_sealed = true


func is_sealed() -> bool:
	return _sealed


func get_depth() -> int:
	return _depth


func size() -> int:
	return _visible_size


func is_empty() -> bool:
	return _visible_size == 0


func has_key(key: Variant) -> bool:
	if _removed.has(key):
		return false
	if _writes.has(key):
		return true
	if _parent != null:
		return bool(_parent.call("has_key", key))
	return _base.has(key)


func get_value(key: Variant, default_value: Variant = null) -> Variant:
	if _removed.has(key):
		return default_value
	if _writes.has(key):
		return _writes[key]
	if _parent != null:
		return _parent.call("get_value", key, default_value)
	return _base.get(key, default_value)


## Returns false when the snapshot has been sealed.
func set_value(key: Variant, value: Variant) -> bool:
	if _sealed:
		return false
	var existed: bool = has_key(key)
	_removed.erase(key)
	_writes[key] = value
	if not existed:
		_visible_size += 1
	return true


## Returns false when the key is absent or the snapshot has been sealed.
func erase_key(key: Variant) -> bool:
	if _sealed or not has_key(key):
		return false
	_writes.erase(key)
	_removed[key] = true
	_visible_size -= 1
	return true


## Explicit full enumeration. This is intentionally O(N), not used by fork()/set/erase.
func keys() -> Array:
	return materialize().keys()


## Produces an independent Dictionary snapshot. Call only at APIs that require a Dictionary.
func materialize() -> Dictionary:
	var layers: Array[RefCounted] = []
	var cursor: RefCounted = self
	while cursor != null:
		layers.append(cursor)
		var parent_value: Variant = cursor.call("_get_parent")
		if not (parent_value is RefCounted):
			break
		cursor = parent_value as RefCounted

	var root_layer: RefCounted = layers.pop_back()
	var root_base: Dictionary = root_layer.call("_get_base_dictionary")
	var result: Dictionary = root_base.duplicate(false)
	while not layers.is_empty():
		var layer: RefCounted = layers.pop_back()
		var changes: Dictionary = layer.call("_get_overlay_changes")
		var removed_keys: Array = changes.get("removed_keys", [])
		for key in removed_keys:
			result.erase(key)
		var writes: Dictionary = changes.get("writes", {})
		for key in writes:
			result[key] = writes[key]

	_materialize_calls += 1
	_materialized_keys += result.size()
	return result


## Flattens the current visible snapshot into a new root map.
## The old map remains valid and unchanged.
func compact() -> RefCounted:
	var flattened: Dictionary = materialize()
	return get_script().new(flattened, false)


func get_stats() -> Dictionary:
	return {
		"depth": _depth,
		"visible_size": _visible_size,
		"local_write_count": _writes.size(),
		"local_tombstone_count": _removed.size(),
		"base_keys_copied": _base_keys_copied,
		"materialize_calls": _materialize_calls,
		"materialized_keys": _materialized_keys,
		"sealed": _sealed
	}


func _get_parent() -> RefCounted:
	return _parent


func _get_base_dictionary() -> Dictionary:
	return _base


func _get_overlay_changes() -> Dictionary:
	return {
		"writes": _writes,
		"removed_keys": _removed.keys()
	}

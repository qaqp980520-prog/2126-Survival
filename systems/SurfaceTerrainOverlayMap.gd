extends RefCounted

## Persistent overlay map with nested Array/Dictionary copy-on-write.
## Root construction takes one deep copy of nested containers. fork() seals the
## current snapshot and creates an O(1) child containing only writes/tombstones.
## Reads of Array/Dictionary values return detached deep copies.
## mutate_value() applies a Callable to a detached copy and commits a second copy,
## so a retained callback reference cannot mutate a sealed or committed snapshot.
## Object/Resource references are not cloned and must remain immutable in a snapshot.
## keys()/materialize()/compact() are explicit O(N) boundaries.
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
var _container_clone_count: int = 0


func _init(base: Dictionary = {}, copy_base: bool = true) -> void:
	if copy_base:
		_base = base.duplicate(true)
		_container_clone_count += 1
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


## Array/Dictionary results are detached deep copies. Scalars and value types are returned directly.
func get_value(key: Variant, default_value: Variant = null) -> Variant:
	if _removed.has(key):
		return _clone_mutable_container(default_value)
	if _writes.has(key):
		return _clone_mutable_container(_writes[key])
	if _parent != null:
		return _parent.call("get_value", key, default_value)
	return _clone_mutable_container(_base.get(key, default_value))


## Applies a mutator to a detached nested container and commits a second copy.
## The Callable may retain its working copy; later mutation of that retained value
## cannot affect the committed snapshot. Return false from the Callable to abort.
func mutate_value(key: Variant, mutator: Callable) -> bool:
	if _sealed or not has_key(key) or not mutator.is_valid():
		return false
	var working_copy: Variant = get_value(key, null)
	if not (working_copy is Dictionary or working_copy is Array):
		return false
	var mutation_result: Variant = mutator.call(working_copy)
	if mutation_result is bool and not mutation_result:
		return false
	return set_value(key, working_copy)


## Returns false when the snapshot has been sealed.
## Mutable containers are deep-copied so caller-owned inputs cannot mutate a snapshot.
func set_value(key: Variant, value: Variant) -> bool:
	if _sealed:
		return false
	var existed: bool = has_key(key)
	var stored_value: Variant = _clone_mutable_container(value)
	_removed.erase(key)
	_writes[key] = stored_value
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


## Produces an independent Dictionary snapshot, including nested Array/Dictionary values.
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
	# Accessors return detached nested containers; this is the explicit O(N) boundary.
	var result: Dictionary = root_layer.call("_get_base_dictionary")
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
		"container_clone_count": _container_clone_count,
		"sealed": _sealed
	}


func _get_parent() -> RefCounted:
	return _parent


## Internal accessors return detached containers; callers cannot mutate sealed backing state.
func _get_base_dictionary() -> Dictionary:
	_container_clone_count += 1
	return _base.duplicate(true)


func _get_overlay_changes() -> Dictionary:
	_container_clone_count += 1
	return {
		"writes": _writes.duplicate(true),
		"removed_keys": _removed.keys()
	}


func _clone_mutable_container(value: Variant) -> Variant:
	if value is Dictionary:
		_container_clone_count += 1
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	if value is Array:
		_container_clone_count += 1
		var array_value: Array = value
		return array_value.duplicate(true)
	return value

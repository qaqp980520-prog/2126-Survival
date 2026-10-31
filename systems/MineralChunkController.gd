extends Node3D
class_name MineralChunkController

## Owns instantiated chunk roots, registering mineral veins and binding stable crop plots.
## Mineral and crop records outlive scene nodes so a reloaded chunk can rebuild its visuals.
const MiningNode = preload("res://systems/MineralMiningNode.gd")
const CropPlotScript = preload("res://systems/CropPlotVisual.gd")
const AdapterScript = preload("res://systems/MineralChunkLifecycleAdapter.gd")

var registry: Node
var adapter: Node
var crop_controller: Node
var object_state_registry: Node
var _chunk_roots: Dictionary = {} # chunk ID -> Node3D root
var _chunk_veins: Dictionary = {} # chunk ID -> local vein ID -> MineralMiningNode
var _chunk_crops: Dictionary = {} # chunk ID -> local crop path -> CropPlotVisual
var _chunk_objects: Dictionary = {} # chunk ID -> stable object ID -> stateful Node3D

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

func bind_crop_controller(candidate: Node) -> bool:
	if candidate == null:
		return false
	for method_name in ["plant_crop", "get_crop", "water_crop", "advance_crop", "advance_crops_to_time", "harvest_crop", "remove_crop", "to_save_dict", "restore_save_dict"]:
		if not candidate.has_method(method_name):
			return false
	if not _chunk_roots.is_empty() and crop_controller != candidate:
		return false
	crop_controller = candidate
	return true

func bind_object_state_registry(candidate: Node) -> bool:
	if candidate == null:
		return false
	for method_name in ["get_object_state", "set_object_state", "to_save_dict", "validate_save_dict", "restore_save_dict"]:
		if not candidate.has_method(method_name):
			return false
	if not _chunk_roots.is_empty() and object_state_registry != candidate:
		return false
	object_state_registry = candidate
	return true

## Accepts an instantiated, unparented chunk root. Mineral and crop local IDs are
## derived from node names/hierarchy; registry records persist after the scene unloads.
func load_chunk(chunk_id: String, chunk_root: Node3D, now_unix: int = -1) -> bool:
	if registry == null or adapter == null or not is_instance_valid(chunk_root):
		return false
	if AdapterScript.make_stable_id(chunk_id, "probe").is_empty():
		return false
	if _chunk_roots.has(chunk_id) or chunk_root.get_parent() != null:
		return false

	var veins: Dictionary = {}
	var crops: Dictionary = {}
	if not _collect_mineral_nodes(chunk_root, str(chunk_root.name), veins):
		return false
	if not _collect_crop_plots(chunk_root, str(chunk_root.name), crops):
		return false
	if not crops.is_empty() and crop_controller == null:
		return false

	var existing_crop_ids: Array[String] = []
	var crop_snapshot: Dictionary = {}
	var world_objects: Dictionary = {}
	if not _collect_world_state_nodes(chunk_root, str(chunk_root.name), world_objects):
		return false
	if not world_objects.is_empty() and object_state_registry == null:
		return false
	for local_path in crops.keys():
		var stable_id := _make_crop_stable_id(chunk_id, str(local_path))
		var plot: Node = crops[local_path] as Node
		if not _valid_crop_stable_id(stable_id):
			return false
		if not plot.has_method("can_configure") or not bool(plot.call(
			"can_configure",
			crop_controller,
			stable_id,
			str(plot.get("crop_id")),
			int(plot.get("plot_index"))
		)):
			return false
		var existing_crop: Dictionary = crop_controller.call("get_crop", stable_id)
		if not existing_crop.is_empty():
			existing_crop_ids.append(stable_id)
	if not existing_crop_ids.is_empty():
		crop_snapshot = crop_controller.call("to_save_dict")
		if not crop_snapshot.has("schema_version") or not crop_snapshot.has("crops"):
			return false
		var catch_up: Dictionary = crop_controller.call("advance_crops_to_time", existing_crop_ids, now_unix)
		if not bool(catch_up.get("ok", false)):
			return false
	for local_path in crops.keys():
		var stable_id := _make_crop_stable_id(chunk_id, str(local_path))
		var plot: Node = crops[local_path]
		if not bool(plot.call("configure", crop_controller, stable_id, str(plot.get("crop_id")), int(plot.get("plot_index")))):
			if not crop_snapshot.is_empty():
				crop_controller.call("restore_save_dict", crop_snapshot)
				for plot_value in crops.values():
					var plot_node: Node = plot_value as Node
					if is_instance_valid(plot_node) and plot_node.has_method("refresh"):
						plot_node.call("refresh")
			return false

	var object_registry_snapshot: Dictionary = {}
	var initial_object_states: Dictionary = {}
	if not world_objects.is_empty():
		object_registry_snapshot = object_state_registry.call("to_save_dict")
		if not object_registry_snapshot.has("schema_version") or not object_registry_snapshot.has("objects"):
			if not crop_snapshot.is_empty():
				crop_controller.call("restore_save_dict", crop_snapshot)
				for plot_value in crops.values():
					var plot_node: Node = plot_value as Node
					if is_instance_valid(plot_node) and plot_node.has_method("refresh"):
						plot_node.call("refresh")
			return false

	add_child(chunk_root)
	if not world_objects.is_empty() and not _restore_world_object_nodes(chunk_id, world_objects, object_registry_snapshot, initial_object_states):
		remove_child(chunk_root)
		if not crop_snapshot.is_empty():
			crop_controller.call("restore_save_dict", crop_snapshot)
			for plot_value in crops.values():
				var plot_node: Node = plot_value as Node
				if is_instance_valid(plot_node) and plot_node.has_method("refresh"):
					plot_node.call("refresh")
		return false
	if not veins.is_empty() and not bool(adapter.load_chunk(chunk_id, veins, now_unix)):
		# A failed registration must not consume the caller's scene. Detach it so the
		# generator can inspect, repair, or retry the same root without reconstructing it.
		remove_child(chunk_root)
		if not world_objects.is_empty():
			_rollback_world_object_restore(initial_object_states, object_registry_snapshot)
		if not crop_snapshot.is_empty():
			var crop_rollback_ok: bool = bool(crop_controller.call("restore_save_dict", crop_snapshot))
			if not crop_rollback_ok:
				push_error("Failed to roll back crop catch-up after mineral chunk registration failed.")
			for plot_value in crops.values():
				var plot_node: Node = plot_value as Node
				if is_instance_valid(plot_node) and plot_node.has_method("refresh"):
					plot_node.call("refresh")
		return false

	_chunk_roots[chunk_id] = chunk_root
	_chunk_veins[chunk_id] = veins
	_chunk_crops[chunk_id] = crops
	var stable_objects: Dictionary = {}
	for local_path in world_objects.keys():
		stable_objects[_make_world_object_stable_id(chunk_id, str(local_path))] = world_objects[local_path]
	_chunk_objects[chunk_id] = stable_objects
	return true

## Captures mineral state before freeing a chunk. Crop records remain in CropRegistry;
## the next root with the same chunk ID reuses the same stable crop IDs.
func unload_chunk(chunk_id: String, now_unix: int = -1) -> bool:
	if registry == null or not _chunk_roots.has(chunk_id):
		return false
	var chunk_root: Node3D = _chunk_roots[chunk_id] as Node3D
	if not is_instance_valid(chunk_root):
		return false
	var veins: Dictionary = _chunk_veins[chunk_id]
	var object_snapshot: Dictionary = {}
	if not _chunk_objects.get(chunk_id, {}).is_empty():
		if object_state_registry == null:
			return false
		object_snapshot = object_state_registry.call("to_save_dict")
		if not object_snapshot.has("schema_version") or not object_snapshot.has("objects"):
			return false
		for stable_id in _chunk_objects[chunk_id].keys():
			var object_node: Node = _chunk_objects[chunk_id][stable_id] as Node
			if not is_instance_valid(object_node) or not object_node.has_method("get_world_object_state"):
				object_state_registry.call("restore_save_dict", object_snapshot)
				return false
			var object_state: Variant = object_node.call("get_world_object_state")
			if not (object_state is Dictionary) or (object_node.has_method("validate_world_object_state") and not bool(object_node.call("validate_world_object_state", object_state))) or not bool(object_state_registry.call("set_object_state", str(stable_id), chunk_id, object_state)):
				object_state_registry.call("restore_save_dict", object_snapshot)
				return false
	if not veins.is_empty() and not bool(adapter.unload_chunk(chunk_id, now_unix)):
		if not object_snapshot.is_empty():
			object_state_registry.call("restore_save_dict", object_snapshot)
		return false

	_chunk_roots.erase(chunk_id)
	_chunk_veins.erase(chunk_id)
	_chunk_crops.erase(chunk_id)
	_chunk_objects.erase(chunk_id)
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

func get_loaded_mineral_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for local_veins in _chunk_veins.values():
		for vein_value in local_veins.values():
			var vein := vein_value as Node3D
			if is_instance_valid(vein):
				nodes.append(vein)
	return nodes

func refresh_crop_plots() -> void:
	for local_plots in _chunk_crops.values():
		for plot_value in local_plots.values():
			var plot: Node = plot_value as Node
			if is_instance_valid(plot) and plot.has_method("refresh"):
				plot.call("refresh")

func get_loaded_crop_plots() -> Array[Node3D]:
	var plots: Array[Node3D] = []
	for local_plots in _chunk_crops.values():
		for plot_value in local_plots.values():
			var plot := plot_value as Node3D
			if is_instance_valid(plot):
				plots.append(plot)
	return plots

func get_loaded_world_state_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for chunk_objects in _chunk_objects.values():
		for node_value in chunk_objects.values():
			var node := node_value as Node3D
			if is_instance_valid(node):
				nodes.append(node)
	return nodes

## Persist the live state of every loaded stateful object before a world save is serialized.
func capture_loaded_world_object_states() -> bool:
	var has_stateful_objects: bool = false
	for chunk_objects in _chunk_objects.values():
		if not chunk_objects.is_empty():
			has_stateful_objects = true
			break
	if not has_stateful_objects:
		return true
	if object_state_registry == null:
		return false
	var snapshot: Dictionary = object_state_registry.call("to_save_dict")
	if not snapshot.has("schema_version") or not snapshot.has("objects"):
		return false
	for chunk_id in _chunk_objects.keys():
		for stable_id in _chunk_objects[chunk_id].keys():
			var node: Node = _chunk_objects[chunk_id][stable_id] as Node
			if not is_instance_valid(node) or not node.has_method("get_world_object_state"):
				object_state_registry.call("restore_save_dict", snapshot)
				return false
			var state: Variant = node.call("get_world_object_state")
			if not (state is Dictionary) or (node.has_method("validate_world_object_state") and not bool(node.call("validate_world_object_state", state))) or not bool(object_state_registry.call("set_object_state", str(stable_id), str(chunk_id), state)):
				object_state_registry.call("restore_save_dict", snapshot)
				return false
	return true

## Atomically restore registry data and apply it to all currently loaded stateful nodes.
func restore_world_object_states(payload: Dictionary) -> bool:
	if object_state_registry == null or not bool(object_state_registry.call("validate_save_dict", payload)):
		return false
	var registry_snapshot: Dictionary = object_state_registry.call("to_save_dict")
	var live_snapshot: Dictionary = _snapshot_live_world_object_states()
	if not bool(live_snapshot.get("ok", false)):
		return false
	if not bool(object_state_registry.call("restore_save_dict", payload)):
		return false
	if _apply_saved_world_object_states():
		return true
	object_state_registry.call("restore_save_dict", registry_snapshot)
	_restore_live_world_object_snapshot(live_snapshot.get("states", {}))
	return false

func _apply_saved_world_object_states() -> bool:
	var live_snapshot: Dictionary = _snapshot_live_world_object_states()
	if not bool(live_snapshot.get("ok", false)):
		return false
	for chunk_id in _chunk_objects.keys():
		for stable_id in _chunk_objects[chunk_id].keys():
			var node: Node = _chunk_objects[chunk_id][stable_id] as Node
			if not is_instance_valid(node):
				_restore_live_world_object_snapshot(live_snapshot.get("states", {}))
				return false
			var record: Dictionary = object_state_registry.call("get_object_state", str(stable_id))
			if record.is_empty():
				var default_state: Variant = node.call("get_world_object_state")
				if not (default_state is Dictionary) or not bool(object_state_registry.call("set_object_state", str(stable_id), str(chunk_id), default_state)):
					_restore_live_world_object_snapshot(live_snapshot.get("states", {}))
					return false
				continue
			var saved_state: Variant = record.get("state", {})
			if str(record.get("chunk_id", "")) != str(chunk_id) or not (saved_state is Dictionary) or (node.has_method("validate_world_object_state") and not bool(node.call("validate_world_object_state", saved_state))) or not bool(node.call("apply_world_object_state", saved_state)):
				_restore_live_world_object_snapshot(live_snapshot.get("states", {}))
				return false
	return true

func _snapshot_live_world_object_states() -> Dictionary:
	var states: Dictionary = {}
	for chunk_id in _chunk_objects.keys():
		for stable_id in _chunk_objects[chunk_id].keys():
			var node: Node = _chunk_objects[chunk_id][stable_id] as Node
			if not is_instance_valid(node) or not node.has_method("get_world_object_state"):
				return {"ok": false, "states": states}
			var state: Variant = node.call("get_world_object_state")
			if not (state is Dictionary):
				return {"ok": false, "states": states}
			states[str(stable_id)] = {"node": node, "state": state.duplicate(true)}
	return {"ok": true, "states": states}

func _restore_live_world_object_snapshot(states: Dictionary) -> bool:
	var success: bool = true
	for stable_id in states.keys():
		var entry: Dictionary = states[stable_id]
		var node: Node = entry.get("node") as Node
		if not is_instance_valid(node) or not node.has_method("apply_world_object_state") or not bool(node.call("apply_world_object_state", entry.get("state", {}))):
			success = false
	return success

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

func _collect_crop_plots(node: Node, path_prefix: String, output: Dictionary) -> bool:
	if node is CropPlotScript:
		if path_prefix.is_empty() or path_prefix != path_prefix.strip_edges() or path_prefix.contains("//"):
			return false
		if output.has(path_prefix):
			return false
		output[path_prefix] = node
	for child: Node in node.get_children():
		var child_path: String = str(child.name) if path_prefix.is_empty() else path_prefix + "/" + str(child.name)
		if not _collect_crop_plots(child, child_path, output):
			return false
	return true

func _collect_world_state_nodes(node: Node, path_prefix: String, output: Dictionary) -> bool:
	if node.has_method("get_world_object_state") and node.has_method("apply_world_object_state"):
		if path_prefix.is_empty() or path_prefix != path_prefix.strip_edges() or path_prefix.contains("//"):
			return false
		if output.has(path_prefix):
			return false
		output[path_prefix] = node
	for child: Node in node.get_children():
		var child_path: String = str(child.name) if path_prefix.is_empty() else path_prefix + "/" + str(child.name)
		if not _collect_world_state_nodes(child, child_path, output):
			return false
	return true

func _restore_world_object_nodes(chunk_id: String, objects: Dictionary, registry_snapshot: Dictionary, initial_states: Dictionary) -> bool:
	var defaults: Dictionary = {}
	for local_path in objects.keys():
		var stable_id: String = _make_world_object_stable_id(chunk_id, str(local_path))
		var node: Node = objects[local_path] as Node
		if not _valid_world_object_stable_id(stable_id) or not is_instance_valid(node) or not node.has_method("get_world_object_state") or not node.has_method("apply_world_object_state"):
			_rollback_world_object_restore(initial_states, registry_snapshot)
			return false
		var current_state: Variant = node.call("get_world_object_state")
		if not (current_state is Dictionary):
			_rollback_world_object_restore(initial_states, registry_snapshot)
			return false
		initial_states[stable_id] = {"node": node, "state": current_state.duplicate(true)}
		var saved_record: Dictionary = object_state_registry.call("get_object_state", stable_id)
		if saved_record.is_empty():
			defaults[stable_id] = current_state.duplicate(true)
			continue
		if str(saved_record.get("chunk_id", "")) != chunk_id or not (saved_record.get("state", {}) is Dictionary) or (node.has_method("validate_world_object_state") and not bool(node.call("validate_world_object_state", saved_record.get("state", {})))) or not bool(node.call("apply_world_object_state", saved_record.get("state", {}))):
			_rollback_world_object_restore(initial_states, registry_snapshot)
			return false
	for stable_id in defaults.keys():
		if not bool(object_state_registry.call("set_object_state", str(stable_id), chunk_id, defaults[stable_id])):
			_rollback_world_object_restore(initial_states, registry_snapshot)
			return false
	return true

func _rollback_world_object_restore(initial_states: Dictionary, registry_snapshot: Dictionary) -> void:
	_restore_live_world_object_snapshot(initial_states)
	if object_state_registry != null and not registry_snapshot.is_empty():
		if not bool(object_state_registry.call("restore_save_dict", registry_snapshot)):
			push_error("Failed to restore world-object registry snapshot after chunk object-state failure.")

func _make_world_object_stable_id(chunk_id: String, local_path: String) -> String:
	return chunk_id + "/object/" + local_path

func _valid_world_object_stable_id(stable_id: String) -> bool:
	return not stable_id.is_empty() and stable_id.length() <= 192 and not stable_id.contains("\n") and not stable_id.contains("\r") and not stable_id.contains("//") and not stable_id.contains("..")

func _make_crop_stable_id(chunk_id: String, local_path: String) -> String:
	return chunk_id + "/crop/" + local_path

func _valid_crop_stable_id(stable_id: String) -> bool:
	return not stable_id.is_empty() and stable_id == stable_id.strip_edges() and stable_id.length() <= 160 and stable_id.find("/") > 0 and not stable_id.contains(" ") and not stable_id.contains("\t") and not stable_id.contains("\n") and not stable_id.contains("..") and not stable_id.contains("//")

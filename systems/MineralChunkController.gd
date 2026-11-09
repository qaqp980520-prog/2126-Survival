extends Node3D
class_name MineralChunkController

## Owns instantiated chunk roots, registering mineral veins and binding stable crop plots.
## Mineral and crop records outlive scene nodes so a reloaded chunk can rebuild its visuals.
const MiningNode = preload("res://systems/MineralMiningNode.gd")
const CropPlotScript = preload("res://systems/CropPlotVisual.gd")
const AdapterScript = preload("res://systems/MineralChunkLifecycleAdapter.gd")
const TerrainAdjacencyBinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const TerrainTransitionColliderManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")
const TERRAIN_ADJACENCY_SIDES: Array[String] = ["east", "west", "north", "south"]

var registry: Node
var adapter: Node
var crop_controller: Node
var object_state_registry: Node
var _chunk_roots: Dictionary = {} # chunk ID -> Node3D root
var _chunk_veins: Dictionary = {} # chunk ID -> local vein ID -> MineralMiningNode
var _chunk_crops: Dictionary = {} # chunk ID -> local crop path -> CropPlotVisual
var _chunk_objects: Dictionary = {} # chunk ID -> stable object ID -> stateful Node3D
var _pending_chunk_unloads: Dictionary = {} # chunk ID -> root, veins, object snapshot and timestamp
var _terrain_transition_descriptors: Dictionary = {} # derived edge key -> descriptor; never serialized
var _terrain_transition_collider_manager: Node3D
var _terrain_adjacency_batch_depth: int = 0
var _terrain_adjacency_batch_dirty: bool = false
var _terrain_adjacency_rebuild_count: int = 0
var _terrain_adjacency_profiling_enabled: bool = false
var _last_terrain_adjacency_profile: Dictionary = {}

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
	if registry == null or adapter == null or not is_instance_valid(chunk_root) or chunk_root.is_queued_for_deletion():
		return false
	if AdapterScript.make_stable_id(chunk_id, "probe").is_empty():
		return false
	if _chunk_roots.has(chunk_id):
		var existing_root: Node3D = _chunk_roots[chunk_id] as Node3D
		if not is_instance_valid(existing_root) or not existing_root.is_queued_for_deletion():
			return false
		if not unload_chunk(chunk_id, now_unix):
			return false
	if chunk_root.get_parent() != null:
		return false

	var veins: Dictionary = {}
	var crops: Dictionary = {}
	if not _collect_mineral_nodes(chunk_root, str(chunk_root.name), veins):
		return false
	var registered_mineral_ids: PackedStringArray = registry.call("get_registered_ids")
	for local_path in veins.keys():
		var stable_id: String = AdapterScript.make_stable_id(chunk_id, str(local_path))
		var vein: Node = veins[local_path] as Node
		if stable_id.is_empty() or registered_mineral_ids.has(stable_id):
			return false
		if not vein.has_method("can_register") or not bool(vein.call("can_register")):
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
		if not object_state_registry.has_method("get_chunk_states"):
			if not crop_snapshot.is_empty():
				crop_controller.call("restore_save_dict", crop_snapshot)
				for plot_value in crops.values():
					var plot_node: Node = plot_value as Node
					if is_instance_valid(plot_node) and plot_node.has_method("refresh"):
						plot_node.call("refresh")
			return false
		object_registry_snapshot = object_state_registry.call("get_chunk_states", chunk_id)
		if not (object_registry_snapshot is Dictionary):
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

	# Register minerals before publishing terrain adjacency. If registration fails,
	# no live patch edge or collider resource has been changed.
	if not veins.is_empty() and not bool(adapter.load_chunk(chunk_id, veins, now_unix)):
		remove_child(chunk_root)
		if not world_objects.is_empty():
			_rollback_world_object_restore(chunk_id, initial_object_states, object_registry_snapshot)
		if not crop_snapshot.is_empty():
			var crop_rollback_ok: bool = bool(crop_controller.call("restore_save_dict", crop_snapshot))
			if not crop_rollback_ok:
				push_error("Failed to roll back crop catch-up after mineral chunk registration failed.")
			for plot_value in crops.values():
				var plot_node: Node = plot_value as Node
				if is_instance_valid(plot_node) and plot_node.has_method("refresh"):
					plot_node.call("refresh")
		return false

	var existing_terrain_patches: Array[Node3D] = _collect_loaded_terrain_patches()
	var candidate_terrain_patches: Array[Node3D] = _collect_terrain_patches(world_objects)
	var all_terrain_patches: Array[Node3D] = existing_terrain_patches.duplicate()
	all_terrain_patches.append_array(candidate_terrain_patches)
	var adjacency_result: Dictionary = _request_terrain_adjacency_rebind(all_terrain_patches, chunk_id, world_objects)
	if not bool(adjacency_result.get("ok", false)):
		# The rebind path restores the previous live adjacency and collider state on
		# failure. Undo mineral registration while the candidate root is still alive.
		if not veins.is_empty():
			var adapter_rollback_ok: bool = bool(adapter.unload_chunk(chunk_id, now_unix))
			if not adapter_rollback_ok:
				push_error("Failed to roll back mineral registration after terrain adjacency failed.")
		remove_child(chunk_root)
		if not world_objects.is_empty():
			_rollback_world_object_restore(chunk_id, initial_object_states, object_registry_snapshot)
		if not crop_snapshot.is_empty():
			var crop_rollback_ok: bool = bool(crop_controller.call("restore_save_dict", crop_snapshot))
			if not crop_rollback_ok:
				push_error("Failed to roll back crop catch-up after terrain adjacency failed.")
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
	for node_value in stable_objects.values():
		var stateful_node: Node = node_value as Node
		if is_instance_valid(stateful_node) and stateful_node.has_signal("terrain_state_changed"):
			var callback := Callable(self, "_on_terrain_patch_state_changed")
			if not stateful_node.is_connected("terrain_state_changed", callback):
				stateful_node.connect("terrain_state_changed", callback)
	return true

## Captures mineral state before freeing a chunk. Crop records remain in CropRegistry;
## the next root with the same chunk ID reuses the same stable crop IDs.
func unload_chunk(chunk_id: String, now_unix: int = -1) -> bool:
	if registry == null or not _chunk_roots.has(chunk_id):
		return false
	var chunk_root: Node3D = _chunk_roots[chunk_id] as Node3D
	if not is_instance_valid(chunk_root):
		return false
	if _pending_chunk_unloads.has(chunk_id):
		return true
	var veins: Dictionary = _chunk_veins[chunk_id]
	var object_snapshot: Dictionary = {}
	if not _chunk_objects.get(chunk_id, {}).is_empty():
		if object_state_registry == null:
			return false
		if not object_state_registry.has_method("get_chunk_states"):
			return false
		object_snapshot = object_state_registry.call("get_chunk_states", chunk_id)
		if not (object_snapshot is Dictionary):
			return false
		for stable_id in _chunk_objects[chunk_id].keys():
			var object_node: Node = _chunk_objects[chunk_id][stable_id] as Node
			if not is_instance_valid(object_node) or not object_node.has_method("get_world_object_state"):
				object_state_registry.call("restore_chunk_states", chunk_id, object_snapshot)
				return false
			var object_state: Variant = object_node.call("get_world_object_state")
			if not (object_state is Dictionary) or (object_node.has_method("validate_world_object_state") and not bool(object_node.call("validate_world_object_state", object_state))) or not bool(object_state_registry.call("set_object_state", str(stable_id), chunk_id, object_state)):
				object_state_registry.call("restore_chunk_states", chunk_id, object_snapshot)
				return false
	if not veins.is_empty() and not bool(adapter.unload_chunk(chunk_id, now_unix)):
		if not object_snapshot.is_empty() and not bool(object_state_registry.call("restore_chunk_states", chunk_id, object_snapshot)):
			push_error("Failed to restore world-object registry after mineral chunk unload failed.")
		return false

	# During a batch, keep the old root, maps and patch Nodes alive until one
	# shared adjacency/collider commit has excluded every pending retirement.
	# This preserves removal-side WeakRef validation without rebuilding once per
	# stale chunk in a large window contraction.
	if _terrain_adjacency_batch_depth > 0:
		_pending_chunk_unloads[chunk_id] = {
			"root": chunk_root,
			"veins": veins.duplicate(),
			"object_snapshot": object_snapshot.duplicate(true),
			"now_unix": now_unix
		}
		_terrain_adjacency_batch_dirty = true
		return true

	# Keep the old root and all of its patch Nodes alive until the candidate
	# adjacency/collider state commits. This is required by removal-side WeakRef
	# validation and gives the adapter an inverse operation if rebind fails.
	var remaining_terrain_patches: Array[Node3D] = _collect_loaded_terrain_patches(chunk_id)
	var adjacency_result: Dictionary = _rebind_terrain_patches(
		remaining_terrain_patches,
		"",
		{},
		chunk_id
	)
	if not bool(adjacency_result.get("ok", false)):
		if not veins.is_empty():
			var adapter_rollback_ok: bool = bool(adapter.load_chunk(chunk_id, veins, now_unix))
			if not adapter_rollback_ok:
				push_error("Failed to restore mineral registration after terrain adjacency unload failed.")
		if not object_snapshot.is_empty() and not bool(object_state_registry.call("restore_chunk_states", chunk_id, object_snapshot)):
			push_error("Failed to restore world-object registry after terrain adjacency unload failed.")
		return false

	_chunk_roots.erase(chunk_id)
	_chunk_veins.erase(chunk_id)
	_chunk_crops.erase(chunk_id)
	_chunk_objects.erase(chunk_id)
	remove_child(chunk_root)
	if not chunk_root.is_queued_for_deletion():
		chunk_root.queue_free()

	return true

func get_chunk_root(chunk_id: String) -> Node3D:
	if not _chunk_roots.has(chunk_id):
		return null
	var chunk_root: Node3D = _chunk_roots[chunk_id] as Node3D
	return chunk_root if is_instance_valid(chunk_root) and not chunk_root.is_queued_for_deletion() else null

func is_chunk_loaded(chunk_id: String) -> bool:
	if not _chunk_roots.has(chunk_id):
		return false
	var chunk_root: Node3D = _chunk_roots[chunk_id] as Node3D
	return is_instance_valid(chunk_root) and not chunk_root.is_queued_for_deletion()

func get_loaded_chunk_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for chunk_id in _chunk_roots.keys():
		var chunk_root: Node3D = _chunk_roots[chunk_id] as Node3D
		if is_instance_valid(chunk_root) and not chunk_root.is_queued_for_deletion():
			ids.append(str(chunk_id))
	ids.sort()
	return ids

func get_loaded_mineral_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for chunk_id in _chunk_roots.keys():
		if _pending_chunk_unloads.has(str(chunk_id)):
			continue
		var chunk_root: Node3D = _chunk_roots[chunk_id] as Node3D
		if not is_instance_valid(chunk_root) or chunk_root.is_queued_for_deletion():
			continue
		var local_veins: Dictionary = _chunk_veins.get(chunk_id, {})
		for vein_value in local_veins.values():
			var vein := vein_value as Node3D
			if is_instance_valid(vein) and not vein.is_queued_for_deletion():
				nodes.append(vein)
	return nodes

func refresh_crop_plots() -> void:
	for chunk_id in _chunk_roots.keys():
		if _pending_chunk_unloads.has(str(chunk_id)):
			continue
		var chunk_root: Node3D = _chunk_roots[chunk_id] as Node3D
		if not is_instance_valid(chunk_root) or chunk_root.is_queued_for_deletion():
			continue
		var local_plots: Dictionary = _chunk_crops.get(chunk_id, {})
		for plot_value in local_plots.values():
			var plot: Node = plot_value as Node
			if is_instance_valid(plot) and not plot.is_queued_for_deletion() and plot.has_method("refresh"):
				plot.call("refresh")

func get_loaded_crop_plots() -> Array[Node3D]:
	var plots: Array[Node3D] = []
	for chunk_id in _chunk_roots.keys():
		if _pending_chunk_unloads.has(str(chunk_id)):
			continue
		var chunk_root: Node3D = _chunk_roots[chunk_id] as Node3D
		if not is_instance_valid(chunk_root) or chunk_root.is_queued_for_deletion():
			continue
		var local_plots: Dictionary = _chunk_crops.get(chunk_id, {})
		for plot_value in local_plots.values():
			var plot := plot_value as Node3D
			if is_instance_valid(plot) and not plot.is_queued_for_deletion():
				plots.append(plot)
	return plots

func get_loaded_world_state_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for chunk_id in _chunk_roots.keys():
		if _pending_chunk_unloads.has(str(chunk_id)):
			continue
		var chunk_root: Node3D = _chunk_roots[chunk_id] as Node3D
		if not is_instance_valid(chunk_root) or chunk_root.is_queued_for_deletion():
			continue
		var chunk_objects: Dictionary = _chunk_objects.get(chunk_id, {})
		for node_value in chunk_objects.values():
			var node := node_value as Node3D
			if is_instance_valid(node) and not node.is_queued_for_deletion():
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

func _collect_loaded_terrain_patches(excluded_chunk_id: String = "") -> Array[Node3D]:
	var patches: Array[Node3D] = []
	for chunk_id_value in _chunk_objects.keys():
		if str(chunk_id_value) == excluded_chunk_id or _pending_chunk_unloads.has(str(chunk_id_value)):
			continue
		var chunk_objects: Dictionary = _chunk_objects[chunk_id_value]
		for node_value in chunk_objects.values():
			var node: Node3D = node_value as Node3D
			if is_instance_valid(node) and node.is_inside_tree() and node.has_method("bind_neighbor_patch"):
				patches.append(node)
	return patches

func _collect_terrain_patches(objects: Dictionary) -> Array[Node3D]:
	var patches: Array[Node3D] = []
	for node_value in objects.values():
		var node: Node3D = node_value as Node3D
		if is_instance_valid(node) and node.is_inside_tree() and node.has_method("bind_neighbor_patch"):
			patches.append(node)
	return patches

## Returns the current derived seam descriptors; these are never part of world-save payloads.
func get_terrain_transition_descriptors() -> Dictionary:
	return _terrain_transition_descriptors.duplicate(true)

func get_terrain_transition_collider_count() -> int:
	if is_instance_valid(_terrain_transition_collider_manager) and _terrain_transition_collider_manager.has_method("get_transition_count"):
		return int(_terrain_transition_collider_manager.call("get_transition_count"))
	return 0

func get_terrain_transition_collider(edge_key: String) -> StaticBody3D:
	if not is_instance_valid(_terrain_transition_collider_manager) or not _terrain_transition_collider_manager.has_method("get_transition_body"):
		return null
	return _terrain_transition_collider_manager.call("get_transition_body", edge_key) as StaticBody3D

func get_blocked_terrain_corner_reports() -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	if not is_instance_valid(_terrain_transition_collider_manager):
		return reports
	if not _terrain_transition_collider_manager.has_method("get_blocked_corner_reports"):
		return reports
	var raw_reports: Array = _terrain_transition_collider_manager.call("get_blocked_corner_reports")
	for report_value in raw_reports:
		if report_value is Dictionary:
			reports.append(report_value.duplicate(true))
	return reports

func _ensure_transition_collider_manager() -> bool:
	if is_instance_valid(_terrain_transition_collider_manager):
		return true
	var manager: Node3D = TerrainTransitionColliderManagerScript.new() as Node3D
	if manager == null:
		return false
	manager.name = "SurfaceTerrainTransitionColliderManager"
	add_child(manager)
	_terrain_transition_collider_manager = manager
	return true

func begin_terrain_adjacency_batch() -> bool:
	if not is_inside_tree() or is_queued_for_deletion():
		return false
	if _terrain_adjacency_batch_depth == 0:
		if not _pending_chunk_unloads.is_empty():
			return false
		_terrain_adjacency_batch_dirty = false
	_terrain_adjacency_batch_depth += 1
	return true

func end_terrain_adjacency_batch() -> Dictionary:
	if _terrain_adjacency_batch_depth <= 0:
		return {"ok": true, "active": false}
	_terrain_adjacency_batch_depth -= 1
	if _terrain_adjacency_batch_depth > 0:
		return {"ok": true, "deferred": true}
	if not _terrain_adjacency_batch_dirty and _pending_chunk_unloads.is_empty():
		return {"ok": true, "rebuild_count": 0}

	var pending_validation: Dictionary = _validate_pending_chunk_unloads()
	if not bool(pending_validation.get("ok", false)):
		var pending_rollback_ok: bool = _cancel_all_pending_chunk_unloads()
		return {
			"ok": false,
			"error": "pending_chunk_unload_validation_failed:" + str(pending_validation.get("error", "unknown")),
			"pending_unload_rollback_ok": pending_rollback_ok
		}

	_terrain_adjacency_batch_dirty = false
	var collect_started_usec: int = Time.get_ticks_usec() if _terrain_adjacency_profiling_enabled else 0
	var patches: Array[Node3D] = _collect_loaded_terrain_patches()
	var collect_usec: int = Time.get_ticks_usec() - collect_started_usec if _terrain_adjacency_profiling_enabled else 0
	var result: Dictionary = _rebind_terrain_patches(patches)
	if _terrain_adjacency_profiling_enabled:
		var profile: Dictionary = _last_terrain_adjacency_profile.duplicate(true)
		profile["collect_loaded_patches_usec"] = collect_usec
		profile["batch_total_usec"] = int(profile.get("controller_rebind_total_usec", 0)) + collect_usec
		_last_terrain_adjacency_profile = profile
		result["profile_usec"] = profile.duplicate(true)

	if not bool(result.get("ok", false)):
		var pending_rollback_ok: bool = _cancel_all_pending_chunk_unloads()
		result["pending_unload_rollback_ok"] = pending_rollback_ok
		if not pending_rollback_ok:
			result["error"] = "terrain_adjacency_failed_and_pending_unload_rollback_failed"
		return result

	var finalize_result: Dictionary = _finalize_pending_chunk_unloads()
	if not bool(finalize_result.get("ok", false)):
		var pending_rollback_ok: bool = _cancel_all_pending_chunk_unloads()
		var adjacency_restore: Dictionary = _rebind_terrain_patches(_collect_loaded_terrain_patches())
		return {
			"ok": false,
			"error": "terrain_adjacency_committed_but_chunk_retirement_failed",
			"pending_unload_rollback_ok": pending_rollback_ok,
			"adjacency_restore_ok": bool(adjacency_restore.get("ok", false))
		}
	result["retired_chunk_count"] = int(finalize_result.get("retired_chunk_count", 0))
	return result

func cancel_pending_chunk_unload(chunk_id: String, now_unix: int = -1) -> bool:
	if not _pending_chunk_unloads.has(chunk_id):
		return is_chunk_loaded(chunk_id)
	var entry: Dictionary = _pending_chunk_unloads[chunk_id]
	var chunk_root: Node3D = entry.get("root") as Node3D
	if not is_instance_valid(chunk_root) or chunk_root.get_parent() != self or chunk_root.is_queued_for_deletion():
		return false

	var restore_time: int = now_unix if now_unix > 0 else int(entry.get("now_unix", -1))
	var veins: Dictionary = entry.get("veins", {})
	var adapter_restored: bool = false
	if not veins.is_empty():
		if adapter == null or not is_instance_valid(adapter) or not adapter.has_method("load_chunk") or not bool(adapter.call("load_chunk", chunk_id, veins, restore_time)):
			return false
		adapter_restored = true

	var object_snapshot: Dictionary = entry.get("object_snapshot", {})
	if not _chunk_objects.get(chunk_id, {}).is_empty():
		if object_state_registry == null or not is_instance_valid(object_state_registry) or not object_state_registry.has_method("restore_chunk_states") or not bool(object_state_registry.call("restore_chunk_states", chunk_id, object_snapshot)):
			if adapter_restored and not bool(adapter.call("unload_chunk", chunk_id, restore_time)):
				push_error("Failed to undo mineral registration after pending chunk-unload cancellation failed.")
			return false

	_pending_chunk_unloads.erase(chunk_id)
	if _terrain_adjacency_batch_depth > 0:
		_terrain_adjacency_batch_dirty = true
	return true

func _validate_pending_chunk_unloads() -> Dictionary:
	for raw_chunk_id in _pending_chunk_unloads.keys():
		var chunk_id: String = str(raw_chunk_id)
		var entry: Dictionary = _pending_chunk_unloads[raw_chunk_id]
		var chunk_root: Node3D = entry.get("root") as Node3D
		if not is_instance_valid(chunk_root) or chunk_root.get_parent() != self or chunk_root.is_queued_for_deletion():
			return {"ok": false, "error": "pending_root_invalid:" + chunk_id}
		if not _chunk_roots.has(chunk_id) or _chunk_roots[chunk_id] != chunk_root:
			return {"ok": false, "error": "pending_root_owner_mismatch:" + chunk_id}
		var veins: Dictionary = entry.get("veins", {})
		if not veins.is_empty() and (
			adapter == null
			or not is_instance_valid(adapter)
			or not adapter.has_method("is_chunk_loaded")
			or bool(adapter.call("is_chunk_loaded", chunk_id))
		):
			return {"ok": false, "error": "pending_mineral_registration_still_active:" + chunk_id}
	return {"ok": true}

func _cancel_all_pending_chunk_unloads() -> bool:
	var chunk_ids: Array[String] = []
	for raw_chunk_id in _pending_chunk_unloads.keys():
		chunk_ids.append(str(raw_chunk_id))
	chunk_ids.sort()
	var success: bool = true
	for chunk_id in chunk_ids:
		if not cancel_pending_chunk_unload(chunk_id):
			success = false
	return success

func _finalize_pending_chunk_unloads() -> Dictionary:
	var chunk_ids: Array[String] = []
	for raw_chunk_id in _pending_chunk_unloads.keys():
		chunk_ids.append(str(raw_chunk_id))
	chunk_ids.sort()
	for chunk_id in chunk_ids:
		var entry: Dictionary = _pending_chunk_unloads.get(chunk_id, {})
		var chunk_root: Node3D = entry.get("root") as Node3D
		if not is_instance_valid(chunk_root) or chunk_root.get_parent() != self or chunk_root.is_queued_for_deletion():
			return {"ok": false, "error": "pending_root_changed_during_finalize:" + chunk_id}
		_chunk_roots.erase(chunk_id)
		_chunk_veins.erase(chunk_id)
		_chunk_crops.erase(chunk_id)
		_chunk_objects.erase(chunk_id)
		remove_child(chunk_root)
		if not chunk_root.is_queued_for_deletion():
			chunk_root.queue_free()
		_pending_chunk_unloads.erase(chunk_id)
	return {"ok": true, "retired_chunk_count": chunk_ids.size()}

func get_terrain_adjacency_rebuild_count() -> int:
	return _terrain_adjacency_rebuild_count

## Profiling is opt-in so normal gameplay does not pay for diagnostic clock reads.
func set_terrain_adjacency_profiling_enabled(enabled: bool) -> void:
	_terrain_adjacency_profiling_enabled = enabled
	if not enabled:
		_last_terrain_adjacency_profile.clear()

func get_last_terrain_adjacency_profile() -> Dictionary:
	return _last_terrain_adjacency_profile.duplicate(true)

func _request_terrain_adjacency_rebind(
	patches: Array[Node3D],
	candidate_chunk_id: String = "",
	candidate_objects: Dictionary = {}
) -> Dictionary:
	if _terrain_adjacency_batch_depth > 0:
		_terrain_adjacency_batch_dirty = true
		return {"ok": true, "deferred": true}
	return _rebind_terrain_patches(patches, candidate_chunk_id, candidate_objects)

func refresh_terrain_adjacency() -> bool:
	var result: Dictionary = _rebind_terrain_patches(_collect_loaded_terrain_patches())
	return bool(result.get("ok", false))

func _on_terrain_patch_state_changed(_patch: Node3D) -> void:
	var result: Dictionary = _request_terrain_adjacency_rebind(_collect_loaded_terrain_patches())
	if not bool(result.get("ok", false)):
		push_error("Terrain transition descriptor rebuild failed after terrain edit: %s" % str(result.get("error", "unknown")))

func _rebind_terrain_patches(patches: Array[Node3D], candidate_chunk_id: String = "", candidate_objects: Dictionary = {}, excluded_chunk_id: String = "") -> Dictionary:
	var total_started_usec: int = Time.get_ticks_usec() if _terrain_adjacency_profiling_enabled else 0
	_terrain_adjacency_rebuild_count += 1
	var profile: Dictionary = {}
	var map_started_usec: int = Time.get_ticks_usec() if _terrain_adjacency_profiling_enabled else 0
	var stable_ids_by_instance: Dictionary = {}
	var patches_by_stable_id: Dictionary = {}
	for chunk_id_value in _chunk_objects.keys():
		if str(chunk_id_value) == excluded_chunk_id or _pending_chunk_unloads.has(str(chunk_id_value)):
			continue
		var chunk_objects: Dictionary = _chunk_objects[chunk_id_value]
		for stable_id in chunk_objects.keys():
			var node: Node = chunk_objects[stable_id] as Node
			if is_instance_valid(node) and node.has_method("bind_neighbor_patch"):
				stable_ids_by_instance[node.get_instance_id()] = str(stable_id)
				patches_by_stable_id[str(stable_id)] = node
	for local_path in candidate_objects.keys():
		var candidate: Node = candidate_objects[local_path] as Node
		if is_instance_valid(candidate) and candidate.has_method("bind_neighbor_patch"):
			var candidate_stable_id: String = _make_world_object_stable_id(candidate_chunk_id, str(local_path))
			stable_ids_by_instance[candidate.get_instance_id()] = candidate_stable_id
			patches_by_stable_id[candidate_stable_id] = candidate
	if _terrain_adjacency_profiling_enabled:
		profile["stable_id_map_usec"] = Time.get_ticks_usec() - map_started_usec
	var adjacency_snapshot_result: Dictionary = _capture_terrain_patch_adjacency_snapshot(patches)
	if not bool(adjacency_snapshot_result.get("ok", false)):
		var snapshot_failure: Dictionary = {"ok": false, "error": "adjacency_snapshot_failed:" + str(adjacency_snapshot_result.get("error", "unknown"))}
		_finish_terrain_adjacency_profile(profile, total_started_usec, patches.size(), snapshot_failure)
		return snapshot_failure
	var adjacency_snapshot: Dictionary = adjacency_snapshot_result.get("snapshot", {})

	var binder_started_usec: int = Time.get_ticks_usec() if _terrain_adjacency_profiling_enabled else 0
	var result: Dictionary = TerrainAdjacencyBinderScript.bind_patches(patches, stable_ids_by_instance, _terrain_adjacency_profiling_enabled)
	if _terrain_adjacency_profiling_enabled:
		profile["binder_total_usec"] = Time.get_ticks_usec() - binder_started_usec
		var binder_profile: Dictionary = result.get("profile_usec", {})
		profile["binder_validation_usec"] = int(binder_profile.get("validation_usec", 0))
		profile["binder_adjacency_discovery_usec"] = int(binder_profile.get("adjacency_discovery_usec", 0))
		profile["binder_edge_apply_usec"] = int(binder_profile.get("edge_apply_usec", 0))
	if not bool(result.get("ok", false)):
		var binder_rollback: Dictionary = _restore_terrain_patch_adjacency_snapshot(adjacency_snapshot)
		if not bool(binder_rollback.get("ok", false)):
			result["rollback_error"] = str(binder_rollback.get("error", "unknown"))
			result["error"] = "terrain_binder_failed_and_rollback_failed"
		_finish_terrain_adjacency_profile(profile, total_started_usec, patches.size(), result)
		return result
	if not _ensure_transition_collider_manager():
		var manager_failure: Dictionary = {"ok": false, "error": "transition_manager_unavailable"}
		var manager_rollback: Dictionary = _restore_terrain_patch_adjacency_snapshot(adjacency_snapshot)
		if not bool(manager_rollback.get("ok", false)):
			manager_failure["rollback_error"] = str(manager_rollback.get("error", "unknown"))
			manager_failure["error"] = "transition_manager_unavailable_and_rollback_failed"
		_finish_terrain_adjacency_profile(profile, total_started_usec, patches.size(), manager_failure)
		return manager_failure
	var collider_started_usec: int = Time.get_ticks_usec() if _terrain_adjacency_profiling_enabled else 0
	var transition_result: Dictionary = _terrain_transition_collider_manager.call(
		"sync_transitions",
		result.get("descriptors", {}),
		patches_by_stable_id,
		_terrain_adjacency_profiling_enabled
	)
	if _terrain_adjacency_profiling_enabled:
		profile["collider_sync_total_usec"] = Time.get_ticks_usec() - collider_started_usec
		var collider_profile: Dictionary = transition_result.get("profile_usec", {})
		profile["collider_candidate_geometry_usec"] = int(collider_profile.get("candidate_geometry_usec", 0))
		profile["collider_corner_resolution_usec"] = int(collider_profile.get("corner_resolution_usec", 0))
		profile["collider_resource_staging_usec"] = int(collider_profile.get("resource_staging_usec", 0))
		profile["collider_activation_commit_usec"] = int(collider_profile.get("activation_commit_usec", 0))
		profile["collider_reused_edge_count"] = int(transition_result.get("reused_edge_count", 0))
		profile["collider_reactivated_edge_count"] = int(transition_result.get("reactivated_edge_count", 0))
		profile["collider_staged_edge_count"] = int(transition_result.get("staged_edge_count", 0))
		profile["collider_retired_edge_count"] = int(transition_result.get("retired_edge_count", 0))
		profile["collider_reused_corner_cap_count"] = int(transition_result.get("reused_corner_cap_count", 0))
		profile["collider_staged_corner_cap_count"] = int(transition_result.get("staged_corner_cap_count", 0))
		profile["collider_retired_corner_cap_count"] = int(transition_result.get("retired_corner_cap_count", 0))
	if not bool(transition_result.get("ok", false)):
		var collider_failure: Dictionary = {"ok": false, "error": "transition_collider_sync_failed:" + str(transition_result.get("error", "unknown"))}
		# sync_transitions stages candidate bodies and retains the old managed set on
		# failure. Restore the patch-side adjacency/activation snapshot to match it.
		var collider_rollback: Dictionary = _restore_terrain_patch_adjacency_snapshot(adjacency_snapshot)
		if not bool(collider_rollback.get("ok", false)):
			collider_failure["rollback_error"] = str(collider_rollback.get("error", "unknown"))
			collider_failure["error"] = "transition_collider_sync_failed_and_rollback_failed"
		_finish_terrain_adjacency_profile(profile, total_started_usec, patches.size(), collider_failure)
		return collider_failure
	_terrain_transition_descriptors = result.get("descriptors", {}).duplicate(true)
	result["transition_collider_count"] = int(transition_result.get("active_count", 0))
	result["corner_cap_count"] = int(transition_result.get("corner_cap_count", 0))
	result["reused_transition_edge_count"] = int(transition_result.get("reused_edge_count", 0))
	result["reactivated_transition_edge_count"] = int(transition_result.get("reactivated_edge_count", 0))
	result["staged_transition_edge_count"] = int(transition_result.get("staged_edge_count", 0))
	result["retired_transition_edge_count"] = int(transition_result.get("retired_edge_count", 0))
	result["reused_corner_cap_count"] = int(transition_result.get("reused_corner_cap_count", 0))
	result["staged_corner_cap_count"] = int(transition_result.get("staged_corner_cap_count", 0))
	result["retired_corner_cap_count"] = int(transition_result.get("retired_corner_cap_count", 0))
	result["blocked_transition_count"] = int(transition_result.get("blocked_count", 0))
	_finish_terrain_adjacency_profile(profile, total_started_usec, patches.size(), result)
	if _terrain_adjacency_profiling_enabled:
		result["profile_usec"] = _last_terrain_adjacency_profile.duplicate(true)
	return result

func _capture_terrain_patch_adjacency_snapshot(patches: Array[Node3D]) -> Dictionary:
	var captured: Array[Node3D] = []
	var seen_instance_ids: Dictionary = {}
	for patch in patches:
		if not is_instance_valid(patch) or not patch.is_inside_tree() or patch.is_queued_for_deletion():
			return {"ok": false, "error": "invalid_patch"}
		var instance_id: int = patch.get_instance_id()
		if not seen_instance_ids.has(instance_id):
			seen_instance_ids[instance_id] = true
			captured.append(patch)
		if not patch.has_method("get_bound_neighbor_patch") or not patch.has_method("is_shared_transition_active") or not patch.has_method("clear_neighbor_edge_state") or not patch.has_method("bind_neighbor_patch") or not patch.has_method("set_shared_transition_active") or not patch.has_method("begin_collision_segmentation_batch") or not patch.has_method("end_collision_segmentation_batch"):
			return {"ok": false, "error": "patch_snapshot_api_missing"}

	# Clearing a selected patch also clears the reciprocal side on its old neighbor.
	# Capture those direct neighbors too, even when they are outside the candidate set.
	var original_patch_count: int = captured.size()
	for patch_index in range(original_patch_count):
		var patch: Node3D = captured[patch_index]
		for side in TERRAIN_ADJACENCY_SIDES:
			var neighbor: Node3D = patch.call("get_bound_neighbor_patch", side) as Node3D
			if not is_instance_valid(neighbor):
				continue
			if not neighbor.is_inside_tree() or neighbor.is_queued_for_deletion():
				return {"ok": false, "error": "invalid_bound_neighbor"}
			if not neighbor.has_method("get_bound_neighbor_patch") or not neighbor.has_method("is_shared_transition_active") or not neighbor.has_method("clear_neighbor_edge_state") or not neighbor.has_method("bind_neighbor_patch") or not neighbor.has_method("set_shared_transition_active") or not neighbor.has_method("begin_collision_segmentation_batch") or not neighbor.has_method("end_collision_segmentation_batch"):
				return {"ok": false, "error": "neighbor_snapshot_api_missing"}
			var neighbor_instance_id: int = neighbor.get_instance_id()
			if not seen_instance_ids.has(neighbor_instance_id):
				seen_instance_ids[neighbor_instance_id] = true
				captured.append(neighbor)

	var records: Dictionary = {}
	for patch in captured:
		var neighbors_by_side: Dictionary = {}
		var active_by_side: Dictionary = {}
		for side in TERRAIN_ADJACENCY_SIDES:
			var neighbor: Node3D = patch.call("get_bound_neighbor_patch", side) as Node3D
			if is_instance_valid(neighbor):
				neighbors_by_side[side] = neighbor
			active_by_side[side] = bool(patch.call("is_shared_transition_active", side))
		records[patch.get_instance_id()] = {
			"patch": patch,
			"neighbors": neighbors_by_side,
			"active": active_by_side
		}
	return {"ok": true, "snapshot": {"patches": captured, "records": records}}


func _restore_terrain_patch_adjacency_snapshot(snapshot: Dictionary) -> Dictionary:
	var patches: Array = snapshot.get("patches", [])
	var records: Dictionary = snapshot.get("records", {})
	var batches: Array[Node3D] = []
	var failure: String = ""
	for patch_value in patches:
		var patch: Node3D = patch_value as Node3D
		if not is_instance_valid(patch):
			failure = "snapshot_patch_released"
			break
		if patch.has_method("begin_collision_segmentation_batch") and patch.has_method("end_collision_segmentation_batch"):
			patch.call("begin_collision_segmentation_batch")
			batches.append(patch)
		else:
			failure = "snapshot_patch_batch_api_missing"
			break

	if failure.is_empty():
		# Remove only edges that differ from the captured snapshot. Reciprocal clears
		# may also clear the opposite endpoint, which is why direct neighbors were captured.
		for patch_value in patches:
			var patch: Node3D = patch_value as Node3D
			var record: Dictionary = records.get(patch.get_instance_id(), {})
			var desired_neighbors: Dictionary = record.get("neighbors", {})
			for side in TERRAIN_ADJACENCY_SIDES:
				var current_neighbor: Node3D = patch.call("get_bound_neighbor_patch", side) as Node3D
				var desired_neighbor: Node3D = desired_neighbors.get(side) as Node3D
				if is_instance_valid(current_neighbor) and current_neighbor != desired_neighbor:
					if not bool(patch.call("clear_neighbor_edge_state", side)):
						failure = "snapshot_edge_clear_failed"
						break
			if not failure.is_empty():
				break

	if failure.is_empty():
		# Rebuild reciprocal links exactly once per endpoint pair.
		for patch_value in patches:
			var patch: Node3D = patch_value as Node3D
			var record: Dictionary = records.get(patch.get_instance_id(), {})
			var desired_neighbors: Dictionary = record.get("neighbors", {})
			for side in TERRAIN_ADJACENCY_SIDES:
				var neighbor: Node3D = desired_neighbors.get(side) as Node3D
				if not is_instance_valid(neighbor):
					continue
				var opposite_side: String = _opposite_terrain_side(side)
				var current_neighbor: Node3D = patch.call("get_bound_neighbor_patch", side) as Node3D
				var current_reciprocal: Node3D = neighbor.call("get_bound_neighbor_patch", opposite_side) as Node3D
				if current_neighbor == neighbor and current_reciprocal == patch:
					continue
				if not bool(patch.call("bind_neighbor_patch", side, neighbor)) or not bool(neighbor.call("bind_neighbor_patch", opposite_side, patch)):
					failure = "snapshot_edge_restore_failed"
					break
			if not failure.is_empty():
				break

	if failure.is_empty():
		# Restore shared-transition activation only after all neighbor policies exist.
		for patch_value in patches:
			var patch: Node3D = patch_value as Node3D
			var record: Dictionary = records.get(patch.get_instance_id(), {})
			var active_by_side: Dictionary = record.get("active", {})
			for side in TERRAIN_ADJACENCY_SIDES:
				var desired_active: bool = bool(active_by_side.get(side, false))
				var current_active: bool = bool(patch.call("is_shared_transition_active", side))
				if current_active != desired_active and not bool(patch.call("set_shared_transition_active", side, desired_active)):
					failure = "snapshot_transition_activation_restore_failed"
					break
			if not failure.is_empty():
				break

	for batch_index in range(batches.size() - 1, -1, -1):
		var batch_patch: Node3D = batches[batch_index]
		if is_instance_valid(batch_patch) and not bool(batch_patch.call("end_collision_segmentation_batch")) and failure.is_empty():
			failure = "snapshot_segmentation_batch_end_failed"
	return {"ok": failure.is_empty(), "error": failure}


func _opposite_terrain_side(side: String) -> String:
	match side:
		"east": return "west"
		"west": return "east"
		"north": return "south"
		"south": return "north"
		_: return ""


func _finish_terrain_adjacency_profile(profile: Dictionary, total_started_usec: int, patch_count: int, result: Dictionary) -> void:
	if not _terrain_adjacency_profiling_enabled:
		return
	profile["controller_rebind_total_usec"] = Time.get_ticks_usec() - total_started_usec
	profile["patch_count"] = patch_count
	var descriptors: Dictionary = result.get("descriptors", {})
	profile["descriptor_count"] = descriptors.size()
	profile["transition_collider_count"] = int(result.get("transition_collider_count", result.get("active_count", 0)))
	profile["corner_cap_count"] = int(result.get("corner_cap_count", 0))
	_last_terrain_adjacency_profile = profile.duplicate(true)

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
			_rollback_world_object_restore(chunk_id, initial_states, registry_snapshot)
			return false
		var current_state: Variant = node.call("get_world_object_state")
		if not (current_state is Dictionary):
			_rollback_world_object_restore(chunk_id, initial_states, registry_snapshot)
			return false
		initial_states[stable_id] = {"node": node, "state": current_state.duplicate(true)}
		var saved_record: Dictionary = object_state_registry.call("get_object_state", stable_id)
		if saved_record.is_empty():
			defaults[stable_id] = current_state.duplicate(true)
			continue
		if str(saved_record.get("chunk_id", "")) != chunk_id or not (saved_record.get("state", {}) is Dictionary) or (node.has_method("validate_world_object_state") and not bool(node.call("validate_world_object_state", saved_record.get("state", {})))) or not bool(node.call("apply_world_object_state", saved_record.get("state", {}))):
			_rollback_world_object_restore(chunk_id, initial_states, registry_snapshot)
			return false
	for stable_id in defaults.keys():
		if not bool(object_state_registry.call("set_object_state", str(stable_id), chunk_id, defaults[stable_id])):
			_rollback_world_object_restore(chunk_id, initial_states, registry_snapshot)
			return false
	return true

func _rollback_world_object_restore(chunk_id: String, initial_states: Dictionary, registry_snapshot: Dictionary) -> void:
	_restore_live_world_object_snapshot(initial_states)
	if object_state_registry != null and not initial_states.is_empty():
		if not bool(object_state_registry.call("restore_chunk_states", chunk_id, registry_snapshot)):
			push_error("Failed to restore chunk-scoped world-object registry snapshot after chunk object-state failure.")

func _make_world_object_stable_id(chunk_id: String, local_path: String) -> String:
	return chunk_id + "/object/" + local_path

func _valid_world_object_stable_id(stable_id: String) -> bool:
	return not stable_id.is_empty() and stable_id.length() <= 192 and not stable_id.contains("\n") and not stable_id.contains("\r") and not stable_id.contains("//") and not stable_id.contains("..")

func _make_crop_stable_id(chunk_id: String, local_path: String) -> String:
	return chunk_id + "/crop/" + local_path

func _valid_crop_stable_id(stable_id: String) -> bool:
	return not stable_id.is_empty() and stable_id == stable_id.strip_edges() and stable_id.length() <= 160 and stable_id.find("/") > 0 and not stable_id.contains(" ") and not stable_id.contains("\t") and not stable_id.contains("\n") and not stable_id.contains("..") and not stable_id.contains("//")

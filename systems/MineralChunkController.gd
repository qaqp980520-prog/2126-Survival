extends Node3D
class_name MineralChunkController

## Owns instantiated chunk roots, registering mineral veins and binding stable crop plots.
## Mineral and crop records outlive scene nodes so a reloaded chunk can rebuild its visuals.
const MiningNode = preload("res://systems/MineralMiningNode.gd")
const CropPlotScript = preload("res://systems/CropPlotVisual.gd")
const AdapterScript = preload("res://systems/MineralChunkLifecycleAdapter.gd")
const TerrainAdjacencyBinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const TerrainTransitionColliderManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")

var registry: Node
var adapter: Node
var crop_controller: Node
var object_state_registry: Node
var _chunk_roots: Dictionary = {} # chunk ID -> Node3D root
var _chunk_veins: Dictionary = {} # chunk ID -> local vein ID -> MineralMiningNode
var _chunk_crops: Dictionary = {} # chunk ID -> local crop path -> CropPlotVisual
var _chunk_objects: Dictionary = {} # chunk ID -> stable object ID -> stateful Node3D
var _terrain_transition_descriptors: Dictionary = {} # derived edge key -> descriptor; never serialized
var _terrain_transition_collider_manager: Node3D
var _terrain_adjacency_recovery_required: bool = false
var _chunk_load_recovery_required: bool = false
var _pending_chunk_load_recovery: Dictionary = {}
var _last_chunk_load_report: Dictionary = {}

func bind_registry(candidate: Node) -> bool:
	if candidate == null:
		return false
	for method_name in ["register_vein", "register_veins_atomic", "unregister_vein", "unregister_veins_atomic", "get_registered_ids", "to_save_dict", "restore_save_dict", "get_last_atomic_registration_report", "has_pending_atomic_registration_recovery", "recover_last_atomic_registration"]:
		if not candidate.has_method(method_name):
			return false
	if _chunk_load_recovery_required and registry != candidate:
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
	if _chunk_load_recovery_required and crop_controller != candidate:
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
	if _chunk_load_recovery_required and object_state_registry != candidate:
		return false
	if not _chunk_roots.is_empty() and object_state_registry != candidate:
		return false
	object_state_registry = candidate
	return true

## Accepts an instantiated, unparented chunk root. Mineral and crop local IDs are
## derived from node names/hierarchy; registry records persist after the scene unloads.
func get_last_chunk_load_report() -> Dictionary:
	return _last_chunk_load_report.duplicate(true)

func has_pending_chunk_load_recovery() -> bool:
	return (
		_chunk_load_recovery_required
		or (
			registry != null
			and is_instance_valid(registry)
			and registry.has_method("has_pending_atomic_registration_recovery")
			and bool(registry.call("has_pending_atomic_registration_recovery"))
		)
	)

func recover_failed_chunk_load() -> bool:
	if registry != null and is_instance_valid(registry) and registry.has_method("has_pending_atomic_registration_recovery") and bool(registry.call("has_pending_atomic_registration_recovery")):
		_chunk_load_recovery_required = true
		_pending_chunk_load_recovery["mineral_registry"] = registry
		_pending_chunk_load_recovery["mineral_recovery_required"] = true
	if not _chunk_load_recovery_required:
		return true
	var pending: Dictionary = _pending_chunk_load_recovery
	var crop_ok: bool = true
	var pending_crop_controller: Node = pending.get("crop_controller") as Node
	var crop_snapshot: Dictionary = pending.get("crop_snapshot", {})
	var crop_plots: Dictionary = pending.get("crop_plots", {})
	if not crop_snapshot.is_empty():
		if not is_instance_valid(pending_crop_controller) or crop_controller != pending_crop_controller:
			crop_ok = false
		else:
			crop_ok = _restore_crop_snapshot(crop_snapshot, crop_plots)

	var initial_object_states: Dictionary = pending.get("initial_object_states", {})
	var live_objects_ok: bool = _restore_live_world_object_snapshot(initial_object_states, true)
	var object_registry_ok: bool = true
	var pending_object_registry: Node = pending.get("object_state_registry") as Node
	var object_snapshot: Dictionary = pending.get("object_registry_snapshot", {})
	if not object_snapshot.is_empty():
		if not is_instance_valid(pending_object_registry) or object_state_registry != pending_object_registry:
			object_registry_ok = false
		else:
			object_registry_ok = bool(object_state_registry.call("restore_save_dict", object_snapshot))

	var terrain_ok: bool = true
	if bool(pending.get("refresh_terrain", false)):
		terrain_ok = refresh_terrain_adjacency()
	var mineral_ok: bool = true
	if bool(pending.get("mineral_recovery_required", false)):
		var pending_mineral_registry: Node = pending.get("mineral_registry") as Node
		if not is_instance_valid(pending_mineral_registry) or registry != pending_mineral_registry or not registry.has_method("recover_last_atomic_registration"):
			mineral_ok = false
		else:
			mineral_ok = bool(registry.call("recover_last_atomic_registration"))
	var rollback_complete: bool = crop_ok and live_objects_ok and object_registry_ok and terrain_ok and mineral_ok
	if rollback_complete:
		_chunk_load_recovery_required = false
		_pending_chunk_load_recovery.clear()
	_set_chunk_load_report(
		rollback_complete,
		"recovery_complete" if rollback_complete else "recovery_incomplete",
		"" if rollback_complete else "One or more chunk-load participants still require recovery.",
		rollback_complete,
		{
			"crop_registry_ok": crop_ok,
			"world_object_live_nodes_ok": live_objects_ok,
			"world_object_registry_ok": object_registry_ok,
			"terrain_adjacency_ok": terrain_ok,
			"mineral_registry_ok": mineral_ok
		}
	)
	return rollback_complete

func load_chunk(chunk_id: String, chunk_root: Node3D, now_unix: int = -1) -> bool:
	_set_chunk_load_report(false, "validation", "preflight_rejected", true)
	if registry != null and is_instance_valid(registry) and registry.has_method("has_pending_atomic_registration_recovery") and bool(registry.call("has_pending_atomic_registration_recovery")):
		_chunk_load_recovery_required = true
		_pending_chunk_load_recovery["mineral_registry"] = registry
		_pending_chunk_load_recovery["mineral_recovery_required"] = true
	if _chunk_load_recovery_required:
		_set_chunk_load_report(false, "recovery_required", "Recover the previous failed chunk-load transaction before loading or unloading more chunks.", false, {"recovery_required": true})
		return false
	if registry == null or adapter == null or not is_instance_valid(chunk_root) or chunk_root.is_queued_for_deletion():
		return false
	if not _ensure_terrain_adjacency_ready():
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
		if not vein.has_method("begin_chunk_load_restore") or not vein.has_method("end_chunk_load_restore") or not vein.has_method("is_chunk_load_restore_pending") or bool(vein.call("is_chunk_load_restore_pending")):
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
			var crop_rollback_ok: bool = _restore_crop_snapshot(crop_snapshot, crops)
			if not crop_rollback_ok:
				_queue_chunk_load_recovery(crop_snapshot, crops, {}, {}, false)
			_set_chunk_load_report(false, "crop_catch_up", str(catch_up.get("reason", "catch_up_failed")), crop_rollback_ok, {"crop_registry_rollback_ok": crop_rollback_ok})
			return false
	for local_path in crops.keys():
		var stable_id := _make_crop_stable_id(chunk_id, str(local_path))
		var plot: Node = crops[local_path]
		if not bool(plot.call("configure", crop_controller, stable_id, str(plot.get("crop_id")), int(plot.get("plot_index")))):
			var crop_rollback_ok: bool = _restore_crop_snapshot(crop_snapshot, crops)
			if not crop_rollback_ok:
				_queue_chunk_load_recovery(crop_snapshot, crops, {}, {}, false)
			_set_chunk_load_report(false, "crop_binding", "A crop plot rejected its chunk binding.", crop_rollback_ok, {"crop_registry_rollback_ok": crop_rollback_ok})
			return false

	var object_registry_snapshot: Dictionary = {}
	var initial_object_states: Dictionary = {}
	if not world_objects.is_empty():
		object_registry_snapshot = object_state_registry.call("to_save_dict")
		if not object_registry_snapshot.has("schema_version") or not object_registry_snapshot.has("objects"):
			var crop_rollback_ok: bool = _restore_crop_snapshot(crop_snapshot, crops)
			if not crop_rollback_ok:
				_queue_chunk_load_recovery(crop_snapshot, crops, {}, {}, false)
			_set_chunk_load_report(false, "object_registry_snapshot", "The world-object registry returned an invalid snapshot.", crop_rollback_ok, {"crop_registry_rollback_ok": crop_rollback_ok})
			return false

	# Defer MineralMiningNode._ready() regeneration until the Registry transaction
	# has prepared every participant at the caller-supplied timestamp.
	for vein_value in veins.values():
		var vein_node: Node = vein_value as Node
		vein_node.call("begin_chunk_load_restore")
	add_child(chunk_root)
	var object_restore_result: Dictionary = {"ok": true, "rollback": {"ok": true, "live_nodes_ok": true, "registry_ok": true}}
	if not world_objects.is_empty():
		object_restore_result = _restore_world_object_nodes(chunk_id, world_objects, object_registry_snapshot, initial_object_states)
	if not bool(object_restore_result.get("ok", false)):
		remove_child(chunk_root)
		_end_chunk_load_restore(veins)
		var object_rollback: Dictionary = object_restore_result.get("rollback", {})
		var crop_rollback_ok: bool = _restore_crop_snapshot(crop_snapshot, crops)
		var world_live_rollback_ok: bool = bool(object_rollback.get("live_nodes_ok", false))
		var world_registry_rollback_ok: bool = bool(object_rollback.get("registry_ok", false))
		var rollback_complete: bool = world_live_rollback_ok and world_registry_rollback_ok and crop_rollback_ok
		if not rollback_complete:
			_queue_chunk_load_recovery(crop_snapshot, crops, object_registry_snapshot, initial_object_states, false)
		_set_chunk_load_report(false, "world_object_restore", str(object_restore_result.get("error", "object_restore_failed")), rollback_complete, {
			"world_object_live_nodes_ok": world_live_rollback_ok,
			"world_object_registry_ok": world_registry_rollback_ok,
			"crop_registry_ok": crop_rollback_ok
		})
		return false
	var existing_terrain_patches: Array[Node3D] = _collect_loaded_terrain_patches()
	var candidate_terrain_patches: Array[Node3D] = _collect_terrain_patches(world_objects)
	var all_terrain_patches: Array[Node3D] = existing_terrain_patches.duplicate()
	all_terrain_patches.append_array(candidate_terrain_patches)
	var adjacency_result: Dictionary = _rebind_terrain_patches(all_terrain_patches, chunk_id, world_objects)
	if not bool(adjacency_result.get("ok", false)):
		remove_child(chunk_root)
		_end_chunk_load_restore(veins)
		var object_rollback: Dictionary = {"ok": true, "live_nodes_ok": true, "registry_ok": true}
		if not world_objects.is_empty():
			object_rollback = _rollback_world_object_restore(initial_object_states, object_registry_snapshot)
		var crop_rollback_ok: bool = _restore_crop_snapshot(crop_snapshot, crops)
		var terrain_restore: Dictionary = _rebind_terrain_patches(existing_terrain_patches)
		var terrain_rollback_ok: bool = bool(terrain_restore.get("ok", false))
		var rollback_complete: bool = bool(object_rollback.get("ok", false)) and crop_rollback_ok and terrain_rollback_ok
		if not rollback_complete:
			_queue_chunk_load_recovery(crop_snapshot, crops, object_registry_snapshot, initial_object_states, true)
		_set_chunk_load_report(false, "terrain_adjacency", str(adjacency_result.get("error", "terrain_rebind_failed")), rollback_complete, {
			"world_object_live_nodes_ok": bool(object_rollback.get("live_nodes_ok", false)),
			"world_object_registry_ok": bool(object_rollback.get("registry_ok", false)),
			"crop_registry_ok": crop_rollback_ok,
			"terrain_adjacency_ok": terrain_rollback_ok
		})
		return false
	if not veins.is_empty() and not bool(adapter.load_chunk(chunk_id, veins, now_unix)):
		# A failed registration must not consume the caller's scene. Detach it so the
		# generator can inspect, repair, or retry the same root without reconstructing it.
		remove_child(chunk_root)
		_end_chunk_load_restore(veins)
		var object_rollback: Dictionary = {"ok": true, "live_nodes_ok": true, "registry_ok": true}
		if not world_objects.is_empty():
			object_rollback = _rollback_world_object_restore(initial_object_states, object_registry_snapshot)
		var crop_rollback_ok: bool = _restore_crop_snapshot(crop_snapshot, crops)
		var terrain_restore: Dictionary = _rebind_terrain_patches(existing_terrain_patches)
		var terrain_rollback_ok: bool = bool(terrain_restore.get("ok", false))
		var mineral_report: Dictionary = registry.call("get_last_atomic_registration_report")
		var mineral_rollback_ok: bool = bool(mineral_report.get("rollback_complete", true))
		var mineral_recovery_required: bool = bool(mineral_report.get("recovery_required", false))
		var rollback_complete: bool = bool(object_rollback.get("ok", false)) and crop_rollback_ok and terrain_rollback_ok and mineral_rollback_ok
		if not rollback_complete:
			_queue_chunk_load_recovery(crop_snapshot, crops, object_registry_snapshot, initial_object_states, true, mineral_recovery_required)
		_set_chunk_load_report(false, "mineral_registration", "Atomic mineral registration rejected the candidate chunk.", rollback_complete, {
			"world_object_live_nodes_ok": bool(object_rollback.get("live_nodes_ok", false)),
			"world_object_registry_ok": bool(object_rollback.get("registry_ok", false)),
			"crop_registry_ok": crop_rollback_ok,
			"terrain_adjacency_ok": terrain_rollback_ok,
			"mineral_registry_rollback_ok": mineral_rollback_ok,
			"mineral_registry_recovery_required": mineral_recovery_required,
			"mineral_registry_report": mineral_report
		})
		return false

	_end_chunk_load_restore(veins)
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
	_set_chunk_load_report(true, "complete", "", true, {"chunk_id": chunk_id, "mineral_count": veins.size(), "crop_count": crops.size(), "world_object_count": world_objects.size()})
	return true

func _end_chunk_load_restore(veins: Dictionary) -> void:
	for vein_value in veins.values():
		var vein_node: Node = vein_value as Node
		if is_instance_valid(vein_node) and vein_node.has_method("end_chunk_load_restore"):
			vein_node.call("end_chunk_load_restore")

## Captures mineral state before freeing a chunk. Crop records remain in CropRegistry;
## the next root with the same chunk ID reuses the same stable crop IDs.
func unload_chunk(chunk_id: String, now_unix: int = -1) -> bool:
	if registry != null and is_instance_valid(registry) and registry.has_method("has_pending_atomic_registration_recovery") and bool(registry.call("has_pending_atomic_registration_recovery")):
		_chunk_load_recovery_required = true
		_pending_chunk_load_recovery["mineral_registry"] = registry
		_pending_chunk_load_recovery["mineral_recovery_required"] = true
	if _chunk_load_recovery_required:
		return false
	if registry == null or not _chunk_roots.has(chunk_id):
		return false
	var chunk_root: Node3D = _chunk_roots[chunk_id] as Node3D
	if not is_instance_valid(chunk_root):
		return false
	if not _ensure_terrain_adjacency_ready():
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
	# Keep the departing root alive until the remaining terrain set has rebound successfully.
	# Temporarily remove only its patch ownership so the Binder can clear reciprocal edges
	# without freeing the old patch Nodes before the adjacency commit is known to succeed.
	var departing_objects: Dictionary = _chunk_objects.get(chunk_id, {}).duplicate()
	_chunk_objects.erase(chunk_id)
	var adjacency_result: Dictionary = _rebind_terrain_patches(_collect_loaded_terrain_patches())
	if not bool(adjacency_result.get("ok", false)):
		_chunk_objects[chunk_id] = departing_objects
		if not object_snapshot.is_empty() and not bool(object_state_registry.call("restore_save_dict", object_snapshot)):
			push_error("Failed to restore world-object registry after terrain adjacency unload preflight failed.")
		# A non-mutating Binder preflight rejection already preserved the previous live
		# adjacency, so do not rebuild it again. Failures after mutation need a full restore.
		var live_state_mutated: bool = bool(adjacency_result.get("live_state_mutated", true))
		if live_state_mutated and not refresh_terrain_adjacency():
			_terrain_adjacency_recovery_required = true
		return false

	if not veins.is_empty() and not bool(adapter.unload_chunk(chunk_id, now_unix)):
		_chunk_objects[chunk_id] = departing_objects
		if not object_snapshot.is_empty() and not bool(object_state_registry.call("restore_save_dict", object_snapshot)):
			push_error("Failed to restore world-object registry after mineral unload failed.")
		if not refresh_terrain_adjacency():
			_terrain_adjacency_recovery_required = true
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

func _restore_live_world_object_snapshot(states: Dictionary, allow_missing_nodes: bool = false) -> bool:
	var success: bool = true
	for stable_id in states.keys():
		var entry: Dictionary = states[stable_id]
		var node: Node = entry.get("node") as Node
		if not is_instance_valid(node):
			if allow_missing_nodes:
				continue
			success = false
			continue
		if not node.has_method("apply_world_object_state") or not bool(node.call("apply_world_object_state", entry.get("state", {}))):
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

func _collect_loaded_terrain_patches() -> Array[Node3D]:
	var patches: Array[Node3D] = []
	for chunk_objects in _chunk_objects.values():
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

func has_pending_terrain_adjacency_recovery() -> bool:
	return _terrain_adjacency_recovery_required

func _ensure_terrain_adjacency_ready() -> bool:
	if not _terrain_adjacency_recovery_required:
		return true
	return refresh_terrain_adjacency()

func refresh_terrain_adjacency() -> bool:
	var result: Dictionary = _rebind_terrain_patches(_collect_loaded_terrain_patches())
	var succeeded: bool = bool(result.get("ok", false))
	_terrain_adjacency_recovery_required = not succeeded
	return succeeded

func _on_terrain_patch_state_changed(_patch: Node3D) -> void:
	var result: Dictionary = _rebind_terrain_patches(_collect_loaded_terrain_patches())
	if not bool(result.get("ok", false)):
		push_error("Terrain transition descriptor rebuild failed after terrain edit: %s" % str(result.get("error", "unknown")))

func _rebind_terrain_patches(patches: Array[Node3D], candidate_chunk_id: String = "", candidate_objects: Dictionary = {}) -> Dictionary:
	var stable_ids_by_instance: Dictionary = {}
	var patches_by_stable_id: Dictionary = {}
	for chunk_objects in _chunk_objects.values():
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
	var result: Dictionary = TerrainAdjacencyBinderScript.bind_patches(patches, stable_ids_by_instance)
	if not bool(result.get("ok", false)):
		# Binder preflight failures occur before live edges change. Preserve the previous
		# descriptor/collider state in that case; clear derived resources only when the
		# Binder reports that it already mutated live patch edges.
		if bool(result.get("live_state_mutated", true)):
			if is_instance_valid(_terrain_transition_collider_manager):
				_terrain_transition_collider_manager.call("clear_all")
			_terrain_transition_descriptors.clear()
		_terrain_adjacency_recovery_required = true
		return result
	if not _ensure_transition_collider_manager():
		_terrain_adjacency_recovery_required = true
		return {"ok": false, "error": "transition_manager_unavailable"}
	var transition_result: Dictionary = _terrain_transition_collider_manager.call(
		"sync_transitions",
		result.get("descriptors", {}),
		patches_by_stable_id
	)
	if not bool(transition_result.get("ok", false)):
		_terrain_adjacency_recovery_required = true
		return {"ok": false, "error": "transition_collider_sync_failed:" + str(transition_result.get("error", "unknown"))}
	_terrain_transition_descriptors = result.get("descriptors", {}).duplicate(true)
	_terrain_adjacency_recovery_required = false
	result["transition_collider_count"] = int(transition_result.get("active_count", 0))
	result["blocked_transition_count"] = int(transition_result.get("blocked_count", 0))
	return result

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

func _restore_world_object_nodes(chunk_id: String, objects: Dictionary, registry_snapshot: Dictionary, initial_states: Dictionary) -> Dictionary:
	var defaults: Dictionary = {}
	for local_path in objects.keys():
		var stable_id: String = _make_world_object_stable_id(chunk_id, str(local_path))
		var node: Node = objects[local_path] as Node
		if not _valid_world_object_stable_id(stable_id) or not is_instance_valid(node) or not node.has_method("get_world_object_state") or not node.has_method("apply_world_object_state"):
			return {"ok": false, "error": "invalid_world_object_node", "rollback": _rollback_world_object_restore(initial_states, registry_snapshot)}
		var current_state: Variant = node.call("get_world_object_state")
		if not (current_state is Dictionary):
			return {"ok": false, "error": "invalid_initial_world_object_state", "rollback": _rollback_world_object_restore(initial_states, registry_snapshot)}
		initial_states[stable_id] = {"node": node, "state": current_state.duplicate(true)}
		var saved_record: Dictionary = object_state_registry.call("get_object_state", stable_id)
		if saved_record.is_empty():
			defaults[stable_id] = current_state.duplicate(true)
			continue
		if str(saved_record.get("chunk_id", "")) != chunk_id or not (saved_record.get("state", {}) is Dictionary) or (node.has_method("validate_world_object_state") and not bool(node.call("validate_world_object_state", saved_record.get("state", {})))) or not bool(node.call("apply_world_object_state", saved_record.get("state", {}))):
			return {"ok": false, "error": "saved_world_object_state_rejected", "rollback": _rollback_world_object_restore(initial_states, registry_snapshot)}
	for stable_id in defaults.keys():
		if not bool(object_state_registry.call("set_object_state", str(stable_id), chunk_id, defaults[stable_id])):
			return {"ok": false, "error": "world_object_default_registration_failed", "rollback": _rollback_world_object_restore(initial_states, registry_snapshot)}
	return {"ok": true, "rollback": {"ok": true, "live_nodes_ok": true, "registry_ok": true}}

func _rollback_world_object_restore(initial_states: Dictionary, registry_snapshot: Dictionary) -> Dictionary:
	var live_nodes_ok: bool = _restore_live_world_object_snapshot(initial_states)
	var registry_ok: bool = true
	if object_state_registry != null and not registry_snapshot.is_empty():
		registry_ok = bool(object_state_registry.call("restore_save_dict", registry_snapshot))
		if not registry_ok:
			push_error("Failed to restore world-object registry snapshot after chunk object-state failure.")
	return {"ok": live_nodes_ok and registry_ok, "live_nodes_ok": live_nodes_ok, "registry_ok": registry_ok}

func _restore_crop_snapshot(snapshot: Dictionary, plots: Dictionary) -> bool:
	if snapshot.is_empty():
		return true
	if crop_controller == null or not is_instance_valid(crop_controller) or not crop_controller.has_method("restore_save_dict"):
		return false
	var restored: bool = bool(crop_controller.call("restore_save_dict", snapshot))
	if restored:
		for plot_value in plots.values():
			var plot_node: Node = plot_value as Node
			if is_instance_valid(plot_node) and plot_node.has_method("refresh"):
				plot_node.call("refresh")
	return restored

func _queue_chunk_load_recovery(
	crop_snapshot: Dictionary,
	crop_plots: Dictionary,
	object_registry_snapshot: Dictionary,
	initial_object_states: Dictionary,
	refresh_terrain: bool,
	mineral_recovery_required: bool = false
) -> void:
	_chunk_load_recovery_required = true
	_pending_chunk_load_recovery = {
		"crop_controller": crop_controller,
		"crop_snapshot": crop_snapshot.duplicate(true),
		"crop_plots": crop_plots.duplicate(),
		"object_state_registry": object_state_registry,
		"object_registry_snapshot": object_registry_snapshot.duplicate(true),
		"initial_object_states": initial_object_states.duplicate(true),
		"refresh_terrain": refresh_terrain,
		"mineral_registry": registry,
		"mineral_recovery_required": mineral_recovery_required
	}

func _set_chunk_load_report(success: bool, phase: String, error: String, rollback_complete: bool, details: Dictionary = {}) -> void:
	_last_chunk_load_report = {
		"success": success,
		"phase": phase,
		"error": error,
		"rollback_complete": rollback_complete,
		"recovery_required": _chunk_load_recovery_required,
		"details": details.duplicate(true)
	}

func _make_world_object_stable_id(chunk_id: String, local_path: String) -> String:
	return chunk_id + "/object/" + local_path

func _valid_world_object_stable_id(stable_id: String) -> bool:
	return not stable_id.is_empty() and stable_id.length() <= 192 and not stable_id.contains("\n") and not stable_id.contains("\r") and not stable_id.contains("//") and not stable_id.contains("..")

func _make_crop_stable_id(chunk_id: String, local_path: String) -> String:
	return chunk_id + "/crop/" + local_path

func _valid_crop_stable_id(stable_id: String) -> bool:
	return not stable_id.is_empty() and stable_id == stable_id.strip_edges() and stable_id.length() <= 160 and stable_id.find("/") > 0 and not stable_id.contains(" ") and not stable_id.contains("\t") and not stable_id.contains("\n") and not stable_id.contains("..") and not stable_id.contains("//")

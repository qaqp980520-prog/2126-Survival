extends Node3D
class_name WorldSessionController

## Shared world-session composition root for streamed world prototypes.
## Owns registry/bridge/controller lifetime and the schema-1 save/restore transaction.
const RegistryScript = preload("res://systems/MineralVeinRegistry.gd")
const ControllerScript = preload("res://systems/MineralChunkController.gd")
const DirectorScript = preload("res://systems/MineralGridStreamingDirector.gd")
const InventoryBridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const CropRegistryScript = preload("res://systems/CropRegistry.gd")
const CropPlotControllerScript = preload("res://systems/CropPlotController.gd")
const InventoryModelScript = preload("res://systems/SurvivalInventory.gd")
const WORLD_CHUNK_SIZE: float = 10.0

var registry: Node
var chunk_controller: Node3D
var director: Node
var inventory_bridge: Node
var crop_registry: Node
var crop_controller: Node
var player: CharacterBody3D
var _stream_clock_unix: int = -1
var _last_grid: Vector2i = Vector2i(999999, 999999)
var _last_restore_report: Dictionary = {}
var _world_session_initialized: bool = false

## Initialize once after the scene enters the tree. The derived world supplies _make_chunk().
func initialize_world_session() -> bool:
	if _world_session_initialized:
		return true
	if not _build_streaming_stack():
		_cleanup_partial_world_session()
		return false
	_world_session_initialized = true
	return true

func _cleanup_partial_world_session() -> void:
	var owned_nodes: Array[Node] = [director, chunk_controller, inventory_bridge, crop_controller, crop_registry, registry]
	for node in owned_nodes:
		if node == null or not is_instance_valid(node):
			continue
		if node.get_parent() == self:
			remove_child(node)
		node.free()
	registry = null
	crop_registry = null
	crop_controller = null
	inventory_bridge = null
	chunk_controller = null
	director = null
	_world_session_initialized = false
	_last_grid = Vector2i(999999, 999999)

func _build_streaming_stack() -> bool:
	registry = RegistryScript.new()
	registry.name = "MineralVeinRegistry"
	add_child(registry)
	crop_registry = CropRegistryScript.new()
	crop_registry.name = "CropRegistry"
	add_child(crop_registry)
	crop_controller = CropPlotControllerScript.new()
	crop_controller.name = "CropPlotController"
	add_child(crop_controller)
	if not crop_controller.bind_registry(crop_registry):
		push_error("World session could not bind the crop registry.")
		return false
	inventory_bridge = InventoryBridgeScript.new()
	inventory_bridge.name = "SurvivalWorldBridge"
	add_child(inventory_bridge)
	chunk_controller = ControllerScript.new()
	chunk_controller.name = "MineralChunkController"
	add_child(chunk_controller)
	if not chunk_controller.bind_registry(registry):
		push_error("World session could not bind the mineral registry.")
		return false
	if not chunk_controller.bind_crop_controller(crop_controller):
		push_error("World session could not bind the crop controller.")
		return false
	director = DirectorScript.new()
	director.name = "MineralGridStreamingDirector"
	director.chunk_size_x = WORLD_CHUNK_SIZE
	director.chunk_size_z = WORLD_CHUNK_SIZE
	director.load_radius = 1
	add_child(director)
	if not director.bind_controller(chunk_controller) or not director.bind_chunk_factory(Callable(self, "_make_chunk")):
		push_error("World session could not bind the streaming director or chunk factory.")
		return false
	return true

func _sync_streaming(now_unix: int = -1) -> bool:
	if player == null or director == null:
		return false
	_stream_clock_unix = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var success: bool = director.sync_to_world_position(player.global_position, _stream_clock_unix)
	if success:
		_last_grid = director.get_grid_coordinate(player.global_position)
		_refresh_world_hud()
	return success

func debug_move_player_to(position: Vector3, now_unix: int = -1) -> bool:
	if player == null:
		return false
	player.global_position = position
	return _sync_streaming(now_unix)

func serialize_stream_state() -> Dictionary:
	if chunk_controller == null or player == null:
		return {}
	var payload: Dictionary = {
		"schema_version": 1,
		"player_position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"minerals": chunk_controller.to_save_dict(),
		"crops": crop_registry.to_save_dict() if crop_registry != null else {}
	}
	if inventory_bridge != null and inventory_bridge.has_method("serialize_inventory"):
		payload["inventory"] = inventory_bridge.call("serialize_inventory")
	return payload

func restore_stream_state(payload: Dictionary, now_unix: int = -1) -> bool:
	_set_restore_report(false, "validation", "Restore payload has not been accepted.", true)
	if player == null or chunk_controller == null or director == null:
		_set_restore_report(false, "validation", "Player, controller, or director is unavailable.", true)
		return false
	var schema_value: Variant = payload.get("schema_version", null)
	var position_value: Variant = payload.get("player_position", null)
	var minerals_value: Variant = payload.get("minerals", null)
	var has_crops: bool = payload.has("crops")
	var crops_value: Variant = payload.get("crops", null)
	var has_inventory: bool = payload.has("inventory")
	var inventory_value: Variant = payload.get("inventory", null)
	if not (schema_value is int) or int(schema_value) != 1:
		_set_restore_report(false, "validation", "Unsupported stream-save schema.", true)
		return false
	if not (position_value is Array) or position_value.size() != 3:
		_set_restore_report(false, "validation", "Player position must contain three components.", true)
		return false
	if not (minerals_value is Dictionary):
		_set_restore_report(false, "validation", "Mineral save payload must be a dictionary.", true)
		return false
	if has_crops and (crop_registry == null or not (crops_value is Dictionary) or not bool(crop_registry.validate_save_dict(crops_value))):
		_set_restore_report(false, "crop_validation", "Crop save payload is invalid; no world state was changed.", true)
		return false
	if has_inventory:
		if inventory_bridge == null or not (inventory_value is Dictionary):
			_set_restore_report(false, "inventory_validation", "Inventory save payload is invalid; no world state was changed.", true)
			return false
		var inventory_probe: Variant = InventoryModelScript.new()
		if not bool(inventory_probe.call("load_save_dict", inventory_value)):
			_set_restore_report(false, "inventory_validation", "Inventory save payload failed model validation; no world state was changed.", true)
			return false
	for component in position_value:
		if not (component is int or component is float) or not is_finite(float(component)):
			_set_restore_report(false, "validation", "Player position contains a non-finite component.", true)
			return false

	var now: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var previous_position: Vector3 = player.global_position
	var previous_minerals: Dictionary = chunk_controller.to_save_dict()
	var previous_crops: Dictionary = crop_registry.to_save_dict() if crop_registry != null else {}
	var previous_inventory: Dictionary = inventory_bridge.call("serialize_inventory") if inventory_bridge != null and inventory_bridge.has_method("serialize_inventory") else {}
	if not previous_minerals.has("schema_version") or not previous_minerals.has("veins"):
		_set_restore_report(false, "snapshot", "Could not snapshot the current mineral state before restore.", true)
		return false
	if has_inventory and (not previous_inventory.has("schema_version") or not previous_inventory.has("inventory")):
		_set_restore_report(false, "snapshot", "Could not snapshot the current inventory before restore.", true)
		return false
	if not chunk_controller.restore_save_dict(minerals_value, now):
		_set_restore_report(false, "mineral_restore", "Mineral registry rejected the candidate save.", true)
		return false
	if has_crops and not bool(crop_registry.restore_save_dict(crops_value)):
		var minerals_rolled_back: bool = chunk_controller.restore_save_dict(previous_minerals, now)
		_set_restore_report(false, "crop_restore", "Crop registry rejected the candidate save.", minerals_rolled_back)
		return false
	if has_inventory and not bool(inventory_bridge.call("restore_inventory", inventory_value)):
		var minerals_rolled_back_for_inventory: bool = chunk_controller.restore_save_dict(previous_minerals, now)
		var crops_rolled_back_for_inventory: bool = crop_registry == null or previous_crops.is_empty() or bool(crop_registry.restore_save_dict(previous_crops))
		if chunk_controller.has_method("refresh_crop_plots"):
			chunk_controller.refresh_crop_plots()
		_set_restore_report(false, "inventory_restore", "Inventory bridge rejected the candidate save.", minerals_rolled_back_for_inventory and crops_rolled_back_for_inventory)
		return false
	if chunk_controller.has_method("refresh_crop_plots"):
		chunk_controller.refresh_crop_plots()

	player.global_position = Vector3(float(position_value[0]), float(position_value[1]), float(position_value[2]))
	_last_grid = Vector2i(999999, 999999)
	if _sync_streaming(now):
		if chunk_controller.has_method("refresh_crop_plots"):
			chunk_controller.refresh_crop_plots()
		_set_restore_report(true, "complete", "", true, {
			"active_chunk_ids": chunk_controller.get_loaded_chunk_ids()
		})
		return true

	# A failed target stream must not leave the candidate mineral payload applied.
	# Reconcile the old chunk window first, then restore the exact pre-attempt mineral snapshot.
	var target_sync_report: Dictionary = director.get_last_sync_report()
	player.global_position = previous_position
	_last_grid = Vector2i(999999, 999999)
	var recovery_success: bool = false
	if director.has_method("recover_to_world_position"):
		recovery_success = bool(director.recover_to_world_position(previous_position, now))
	else:
		recovery_success = _sync_streaming(now)
	var recovery_report: Dictionary = director.get_last_sync_report()
	if recovery_success:
		_last_grid = director.get_grid_coordinate(previous_position)

	var minerals_restored: bool = chunk_controller.restore_save_dict(previous_minerals, now)
	var crops_restored: bool = crop_registry == null or previous_crops.is_empty() or bool(crop_registry.restore_save_dict(previous_crops))
	var inventory_restored: bool = true
	if has_inventory and inventory_bridge != null and not previous_inventory.is_empty():
		inventory_restored = bool(inventory_bridge.call("restore_inventory", previous_inventory))
	if chunk_controller.has_method("refresh_crop_plots"):
		chunk_controller.refresh_crop_plots()
	var ids_consistent: bool = director.get_managed_chunk_ids() == chunk_controller.get_loaded_chunk_ids()
	var position_restored: bool = player.global_position.is_equal_approx(previous_position)
	var rollback_complete: bool = recovery_success and minerals_restored and crops_restored and inventory_restored and ids_consistent and position_restored
	_refresh_world_hud()
	_set_restore_report(false, "stream_sync", "Target stream sync failed; rollback status is reported in details.", rollback_complete, {
		"target_sync_report": target_sync_report,
		"recovery_report": recovery_report,
		"recovery_success": recovery_success,
		"minerals_restored": minerals_restored,
		"crops_restored": crops_restored,
		"inventory_restored": inventory_restored,
		"ids_consistent": ids_consistent,
		"position_restored": position_restored
	})
	if not rollback_complete:
		push_warning("Surface stream restore rollback was incomplete; inspect get_last_restore_report().")
	return false

func get_last_restore_report() -> Dictionary:
	return _last_restore_report.duplicate(true)

func _set_restore_report(success: bool, phase: String, message: String, rollback_complete: bool, details: Dictionary = {}) -> void:
	_last_restore_report = {
		"success": success,
		"phase": phase,
		"message": message,
		"rollback_complete": rollback_complete,
		"details": details.duplicate(true)
	}

func _refresh_world_hud() -> void:
	if has_method("_refresh_hud"):
		call("_refresh_hud")

## Stable status snapshot for HUD, diagnostics and save/load acceptance tests.
func get_world_session_status() -> Dictionary:
	var inventory_summary: Dictionary = inventory_bridge.call("get_summary") if inventory_bridge != null and inventory_bridge.has_method("get_summary") else {}
	var active_ids: PackedStringArray = chunk_controller.get_loaded_chunk_ids() if chunk_controller != null and chunk_controller.has_method("get_loaded_chunk_ids") else PackedStringArray()
	var vein_count: int = registry.get_saved_ids().size() if registry != null and registry.has_method("get_saved_ids") else 0
	var crop_count: int = crop_registry.get_saved_ids().size() if crop_registry != null and crop_registry.has_method("get_saved_ids") else 0
	var position_value: Array = [player.global_position.x, player.global_position.y, player.global_position.z] if player != null else []
	return {
		"ready": _world_session_initialized and registry != null and chunk_controller != null and director != null and crop_registry != null and crop_controller != null,
		"active_chunk_ids": active_ids,
		"saved_vein_count": vein_count,
		"saved_crop_count": crop_count,
		"inventory": inventory_summary,
		"player_position": position_value
	}

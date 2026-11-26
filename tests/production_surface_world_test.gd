extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const ORIGIN_CHUNK_ID: String = "surface/chunk_0_0"

class PendingRegistryPairDirector extends Node:
	var pending: bool = true

	func has_pending_registry_pair_recovery() -> bool:
		return pending

	func get_pending_registry_pair_recovery_report() -> Dictionary:
		return {"recovery_required": pending, "reason": "injected_pair_recovery", "chunk_ids": ["underground/test_chunk"]}
var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "surface world scene instantiates")
	if world == null:
		_finish(1)
		return
	root.add_child(world)
	await process_frame
	_expect(bool(world.call("initialize_world_session")), "surface world initializes shared session")
	var diagnostics_panel: Control = world.find_child("StreamingDiagnosticsPanel", true, false) as Control
	_expect(diagnostics_panel != null, "surface world embeds the streaming diagnostics panel")
	if diagnostics_panel != null:
		_expect(not diagnostics_panel.visible, "streaming diagnostics panel starts hidden")
		diagnostics_panel.call("toggle_open")
		_expect(diagnostics_panel.visible, "streaming diagnostics panel opens through its toggle API")
		diagnostics_panel.call("toggle_open")
		_expect(not diagnostics_panel.visible, "streaming diagnostics panel closes through its toggle API")
	var status: Dictionary = world.call("get_world_session_status")
	_expect(bool(status.get("ready", false)), "surface world reports ready")
	var ids: PackedStringArray = status.get("active_chunk_ids", PackedStringArray())
	_expect(ids.size() == 18, "surface world loads nine surface chunks plus a nine-chunk underground mine window")
	_expect(ids.has("underground/mine_0_0"), "active chunk IDs include the persistent underground mine")
	_expect(int(status.get("saved_vein_count", 0)) == 36, "nine surface veins plus twenty-seven underground mine veins are registered")
	_expect(world.chunk_controller.is_chunk_loaded("underground/mine_0_0"), "dedicated underground mine chunk loads with the playable surface world")
	var surface_crate_count: int = 0
	var terrain_patch_count: int = 0
	var underground_cache_count: int = 0
	var underground_lift_count: int = 0
	for prop in world.chunk_controller.get_loaded_world_state_nodes():
		if not is_instance_valid(prop):
			continue
		if prop.name == "MineLiftAnchor":
			underground_lift_count += 1
		elif str(prop.name).begins_with("TerrainPatch"):
			terrain_patch_count += 1
			_expect(prop.has_method("get_world_object_state"), "surface terrain patch participates in the world-object state contract")
		elif prop.global_position.y < -7.0:
			if str(prop.name).begins_with("MineCache_"):
				underground_cache_count += 1
		else:
			if str(prop.name).begins_with("SalvageCrate"):
				surface_crate_count += 1
	_expect(surface_crate_count == 9, "nine surface chunks retain one stable salvage crate each")
	_expect(terrain_patch_count == 63, "nine loaded surface chunks register seven persistent terrain patches each")
	_expect(underground_cache_count == 7, "nine-room underground window contributes two origin caches and five regional caches")
	_expect(underground_lift_count == 1, "origin underground chunk registers one stateful lift anchor")
	_expect(int(status.get("saved_world_object_count", 0)) == 80, "world-object registry counts nine crates, sixty-three terrain patches, seven underground caches and one mine lift")
	var initial_plots: Array[Node3D] = world.chunk_controller.get_loaded_crop_plots()
	_expect(initial_plots.size() == 18, "two crop plot visuals are bound per loaded chunk")
	_expect(int(status.get("saved_crop_count", 0)) == 0, "empty plots are not prematurely written as planted crop records")
	var origin: Node3D = world.chunk_controller.get_chunk_root(ORIGIN_CHUNK_ID)
	var crate: Node = origin.get_node_or_null("SalvageCrate") if origin != null else null
	_expect(crate != null, "origin chunk creates a salvage crate")
	if crate == null:
		_finish(1)
		return
	_expect(origin.get_node_or_null("Ground") != null, "shared factory creates a collidable ground body")
	_expect(origin.get_node_or_null("Ore_0_0") != null, "shared factory creates the mineral node")
	_expect(origin.get_node_or_null("CropPlot_0") != null and origin.get_node_or_null("CropPlot_1") != null, "shared factory creates both crop plots")
	var original_id: int = crate.get_instance_id()
	var item_id: String = str(crate.get("loot_item_id"))
	var crate_position: Vector3 = crate.global_position
	var near_crate: Vector3 = crate_position + Vector3(0.0, 1.0, 2.0)
	world.player.global_position = near_crate
	world.camera.look_at(crate_position + Vector3(0.0, 0.55, 0.0), Vector3.UP)
	await physics_frame
	await physics_frame
	var now: int = int(Time.get_unix_time_from_system())
	var first: Dictionary = world.call("_interact_nearest_world_prop", now)
	_expect(bool(first.get("ok", false)), "salvage interaction grants an item through the shared inventory bridge")
	_expect(_inventory_count(item_id) == 1, "first interaction adds exactly one item")
	var save_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not save_payload.is_empty() and save_payload.has("world_objects") and save_payload.has("inventory"), "save contains world objects and inventory")
	_expect(bool(world.call("debug_move_player_to", Vector3(21.0, 2.0, 1.0), now + 1)), "moving away advances the chunk window")
	await process_frame
	_expect(not world.chunk_controller.is_chunk_loaded(ORIGIN_CHUNK_ID), "origin chunk unloads outside the radius")
	_expect(bool(world.call("debug_move_player_to", near_crate, now + 2)), "returning to origin reloads the chunk")
	await process_frame
	world.camera.look_at(crate_position + Vector3(0.0, 0.55, 0.0), Vector3.UP)
	await physics_frame
	await physics_frame
	var restored_root: Node3D = world.chunk_controller.get_chunk_root(ORIGIN_CHUNK_ID)
	var restored_crate: Node = restored_root.get_node_or_null("SalvageCrate") if restored_root != null else null
	_expect(restored_crate != null, "factory recreates the crate")
	if restored_crate == null:
		_finish(1)
		return
	_expect(restored_crate.get_instance_id() != original_id, "reloaded crate is a fresh node instance")
	_expect(str(restored_crate.get("loot_item_id")) == item_id and int(restored_crate.get("loot_remaining")) == 1, "reloaded crate restores identity and remaining count")
	_expect(_inventory_count(item_id) == 1, "reload does not duplicate inventory")
	var second: Dictionary = world.call("_interact_nearest_world_prop", now + 3)
	_expect(bool(second.get("ok", false)) and int(second.get("remaining", -1)) == 0, "reloaded crate grants its final unit")
	_expect(_inventory_count(item_id) == 2, "second interaction increments inventory once")
	_expect(bool(world.call("restore_stream_state", save_payload, now + 4)), "world restores the saved snapshot")
	var save_root: Node3D = world.chunk_controller.get_chunk_root(ORIGIN_CHUNK_ID)
	var save_crate: Node = save_root.get_node_or_null("SalvageCrate") if save_root != null else null
	_expect(save_crate != null and int(save_crate.get("loot_remaining")) == 1, "save restore reapplies crate state")
	_expect(_inventory_count(item_id) == 1, "save restore rolls inventory back to the matching count")
	var plots: Array[Node3D] = world.chunk_controller.get_loaded_crop_plots()
	_expect(not plots.is_empty(), "surface world exposes loaded crop plots")
	if not plots.is_empty():
		var crop_approach_position: Vector3 = plots[0].global_position + Vector3(0.0, 1.0, 2.0)
		_expect(bool(world.call("debug_move_player_to", crop_approach_position, now + 5)), "test setup synchronously prepares the crop interaction chunk window")
		world.camera.look_at(plots[0].global_position + Vector3(0.0, 0.9, 0.0), Vector3.UP)
		await physics_frame
		await physics_frame
		var crop_result: Dictionary = world.call("_interact_nearest_crop_plot", now + 5)
		_expect(bool(crop_result.get("ok", false)), "E interaction plants or advances a crop")
	var buttons: Dictionary = world.get("touch_buttons")
	_expect(buttons.has("forward") and buttons.has("jump") and buttons.has("crop") and buttons.has("crate") and buttons.has("shaft"), "HUD exposes touch movement, mining and mine-shaft controls")
	var directions: Dictionary = world.get("_touch_directions")
	buttons["forward"].emit_signal("button_down")
	_expect(directions.has("forward"), "touch button activates virtual forward input")
	buttons["forward"].emit_signal("button_up")
	_expect(not directions.has("forward"), "touch release clears virtual input")
	_test_world_save_recovery_gate(save_payload, now + 6)
	_finish(0 if failures.is_empty() else 1)

func _test_world_save_recovery_gate(save_payload: Dictionary, now_unix: int) -> void:
	var previous_mine_director: Node = world.get("mine_director") as Node
	var barrier_director := PendingRegistryPairDirector.new()
	root.add_child(barrier_director)
	world.set("mine_director", barrier_director)

	var live_crate: Node = null
	for candidate in world.chunk_controller.get_loaded_world_state_nodes():
		if is_instance_valid(candidate) and str(candidate.name).begins_with("SalvageCrate"):
			live_crate = candidate
			break
	_expect(live_crate != null, "save-gate fixture finds a loaded stateful crate")
	if live_crate != null:
		var live_state: Variant = live_crate.call("get_world_object_state")
		if live_state is Dictionary:
			var changed_state: Dictionary = live_state.duplicate(true)
			changed_state["opened"] = not bool(changed_state.get("opened", false))
			if changed_state.has("loot_remaining"):
				changed_state["loot_remaining"] = maxi(0, int(changed_state.get("loot_remaining", 0)) - 1)
			_expect(bool(live_crate.call("apply_world_object_state", changed_state)), "save-gate fixture creates an unsaved live object-state change")
		else:
			_expect(false, "save-gate fixture reads a valid live object-state dictionary")

	var before_minerals: Dictionary = world.chunk_controller.call("to_save_dict")
	var before_crops: Dictionary = world.crop_registry.call("to_save_dict")
	var before_objects: Dictionary = world.object_state_registry.call("to_save_dict")
	var before_inventory: Dictionary = world.inventory_bridge.call("serialize_inventory")
	var before_position: Vector3 = world.player.global_position
	var before_seed: int = int(world.get("world_seed"))
	var before_ids: PackedStringArray = world.chunk_controller.get_loaded_chunk_ids()

	var blocked_save: Dictionary = world.call("serialize_stream_state")
	_expect(blocked_save.is_empty(), "world serialization is refused while Registry-pair recovery is pending")
	_expect(world.object_state_registry.call("to_save_dict") == before_objects, "blocked save does not capture or mutate live world-object records")
	_expect(world.chunk_controller.call("to_save_dict") == before_minerals, "blocked save preserves mineral records")
	_expect(world.crop_registry.call("to_save_dict") == before_crops, "blocked save preserves crop records")
	_expect(world.inventory_bridge.call("serialize_inventory") == before_inventory, "blocked save preserves inventory")

	var blocked_restore_payload: Dictionary = save_payload.duplicate(true)
	blocked_restore_payload["world_seed"] = before_seed + 1
	_expect(not bool(world.call("restore_stream_state", blocked_restore_payload, now_unix)), "world restore is refused before any streaming or seed mutation")
	var restore_report: Dictionary = world.call("get_last_restore_report")
	_expect(str(restore_report.get("phase", "")) == "registry_pair_recovery_barrier" and not bool(restore_report.get("rollback_complete", true)), "blocked restore exposes the pending pair barrier and incomplete status")
	_expect(world.chunk_controller.call("to_save_dict") == before_minerals, "blocked restore preserves mineral records")
	_expect(world.crop_registry.call("to_save_dict") == before_crops, "blocked restore preserves crop records")
	_expect(world.object_state_registry.call("to_save_dict") == before_objects, "blocked restore preserves world-object records")
	_expect(world.inventory_bridge.call("serialize_inventory") == before_inventory, "blocked restore preserves inventory")
	_expect(world.player.global_position.is_equal_approx(before_position) and int(world.get("world_seed")) == before_seed, "blocked restore preserves player position and world seed")
	_expect(world.chunk_controller.get_loaded_chunk_ids() == before_ids, "blocked restore does not alter the active chunk window")

	world.set("mine_director", previous_mine_director)
	barrier_director.queue_free()
	var resumed_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not resumed_payload.is_empty(), "world serialization resumes after the original Director is restored")

	var missing_api_director := Node.new()
	root.add_child(missing_api_director)
	world.set("mine_director", missing_api_director)
	var missing_api_payload: Dictionary = world.call("serialize_stream_state")
	_expect(missing_api_payload.is_empty(), "save capture fails closed when the underground Director lacks the recovery API")
	world.set("mine_director", previous_mine_director)
	missing_api_director.queue_free()

func _inventory_count(item_id: String) -> int:
	var payload: Dictionary = world.inventory_bridge.call("serialize_inventory")
	var counts: Dictionary = payload.get("inventory", {})
	return int(counts.get(item_id, 0))

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish(exit_code: int) -> void:
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("Production surface world integration tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

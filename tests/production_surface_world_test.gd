extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const ORIGIN_CHUNK_ID: String = "surface/chunk_0_0"

class FailOnceStamina extends RefCounted:
	var current_stamina: float = 100.0
	var _payload: Dictionary = {}
	var _fail_next_load: bool = true

	func _init(initial_payload: Dictionary) -> void:
		_payload = initial_payload.duplicate(true)
		current_stamina = float(_payload.get("current", 100.0))

	func to_save_dict() -> Dictionary:
		return _payload.duplicate(true)

	func load_save_dict(data: Dictionary) -> bool:
		_payload = data.duplicate(true)
		current_stamina = float(_payload.get("current", 100.0))
		if _fail_next_load:
			_fail_next_load = false
			return false
		return true

	func can_jump() -> bool:
		return current_stamina >= 10.0

	func can_sprint() -> bool:
		return current_stamina >= 5.0

	func get_movement_speed_multiplier(_sprinting: bool = false) -> float:
		return 1.0 if current_stamina > 0.0 else 0.65

	func get_max_stamina() -> float:
		return 100.0


class FailOnceQuickUse extends RefCounted:
	var slots: Array[String] = []
	var selected_slot: int = 0
	var _fail_next_load: bool = true

	func _init(initial_payload: Dictionary) -> void:
		_apply_payload(initial_payload)

	func _apply_payload(data: Dictionary) -> void:
		slots.clear()
		for item_id in data.get("slots", []):
			slots.append(str(item_id))
		selected_slot = int(data.get("selected_slot", 0))

	func to_save_dict() -> Dictionary:
		return {
			"schema_version": 1,
			"slots": slots.duplicate(),
			"selected_slot": selected_slot
		}

	func load_save_dict(data: Dictionary) -> bool:
		_apply_payload(data)
		if _fail_next_load:
			_fail_next_load = false
			return false
		return true

	func get_slot_item(slot_index: int) -> String:
		if slot_index < 0 or slot_index >= slots.size():
			return ""
		return slots[slot_index]

	func get_slot_count(slot_index: int, inventory_bridge: Node) -> int:
		var item_id: String = get_slot_item(slot_index)
		if item_id.is_empty() or inventory_bridge == null or not inventory_bridge.has_method("get_item_count"):
			return 0
		return int(inventory_bridge.call("get_item_count", item_id))


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
	_expect(world.player != null, "surface world creates its production player")
	if world.player != null:
		_expect(world.player.is_in_group("player"), "production player joins the shared player group used by world-transition triggers")
	_expect(bool(world.call("initialize_world_session")), "surface world initializes shared session")
	var diagnostics_panel: Control = world.find_child("StreamingDiagnosticsPanel", true, false) as Control
	_expect(diagnostics_panel != null, "surface world embeds the streaming diagnostics panel")
	if diagnostics_panel != null:
		_expect(not diagnostics_panel.visible, "streaming diagnostics panel starts hidden")
		diagnostics_panel.call("toggle_open")
		_expect(diagnostics_panel.visible, "streaming diagnostics panel opens through its toggle API")
		diagnostics_panel.call("toggle_open")
		_expect(not diagnostics_panel.visible, "streaming diagnostics panel closes through its toggle API")
	var loaded_window: Rect2 = world.call("get_loaded_surface_window_bounds")
	_expect(loaded_window == Rect2(-10.0, -10.0, 30.0, 30.0), "portal spawn bounds exactly match the loaded 3x3 surface chunk window")
	var owned_backrooms_director: RefCounted = world.get("backrooms_portal_director") as RefCounted
	_expect(owned_backrooms_director != null, "SurfaceWorld owns a world-seeded Backrooms portal director")
	if owned_backrooms_director != null:
		_expect(owned_backrooms_director.get("world_bounds") == loaded_window, "owned portal director starts with the current loaded surface window")
		_expect(int(world.get("_backrooms_portal_world_seed")) == int(world.get("world_seed")), "owned portal director seed identity matches the production world seed")
	var backrooms_director: RefCounted = world.call("create_backrooms_portal_director") as RefCounted
	_expect(backrooms_director != null, "production SurfaceWorld creates a Backrooms portal director configured for its loaded window")
	if backrooms_director != null:
		_expect(backrooms_director.get("world_bounds") == loaded_window, "portal director uses the exact loaded SurfaceWorld bounds")
		_expect(is_equal_approx(float(backrooms_director.get("min_player_distance")), float(world.get("backrooms_portal_safe_distance"))), "portal director uses the exported player-safe distance")
		_expect(is_equal_approx(float(backrooms_director.get("spawn_padding")), float(world.get("backrooms_portal_spawn_padding"))), "portal director uses the exported loaded-window edge margin")
		backrooms_director.set("next_spawn_in", 0.01)
		var portal_spawn: Dictionary = backrooms_director.call("tick", 0.02, Vector2(world.player.global_position.x, world.player.global_position.z))
		_expect(str(portal_spawn.get("event", "")) == "spawned", "configured production loaded window can produce a portal candidate")
		if str(portal_spawn.get("event", "")) == "spawned":
			var portal_position: Vector2 = portal_spawn["portal"]["position"]
			var safe_distance: float = float(world.get("backrooms_portal_safe_distance"))
			var padding: float = float(world.get("backrooms_portal_spawn_padding"))
			_expect(loaded_window.has_point(portal_position), "portal candidate stays inside currently loaded surface chunks")
			_expect(portal_position.x >= loaded_window.position.x + padding and portal_position.x <= loaded_window.end.x - padding, "portal candidate respects loaded-window X edge margin")
			_expect(portal_position.y >= loaded_window.position.y + padding and portal_position.y <= loaded_window.end.y - padding, "portal candidate respects loaded-window Z edge margin")
			_expect(portal_position.distance_to(Vector2(world.player.global_position.x, world.player.global_position.z)) >= safe_distance, "portal candidate respects the player-safe distance")
		var director_bounds_before_rejection: Rect2 = backrooms_director.get("world_bounds")
		world.set("_surface_stream_pending", true)
		_expect(not bool(world.call("configure_backrooms_portal_director", backrooms_director)), "portal spawn-window configuration is blocked while surface streaming is pending")
		_expect(backrooms_director.get("world_bounds") == director_bounds_before_rejection, "a blocked stream-time reconfiguration leaves the director window unchanged")
		world.set("_surface_stream_pending", false)
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
	if owned_backrooms_director != null:
		owned_backrooms_director.set("next_spawn_in", 0.01)
		var owned_portal_spawn: Dictionary = owned_backrooms_director.call("tick", 0.02, Vector2(world.player.global_position.x, world.player.global_position.z))
		_expect(str(owned_portal_spawn.get("event", "")) == "spawned", "SurfaceWorld-owned portal director can produce a deterministic active portal")
	var save_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not save_payload.is_empty() and save_payload.has("world_objects") and save_payload.has("inventory"), "save contains world objects and inventory")
	var saved_portal_wrapper: Dictionary = save_payload.get("backrooms_portal", {})
	var saved_portal_director: Dictionary = saved_portal_wrapper.get("director", {})
	_expect(int(saved_portal_wrapper.get("schema_version", -1)) == 1 and int(saved_portal_wrapper.get("world_seed", -1)) == int(world.get("world_seed")), "world save binds Backrooms portal state to the same schema and world seed")
	_expect(owned_backrooms_director != null and saved_portal_director == owned_backrooms_director.call("to_save_dict"), "world save captures the complete owned portal director state")
	var saved_active_portal: Dictionary = saved_portal_director.get("active_portal", {})
	_expect(not saved_active_portal.is_empty(), "world save preserves the active one-use portal and its original spawn window")
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
	if owned_backrooms_director != null and not saved_active_portal.is_empty():
		var saved_portal_id: int = int(saved_active_portal["id"])
		var consumed_portal: Dictionary = owned_backrooms_director.call("consume_portal", saved_portal_id)
		_expect(bool(consumed_portal.get("ok", false)), "test diverges the live portal director before restoring the saved snapshot")
	_expect(bool(world.call("restore_stream_state", save_payload, now + 4)), "world restores the saved snapshot")
	var restored_backrooms_director: RefCounted = world.get("backrooms_portal_director") as RefCounted
	_expect(restored_backrooms_director != null and restored_backrooms_director.call("to_save_dict") == saved_portal_director, "world restore reinstates the exact portal RNG, countdown, serial and active portal state")
	var save_root: Node3D = world.chunk_controller.get_chunk_root(ORIGIN_CHUNK_ID)
	var save_crate: Node = save_root.get_node_or_null("SalvageCrate") if save_root != null else null
	_expect(save_crate != null and int(save_crate.get("loot_remaining")) == 1, "save restore reapplies crate state")
	_expect(_inventory_count(item_id) == 1, "save restore rolls inventory back to the matching count")
	var portal_state_before_invalid_restore: Dictionary = restored_backrooms_director.call("to_save_dict") if restored_backrooms_director != null else {}
	var world_seed_before_invalid_restore: int = int(world.get("world_seed"))
	var position_before_invalid_restore: Vector3 = world.player.global_position
	var invalid_portal_save: Dictionary = save_payload.duplicate(true)
	var invalid_portal_wrapper_value: Variant = invalid_portal_save.get("backrooms_portal", {})
	var invalid_portal_wrapper: Dictionary = invalid_portal_wrapper_value.duplicate(true) if invalid_portal_wrapper_value is Dictionary else {}
	invalid_portal_wrapper["world_seed"] = world_seed_before_invalid_restore + 1
	invalid_portal_save["backrooms_portal"] = invalid_portal_wrapper
	_expect(not bool(world.call("restore_stream_state", invalid_portal_save, now + 5)), "portal state bound to a different world seed is rejected before restore mutation")
	_expect(int(world.get("world_seed")) == world_seed_before_invalid_restore and world.player.global_position == position_before_invalid_restore, "mismatched portal seed rejection preserves world seed and player position")
	var director_after_invalid_restore: RefCounted = world.get("backrooms_portal_director") as RefCounted
	_expect(director_after_invalid_restore != null and director_after_invalid_restore.call("to_save_dict") == portal_state_before_invalid_restore, "mismatched portal seed rejection preserves the live director payload")
	var legacy_portal_save: Dictionary = save_payload.duplicate(true)
	legacy_portal_save.erase("backrooms_portal")
	_expect(bool(world.call("restore_stream_state", legacy_portal_save, now + 6)), "legacy schema-1 world saves without Backrooms portal state remain loadable")
	var legacy_portal_director: RefCounted = world.get("backrooms_portal_director") as RefCounted
	var legacy_portal_state: Dictionary = legacy_portal_director.call("to_save_dict") if legacy_portal_director != null else {}
	var legacy_active_portal: Dictionary = legacy_portal_state.get("active_portal", {})
	_expect(legacy_portal_director != null and legacy_active_portal.is_empty(), "legacy restore initializes a fresh portal director instead of inheriting stale active portals")
	_test_auxiliary_restore_rollback(now + 6)
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
	_finish(0 if failures.is_empty() else 1)

func _test_auxiliary_restore_rollback(now: int) -> void:
	var baseline_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not baseline_payload.is_empty(), "auxiliary rollback test captures a complete SurfaceWorld snapshot")
	if baseline_payload.is_empty():
		return
	var baseline_position: Array = baseline_payload.get("player_position", [])
	var baseline_ids: Array = Array(world.chunk_controller.get_loaded_chunk_ids())
	baseline_ids.sort()
	var baseline_world_seed: int = int(baseline_payload.get("world_seed", -1))
	_expect(baseline_world_seed >= 0 and baseline_world_seed < 2147483647, "auxiliary rollback baseline has a valid incrementable world seed")
	var baseline_mine_ids: Array = Array(world.mine_director.call("get_managed_chunk_ids"))
	baseline_mine_ids.sort()
	var original_stamina: RefCounted = world.stamina
	var original_quick_use: RefCounted = world.quick_use
	var baseline_stamina: Dictionary = original_stamina.call("to_save_dict")
	var baseline_quick_use: Dictionary = original_quick_use.call("to_save_dict")

	var stamina_candidate: Dictionary = baseline_payload.duplicate(true)
	stamina_candidate["player_position"] = [21.0, 2.0, 1.0]
	stamina_candidate["world_seed"] = baseline_world_seed + 1
	stamina_candidate.erase("backrooms_portal")
	var changed_stamina: Dictionary = baseline_stamina.duplicate(true)
	changed_stamina["current"] = 25.0
	stamina_candidate["stamina"] = changed_stamina
	var failing_stamina := FailOnceStamina.new(baseline_stamina)
	world.stamina = failing_stamina
	var stamina_result: bool = bool(world.call("restore_stream_state", stamina_candidate, now))
	var stamina_report: Dictionary = world.call("get_last_restore_report")
	_expect(not stamina_result, "SurfaceWorld rejects an auxiliary stamina apply that fails after base world restore")
	_expect(failing_stamina.to_save_dict() == baseline_stamina, "stamina state partially applied before failure is restored from its snapshot")
	_expect(str(stamina_report.get("phase", "")) == "stamina_restore" and bool(stamina_report.get("rollback_complete", false)), "stamina failure reports a complete cross-system rollback")
	var stamina_rollback_details: Dictionary = stamina_report.get("details", {})
	_expect(bool(stamina_rollback_details.get("minerals_restored", false)) and bool(stamina_rollback_details.get("world_objects_restored", false)), "stamina failure restores exact mineral and world-object snapshots after streaming")
	_expect(bool(stamina_rollback_details.get("mine_window_restored", false)) and bool(stamina_rollback_details.get("layer_state_restored", false)) and bool(stamina_rollback_details.get("mine_chunk_ready_restored", false)), "stamina failure restores the previous mine window and world seed after a seed-changing candidate")
	world.stamina = original_stamina
	_expect_world_snapshot_restored(baseline_payload, baseline_position, baseline_ids, "stamina failure")
	_expect_mine_window_restored(baseline_mine_ids, "stamina failure")

	var quick_use_candidate: Dictionary = baseline_payload.duplicate(true)
	quick_use_candidate["player_position"] = [21.0, 2.0, 1.0]
	quick_use_candidate["world_seed"] = baseline_world_seed + 1
	quick_use_candidate.erase("backrooms_portal")
	var changed_quick_use: Dictionary = baseline_quick_use.duplicate(true)
	changed_quick_use["selected_slot"] = 2
	quick_use_candidate["quick_use"] = changed_quick_use
	var failing_quick_use := FailOnceQuickUse.new(baseline_quick_use)
	world.quick_use = failing_quick_use
	var quick_use_result: bool = bool(world.call("restore_stream_state", quick_use_candidate, now))
	var quick_use_report: Dictionary = world.call("get_last_restore_report")
	_expect(not quick_use_result, "SurfaceWorld rejects an auxiliary quick-use apply that fails after stamina and base restore")
	_expect(failing_quick_use.to_save_dict() == baseline_quick_use, "quick-use state partially applied before failure is restored from its snapshot")
	_expect(str(quick_use_report.get("phase", "")) == "quick_use_restore" and bool(quick_use_report.get("rollback_complete", false)), "quick-use failure reports a complete cross-system rollback")
	var quick_use_rollback_details: Dictionary = quick_use_report.get("details", {})
	_expect(bool(quick_use_rollback_details.get("minerals_restored", false)) and bool(quick_use_rollback_details.get("world_objects_restored", false)), "quick-use failure restores exact mineral and world-object snapshots after streaming")
	_expect(bool(quick_use_rollback_details.get("mine_window_restored", false)) and bool(quick_use_rollback_details.get("layer_state_restored", false)) and bool(quick_use_rollback_details.get("mine_chunk_ready_restored", false)), "quick-use failure restores the previous mine window and world seed after a seed-changing candidate")
	world.quick_use = original_quick_use
	_expect_world_snapshot_restored(baseline_payload, baseline_position, baseline_ids, "quick-use failure")
	_expect_mine_window_restored(baseline_mine_ids, "quick-use failure")


func _expect_world_snapshot_restored(
	baseline_payload: Dictionary,
	baseline_position: Array,
	baseline_ids: Array,
	failure_phase: String
) -> void:
	var current_payload: Dictionary = world.call("serialize_stream_state")
	var current_ids: Array = Array(world.chunk_controller.get_loaded_chunk_ids())
	current_ids.sort()
	_expect(current_payload.get("player_position", []) == baseline_position, "%s rollback restores the exact player position" % failure_phase)
	_expect(current_ids == baseline_ids, "%s rollback restores the exact streamed chunk set" % failure_phase)
	_expect(current_payload.get("minerals", {}) == baseline_payload.get("minerals", {}), "%s rollback restores mineral registry state" % failure_phase)
	_expect(current_payload.get("crops", {}) == baseline_payload.get("crops", {}), "%s rollback restores crop registry state" % failure_phase)
	_expect(current_payload.get("world_objects", {}) == baseline_payload.get("world_objects", {}), "%s rollback restores world-object registry state" % failure_phase)
	_expect(current_payload.get("inventory", {}) == baseline_payload.get("inventory", {}), "%s rollback restores inventory bridge state" % failure_phase)
	_expect(current_payload.get("stamina", {}) == baseline_payload.get("stamina", {}), "%s rollback restores stamina state" % failure_phase)
	_expect(current_payload.get("quick_use", {}) == baseline_payload.get("quick_use", {}), "%s rollback restores quick-use state" % failure_phase)
	_expect(current_payload.get("world_seed", -1) == baseline_payload.get("world_seed", -2), "%s rollback restores the exact world seed" % failure_phase)
	_expect(current_payload.get("location_layer", "") == baseline_payload.get("location_layer", ""), "%s rollback restores the exact location layer" % failure_phase)
	_expect(current_payload.get("mine_depth", -1) == baseline_payload.get("mine_depth", -2), "%s rollback restores the exact mine depth" % failure_phase)
	_expect(current_payload.get("surface_return_position", []) == baseline_payload.get("surface_return_position", []), "%s rollback restores the exact surface return position" % failure_phase)
	_expect(current_payload.get("backrooms_portal", {}) == baseline_payload.get("backrooms_portal", {}), "%s rollback preserves the exact Backrooms portal director save state" % failure_phase)


func _expect_mine_window_restored(baseline_mine_ids: Array, failure_phase: String) -> void:
	var current_mine_ids: Array = Array(world.mine_director.call("get_managed_chunk_ids"))
	current_mine_ids.sort()
	_expect(current_mine_ids == baseline_mine_ids, "%s rollback restores the exact UndergroundMineDirector managed window" % failure_phase)
	_expect(world.chunk_controller.is_chunk_loaded("underground/mine_0_0"), "%s rollback restores the persistent mine origin chunk" % failure_phase)


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

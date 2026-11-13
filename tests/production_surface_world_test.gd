extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const BackroomsPortalDirectorScript = preload("res://systems/BackroomsPortalDirector.gd")
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
	var maze_runtime: Node3D = world.get("backrooms_maze_runtime") as Node3D
	_expect(maze_runtime != null and maze_runtime.get_parent() == world, "SurfaceWorld owns one Backrooms maze cell runtime")
	if maze_runtime != null:
		_expect(not maze_runtime.visible and not bool(maze_runtime.call("is_active")), "owned maze runtime starts hidden and inactive")
		_expect(int(maze_runtime.call("get_loaded_cell_count")) == 0, "SurfaceWorld does not generate a Backrooms map before a transition is prepared")
	var prepared_maze: Dictionary = world.call("prepare_backrooms_destination", "Level 1", 20261113, Vector3.ZERO)
	_expect(bool(prepared_maze.get("ok", false)), "SurfaceWorld can prepare a hidden Backrooms destination from a validated level and seed")
	_expect(maze_runtime != null and int(maze_runtime.call("get_loaded_cell_count")) == 9, "SurfaceWorld-owned runtime stages the initial nine-cell window")
	_expect(maze_runtime != null and not bool(maze_runtime.call("is_active")) and not maze_runtime.visible, "destination preparation does not expose or collide with the hidden maze")
	_expect(bool(world.call("activate_backrooms_destination")), "SurfaceWorld can explicitly activate a prepared maze destination")
	_expect(maze_runtime != null and bool(maze_runtime.call("is_active")) and maze_runtime.visible, "explicit activation reveals the prepared destination")
	_expect(bool(world.call("deactivate_backrooms_destination")), "SurfaceWorld can deactivate and retire the prepared maze destination")
	_expect(maze_runtime != null and int(maze_runtime.call("get_loaded_cell_count")) == 0, "deactivation clears all SurfaceWorld-owned maze cell roots")
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
	_expect(int(world.get("_backrooms_portal_world_seed")) == int(world.get("world_seed")), "owned portal director records the exact production world seed")
	var missing_window_chunk_id: String = "surface/chunk_1_1"
	var missing_window_chunk: Node3D = world.chunk_controller.get_chunk_root(missing_window_chunk_id)
	_expect(missing_window_chunk != null, "loaded-window completeness test finds its target surface chunk")
	if missing_window_chunk != null:
		var window_test_now: int = int(Time.get_unix_time_from_system())
		var window_chunk_unloaded: bool = world.chunk_controller.unload_chunk(missing_window_chunk_id, window_test_now)
		_expect(window_chunk_unloaded, "loaded-window completeness test can unload one managed surface chunk")
		if window_chunk_unloaded:
			_expect(world.call("get_loaded_surface_window_bounds") == Rect2(), "portal spawn bounds fail closed when any required surface chunk is absent")
			_expect(bool(world.call("_sync_streaming", window_test_now)), "surface streaming director reloads the missing managed chunk")
			_expect(world.call("get_loaded_surface_window_bounds") == loaded_window, "portal spawn bounds recover only after the complete 3x3 window is loaded again")
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
		world.set("_surface_stream_pending", true)
		_expect(world.call("serialize_stream_state") == {}, "SurfaceWorld refuses to serialize while asynchronous surface streaming is pending")
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
	_test_auxiliary_restore_rollback(now + 4)
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

	var portal_director: RefCounted = world.get("backrooms_portal_director") as RefCounted
	_expect(portal_director != null, "production SurfaceWorld owns a persistent Backrooms portal director")
	if portal_director != null:
		portal_director.set("next_spawn_in", 0.01)
		world.call("_process", 0.02)
		var portal_visual: Area3D = world.get("backrooms_portal_visual") as Area3D
		_expect(portal_visual != null, "live SurfaceWorld tick creates a portal interaction anchor")
		if portal_visual != null:
			_expect(portal_visual.is_in_group("backrooms_portal"), "production portal joins the camera interaction target group")
			_expect(int(portal_visual.get("portal_id")) > 0, "production portal visual receives the director's active ID")
			_expect(bool(portal_visual.get("activation_enabled")), "production portal unlocks only when SurfaceWorld owns the transition manager and maze runtime")
			_expect(not bool(portal_visual.call("interact", world.player)), "production portal still rejects an out-of-range player")
			_expect((portal_visual.collision_layer & (1 << 1)) != 0 and portal_visual.collision_mask == 1, "portal anchor uses the production interaction layer and world mask")
			if DisplayServer.get_name() == "headless":
				_expect(portal_visual.get_node_or_null("PortalRing") == null, "headless portal anchor avoids renderer-only mesh nodes")
		var portal_save_payload: Dictionary = world.call("serialize_stream_state")
		var portal_envelope: Dictionary = portal_save_payload.get("backrooms_portal_director", {})
		var portal_saved_state: Dictionary = portal_envelope.get("state", {})
		_expect(int(portal_envelope.get("schema_version", -1)) == 1, "portal RNG save envelope has an explicit schema version")
		_expect(int(portal_envelope.get("world_seed", -1)) == int(portal_save_payload.get("world_seed", -2)), "portal RNG save envelope is bound to the exact SurfaceWorld seed")
		var saved_active_portal: Dictionary = portal_saved_state.get("active_portal", {})
		_expect(not portal_saved_state.is_empty() and not saved_active_portal.is_empty(), "world save captures the active one-use portal and RNG state")
		var surface_return_position: Vector3 = world.player.global_position
		var surface_window_before_mine: Rect2 = world.call("get_loaded_surface_window_bounds")
		var mine_director: Node = world.get("mine_director") as Node
		var mine_floor_y: float = float(mine_director.call("get_layer_floor_y", 0)) if mine_director != null else -18.0
		var explored_mine_position := Vector3(41.0, mine_floor_y, 41.0)
		var moved_into_mine_window: bool = mine_director != null and bool(mine_director.call("sync_to_world_position", explored_mine_position, now + 10))
		_expect(moved_into_mine_window, "underground save regression prepares a mine window outside the loaded surface window")
		if moved_into_mine_window:
			world.set("_surface_return_position", surface_return_position)
			world.set("_is_underground", true)
			world.set("_mine_layer_index", 0)
			world.set("_last_mine_grid", mine_director.call("get_grid_coordinate", explored_mine_position))
			world.set("_last_mine_layer_index", 0)
			world.set("_mine_chunk_ready", world.chunk_controller.is_chunk_loaded("underground/mine_0_0"))
			world.player.global_position = explored_mine_position
			var underground_save_payload: Dictionary = world.call("serialize_stream_state")
			_expect(not underground_save_payload.is_empty(), "underground save validates the loaded surface window at the saved return position, not the distant mine player position")
			_expect(str(underground_save_payload.get("location_layer", "")) == "underground", "underground save preserves the current location layer")
			_expect(underground_save_payload.get("surface_return_position", []) == [surface_return_position.x, surface_return_position.y, surface_return_position.z], "underground save preserves the exact surface return position")
			var other_mine_position := Vector3(57.0, mine_floor_y, 57.0)
			var moved_to_other_mine_window: bool = bool(mine_director.call("sync_to_world_position", other_mine_position, now + 11))
			_expect(moved_to_other_mine_window, "underground restore regression moves the current mine window away from the saved mine window")
			if moved_to_other_mine_window:
				world.set("_last_mine_grid", mine_director.call("get_grid_coordinate", other_mine_position))
				world.set("_last_mine_layer_index", 0)
				world.set("_mine_chunk_ready", world.chunk_controller.is_chunk_loaded("underground/mine_0_0"))
				world.player.global_position = other_mine_position
				var underground_restore_success: bool = bool(world.call("restore_stream_state", underground_save_payload, now + 12))
				_expect(underground_restore_success, "underground save restores with the surface stream anchored to the saved return position")
				if underground_restore_success:
					_expect(world.player.global_position.is_equal_approx(explored_mine_position), "underground restore returns the player to the saved mine coordinates")
					_expect(bool(world.get("_is_underground")), "underground restore preserves the underground layer flag")
					var restored_return_position: Vector3 = world.get("_surface_return_position")
					_expect(restored_return_position.is_equal_approx(surface_return_position), "underground restore preserves the exact surface return position")
					_expect(world.call("get_loaded_surface_window_bounds_at", surface_return_position) == surface_window_before_mine, "underground restore keeps the real surface chunk window around the return position")
					_expect(world.call("get_loaded_surface_window_bounds") == surface_window_before_mine, "public loaded-surface bounds resolve from the return position while underground")
					_expect(world.get("backrooms_portal_visual") != null, "underground restore keeps the active portal anchor when its owning surface chunk remains loaded")
					_test_auxiliary_restore_rollback(now + 12)
					_test_underground_base_stream_failure_rollback(now + 12)
			_expect(bool(world.call("restore_stream_state", portal_save_payload, now + 13)), "surface save can be restored after the underground round-trip regression")
			portal_director = world.get("backrooms_portal_director") as RefCounted
		var live_director_state: Dictionary = portal_director.call("to_save_dict")
		var live_player_position: Vector3 = world.player.global_position
		var original_active_portal: Dictionary = portal_director.get("active_portal").duplicate(true)
		var stale_active_portal: Dictionary = original_active_portal.duplicate(true)
		stale_active_portal["position"] = Vector2(1000.0, 1000.0)
		stale_active_portal["spawn_bounds"] = Rect2(990.0, 990.0, 20.0, 20.0)
		portal_director.set("active_portal", stale_active_portal)
		_expect(world.call("serialize_stream_state") == {}, "world save fails closed when an active portal is outside the current loaded surface window")
		portal_director.set("active_portal", original_active_portal)
		var mismatched_world_seed: int = int(world.get("world_seed"))
		world.set("world_seed", mismatched_world_seed + 1)
		_expect(world.call("serialize_stream_state") == {}, "world save fails closed when the owned director seed identity differs from SurfaceWorld")
		world.set("world_seed", mismatched_world_seed)
		var wrong_seed_payload: Dictionary = portal_save_payload.duplicate(true)
		wrong_seed_payload["backrooms_portal_director"]["world_seed"] = int(portal_save_payload.get("world_seed", 0)) + 1
		_expect(not bool(world.call("restore_stream_state", wrong_seed_payload, now + 6)), "world restore rejects a portal RNG envelope from another world seed")
		_expect(portal_director.call("to_save_dict") == live_director_state and world.player.global_position == live_player_position, "wrong-seed portal payload is rejected without mutating the live world or director")
		var invalid_rng_payload: Dictionary = portal_save_payload.duplicate(true)
		invalid_rng_payload["backrooms_portal_director"]["state"]["rng_state"] = "invalid"
		_expect(not bool(world.call("restore_stream_state", invalid_rng_payload, now + 7)), "world restore rejects an invalid nested portal RNG state")
		_expect(portal_director.call("to_save_dict") == live_director_state, "invalid portal RNG payload leaves the live director snapshot unchanged")
		_expect(bool(world.call("_retire_backrooms_portal", "save_round_trip_test")), "test can retire the live portal through the director contract")
		_expect(world.get("backrooms_portal_visual") == null, "retiring a portal removes its production visual anchor")
		_expect(bool(world.call("restore_stream_state", portal_save_payload, now + 8)), "world restore reconstructs the saved Backrooms portal director state")
		var restored_portal_director: RefCounted = world.get("backrooms_portal_director") as RefCounted
		_expect(restored_portal_director != null, "successful restore installs a new portal director instance")
		if restored_portal_director != null:
			_expect(restored_portal_director.call("to_save_dict") == portal_saved_state, "restored director exactly preserves RNG, serial, timer and active portal")
			var restored_portal_visual: Area3D = world.get("backrooms_portal_visual") as Area3D
			_expect(restored_portal_visual != null and int(restored_portal_visual.get("portal_id")) == int(saved_active_portal.get("id", -1)), "restored active portal recreates its visual/interaction anchor")
			var original_portal_chunk_id: String = str(world.get("_backrooms_portal_chunk_id"))
			_expect(not original_portal_chunk_id.is_empty() and world.chunk_controller.is_chunk_loaded(original_portal_chunk_id), "active portal's owning surface chunk is currently loaded")
			var restored_portal_serial: int = int(restored_portal_director.get("portal_serial"))
			_expect(bool(world.call("debug_move_player_to", Vector3(100.0, 2.0, 100.0), now + 9)), "moving the player streams to a distant surface window")
			_expect(not world.chunk_controller.is_chunk_loaded(original_portal_chunk_id), "distant streaming unloads the portal's original owning chunk")
			var retired_active_portal: Dictionary = restored_portal_director.get("active_portal")
			_expect(retired_active_portal.is_empty(), "portal is retired when its owning chunk leaves the loaded window")
			_expect(world.get("backrooms_portal_visual") == null, "retired portal visual is removed after chunk unload")
			_expect(int(restored_portal_director.get("portal_serial")) == restored_portal_serial, "retirement preserves the portal serial for deterministic history")
			_expect(float(restored_portal_director.get("next_spawn_in")) >= BackroomsPortalDirectorScript.MIN_SPAWN_INTERVAL and float(restored_portal_director.get("next_spawn_in")) <= BackroomsPortalDirectorScript.MAX_SPAWN_INTERVAL, "retirement schedules a normal future spawn interval")
	var handoff_director: RefCounted = world.get("backrooms_portal_director") as RefCounted
	_expect(handoff_director != null, "production world retains the portal director for the real handoff test")
	if handoff_director != null:
		handoff_director.set("next_spawn_in", 0.01)
		world.call("_process", 0.02)
		var handoff_portal: Area3D = world.get("backrooms_portal_visual") as Area3D
		_expect(handoff_portal != null and bool(handoff_portal.get("activation_enabled")), "SurfaceWorld exposes an interactable portal after all transition dependencies are ready")
		if handoff_portal != null:
			var handoff_active: Dictionary = handoff_director.get("active_portal")
			var handoff_position: Vector2 = handoff_active.get("position", Vector2.ZERO)
			var handoff_approach: Vector3 = Vector3(handoff_position.x, 2.0, handoff_position.y + 2.0)
			_expect(bool(world.call("debug_move_player_to", handoff_approach, int(Time.get_unix_time_from_system()) + 20)), "test approach streams the production surface window around the portal before entry")
			handoff_portal = world.get("backrooms_portal_visual") as Area3D
			if handoff_portal == null:
				_expect(false, "active portal visual remains attached after the player streams to its owning chunk")
				_finish(1)
				return
			var surface_position_before_handoff: Vector3 = world.player.global_position
			var surface_ids_before_handoff: Array = Array(world.chunk_controller.get_loaded_chunk_ids())
			surface_ids_before_handoff.sort()
			var surface_bounds_before_handoff: Rect2 = world.call("get_loaded_surface_window_bounds")
			_expect(bool(handoff_portal.call("interact", world.player)), "the real portal interaction range accepts the nearby production player")
			var entry_result: Dictionary = world.call("enter_backrooms_from_portal", int(handoff_portal.get("portal_id")))
			_expect(bool(entry_result.get("ok", false)), "SurfaceWorld completes the validated player handoff into the Backrooms runtime")
			_expect(bool(world.get("_is_in_backrooms")), "SurfaceWorld switches its movement and streaming mode to Backrooms")
			_expect(world.player.global_position.y >= 1000.0, "the production player is moved into the isolated Backrooms runtime space")
			_expect(bool(world.backrooms_maze_runtime.call("is_active")) and world.backrooms_maze_runtime.visible, "the committed maze runtime is active and visible after player handoff")
			_expect(handoff_director.get("active_portal").is_empty(), "the one-use portal is consumed only after the destination is prepared")
			var surface_ids_during_backrooms: Array = Array(world.chunk_controller.get_loaded_chunk_ids())
			surface_ids_during_backrooms.sort()
			_expect(surface_ids_during_backrooms == surface_ids_before_handoff, "SurfaceWorld chunk streaming remains frozen while the player is in Backrooms")
			var backrooms_shifted_position: Vector3 = world.player.global_position + Vector3(8.0, 0.0, 0.0)
			var backrooms_shift_result: Dictionary = world.backrooms_transition_manager.call("sync_backrooms_runtime", world.backrooms_maze_runtime, backrooms_shifted_position)
			_expect(bool(backrooms_shift_result.get("ok", false)), "moving one maze cell synchronizes the runtime window and LocationSession transaction")
			world.player.global_position = backrooms_shifted_position
			world.set("_last_backrooms_sync_position", backrooms_shifted_position)
			var shifted_session_save: Dictionary = world.backrooms_transition_manager.call("get_session_save_dict")
			_expect(shifted_session_save.get("backrooms_position", []) == [backrooms_shifted_position.x, backrooms_shifted_position.y, backrooms_shifted_position.z], "Backrooms Session records the shifted production player position")
			_expect(shifted_session_save.get("maze_stream_state", {}) == world.backrooms_maze_runtime.call("to_save_dict"), "Backrooms Session and live maze runtime retain the exact same shifted window payload")
			_expect(int(world.backrooms_maze_runtime.call("get_loaded_cell_count")) == 9, "one-cell Backrooms movement retains a complete 3x3 maze window")
			_expect(world.call("get_loaded_surface_window_bounds") == surface_bounds_before_handoff, "SurfaceWorld loaded-window bounds remain anchored to the saved return position while the Backrooms player moves")
			_expect(world.call("serialize_stream_state") == {}, "SurfaceWorld refuses to write a surface-only save while Backrooms is active")
			var backrooms_position_before_restore: Vector3 = world.player.global_position
			var portal_timer_before_backrooms_tick: float = float(handoff_director.get("next_spawn_in"))
			world.call("_process", 10.0)
			_expect(is_equal_approx(float(handoff_director.get("next_spawn_in")), portal_timer_before_backrooms_tick), "portal spawn timer pauses while the player is in Backrooms")
			_expect(not bool(world.call("debug_move_player_to", Vector3.ZERO, int(Time.get_unix_time_from_system()) + 21)), "surface streaming debug moves are rejected while Backrooms is active")
			_expect(not bool(world.call("restore_stream_state", portal_save_payload, int(Time.get_unix_time_from_system()) + 22)), "surface-only restore is rejected while Backrooms is active")
			_expect(world.player.global_position.is_equal_approx(backrooms_position_before_restore) and bool(world.backrooms_maze_runtime.call("is_active")), "rejected surface restore leaves the live Backrooms player and runtime unchanged")
			var hidden_surface_root: Node3D = null
			for chunk_id_value in surface_ids_during_backrooms:
				var chunk_id: String = str(chunk_id_value)
				if chunk_id.begins_with("surface/"):
					hidden_surface_root = world.chunk_controller.get_chunk_root(chunk_id)
					break
			_expect(hidden_surface_root != null and not hidden_surface_root.visible, "loaded surface chunk visuals are hidden during the Backrooms handoff")
			var return_result: Dictionary = world.call("return_from_backrooms")
			_expect(bool(return_result.get("ok", false)), "SurfaceWorld restores the original surface position before retiring the Backrooms runtime")
			_expect(not bool(world.get("_is_in_backrooms")), "successful return restores SurfaceWorld movement and streaming mode")
			_expect(world.player.global_position.is_equal_approx(surface_position_before_handoff), "successful return restores the exact saved surface return position")
			_expect(not bool(world.backrooms_maze_runtime.call("is_prepared")) and int(world.backrooms_maze_runtime.call("get_loaded_cell_count")) == 0, "successful return retires every Backrooms maze cell root")
			_expect(handoff_director.get("active_portal").is_empty(), "consumed portal remains absent after a successful return")
			var surface_ids_after_return: Array = Array(world.chunk_controller.get_loaded_chunk_ids())
			surface_ids_after_return.sort()
			_expect(surface_ids_after_return == surface_ids_before_handoff, "return preserves the exact pre-entry SurfaceWorld chunk window")
			var restored_surface_root: Node3D = world.chunk_controller.get_chunk_root(str(surface_ids_before_handoff[0]))
			_expect(restored_surface_root != null and restored_surface_root.visible, "surface chunk visibility is restored after returning")
			var transition_session: Variant = world.backrooms_transition_manager.call("get_session")
			_expect(transition_session is Object and not bool(transition_session.call("is_active")), "successful return clears the Backrooms LocationSession only after SurfaceWorld restoration")
	_finish(0 if failures.is_empty() else 1)

func _test_underground_base_stream_failure_rollback(now: int) -> void:
	var baseline_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not baseline_payload.is_empty(), "underground base-stream failure test captures a complete snapshot")
	if baseline_payload.is_empty():
		return
	var baseline_crops_value: Variant = baseline_payload.get("crops", {})
	var baseline_crop_records: Dictionary = baseline_crops_value.get("crops", {}) if baseline_crops_value is Dictionary else {}
	_expect(not baseline_crop_records.is_empty(), "underground seed-change rollback baseline includes planted crop records")
	var baseline_position: Vector3 = world.player.global_position
	var baseline_return_position: Vector3 = world.get("_surface_return_position")
	var baseline_surface_bounds: Rect2 = world.call("get_loaded_surface_window_bounds")
	var baseline_world_seed: int = int(baseline_payload.get("world_seed", -1))
	var baseline_mine_ids: Array = Array(world.mine_director.call("get_managed_chunk_ids"))
	baseline_mine_ids.sort()
	var baseline_mine_origin_loaded: bool = baseline_mine_ids.has("underground/mine_0_0")
	var baseline_surface_ids: Array = Array(world.chunk_controller.get_loaded_chunk_ids())
	baseline_surface_ids.sort()
	var baseline_player_position: Array = baseline_payload.get("player_position", []).duplicate()
	var baseline_portal_state: Dictionary = world.backrooms_portal_director.call("to_save_dict")
	var baseline_director: RefCounted = world.backrooms_portal_director as RefCounted
	var baseline_director_seed: int = int(world.get("_backrooms_portal_world_seed"))
	var baseline_active_portal: Dictionary = baseline_portal_state.get("active_portal", {})
	var baseline_portal_id: int = int(baseline_active_portal.get("id", -1))
	var baseline_portal_position: Vector2 = Vector2.ZERO
	var baseline_portal_position_value: Variant = baseline_active_portal.get("position", [])
	if baseline_portal_position_value is Array and baseline_portal_position_value.size() == 2:
		baseline_portal_position = Vector2(float(baseline_portal_position_value[0]), float(baseline_portal_position_value[1]))
	_expect(baseline_director != null and baseline_portal_id > 0, "underground seed-change rollback baseline has an active production portal")
	var original_factory: Callable = world.director.chunk_factory
	var failure_state: Dictionary = {"remaining": 1, "world_seed_at_failure": -1}
	var failing_factory: Callable = func(coord: Vector2i) -> Node3D:
		if int(failure_state.get("remaining", 0)) > 0:
			failure_state["remaining"] = int(failure_state.get("remaining", 0)) - 1
			failure_state["world_seed_at_failure"] = int(world.get("world_seed"))
			return null
		return original_factory.call(coord) as Node3D
	var factory_bound: bool = bool(world.director.call("bind_chunk_factory", failing_factory))
	_expect(factory_bound, "underground base-stream failure test installs a one-shot surface chunk factory")
	if not factory_bound:
		return
	var candidate_payload: Dictionary = baseline_payload.duplicate(true)
	var candidate_world_seed: int = baseline_world_seed + 1 if baseline_world_seed < 2147483647 else baseline_world_seed - 1
	candidate_payload["backrooms_portal_director"] = _make_backrooms_portal_director_envelope(candidate_world_seed)
	candidate_payload["world_seed"] = candidate_world_seed
	_expect(candidate_world_seed != baseline_world_seed, "underground stream-failure candidate changes the world seed")
	var alternate_return_position := Vector3(61.0, 2.0, 61.0)
	candidate_payload["surface_return_position"] = [
		alternate_return_position.x,
		alternate_return_position.y,
		alternate_return_position.z
	]
	var restore_result: bool = bool(world.call("restore_stream_state", candidate_payload, now))
	world.director.call("bind_chunk_factory", original_factory)
	var restore_report: Dictionary = world.call("get_last_restore_report")
	_expect(not restore_result, "underground restore rejects the injected surface chunk-factory failure")
	_expect(int(failure_state.get("remaining", -1)) == 0, "base stream failure was actually injected before rollback")
	_expect(int(failure_state.get("world_seed_at_failure", -1)) == candidate_world_seed, "surface stream failure occurs after the candidate world seed and mine window are applied")
	_expect(str(restore_report.get("phase", "")) == "stream_sync" and bool(restore_report.get("rollback_complete", false)), "failed underground base stream reports a complete cross-layer rollback")
	var rollback_details: Dictionary = restore_report.get("details", {})
	_expect(bool(rollback_details.get("crops_restored", false)), "failed underground base stream reports exact crop snapshot restoration after final streaming")
	_expect_world_snapshot_restored(baseline_payload, baseline_player_position, baseline_surface_ids, "underground seed-change surface stream failure")
	_expect_mine_window_restored(baseline_mine_ids, "underground seed-change surface stream failure")
	_expect(world.player.global_position.is_equal_approx(baseline_position), "failed underground base stream restores the exact mine player position")
	_expect(bool(world.get("_is_underground")) and int(world.get("_mine_layer_index")) == 0, "failed underground base stream restores the exact mine layer")
	var restored_return_position: Vector3 = world.get("_surface_return_position")
	_expect(restored_return_position.is_equal_approx(baseline_return_position), "failed underground base stream restores the exact previous surface return position")
	_expect(world.call("get_loaded_surface_window_bounds") == baseline_surface_bounds, "failed underground base stream restores the previous surface chunk window")
	var restored_mine_ids: Array = Array(world.mine_director.call("get_managed_chunk_ids"))
	restored_mine_ids.sort()
	_expect(restored_mine_ids == baseline_mine_ids, "failed underground base stream restores the exact mine director window")
	_expect(int(world.get("world_seed")) == baseline_world_seed, "failed underground base stream restores the exact world seed")
	_expect(int(world.get("_backrooms_portal_world_seed")) == baseline_director_seed, "failed underground base stream restores the portal director seed identity")
	_expect(world.backrooms_portal_director == baseline_director, "failed underground base stream preserves the original portal director instance")
	_expect(world.backrooms_portal_director.call("to_save_dict") == baseline_portal_state, "failed underground base stream preserves the exact portal director state")
	_expect(world.chunk_controller.is_chunk_loaded(ORIGIN_CHUNK_ID), "failed underground base stream restores the origin surface chunk")
	_expect(world.chunk_controller.is_chunk_loaded("underground/mine_0_0") == baseline_mine_origin_loaded, "failed underground base stream restores the mine origin chunk's exact baseline loaded state")
	var restored_portal_visual: Area3D = world.get("backrooms_portal_visual") as Area3D
	_expect(restored_portal_visual != null and int(restored_portal_visual.get("portal_id")) == baseline_portal_id, "failed underground base stream recreates the same active portal ID")
	if restored_portal_visual != null:
		var restored_portal_position := Vector2(restored_portal_visual.global_position.x, restored_portal_visual.global_position.z)
		_expect(restored_portal_position.is_equal_approx(baseline_portal_position), "failed underground base stream restores the portal anchor to its exact surface position")


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
	var candidate_player_position := Vector3(21.0, 2.0, 1.0)
	if str(baseline_payload.get("location_layer", "surface")) == "underground" and baseline_position.size() == 3:
		candidate_player_position = Vector3(float(baseline_position[0]), float(baseline_position[1]), float(baseline_position[2])) + Vector3(16.0, 0.0, 16.0)
	var baseline_mine_ids: Array = Array(world.mine_director.call("get_managed_chunk_ids"))
	baseline_mine_ids.sort()
	var original_stamina: RefCounted = world.stamina
	var original_quick_use: RefCounted = world.quick_use
	var baseline_stamina: Dictionary = original_stamina.call("to_save_dict")
	var baseline_quick_use: Dictionary = original_quick_use.call("to_save_dict")
	var baseline_portal_director: Dictionary = world.backrooms_portal_director.call("to_save_dict")

	var stamina_candidate: Dictionary = baseline_payload.duplicate(true)
	stamina_candidate["player_position"] = [candidate_player_position.x, candidate_player_position.y, candidate_player_position.z]
	stamina_candidate["world_seed"] = baseline_world_seed + 1
	stamina_candidate["backrooms_portal_director"] = _make_backrooms_portal_director_envelope(baseline_world_seed + 1)
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
	_expect(world.backrooms_portal_director.call("to_save_dict") == baseline_portal_director, "stamina failure leaves the live portal RNG, serial, timer and active portal unchanged")

	var quick_use_candidate: Dictionary = baseline_payload.duplicate(true)
	quick_use_candidate["player_position"] = [candidate_player_position.x, candidate_player_position.y, candidate_player_position.z]
	quick_use_candidate["world_seed"] = baseline_world_seed + 1
	quick_use_candidate["backrooms_portal_director"] = _make_backrooms_portal_director_envelope(baseline_world_seed + 1)
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
	_expect(world.backrooms_portal_director.call("to_save_dict") == baseline_portal_director, "quick-use failure leaves the live portal RNG, serial, timer and active portal unchanged")


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
	var expected_surface_reference := Vector3.ZERO
	var saved_return_value: Variant = baseline_payload.get("surface_return_position", [])
	if str(baseline_payload.get("location_layer", "surface")) == "underground" and saved_return_value is Array and saved_return_value.size() == 3:
		expected_surface_reference = Vector3(float(saved_return_value[0]), float(saved_return_value[1]), float(saved_return_value[2]))
	elif baseline_position.size() == 3:
		expected_surface_reference = Vector3(float(baseline_position[0]), float(baseline_position[1]), float(baseline_position[2]))
	var expected_surface_bounds: Rect2 = world.call("get_loaded_surface_window_bounds_at", expected_surface_reference)
	_expect(expected_surface_bounds.size.x > 0.0 and expected_surface_bounds.size.y > 0.0, "%s rollback restores a valid loaded surface window at the correct surface reference position" % failure_phase)
	_expect(world.call("get_loaded_surface_window_bounds") == expected_surface_bounds, "%s rollback restores the public loaded-surface window reference" % failure_phase)
	_expect(current_payload.get("backrooms_portal_director", {}) == baseline_payload.get("backrooms_portal_director", {}), "%s rollback preserves the exact Backrooms portal envelope" % failure_phase)


func _expect_mine_window_restored(baseline_mine_ids: Array, failure_phase: String) -> void:
	var current_mine_ids: Array = Array(world.mine_director.call("get_managed_chunk_ids"))
	current_mine_ids.sort()
	_expect(current_mine_ids == baseline_mine_ids, "%s rollback restores the exact UndergroundMineDirector managed window" % failure_phase)
	var baseline_has_origin: bool = baseline_mine_ids.has("underground/mine_0_0")
	_expect(world.chunk_controller.is_chunk_loaded("underground/mine_0_0") == baseline_has_origin, "%s rollback restores the origin mine chunk's exact loaded state" % failure_phase)


func _make_backrooms_portal_director_envelope(seed_value: int) -> Dictionary:
	var candidate: RefCounted = BackroomsPortalDirectorScript.new(seed_value, Rect2(-500.0, -500.0, 1000.0, 1000.0), 8.0)
	assert(bool(candidate.call("set_spawn_window", Rect2(-10.0, -10.0, 30.0, 30.0), 8.0, 4.0)))
	return {
		"schema_version": 1,
		"world_seed": seed_value,
		"state": candidate.call("to_save_dict")
	}

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

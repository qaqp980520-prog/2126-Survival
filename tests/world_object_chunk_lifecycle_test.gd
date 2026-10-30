extends SceneTree

const PlaygroundScene = preload("res://prototypes/SurfaceChunkStreamingPlayground.tscn")
const ORIGIN_CHUNK_ID: String = "surface/chunk_0_0"
const CRATE_STABLE_ID: String = "surface/chunk_0_0/object/Chunk_0_0/SalvageCrate"

var failures: Array[String] = []
var _finished: bool = false
var watchdog: Timer
var playground: Node

func _initialize() -> void:
	watchdog = Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 35.0
	root.add_child(watchdog)
	watchdog.timeout.connect(_on_timeout)
	call_deferred("_start_watchdog")
	call_deferred("_run")


func _start_watchdog() -> void:
	if is_instance_valid(watchdog) and watchdog.is_inside_tree():
		watchdog.start()


func _run() -> void:
	playground = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	if playground == null or playground.chunk_controller == null or playground.object_state_registry == null or playground.inventory_bridge == null or playground.player == null:
		_expect(false, "surface streaming playground initializes the world-object stack")
		_finish(1)
		return

	var chunk_root: Node3D = playground.chunk_controller.get_chunk_root(ORIGIN_CHUNK_ID)
	var crate: Node = chunk_root.get_node_or_null("SalvageCrate") if chunk_root != null else null
	if crate == null:
		_expect(false, "origin chunk creates a real SalvageCrate instance")
		_finish(1)
		return
	var original_instance_id: int = crate.get_instance_id()
	var item_id: String = str(crate.get("loot_item_id"))
	_expect(item_id == "iron_ore", "origin chunk uses its coordinate-derived iron ore loot identity")
	_expect(int(crate.get("loot_remaining")) == 2 and not bool(crate.get("opened")), "new crate starts closed with two salvage units")

	var interaction_position: Vector3 = crate.global_position + Vector3(0.0, 1.0, 0.0)
	playground.player.global_position = interaction_position
	var now: int = int(Time.get_unix_time_from_system())
	var first_result: Dictionary = playground.call("_interact_nearest_world_prop")
	_expect(bool(first_result.get("ok", false)), "first real interaction grants one item through SurvivalWorldBridge")
	_expect(str(first_result.get("item_id", "")) == item_id and int(first_result.get("remaining", -1)) == 1, "first interaction consumes exactly one unit of the crate's configured item")
	_expect(bool(crate.get("opened")) and int(crate.get("loot_remaining")) == 1, "live crate reflects the first successful transaction")
	_expect(_inventory_count(item_id) == 1, "inventory receives exactly one item before streaming")

	var save_payload: Dictionary = playground.call("serialize_stream_state")
	_expect(not save_payload.is_empty(), "world session serializes a complete stream snapshot")
	var object_payload: Dictionary = save_payload.get("world_objects", {})
	var object_records: Dictionary = object_payload.get("objects", {})
	_expect(object_records.has(CRATE_STABLE_ID), "world save captures the actual crate's chunk-scoped stable ID")
	var saved_record: Dictionary = object_records.get(CRATE_STABLE_ID, {})
	var saved_state: Dictionary = saved_record.get("state", {})
	_expect(bool(saved_state.get("opened", false)) and int(saved_state.get("loot_remaining", -1)) == 1, "world save captures the crate's opened and remaining fields")
	_expect(str(saved_state.get("loot_item_id", "")) == item_id, "world save captures the crate's exact loot identity")

	_expect(bool(playground.debug_move_player_to(Vector3(21.0, 2.0, 1.0), now + 1)), "moving away advances the streamed chunk window")
	await process_frame
	_expect(not playground.chunk_controller.is_chunk_loaded(ORIGIN_CHUNK_ID), "origin chunk unloads after the player leaves its stream window")
	var persisted_record: Dictionary = playground.object_state_registry.call("get_object_state", CRATE_STABLE_ID)
	var persisted_state: Dictionary = persisted_record.get("state", {})
	_expect(bool(persisted_state.get("opened", false)) and int(persisted_state.get("loot_remaining", -1)) == 1, "chunk unload persists the live crate state into the object registry")
	_expect(str(persisted_state.get("loot_item_id", "")) == item_id, "chunk unload preserves the loot identity")

	_expect(bool(playground.debug_move_player_to(interaction_position, now + 2)), "returning to the origin regenerates its chunk")
	await process_frame
	var restored_root: Node3D = playground.chunk_controller.get_chunk_root(ORIGIN_CHUNK_ID)
	var restored_crate: Node = restored_root.get_node_or_null("SalvageCrate") if restored_root != null else null
	if restored_crate == null:
		_expect(false, "reloaded origin chunk recreates the SalvageCrate")
		_finish(1)
		return
	_expect(restored_crate.get_instance_id() != original_instance_id, "reloaded crate is a new node instance")
	_expect(bool(restored_crate.get("opened")) and int(restored_crate.get("loot_remaining")) == 1, "reloaded crate restores its saved opened and remaining state")
	_expect(str(restored_crate.get("loot_item_id")) == item_id, "reloaded crate restores its saved item identity")
	_expect(_inventory_count(item_id) == 1, "chunk reload does not duplicate the previously collected item")

	var second_result: Dictionary = playground.call("_interact_nearest_world_prop")
	_expect(bool(second_result.get("ok", false)) and int(second_result.get("remaining", -1)) == 0, "second interaction consumes the final saved salvage unit")
	_expect(_inventory_count(item_id) == 2, "second interaction adds exactly one more item")

	_expect(bool(playground.call("restore_stream_state", save_payload, now + 4)), "full world-save restore accepts the earlier crate and inventory snapshot")
	var save_restored_root: Node3D = playground.chunk_controller.get_chunk_root(ORIGIN_CHUNK_ID)
	var save_restored_crate: Node = save_restored_root.get_node_or_null("SalvageCrate") if save_restored_root != null else null
	_expect(save_restored_crate != null and bool(save_restored_crate.get("opened")) and int(save_restored_crate.get("loot_remaining")) == 1, "full world restore reapplies the earlier crate state to the live node")
	_expect(save_restored_crate != null and str(save_restored_crate.get("loot_item_id")) == item_id, "full world restore retains the crate item identity")
	_expect(_inventory_count(item_id) == 1, "full world restore rolls inventory back to the matching saved count")

	var final_result: Dictionary = playground.call("_interact_nearest_world_prop")
	_expect(bool(final_result.get("ok", false)) and int(final_result.get("remaining", -1)) == 0, "restored crate can be interacted with again")
	var empty_result: Dictionary = playground.call("_interact_nearest_world_prop")
	_expect(not bool(empty_result.get("ok", false)) and str(empty_result.get("reason", "")) == "empty", "empty crate cannot grant a third item")
	_expect(_inventory_count(item_id) == 2, "repeated empty interaction does not duplicate inventory")

	_finish(0 if failures.is_empty() else 1)


func _inventory_count(item_id: String) -> int:
	var inventory: Dictionary = playground.inventory_bridge.call("serialize_inventory")
	var counts: Dictionary = inventory.get("inventory", {})
	return int(counts.get(item_id, 0))


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)


func _on_timeout() -> void:
	push_error("World-object chunk lifecycle test timed out.")
	_finish(2)


func _finish(exit_code: int) -> void:
	if _finished:
		return
	_finished = true
	if is_instance_valid(watchdog):
		watchdog.stop()
		watchdog.queue_free()
	if is_instance_valid(playground):
		playground.queue_free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("World-object chunk lifecycle tests passed.")
	quit(exit_code)

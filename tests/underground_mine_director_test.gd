extends SceneTree

class FailOnceUnloadController:
	extends Node3D
	var delegate: Node
	var registry: Node
	var object_state_registry: Node
	var fail_unload_id: String = ""
	var fail_once: bool = false

	func get_loaded_chunk_ids() -> PackedStringArray:
		return delegate.call("get_loaded_chunk_ids")

	func is_chunk_loaded(chunk_id: String) -> bool:
		return bool(delegate.call("is_chunk_loaded", chunk_id))

	func get_chunk_root(chunk_id: String) -> Node3D:
		return delegate.call("get_chunk_root", chunk_id) as Node3D

	func load_chunk(chunk_id: String, chunk_root: Node3D, now_unix: int = -1) -> bool:
		return bool(delegate.call("load_chunk", chunk_id, chunk_root, now_unix))

	func unload_chunk(chunk_id: String, now_unix: int = -1) -> bool:
		if fail_once and chunk_id == fail_unload_id:
			fail_once = false
			return false
		return bool(delegate.call("unload_chunk", chunk_id, now_unix))

	func has_pending_chunk_load_recovery() -> bool:
		return bool(delegate.call("has_pending_chunk_load_recovery"))

	func recover_failed_chunk_load() -> bool:
		return bool(delegate.call("recover_failed_chunk_load"))

class PairRecoveryObjectRegistry:
	extends Node
	var records: Dictionary = {"pair/chunk/object": {"opened": false}}
	var restore_calls: int = 0
	var rejected_restore_calls: Dictionary = {2: true, 3: true}

	func to_chunk_set_save_dict(chunk_ids: Array) -> Dictionary:
		return {"chunk_ids": chunk_ids.duplicate(), "objects": records.duplicate(true)}

	func validate_chunk_set_save_dict(chunk_ids: Array, data: Dictionary) -> bool:
		var supplied_ids: Variant = data.get("chunk_ids", null)
		var supplied_records: Variant = data.get("objects", null)
		return supplied_ids is Array and supplied_ids == chunk_ids and supplied_records is Dictionary

	func restore_chunk_set_save_dict(_chunk_ids: Array, data: Dictionary) -> bool:
		restore_calls += 1
		if rejected_restore_calls.has(restore_calls):
			return false
		var next_records: Variant = data.get("objects", null)
		if not (next_records is Dictionary):
			return false
		records = next_records.duplicate(true)
		return true


class PairRecoveryMineralRegistry:
	extends Node
	var records: Dictionary = {"pair/chunk/vein/ore": {"remaining_units": 3}}
	var restore_calls: int = 0
	var reject_first_restore: bool = true
	var pending_recovery: bool = false
	var recovery_calls: int = 0

	func to_chunk_set_snapshot(chunk_ids: Array) -> Dictionary:
		return {"schema_version": 1, "chunk_ids": chunk_ids.duplicate(), "veins": records.duplicate(true)}

	func validate_chunk_set_snapshot(chunk_ids: Array, data: Dictionary, _now_unix: int = -1) -> bool:
		var supplied_ids: Variant = data.get("chunk_ids", null)
		var supplied_records: Variant = data.get("veins", null)
		return int(data.get("schema_version", 0)) == 1 and supplied_ids is Array and supplied_ids == chunk_ids and supplied_records is Dictionary

	func restore_chunk_set_snapshot(_chunk_ids: Array, data: Dictionary, _now_unix: int = -1) -> bool:
		restore_calls += 1
		if reject_first_restore and restore_calls == 1:
			reject_first_restore = false
			return false
		var next_records: Variant = data.get("veins", null)
		if not (next_records is Dictionary):
			return false
		records = next_records.duplicate(true)
		return true

	func has_pending_atomic_registration_recovery() -> bool:
		return pending_recovery

	func recover_last_atomic_registration() -> bool:
		recovery_calls += 1
		pending_recovery = false
		return true


class PairRecoveryController:
	extends Node3D
	var registry: Node
	var object_state_registry: Node
	var loaded_ids: PackedStringArray = PackedStringArray(["underground/mine_0_0"])
	var load_calls: int = 0
	var unload_calls: int = 0

	func get_loaded_chunk_ids() -> PackedStringArray:
		return loaded_ids

	func is_chunk_loaded(chunk_id: String) -> bool:
		return loaded_ids.has(chunk_id)

	func load_chunk(_chunk_id: String, _chunk_root: Node3D, _now_unix: int = -1) -> bool:
		load_calls += 1
		return false

	func unload_chunk(_chunk_id: String, _now_unix: int = -1) -> bool:
		unload_calls += 1
		return false


const Registry = preload("res://systems/MineralVeinRegistry.gd")
const Controller = preload("res://systems/MineralChunkController.gd")
const Director = preload("res://systems/UndergroundMineDirector.gd")
const Factory = preload("res://systems/UndergroundMineFactory.gd")
const MiningNode = preload("res://systems/MineralMiningNode.gd")
const ObjectRegistryScript = preload("res://systems/WorldObjectStateRegistry.gd")

var failures: Array[String] = []
var fail_coordinate: Vector2i = Vector2i(999, 999)
var fail_layer: int = 0
var registry: Node
var controller: Node3D
var controller_proxy: Node3D
var director: Node
var object_registry: Node
var mutate_unrelated_on_factory_failure: bool = false
var mutate_unrelated_on_factory_success: bool = false
var unrelated_loaded_vein: Node
var unrelated_unloaded_vein_id: String = "unrelated/unloaded/vein/ore"
var unrelated_object_id: String = "unrelated/chunk/crate"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	registry = Registry.new()
	controller = Controller.new()
	director = Director.new()
	object_registry = ObjectRegistryScript.new()
	root.add_child(registry)
	root.add_child(object_registry)
	root.add_child(controller)
	root.add_child(director)
	controller_proxy = FailOnceUnloadController.new()
	controller_proxy.delegate = controller
	controller_proxy.registry = registry
	controller_proxy.object_state_registry = object_registry
	root.add_child(controller_proxy)
	await process_frame
	_expect(bool(controller.call("bind_registry", registry)), "mineral chunk controller binds the mineral registry")
	_expect(bool(controller.call("bind_object_state_registry", object_registry)), "mineral chunk controller binds the shared world-object registry")
	_expect(bool(director.call("bind_controller", controller_proxy)), "underground director binds the shared chunk controller through a failure-injection proxy")
	_expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_chunk"))), "underground director accepts a deterministic factory")
	_expect(bool(director.call("sync_to_world_position", Vector3(1.5, -8.25, 7.5), 1000)), "initial underground window loads")
	_expect(director.call("get_managed_chunk_ids").size() == 9, "initial mine window contains nine chunks")
	_expect(controller.call("is_chunk_loaded", "underground/mine_0_0"), "origin mine chunk is loaded")
	_expect(controller.call("is_chunk_loaded", "underground/mine_-1_-1"), "negative-coordinate mine chunk is loaded")
	var initial_world_objects: Array = controller.call("get_loaded_world_state_nodes")
	var initial_cache_count: int = 0
	var initial_lift_count: int = 0
	for world_object in initial_world_objects:
		if not is_instance_valid(world_object):
			continue
		if world_object.name == "MineLiftAnchor":
			initial_lift_count += 1
		elif str(world_object.name).begins_with("MineCache_"):
			initial_cache_count += 1
	_expect(initial_cache_count == 7, "initial nine-room window registers two origin caches and five deterministic regional caches")
	_expect(initial_lift_count == 1, "origin mine chunk registers one stateful lift anchor")
	var center: Node3D = controller.call("get_chunk_root", "underground/mine_0_0")
	var east: Node3D = controller.call("get_chunk_root", "underground/mine_1_0")
	var vein: Node3D = null
	var east_vein: Node3D = null
	if center != null:
		vein = center.get_node_or_null("Vein_0") as Node3D
	if east != null:
		east_vein = east.get_node_or_null("Vein_0") as Node3D
	_expect(vein != null, "origin chunk contains a stable mineral node")
	_expect(east_vein != null and vein != null and str(east_vein.get("mineral_id")) != str(vein.get("mineral_id")), "mineral identity varies deterministically by room coordinate")
	if center != null and east != null:
		var east_wall_a: Node3D = center.get_node_or_null("MineWallEast_A") as Node3D
		var east_wall_b: Node3D = center.get_node_or_null("MineWallEast_B") as Node3D
		var west_wall_a: Node3D = east.get_node_or_null("MineWallWest_A") as Node3D
		_expect(east_wall_a != null and east_wall_b != null and west_wall_a != null, "adjacent rooms create aligned split wall segments")
		if east_wall_a != null and east_wall_b != null and west_wall_a != null:
			_expect(is_equal_approx(east_wall_a.position.z, west_wall_a.position.z) and is_equal_approx(east_wall_a.position.z, 2.0) and is_equal_approx(east_wall_b.position.z, 8.0), "doorway gaps align across adjacent room boundaries")
	if vein != null:
		vein.set("remaining_units", 5)
	_expect(bool(director.call("sync_to_world_position", Vector3(21.5, -8.25, 7.5), 1001)), "moving two chunks east shifts the mine window")
	_expect(director.call("get_managed_chunk_ids").size() == 9, "shifted mine window remains bounded to nine chunks")
	_expect(not bool(controller.call("is_chunk_loaded", "underground/mine_0_0")), "stale origin chunk unloads outside the radius")
	_expect(bool(controller.call("is_chunk_loaded", "underground/mine_2_0")), "new east mine chunk loads")
	_expect(bool(director.call("sync_to_world_position", Vector3(1.5, -8.25, 7.5), 1002)), "returning to the origin reloads its stable chunk")
	var restored: Node3D = controller.call("get_chunk_root", "underground/mine_0_0")
	var restored_vein: Node3D = null
	if restored != null:
		restored_vein = restored.get_node_or_null("Vein_0") as Node3D
	_expect(restored_vein != null and int(restored_vein.get("remaining_units")) == 5, "mineral stock survives a real director unload/reload")
	var previous_ids: PackedStringArray = director.call("get_managed_chunk_ids")
	var previous_saved_ids: PackedStringArray = registry.call("get_saved_ids")
	var previous_object_ids: PackedStringArray = object_registry.call("get_saved_ids")
	var previous_regen_timestamp: int = int(restored_vein.get("last_regen_unix"))
	_expect(not bool(director.call("sync_to_world_position", Vector3(INF, -8.25, 7.5), 1002)), "non-finite underground positions are rejected")
	_expect(director.call("get_managed_chunk_ids") == previous_ids, "invalid position leaves the active mine window unchanged")
	fail_coordinate = Vector2i(3, -1)
	_expect(not bool(director.call("sync_to_world_position", Vector3(21.5, -8.25, 7.5), 1003)), "factory failure rejects the shifted window")
	_expect(director.call("get_managed_chunk_ids") == previous_ids, "failed sync restores the previous managed ID set")
	_expect(bool(controller.call("is_chunk_loaded", "underground/mine_0_0")), "failed sync preserves the old origin chunk")
	var rollback_root: Node3D = controller.call("get_chunk_root", "underground/mine_0_0")
	var rollback_vein: Node3D = null
	if rollback_root != null:
		rollback_vein = rollback_root.get_node_or_null("Vein_0") as Node3D
	_expect(rollback_vein != null and int(rollback_vein.get("last_regen_unix")) == previous_regen_timestamp, "failed sync restores the exact mineral regeneration clock")
	_expect(not bool(controller.call("is_chunk_loaded", "underground/mine_2_-1")), "failed sync rolls back a partial new load")
	_expect(not bool(controller.call("is_chunk_loaded", "underground/mine_3_-1")), "failed factory chunk is never registered")
	_expect(registry.call("get_saved_ids") == previous_saved_ids, "failed window generation leaves no orphan mineral records")
	_expect(object_registry.call("get_saved_ids") == previous_object_ids, "failed window generation leaves no orphan world-object records")
	var report: Dictionary = director.call("get_last_sync_report")
	_expect(bool(report.get("rollback_complete", false)), "failed sync reports a complete rollback")
	var pre_deeper_mineral_ids: PackedStringArray = registry.call("get_saved_ids")
	var pre_deeper_object_ids: PackedStringArray = object_registry.call("get_saved_ids")
	fail_coordinate = Vector2i(1, 0)
	fail_layer = 1
	_expect(not bool(director.call("sync_to_world_position", Vector3(1.5, -28.25, 7.5), 1004)), "injected deeper-layer factory failure rejects the vertical transition")
	_expect(bool(controller.call("is_chunk_loaded", "underground/mine_0_0")), "failed deeper-layer transition preserves the previous layer-zero window")
	_expect(not bool(controller.call("is_chunk_loaded", "underground/layer_1/mine_0_0")), "failed deeper-layer transition removes its partially loaded origin")
	_expect(registry.call("get_saved_ids") == pre_deeper_mineral_ids, "deeper-layer rollback restores the exact mineral registry snapshot")
	_expect(object_registry.call("get_saved_ids") == pre_deeper_object_ids, "deeper-layer rollback restores the exact world-object registry snapshot")
	var deeper_failure_report: Dictionary = director.call("get_last_sync_report")
	_expect(bool(deeper_failure_report.get("rollback_complete", false)), "deeper-layer failure reports a complete two-registry rollback")
	var unrelated_loaded_id: String = "unrelated/loaded/vein/ore"
	unrelated_loaded_vein = MiningNode.new()
	unrelated_loaded_vein.set("mineral_id", "iron_ore")
	unrelated_loaded_vein.set("remaining_units", 6)
	unrelated_loaded_vein.set("last_regen_unix", 1006)
	_expect(bool(registry.call("register_vein", unrelated_loaded_id, unrelated_loaded_vein, 1006)), "unrelated loaded mineral vein is registered outside the mine window")
	var unrelated_unloaded_vein: Node = MiningNode.new()
	unrelated_unloaded_vein.set("mineral_id", "copper_ore")
	unrelated_unloaded_vein.set("remaining_units", 8)
	unrelated_unloaded_vein.set("last_regen_unix", 1006)
	_expect(bool(registry.call("register_vein", unrelated_unloaded_vein_id, unrelated_unloaded_vein, 1006)), "unrelated unloaded mineral vein is registered")
	_expect(bool(registry.call("unregister_vein", unrelated_unloaded_vein_id, unrelated_unloaded_vein, 1006)), "unrelated mineral vein is converted to an unloaded saved record")
	unrelated_unloaded_vein.free()
	_expect(bool(object_registry.call("set_object_state", unrelated_object_id, "unrelated/chunk", {"opened": false})), "unrelated world-object record is created")
	mutate_unrelated_on_factory_failure = true
	fail_coordinate = Vector2i(3, -1)
	fail_layer = 0
	_expect(not bool(director.call("sync_to_world_position", Vector3(21.5, -8.25, 7.5), 1007)), "later factory failure rejects a window after the scoped snapshot")
	_expect(unrelated_loaded_vein != null and int(unrelated_loaded_vein.get("remaining_units")) == 17, "newer unrelated loaded mineral state survives Director rollback")
	var unrelated_mineral_save: Dictionary = registry.call("to_save_dict")
	_expect(int(unrelated_mineral_save.get("veins", {}).get(unrelated_unloaded_vein_id, {}).get("remaining_units", -1)) == 19, "newer unrelated unloaded mineral record survives Director rollback")
	_expect(bool(object_registry.call("get_object_state", unrelated_object_id).get("state", {}).get("opened", false)), "newer unrelated world-object record survives Director rollback")
	var scoped_rollback_report: Dictionary = director.call("get_last_sync_report")
	_expect(bool(scoped_rollback_report.get("rollback_complete", false)), "scoped multi-registry rollback reports complete")
	mutate_unrelated_on_factory_failure = false
	fail_coordinate = Vector2i(999, 999)
	fail_layer = 0
	var current_managed_ids: PackedStringArray = director.call("get_managed_chunk_ids")
	var shifted_desired_ids: Dictionary = {}
	for z in range(-1, 2):
		for x in range(1, 4):
			shifted_desired_ids["underground/mine_%d_%d" % [x, z]] = true
	var stale_ids_for_unload_failure: Array[String] = []
	for raw_id in current_managed_ids:
		var current_id: String = str(raw_id)
		if not shifted_desired_ids.has(current_id):
			stale_ids_for_unload_failure.append(current_id)
	stale_ids_for_unload_failure.sort()
	_expect(stale_ids_for_unload_failure.size() == 6, "shifted window identifies six stale chunks for unload")
	var first_stale_root: Node3D = controller.call("get_chunk_root", stale_ids_for_unload_failure[0]) as Node3D
	var first_stale_vein: Node3D = first_stale_root.get_node_or_null("Vein_0") as Node3D if first_stale_root != null else null
	var first_stale_remaining: int = int(first_stale_vein.get("remaining_units")) if first_stale_vein != null else -1
	var first_stale_regen: int = int(first_stale_vein.get("last_regen_unix")) if first_stale_vein != null else -1
	controller_proxy.fail_unload_id = stale_ids_for_unload_failure[1]
	controller_proxy.fail_once = true
	mutate_unrelated_on_factory_success = true
	_expect(not bool(director.call("sync_to_world_position", Vector3(21.5, -8.25, 7.5), 1008)), "second stale unload failure rejects a partially committed window shift")
	_expect(director.call("get_managed_chunk_ids") == current_managed_ids, "stale-unload failure restores the previous managed window")
	_expect(bool(controller.call("is_chunk_loaded", stale_ids_for_unload_failure[0])), "previously unloaded first stale chunk is restored")
	_expect(bool(controller.call("is_chunk_loaded", stale_ids_for_unload_failure[1])), "stale chunk that rejected unload remains loaded")
	_expect(not bool(controller.call("is_chunk_loaded", "underground/mine_2_-1")), "new chunk loads are removed after stale-unload failure")
	var first_stale_restored_root: Node3D = controller.call("get_chunk_root", stale_ids_for_unload_failure[0]) as Node3D
	var first_stale_restored_vein: Node3D = first_stale_restored_root.get_node_or_null("Vein_0") as Node3D if first_stale_restored_root != null else null
	_expect(first_stale_restored_vein != null and int(first_stale_restored_vein.get("remaining_units")) == first_stale_remaining, "stale mineral stock is restored exactly after partial unload")
	_expect(first_stale_restored_vein != null and int(first_stale_restored_vein.get("last_regen_unix")) == first_stale_regen, "stale mineral regeneration clock is restored exactly after partial unload")
	_expect(int(unrelated_loaded_vein.get("remaining_units")) == 18, "newer unrelated loaded mineral write survives stale-unload rollback")
	var stale_unload_mineral_save: Dictionary = registry.call("to_save_dict")
	_expect(int(stale_unload_mineral_save.get("veins", {}).get(unrelated_unloaded_vein_id, {}).get("remaining_units", -1)) == 20, "newer unrelated unloaded mineral record survives stale-unload rollback")
	_expect(not bool(object_registry.call("get_object_state", unrelated_object_id).get("state", {}).get("opened", true)), "newer unrelated world-object write survives stale-unload rollback")
	var stale_unload_report: Dictionary = director.call("get_last_sync_report")
	_expect(bool(stale_unload_report.get("rollback_complete", false)), "partial stale-unload failure reports a complete rollback")
	mutate_unrelated_on_factory_success = false
	controller_proxy.fail_unload_id = ""
	_expect(bool(director.call("sync_to_world_position", Vector3(1.5, -28.25, 7.5), 1005)), "director switches transactionally to the second vertical mine layer")
	_expect(director.call("get_managed_chunk_ids").size() == 9, "deeper mine window remains bounded to nine chunks")
	_expect(controller.call("is_chunk_loaded", "underground/layer_1/mine_0_0"), "deeper origin chunk uses its layer-qualified stable ID")
	_expect(not bool(controller.call("is_chunk_loaded", "underground/mine_0_0")), "switching depth unloads the old layer-zero window")
	var deeper_root: Node3D = controller.call("get_chunk_root", "underground/layer_1/mine_0_0")
	_expect(deeper_root != null and is_equal_approx(deeper_root.position.y, -20.0), "deeper chunk root is placed at the expected vertical offset")
	_expect(deeper_root != null and deeper_root.get_node_or_null("MineLiftAnchor") != null, "deeper origin chunk contains the lift anchor")
	_expect(bool(director.call("sync_to_world_position", Vector3(1.5, -8.25, 7.5), 1006)), "director can return to the legacy layer-zero window")
	_expect(bool(controller.call("is_chunk_loaded", "underground/mine_0_0")) and not bool(controller.call("is_chunk_loaded", "underground/layer_1/mine_0_0")), "returning to layer zero unloads the deeper window")
	_test_registry_pair_compensation_recovery()
	_finish(0 if failures.is_empty() else 1)

func _test_registry_pair_compensation_recovery() -> void:
	var pair_object_registry := PairRecoveryObjectRegistry.new()
	var pair_mineral_registry := PairRecoveryMineralRegistry.new()
	var pair_controller := PairRecoveryController.new()
	var pair_director := Director.new()
	pair_controller.registry = pair_mineral_registry
	pair_controller.object_state_registry = pair_object_registry
	root.add_child(pair_object_registry)
	root.add_child(pair_mineral_registry)
	root.add_child(pair_controller)
	root.add_child(pair_director)
	pair_director.load_radius = 0
	_expect(bool(pair_director.call("bind_controller", pair_controller)), "pair-recovery director binds the injected two-registry controller")
	_expect(bool(pair_director.call("bind_chunk_factory", Callable(self, "_make_chunk"))), "pair-recovery director accepts a factory")
	var chunk_ids: Array[String] = ["pair/chunk"]
	var target_objects: Dictionary = pair_object_registry.to_chunk_set_save_dict(chunk_ids)
	var target_object_records: Dictionary = target_objects["objects"].duplicate(true)
	target_object_records["pair/chunk/object"]["opened"] = true
	target_objects["objects"] = target_object_records
	var target_mineral: Dictionary = pair_mineral_registry.to_chunk_set_snapshot(chunk_ids)
	var target_vein_records: Dictionary = target_mineral["veins"].duplicate(true)
	target_vein_records["pair/chunk/vein/ore"]["remaining_units"] = 1
	target_mineral["veins"] = target_vein_records
	var pair_snapshot: Dictionary = {
		"chunk_ids": chunk_ids.duplicate(),
		"objects": target_objects,
		"mineral": target_mineral
	}
	_expect(not bool(pair_director.call("_restore_registry_snapshot_pair", pair_snapshot, 100)), "mineral restore rejection rejects the registry-pair restore")
	_expect(bool(pair_object_registry.records["pair/chunk/object"]["opened"]), "object target restore is visible before the injected compensation rejection")
	_expect(bool(pair_director.call("has_pending_registry_pair_recovery")), "failed object compensation creates a durable director recovery barrier")
	_expect(pair_object_registry.restore_calls == 2, "initial object restore and first compensation attempt are both observed")
	var alternate_object_registry := PairRecoveryObjectRegistry.new()
	var alternate_mineral_registry := PairRecoveryMineralRegistry.new()
	var alternate_controller := PairRecoveryController.new()
	alternate_controller.registry = alternate_mineral_registry
	alternate_controller.object_state_registry = alternate_object_registry
	root.add_child(alternate_object_registry)
	root.add_child(alternate_mineral_registry)
	root.add_child(alternate_controller)
	pair_director._managed_chunk_ids.clear()
	_expect(not bool(pair_director.call("bind_controller", alternate_controller)), "pending pair recovery prevents rebinding to a different controller even with an empty managed window")
	alternate_mineral_registry.pending_recovery = true
	pair_controller.registry = alternate_mineral_registry
	_expect(not bool(pair_director.call("sync_to_world_position", Vector3(1.5, -8.25, 1.5), 100)), "registry identity change blocks pair recovery instead of restoring into a replacement registry")
	_expect(alternate_mineral_registry.restore_calls == 0 and alternate_mineral_registry.recovery_calls == 0 and alternate_mineral_registry.pending_recovery and bool(pair_director.call("has_pending_registry_pair_recovery")), "identity mismatch is checked before any recovery method touches the replacement registry")
	pair_controller.registry = pair_mineral_registry
	_expect(pair_object_registry.restore_calls == 2, "identity mismatch does not consume another object compensation attempt")
	var blocked_sync: bool = bool(pair_director.call("sync_to_world_position", Vector3(1.5, -8.25, 1.5), 100))
	_expect(not blocked_sync, "underground streaming remains blocked while pair compensation is unresolved")
	var blocked_report: Dictionary = pair_director.call("get_last_sync_report")
	_expect(str(blocked_report.get("phase", "")) == "registry_pair_recovery_barrier" and not bool(blocked_report.get("rollback_complete", true)), "director reports the incomplete registry-pair rollback")
	_expect(pair_controller.load_calls == 0 and pair_controller.unload_calls == 0, "blocked streaming performs no controller load or unload")
	_expect(pair_director.call("has_pending_registry_pair_recovery"), "failed retry retains the director recovery barrier")
	pair_object_registry.rejected_restore_calls.erase(2)
	pair_object_registry.rejected_restore_calls.erase(3)
	_expect(bool(pair_director.call("sync_to_world_position", Vector3(1.5, -8.25, 1.5), 100)), "streaming resumes after both registry snapshots recover and verify")
	_expect(not bool(pair_director.call("has_pending_registry_pair_recovery")), "verified pair recovery clears the director barrier")
	_expect(not bool(pair_object_registry.records["pair/chunk/object"]["opened"]), "object registry returns to the exact pre-compensation state")
	_expect(int(pair_mineral_registry.records["pair/chunk/vein/ore"]["remaining_units"]) == 3, "mineral registry returns to the exact pre-compensation state")
	_expect(pair_mineral_registry.restore_calls == 2, "mineral snapshot is retried only during pair recovery")
	_expect(pair_director.call("get_managed_chunk_ids").size() == 1, "managed underground window is reconciled after pair recovery")
	pair_director.free()
	pair_controller.free()
	pair_object_registry.free()
	pair_mineral_registry.free()
	alternate_controller.free()
	alternate_object_registry.free()
	alternate_mineral_registry.free()


func _make_chunk(coord: Vector2i, layer_index: int, now_unix: int) -> Node3D:
	if mutate_unrelated_on_factory_success and coord == Vector2i(2, -1) and layer_index == 0:
		mutate_unrelated_on_factory_success = false
		_commit_unrelated_registry_writes(now_unix, 18, 20, false)
	if coord == fail_coordinate and layer_index == fail_layer:
		if mutate_unrelated_on_factory_failure:
			mutate_unrelated_on_factory_failure = false
			_commit_unrelated_registry_writes(now_unix, 17, 19, true)
		return null
	return Factory.make_chunk(now_unix, coord, layer_index)

func _commit_unrelated_registry_writes(now_unix: int, loaded_amount: int, unloaded_amount: int, object_opened: bool) -> void:
	if is_instance_valid(unrelated_loaded_vein):
		unrelated_loaded_vein.set("remaining_units", loaded_amount)
		unrelated_loaded_vein.set("last_regen_unix", now_unix)
	var mineral_save: Dictionary = registry.call("to_save_dict")
	var unloaded_record: Dictionary = mineral_save.get("veins", {}).get(unrelated_unloaded_vein_id, {}).duplicate(true)
	unloaded_record["remaining_units"] = unloaded_amount
	unloaded_record["last_regen_unix"] = now_unix
	mineral_save["veins"][unrelated_unloaded_vein_id] = unloaded_record
	_expect(bool(registry.call("restore_snapshot_exact", mineral_save, now_unix)), "factory callback commits newer unrelated loaded and unloaded mineral state")
	_expect(bool(object_registry.call("set_object_state", unrelated_object_id, "unrelated/chunk", {"opened": object_opened})), "factory callback commits newer unrelated world-object state")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish(exit_code: int) -> void:
	if is_instance_valid(director):
		director.queue_free()
	if is_instance_valid(controller_proxy):
		controller_proxy.queue_free()
	if is_instance_valid(controller):
		controller.queue_free()
	if is_instance_valid(registry):
		registry.queue_free()
	if is_instance_valid(object_registry):
		object_registry.queue_free()
	if is_instance_valid(unrelated_loaded_vein):
		unrelated_loaded_vein.free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("Underground mine director tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

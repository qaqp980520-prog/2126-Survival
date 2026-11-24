extends SceneTree

const MineralRegistryScript = preload("res://systems/MineralVeinRegistry.gd")
const ControllerScript = preload("res://systems/MineralChunkController.gd")
const StatefulPropScript = preload("res://systems/WorldObjectStatefulProp.gd")

const PROP_COUNT: int = 4
const SAVED_STATE: Dictionary = {"opened": true, "loot_remaining": 1, "loot_item_id": "iron_ore"}
const DEFAULT_STATE: Dictionary = {"opened": false, "loot_remaining": 2, "loot_item_id": "iron_ore"}
const UNRELATED_CHUNK_ID: String = "unloaded/multiprop-rollback"
const UNRELATED_STABLE_ID: String = UNRELATED_CHUNK_ID + "/object/Crate"
const UNRELATED_STATE: Dictionary = {"opened": true, "loot_remaining": 1, "loot_item_id": "iron_ore"}

class InstrumentedObjectRegistry:
	extends "res://systems/WorldObjectStateRegistry.gd"
	var set_calls: int = 0
	var fail_after_set_calls: int = -1
	var full_snapshot_calls: int = 0
	var forget_calls: int = 0
	var fail_after_forget_calls: int = -1

	func set_object_state(stable_id: String, chunk_id: String, state: Dictionary) -> bool:
		set_calls += 1
		if fail_after_set_calls >= 0 and set_calls > fail_after_set_calls:
			fail_after_set_calls = -1
			return false
		return super.set_object_state(stable_id, chunk_id, state)

	func to_save_dict() -> Dictionary:
		full_snapshot_calls += 1
		return super.to_save_dict()

	func forget_object_state(stable_id: String) -> bool:
		forget_calls += 1
		if fail_after_forget_calls >= 0 and forget_calls > fail_after_forget_calls:
			fail_after_forget_calls = -1
			return false
		return super.forget_object_state(stable_id)

class RejectingStatefulProp:
	extends "res://systems/WorldObjectStatefulProp.gd"
	var reject_opened_state: bool = false

	func apply_world_object_state(state: Dictionary) -> bool:
		if reject_opened_state and bool(state.get("opened", false)):
			return false
		return super.apply_world_object_state(state)

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_partial_default_record_insert_rollback()
	await process_frame
	await _test_four_prop_saved_state_apply_rollback()
	await process_frame
	await _test_four_prop_capture_and_unload_rollback()
	await process_frame
	await _test_scoped_snapshot_recovery_after_partial_restore_failure()
	await process_frame
	if failures.is_empty():
		print("World object multi-prop rollback tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _create_environment(label: String) -> Dictionary:
	var mineral_registry: Node = MineralRegistryScript.new()
	var object_registry: Node = InstrumentedObjectRegistry.new()
	var controller: Node3D = ControllerScript.new()
	root.add_child(mineral_registry)
	root.add_child(object_registry)
	root.add_child(controller)
	await process_frame
	var bound: bool = bool(controller.call("bind_registry", mineral_registry))
	bound = bound and bool(controller.call("bind_object_state_registry", object_registry))
	_expect(bound, "%s binds the production mineral and object registries" % label)
	return {
		"mineral_registry": mineral_registry,
		"object_registry": object_registry,
		"controller": controller
	}

func _test_partial_default_record_insert_rollback() -> void:
	var env: Dictionary = await _create_environment("four-prop default-insert rollback")
	var registry: Node = env["object_registry"] as Node
	var controller: Node3D = env["controller"] as Node3D
	var chunk_id: String = "surface/multiprop-rollback/default-insert"
	_expect(_seed_unrelated_record(registry), "default-insert fixture seeds an unrelated unloaded record")
	var chunk: Node3D = _new_chunk()
	registry.set("set_calls", 0)
	registry.set("fail_after_set_calls", 2)
	var loaded: bool = bool(controller.call("load_chunk", chunk_id, chunk, 1000))
	_expect(not loaded, "failure on the third default record rejects the four-prop chunk")
	_expect(chunk.get_parent() == null, "failed four-prop load leaves the caller-owned root detached")
	var loaded_ids: PackedStringArray = controller.call("get_loaded_chunk_ids")
	_expect(loaded_ids.is_empty(), "failed four-prop load does not publish partial controller ownership")
	_expect(int(registry.get("set_calls")) == 3, "default-insert fixture fails after exactly two successful record writes")
	_expect(int(registry.get("full_snapshot_calls")) == 0, "default-insert rollback never serializes the full object registry")
	_expect(_chunk_records_absent(registry, chunk_id), "rollback removes every partially-created record from the four-prop chunk")
	_expect(_read_unrelated_record(registry) == _expected_unrelated_record(), "default-insert rollback preserves the unrelated unloaded record")
	_expect(_live_props_match(chunk, DEFAULT_STATE), "default-insert rollback leaves all four live props at their initial states")
	await _cleanup_environment(env, chunk)

func _test_four_prop_saved_state_apply_rollback() -> void:
	var env: Dictionary = await _create_environment("four-prop saved-state apply rollback")
	var registry: Node = env["object_registry"] as Node
	var controller: Node3D = env["controller"] as Node3D
	var chunk_id: String = "surface/multiprop-rollback/saved-apply"
	_expect(_seed_unrelated_record(registry), "saved-apply fixture seeds an unrelated unloaded record")
	_expect(_seed_chunk_records(registry, chunk_id, SAVED_STATE), "saved-apply fixture seeds all four saved object records")
	var expected_records: Dictionary = _read_chunk_records(registry, chunk_id)
	registry.set("set_calls", 0)
	var chunk: Node3D = _new_chunk(2)
	var loaded: bool = bool(controller.call("load_chunk", chunk_id, chunk, 1000))
	_expect(not loaded, "the third prop rejecting its saved state rejects the entire four-prop chunk")
	_expect(chunk.get_parent() == null, "saved-state failure leaves the caller-owned root detached")
	var loaded_ids: PackedStringArray = controller.call("get_loaded_chunk_ids")
	_expect(loaded_ids.is_empty(), "saved-state failure does not publish partial controller ownership")
	_expect(_live_props_match(chunk, DEFAULT_STATE), "saved-state rollback restores every already-visited live prop")
	_expect(_read_chunk_records(registry, chunk_id) == expected_records, "saved-state rollback restores all four registry records exactly")
	_expect(_read_unrelated_record(registry) == _expected_unrelated_record(), "saved-state rollback preserves unrelated unloaded records")
	_expect(int(registry.get("full_snapshot_calls")) == 0, "saved-state rollback uses only chunk-scoped registry records")
	await _cleanup_environment(env, chunk)

func _test_four_prop_capture_and_unload_rollback() -> void:
	var env: Dictionary = await _create_environment("four-prop capture and unload rollback")
	var registry: Node = env["object_registry"] as Node
	var controller: Node3D = env["controller"] as Node3D
	var chunk_id: String = "surface/multiprop-rollback/capture-unload"
	_expect(_seed_unrelated_record(registry), "capture/unload fixture seeds an unrelated unloaded record")
	var chunk: Node3D = _new_chunk()
	var loaded: bool = bool(controller.call("load_chunk", chunk_id, chunk, 1000))
	_expect(loaded, "four-prop capture/unload fixture loads successfully")
	if not loaded:
		await _cleanup_environment(env, chunk)
		return
	var original_records: Dictionary = _read_chunk_records(registry, chunk_id)
	_expect(_interact_all_props(chunk), "all four props mutate independently before capture")
	registry.set("set_calls", 0)
	registry.set("fail_after_set_calls", 2)
	var captured: bool = bool(controller.call("capture_loaded_world_object_states"))
	_expect(not captured, "failure on the third object write rejects the four-prop world-state capture")
	_expect(_read_chunk_records(registry, chunk_id) == original_records, "failed capture restores all four pre-capture registry records")
	_expect(_live_props_match(chunk, SAVED_STATE), "failed capture leaves the four live props' interacted states unchanged")
	_expect(int(registry.get("full_snapshot_calls")) == 0, "failed capture rollback avoids the full-registry serializer")
	_expect(bool(controller.call("capture_loaded_world_object_states")), "four-prop world-state capture succeeds after the one-shot registry failure")
	var captured_records: Dictionary = _read_chunk_records(registry, chunk_id)
	_expect(_records_match_state(captured_records, chunk_id, SAVED_STATE), "successful capture persists all four interacted prop states")

	_expect(_apply_default_to_all_props(chunk), "all four live props can change after the successful capture")
	registry.set("set_calls", 0)
	registry.set("fail_after_set_calls", 2)
	var unloaded: bool = bool(controller.call("unload_chunk", chunk_id, 1000))
	_expect(not unloaded, "failure on the third object write rejects the four-prop chunk unload")
	_expect(bool(controller.call("is_chunk_loaded", chunk_id)), "failed four-prop unload retains controller ownership")
	_expect(chunk.get_parent() == controller, "failed four-prop unload keeps the chunk root attached")
	_expect(_read_chunk_records(registry, chunk_id) == captured_records, "failed unload restores all four pre-unload registry records")
	_expect(_live_props_match(chunk, DEFAULT_STATE), "failed unload leaves the four live props available in their current state")
	_expect(_read_unrelated_record(registry) == _expected_unrelated_record(), "capture/unload rollback preserves unrelated unloaded records")
	_expect(int(registry.get("full_snapshot_calls")) == 0, "capture and unload rollback never serialize the full object registry")
	_expect(bool(controller.call("unload_chunk", chunk_id, 1000)), "four-prop unload succeeds after the one-shot registry failure")
	_expect(not bool(controller.call("is_chunk_loaded", chunk_id)), "successful retry removes controller ownership")
	_expect(_records_match_state(_read_chunk_records(registry, chunk_id), chunk_id, DEFAULT_STATE), "successful unload persists the four current live prop states")
	_expect(_read_unrelated_record(registry) == _expected_unrelated_record(), "successful unload also preserves unrelated unloaded records")
	_expect(int(registry.get("full_snapshot_calls")) == 0, "successful four-prop capture and unload avoid full-registry snapshots")
	await _cleanup_environment(env, chunk)

func _test_scoped_snapshot_recovery_after_partial_restore_failure() -> void:
	var env: Dictionary = await _create_environment("scoped snapshot self-recovery")
	var registry: Node = env["object_registry"] as Node
	var controller: Node3D = env["controller"] as Node3D
	var chunk_id: String = "surface/multiprop-rollback/self-recovery"
	_expect(_seed_unrelated_record(registry), "self-recovery fixture seeds an unrelated unloaded record")
	_expect(_seed_chunk_records(registry, chunk_id, DEFAULT_STATE), "self-recovery fixture seeds all four target records")
	var stable_ids: Array[String] = []
	for index in range(PROP_COUNT):
		stable_ids.append(_stable_id(chunk_id, index))
	var target_snapshot: Dictionary = controller.call("_capture_world_object_registry_snapshot", stable_ids)
	_expect(str(target_snapshot.get("mode", "")) == "records", "self-recovery fixture captures a chunk-scoped target snapshot")
	_expect(_seed_chunk_records(registry, chunk_id, SAVED_STATE), "self-recovery fixture writes a distinct current state")
	var expected_current_records: Dictionary = _read_chunk_records(registry, chunk_id)

	registry.set("set_calls", 0)
	registry.set("fail_after_set_calls", 2)
	var restored_after_set_failure: bool = bool(controller.call("_restore_world_object_registry_snapshot", target_snapshot))
	_expect(not restored_after_set_failure, "a one-shot third set failure rejects the target snapshot restore")
	_expect(int(registry.get("set_calls")) == 7, "set failure triggers all four writes needed to recover the pre-attempt records")
	_expect(_read_chunk_records(registry, chunk_id) == expected_current_records, "set failure recovery restores every pre-attempt chunk record exactly")
	_expect(_read_unrelated_record(registry) == _expected_unrelated_record(), "set failure recovery preserves unrelated unloaded records")
	_expect(int(registry.get("full_snapshot_calls")) == 0, "set failure recovery never serializes the full object registry")

	registry.set("forget_calls", 0)
	registry.set("fail_after_forget_calls", 2)
	var restored_after_forget_failure: bool = bool(controller.call("_restore_world_object_registry_snapshot", target_snapshot))
	_expect(not restored_after_forget_failure, "a one-shot third forget failure rejects the target snapshot restore")
	_expect(int(registry.get("forget_calls")) == 5, "forget failure recovery removes remaining records and retries all four current records")
	_expect(_read_chunk_records(registry, chunk_id) == expected_current_records, "forget failure recovery restores every pre-attempt chunk record exactly")
	_expect(_read_unrelated_record(registry) == _expected_unrelated_record(), "forget failure recovery preserves unrelated unloaded records")
	_expect(int(registry.get("full_snapshot_calls")) == 0, "forget failure recovery never serializes the full object registry")
	await _cleanup_environment(env, null)

func _seed_unrelated_record(registry: Node) -> bool:
	return bool(registry.call("set_object_state", UNRELATED_STABLE_ID, UNRELATED_CHUNK_ID, UNRELATED_STATE))

func _seed_chunk_records(registry: Node, chunk_id: String, state: Dictionary) -> bool:
	for index in range(PROP_COUNT):
		if not bool(registry.call("set_object_state", _stable_id(chunk_id, index), chunk_id, state)):
			return false
	return true

func _new_chunk(reject_index: int = -1) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "ChunkRoot"
	for index in range(PROP_COUNT):
		var prop: Node3D
		if index == reject_index:
			prop = RejectingStatefulProp.new()
			prop.set("reject_opened_state", true)
		else:
			prop = StatefulPropScript.new()
		prop.name = _prop_name(index)
		chunk.add_child(prop)
	return chunk

func _interact_all_props(chunk: Node3D) -> bool:
	for index in range(PROP_COUNT):
		var prop: Node = chunk.get_node(_prop_name(index))
		if not bool(prop.call("interact")):
			return false
	return true

func _apply_default_to_all_props(chunk: Node3D) -> bool:
	for index in range(PROP_COUNT):
		var prop: Node = chunk.get_node(_prop_name(index))
		if not bool(prop.call("apply_world_object_state", DEFAULT_STATE)):
			return false
	return true

func _live_props_match(chunk: Node3D, expected_state: Dictionary) -> bool:
	for index in range(PROP_COUNT):
		var prop: Node = chunk.get_node(_prop_name(index))
		if prop.call("get_world_object_state") != expected_state:
			return false
	return true

func _chunk_records_absent(registry: Node, chunk_id: String) -> bool:
	for index in range(PROP_COUNT):
		var record: Variant = registry.call("get_object_state", _stable_id(chunk_id, index))
		if not (record is Dictionary) or not record.is_empty():
			return false
	return true

func _read_chunk_records(registry: Node, chunk_id: String) -> Dictionary:
	var records: Dictionary = {}
	for index in range(PROP_COUNT):
		var stable_id: String = _stable_id(chunk_id, index)
		records[stable_id] = registry.call("get_object_state", stable_id)
	return records

func _records_match_state(records: Dictionary, chunk_id: String, expected_state: Dictionary) -> bool:
	for index in range(PROP_COUNT):
		var stable_id: String = _stable_id(chunk_id, index)
		var record: Dictionary = records.get(stable_id, {})
		if str(record.get("chunk_id", "")) != chunk_id or record.get("state", {}) != expected_state:
			return false
	return true

func _read_unrelated_record(registry: Node) -> Dictionary:
	return registry.call("get_object_state", UNRELATED_STABLE_ID)

func _expected_unrelated_record() -> Dictionary:
	return {"chunk_id": UNRELATED_CHUNK_ID, "state": UNRELATED_STATE}

func _stable_id(chunk_id: String, index: int) -> String:
	return chunk_id + "/object/ChunkRoot/" + _prop_name(index)

func _prop_name(index: int) -> String:
	return "Prop_%02d" % index

func _cleanup_environment(env: Dictionary, chunk: Node3D) -> void:
	var controller: Node3D = env.get("controller") as Node3D
	var object_registry: Node = env.get("object_registry") as Node
	var mineral_registry: Node = env.get("mineral_registry") as Node
	if is_instance_valid(controller):
		controller.queue_free()
	if is_instance_valid(chunk) and chunk.get_parent() == null and not chunk.is_queued_for_deletion():
		chunk.free()
	if is_instance_valid(object_registry):
		object_registry.queue_free()
	if is_instance_valid(mineral_registry):
		mineral_registry.queue_free()
	await process_frame

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

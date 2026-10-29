extends SceneTree

const RegistryScript = preload("res://systems/WorldObjectStateRegistry.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry: Node = RegistryScript.new()
	root.add_child(registry)
	await process_frame
	_expect(bool(registry.call("set_object_state", "surface/chunk_0_0/crate_1", "surface/chunk_0_0", {"opened": false, "loot_seed": 42})), "valid object state is accepted")
	_expect(bool(registry.call("set_property", "surface/chunk_0_0/crate_1", "surface/chunk_0_0", "opened", true)), "property updates preserve stable object identity")
	var state: Dictionary = registry.call("get_object_state", "surface/chunk_0_0/crate_1")
	_expect(bool(state["state"]["opened"]) and int(state["state"]["loot_seed"]) == 42, "updated object properties are readable")
	_expect(registry.call("get_chunk_states", "surface/chunk_0_0").size() == 1, "chunk query returns only its object records")
	_expect(not bool(registry.call("set_object_state", "surface/chunk_0_0/crate_1", "surface/chunk_1_0", {"opened": false})), "stable ID cannot be reassigned to a different chunk")
	_expect(not bool(registry.call("set_property", "surface/chunk_0_0/crate_1", "surface/chunk_0_0", "nested", {"unsafe": true})), "nested values are rejected")
	_expect(not bool(registry.call("set_property", "surface/chunk_0_0/crate_1", "surface/chunk_0_0", "bad_float", INF)), "non-finite numbers are rejected")
	var oversized_state: Dictionary = {}
	for index in range(65):
		oversized_state["property_%d" % index] = index
	_expect(not bool(registry.call("set_object_state", "surface/chunk_0_0/oversized", "surface/chunk_0_0", oversized_state)), "objects exceeding the property-count cap are rejected")
	_expect(registry.call("get_saved_ids").size() == 1, "rejected oversized object state does not create a partial record")

	var save: Dictionary = registry.call("to_save_dict")
	_expect(bool(registry.call("validate_save_dict", save)), "valid registry save passes validation")
	var copied: Dictionary = registry.call("to_save_dict")
	copied["objects"]["surface/chunk_0_0/crate_1"]["state"]["opened"] = false
	_expect(bool(registry.call("get_object_state", "surface/chunk_0_0/crate_1")["state"]["opened"]), "save snapshot is a deep copy")

	var previous_ids: PackedStringArray = registry.call("get_saved_ids")
	var invalid: Dictionary = save.duplicate(true)
	invalid["objects"]["surface/chunk_0_0/crate_1"]["state"]["opened"] = ["invalid"]
	_expect(not bool(registry.call("restore_save_dict", invalid)), "invalid record rejects the whole restore")
	_expect(registry.call("get_saved_ids") == previous_ids, "failed restore preserves all current IDs")
	_expect(bool(registry.call("restore_save_dict", save)), "valid restore replaces records")
	_expect(bool(registry.call("forget_object_state", "surface/chunk_0_0/crate_1")), "explicit forget removes a record")
	_expect(registry.call("get_saved_ids").is_empty(), "registry is empty after explicit forget")

	var budget_registry: Node = RegistryScript.new()
	root.add_child(budget_registry)
	await process_frame
	var long_value: String = ""
	for character_index in range(256):
		long_value += "x"
	var large_string_state: Dictionary = {}
	for property_index in range(64):
		large_string_state["p_%02d" % property_index] = long_value
	for record_index in range(61):
		_expect(bool(budget_registry.call("set_object_state", "budget/chunk/item_%d" % record_index, "budget/chunk", large_string_state)), "aggregate string budget accepts record %d" % record_index)
	_expect(not bool(budget_registry.call("set_object_state", "budget/chunk/item_61", "budget/chunk", large_string_state)), "aggregate string-character budget rejects the next oversized record")
	_expect(budget_registry.call("get_saved_ids").size() == 61, "rejected aggregate string payload creates no partial record")
	_expect(bool(budget_registry.call("set_object_state", "budget/chunk/item_0", "budget/chunk", {"note": "ok"})), "replacing a record releases its prior aggregate budget")
	_expect(bool(budget_registry.call("set_object_state", "budget/chunk/item_61", "budget/chunk", large_string_state)), "released aggregate budget can be reused")
	var budget_save: Dictionary = budget_registry.call("to_save_dict")
	var over_budget_save: Dictionary = budget_save.duplicate(true)
	over_budget_save["objects"]["budget/chunk/item_62"] = {"chunk_id": "budget/chunk", "state": large_string_state.duplicate(true)}
	var ids_before_overflow_restore: PackedStringArray = budget_registry.call("get_saved_ids")
	_expect(not bool(budget_registry.call("validate_save_dict", over_budget_save)), "save validation rejects aggregate string payload overflow")
	_expect(not bool(budget_registry.call("restore_save_dict", over_budget_save)), "restore rejects aggregate string payload overflow")
	_expect(budget_registry.call("get_saved_ids") == ids_before_overflow_restore, "over-budget restore leaves all existing records unchanged")
	_expect(bool(budget_registry.call("forget_object_state", "budget/chunk/item_1")), "forgetting a record releases aggregate string budget")
	_expect(bool(budget_registry.call("set_object_state", "budget/chunk/item_62", "budget/chunk", large_string_state)), "released budget remains accurate after deletion")

	var property_registry: Node = RegistryScript.new()
	root.add_child(property_registry)
	await process_frame
	var numeric_state: Dictionary = {}
	for property_index in range(64):
		numeric_state["p_%02d" % property_index] = property_index
	for record_index in range(1562):
		if not bool(property_registry.call("set_object_state", "property/chunk/item_%d" % record_index, "property/chunk", numeric_state)):
			_expect(false, "aggregate property budget accepts records up to the configured limit")
			break
	_expect(not bool(property_registry.call("set_object_state", "property/chunk/item_1562", "property/chunk", numeric_state)), "aggregate property-count budget rejects the next record")
	_expect(property_registry.call("get_saved_ids").size() == 1562, "property-budget rejection leaves record count unchanged")

	budget_registry.queue_free()
	property_registry.queue_free()
	await process_frame
	registry.queue_free()
	await process_frame
	if failures.is_empty():
		print("World object state registry tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

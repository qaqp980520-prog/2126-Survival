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

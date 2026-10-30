extends SceneTree

const PropScript = preload("res://systems/WorldObjectStatefulProp.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var prop: Node3D = PropScript.new()
	root.add_child(prop)
	await process_frame

	_expect(_is_read_only(prop, "opened"), "opened is exposed as a read-only property")
	_expect(_is_read_only(prop, "loot_remaining"), "loot_remaining is exposed as a read-only property")
	_expect(_is_read_only(prop, "loot_item_id"), "loot_item_id is exposed as a read-only property")
	_expect(not _has_setter(prop, "opened"), "opened has no public setter")
	_expect(not _has_setter(prop, "loot_remaining"), "loot_remaining has no public setter")
	_expect(not _has_setter(prop, "loot_item_id"), "loot_item_id has no public setter")
	_expect(not bool(prop.get("opened")), "opened remains readable through the compatibility property")
	_expect(int(prop.get("loot_remaining")) == PropScript.MAX_LOOT, "loot_remaining remains readable through the compatibility property")
	_expect(str(prop.get("loot_item_id")) == "iron_ore", "loot_item_id remains readable through the compatibility property")

	_expect(bool(prop.call("set_loot_item", "copper_ore")), "validated loot configuration still works")
	var configured: Dictionary = prop.call("get_world_object_state")
	_expect(str(configured.get("loot_item_id", "")) == "copper_ore", "validated setter updates the private backing field")

	prop.queue_free()
	await process_frame
	if failures.is_empty():
		print("Salvage crate read-only state tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _is_read_only(target: Object, property_name: String) -> bool:
	for info in target.get_property_list():
		if str(info.get("name", "")) == property_name:
			return (int(info.get("usage", 0)) & PROPERTY_USAGE_READ_ONLY) != 0
	return false

func _has_setter(target: Object, property_name: String) -> bool:
	for info in target.get_property_list():
		if str(info.get("name", "")) == property_name:
			return not str(info.get("setter", "")).is_empty()
	return true

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

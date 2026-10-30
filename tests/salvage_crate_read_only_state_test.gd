extends SceneTree

const PropScript = preload("res://systems/WorldObjectStatefulProp.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var prop: Node3D = PropScript.new()
	root.add_child(prop)
	await process_frame

	var source: String = FileAccess.get_file_as_string("res://systems/WorldObjectStatefulProp.gd")
	_expect(_property_is_getter_only(source, "opened", "_opened"), "opened is declared with a getter and no setter")
	_expect(_property_is_getter_only(source, "loot_remaining", "_loot_remaining"), "loot_remaining is declared with a getter and no setter")
	_expect(_property_is_getter_only(source, "loot_item_id", "_loot_item_id"), "loot_item_id is declared with a getter and no setter")
	_expect(source.contains("var _opened: bool"), "opened data uses a private backing field")
	_expect(source.contains("var _loot_remaining: int"), "loot count uses a private backing field")
	_expect(source.contains("var _loot_item_id: String"), "loot identity uses a private backing field")
	_expect(not bool(prop.get("opened")), "opened remains readable through the compatibility property")
	_expect(int(prop.get("loot_remaining")) == PropScript.MAX_LOOT, "loot_remaining remains readable through the compatibility property")
	_expect(str(prop.get("loot_item_id")) == "iron_ore", "loot_item_id remains readable through the compatibility property")

	_expect(bool(prop.call("set_loot_item", "copper_ore")), "validated loot configuration still works")
	var configured: Dictionary = prop.call("get_world_object_state")
	_expect(str(configured.get("loot_item_id", "")) == "copper_ore", "validated setter updates the private backing field")
	_expect(bool(prop.call("apply_world_object_state", {"opened": false, "loot_remaining": 2, "loot_item_id": "silver_ore"})), "validated state restore still works")
	_expect(str(prop.get("loot_item_id")) == "silver_ore", "read-only property reflects validated state restoration")

	prop.queue_free()
	await process_frame
	if failures.is_empty():
		print("Salvage crate read-only state tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _property_is_getter_only(source: String, property_name: String, backing_name: String) -> bool:
	var marker: String = "var " + property_name + ":"
	var start: int = source.find(marker)
	if start < 0:
		return false
	var next_property: int = source.find("\nvar ", start + marker.length())
	var block: String = source.substr(start, next_property - start if next_property >= 0 else source.length() - start)
	return block.contains("\tget:") and block.contains("\t\treturn " + backing_name) and not block.contains("\tset:")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

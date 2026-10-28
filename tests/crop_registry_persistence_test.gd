extends SceneTree

const WorldScene = preload("res://prototypes/BackroomsPortalPlayground.tscn")
const SAVE_PATH := "user://backrooms_playground_save.json"
const RELATED_PATHS := [
	"user://backrooms_playground_save.json",
	"user://backrooms_playground_save.json.tmp",
	"user://backrooms_playground_save.json.bak",
	"user://backrooms_playground_save.json.corrupt"
]
const TOMATO_ID := "surface/chunk_0_0/tomato-01"
const WHEAT_ID := "surface/chunk_1_0/wheat-02"

var failures: Array[String] = []
var world: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup_save_files()
	world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	var registry: Node = world.get("crop_registry")
	_expect(registry != null and registry.has_method("register_crop"), "active world owns a crop state registry")
	if registry == null:
		await _finish(1)
		return

	var now: int = int(Time.get_unix_time_from_system())
	_expect(bool(registry.call("register_crop", TOMATO_ID, "tomato", 2, 0.35, 65.0, now, 1)), "register a crop in a loaded surface chunk")
	_expect(bool(registry.call("register_crop", WHEAT_ID, "wheat", 1, 0.7, 40.0, now, 0)), "register a second crop record for a separate chunk")
	_expect(not bool(registry.call("register_crop", TOMATO_ID, "tomato", 0, 0.0, 0.0, now, 0)), "duplicate stable crop ID is rejected")
	_expect(not bool(registry.call("register_crop", "surface/chunk_0_0/unknown-01", "unknown_crop", 0, 0.0, 0.0, now, 0)), "unknown crop ID is rejected")
	var before_invalid_update: Dictionary = registry.call("get_crop", TOMATO_ID)
	_expect(not bool(registry.call("update_crop", TOMATO_ID, 99, 0.5, 50.0, now + 1, 1)), "invalid growth stage update is rejected")
	_expect(registry.call("get_crop", TOMATO_ID) == before_invalid_update, "invalid crop update leaves the existing record unchanged")
	var detached_payload: Dictionary = registry.call("to_save_dict")
	detached_payload["crops"][TOMATO_ID]["growth_stage"] = 99
	_expect(_crop_stage(registry, TOMATO_ID) == 2, "save snapshot is detached from live crop records")
	var snapshot: Dictionary = world.call("serialize_world_state")
	_expect(snapshot.has("crop_registry_state"), "world envelope serializes crop registry state")
	_expect(bool(world.call("save_game")), "active world writes crop state through the real save writer")
	var bad_schema: Dictionary = registry.call("to_save_dict")
	bad_schema["schema_version"] = 1.5
	_expect(not bool(registry.call("validate_save_dict", bad_schema)), "fractional crop registry schema is rejected")

	registry.call("update_crop", TOMATO_ID, 4, 0.95, 20.0, now + 1, 2)
	var player := world.get_node("Player") as Node3D
	player.global_position = Vector3(4.0, 0.0, 6.0)
	_expect(bool(world.call("load_game")), "active world reloads saved crop state from user://")
	_expect(_crop_stage(registry, TOMATO_ID) == 2, "load restores saved tomato growth stage")
	_expect(is_equal_approx(_crop_progress(registry, TOMATO_ID), 0.35), "load restores saved growth progress")

	world.queue_free()
	await process_frame
	world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	registry = world.get("crop_registry")
	_expect(bool(world.call("load_game")), "fresh world instance restores crop registry from disk")
	_expect(_crop_stage(registry, TOMATO_ID) == 2 and _crop_stage(registry, WHEAT_ID) == 1, "fresh world restores all stable-ID crop records")

	var valid_snapshot: Dictionary = world.call("serialize_world_state")
	var invalid_snapshot: Dictionary = valid_snapshot.duplicate(true)
	var crop_payload: Dictionary = invalid_snapshot["crop_registry_state"].duplicate(true)
	var crop_records: Dictionary = crop_payload["crops"].duplicate(true)
	var bad_wheat: Dictionary = crop_records[WHEAT_ID].duplicate(true)
	bad_wheat["growth_stage"] = 99
	crop_records[WHEAT_ID] = bad_wheat
	crop_payload["crops"] = crop_records
	invalid_snapshot["crop_registry_state"] = crop_payload

	var bridge: Node = world.get("bridge")
	player = world.get_node("Player") as Node3D
	_expect(bool(bridge.call("collect_world_item", "berries", 1)), "mutate inventory before invalid crop restore")
	player.global_position = Vector3(7.0, 0.0, 7.0)
	_expect(bool(registry.call("update_crop", TOMATO_ID, 3, 0.5, 55.0, now + 2, 1)), "mutate live crop before invalid restore")
	var weight_before: float = float(bridge.call("get_weight_kg"))
	var player_before: Vector3 = player.global_position
	_expect(not bool(world.call("load_world_state_from_dictionary", invalid_snapshot)), "invalid later crop record rejects the entire world restore")
	_expect(_crop_stage(registry, TOMATO_ID) == 3, "invalid crop restore does not partially replace earlier live records")
	_expect(int(world.call("get_inventory_count", "berries")) == 1, "invalid crop restore does not mutate inventory")
	_expect(is_equal_approx(float(bridge.call("get_weight_kg")), weight_before), "invalid crop restore preserves carry weight")
	_expect(player.global_position.is_equal_approx(player_before), "invalid crop restore preserves player position")

	var legacy_snapshot: Dictionary = world.call("serialize_world_state")
	legacy_snapshot.erase("crop_registry_state")
	_expect(bool(registry.call("update_crop", TOMATO_ID, 4, 0.8, 35.0, now + 3, 2)), "prepare live crop state before legacy load")
	_expect(bool(world.call("load_world_state_from_dictionary", legacy_snapshot)), "legacy world save without crop registry remains compatible")
	_expect(_crop_stage(registry, TOMATO_ID) == 4, "legacy save preserves the current crop snapshot instead of erasing it")

	await _finish(0 if failures.is_empty() else 1)

func _crop_stage(registry: Node, stable_id: String) -> int:
	var record: Variant = registry.call("get_crop", stable_id)
	if not (record is Dictionary):
		return -1
	return int(record.get("growth_stage", -1))

func _crop_progress(registry: Node, stable_id: String) -> float:
	var record: Variant = registry.call("get_crop", stable_id)
	if not (record is Dictionary):
		return -1.0
	return float(record.get("growth_progress", -1.0))

func _cleanup_save_files() -> void:
	for path in RELATED_PATHS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish(code: int) -> void:
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	_cleanup_save_files()
	if code == 0:
		print("Crop registry persistence integration test passed.")
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	quit(code)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

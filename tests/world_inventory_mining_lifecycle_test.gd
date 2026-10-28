extends SceneTree

const WorldScene = preload("res://prototypes/BackroomsPortalPlayground.tscn")
const MiningNode = preload("res://systems/MineralMiningNode.gd")
const SAVE_PATH: String = "user://backrooms_playground_save.json"
const RELATED_PATHS: Array[String] = [
	"user://backrooms_playground_save.json",
	"user://backrooms_playground_save.json.tmp",
	"user://backrooms_playground_save.json.bak",
	"user://backrooms_playground_save.json.corrupt"
]
const VEIN_ID := "underground/cave_0_0/iron-vein-01"

var failures: Array[String] = []
var watchdog: Timer
var world: Node
var replacement_world: Node

func _initialize() -> void:
	watchdog = Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 45.0
	root.add_child(watchdog)
	watchdog.timeout.connect(_on_timeout)
	call_deferred("_start_watchdog")
	call_deferred("_run")

func _start_watchdog() -> void:
	if is_instance_valid(watchdog) and watchdog.is_inside_tree():
		watchdog.start()

func _run() -> void:
	_cleanup_save_files()
	world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame

	var bridge: Node = world.get("bridge")
	var registry: Node = world.get("mineral_vein_registry")
	var player := world.get_node("Player") as Node3D
	_expect(bridge != null, "active world creates the shared inventory bridge")
	_expect(registry != null and registry.has_method("register_vein"), "active world owns a mineral vein registry")
	if bridge == null or registry == null:
		_finish(1)
		return

	var vein := _new_iron_vein(world)
	await process_frame
	_expect(bool(registry.call("register_vein", VEIN_ID, vein, int(Time.get_unix_time_from_system()))), "active world registers a stable-ID underground vein")

	var starting_weight := float(bridge.call("get_weight_kg"))
	var accepted := int(vein.call("mine_hit"))
	_expect(accepted == 2, "real MineralMiningNode transfers two ore through the active world's bridge")
	_expect(int(vein.get("remaining_units")) == 3, "vein stock decreases only by accepted ore")
	_expect(int(world.call("get_inventory_count", "iron_ore")) == 2, "mined ore appears in the shared inventory")
	var mined_weight := float(bridge.call("get_weight_kg"))
	_expect(is_equal_approx(mined_weight, starting_weight + 6.0), "two iron ore immediately add six kilograms")

	player.global_position = Vector3(2.0, 0.0, 3.0)
	_expect(bool(world.call("save_game")), "active world saves inventory, player position and vein registry to a real user:// file")
	_expect(FileAccess.file_exists(SAVE_PATH), "world save file exists after save_game")
	var saved := _read_save()
	_expect(saved.has("mineral_veins"), "world envelope contains the mineral_veins payload")
	_expect(int(saved.get("mineral_veins", {}).get("veins", {}).get(VEIN_ID, {}).get("remaining_units", -1)) == 3, "save captures the accepted post-mining vein stock")

	_expect(bool(bridge.call("drop_item", "iron_ore", 1)), "shared bridge accepts an ore drop after mining")
	_expect(is_equal_approx(float(bridge.call("get_weight_kg")), mined_weight - 3.0), "dropping ore immediately recalculates carry weight")
	player.global_position = Vector3(8.0, 0.0, 9.0)
	_expect(bool(bridge.call("collect_world_item", "berries", 2)), "post-save inventory mutation succeeds before reload")
	vein.set("remaining_units", 1)
	_expect(bool(world.call("load_game")), "active world reloads the saved inventory and vein registry")
	_expect(int(world.call("get_inventory_count", "iron_ore")) == 2, "reload restores the mined ore count")
	_expect(int(world.call("get_inventory_count", "berries")) == 0, "reload discards inventory mutations made after saving")
	_expect(is_equal_approx(float(bridge.call("get_weight_kg")), mined_weight), "reload restores the saved inventory weight")
	_expect(player.global_position.is_equal_approx(Vector3(2.0, 0.0, 3.0)), "reload restores the saved player position")
	_expect(int(vein.get("remaining_units")) == 3, "reload restores the saved remaining_units for a live vein")

	_expect(bool(registry.call("unregister_vein", VEIN_ID, vein, int(Time.get_unix_time_from_system()))), "unload captures the final live vein record")
	vein.queue_free()
	await process_frame
	_expect(bool(world.call("save_game")), "world save retains a vein record after its live node unloads")
	var unloaded_save := _read_save()
	_expect(int(unloaded_save.get("mineral_veins", {}).get("veins", {}).get(VEIN_ID, {}).get("remaining_units", -1)) == 3, "unloaded vein remains in the serialized registry")
	world.queue_free()
	await process_frame

	replacement_world = WorldScene.instantiate()
	root.add_child(replacement_world)
	await process_frame
	await physics_frame
	var bridge2: Node = replacement_world.get("bridge")
	var registry2: Node = replacement_world.get("mineral_vein_registry")
	var player2 := replacement_world.get_node("Player") as Node3D
	_expect(bool(replacement_world.call("load_game")), "fresh world restores the saved unloaded vein record")
	_expect(int(replacement_world.call("get_inventory_count", "iron_ore")) == 2, "fresh world also restores the shared inventory")
	var legacy_unloaded_save: Dictionary = replacement_world.call("serialize_world_state")
	legacy_unloaded_save.erase("mineral_veins")
	_expect(bool(replacement_world.call("load_world_state_from_dictionary", legacy_unloaded_save)), "legacy save without vein field is accepted before chunk reload")
	var vein2 := _new_iron_vein(replacement_world)
	vein2.set("remaining_units", 8)
	await process_frame
	_expect(bool(registry2.call("register_vein", VEIN_ID, vein2, int(Time.get_unix_time_from_system()))), "new chunk node registers under the saved stable vein ID")
	_expect(int(vein2.get("remaining_units")) == 3, "reloaded chunk node receives its saved vein stock instead of its scene default")

	# Older v2 world saves do not carry mineral_veins; they must not erase live vein state.
	vein2.set("remaining_units", 2)
	var legacy_save: Dictionary = replacement_world.call("serialize_world_state")
	legacy_save.erase("mineral_veins")
	_expect(bool(replacement_world.call("load_world_state_from_dictionary", legacy_save)), "legacy world save without mineral_veins remains compatible")
	_expect(int(vein2.get("remaining_units")) == 2, "legacy save does not erase the current live vein state")

	# Invalid vein records must be rejected before inventory, player or live veins mutate.
	_expect(bool(replacement_world.call("save_game")), "prepare a valid save before the invalid-registry atomicity case")
	var invalid_save := _read_save()
	var invalid_veins: Dictionary = invalid_save.get("mineral_veins", {}).duplicate(true)
	var invalid_records: Dictionary = invalid_veins.get("veins", {}).duplicate(true)
	var invalid_record: Dictionary = invalid_records.get(VEIN_ID, {}).duplicate(true)
	invalid_record["mineral_id"] = "unknown_ore"
	invalid_records[VEIN_ID] = invalid_record
	invalid_veins["veins"] = invalid_records
	invalid_save["mineral_veins"] = invalid_veins
	for suffix in [".bak", ".corrupt"]:
		var path := SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_expect(bool(bridge2.call("collect_world_item", "berries", 1)), "mutate inventory before invalid vein restore")
	player2.global_position = Vector3(8.0, 0.0, 9.0)
	vein2.set("remaining_units", 1)
	_expect(_write_save(invalid_save), "write a syntactically valid save with an invalid mineral ID")
	_expect(not bool(replacement_world.call("load_game")), "invalid mineral registry payload rejects the complete world load")
	_expect(int(replacement_world.call("get_inventory_count", "berries")) == 1, "rejected vein payload does not mutate inventory")
	_expect(player2.global_position.is_equal_approx(Vector3(8.0, 0.0, 9.0)), "rejected vein payload does not mutate player position")
	_expect(int(vein2.get("remaining_units")) == 1, "rejected vein payload does not mutate live vein stock")

	_cleanup_save_files()
	if is_instance_valid(replacement_world):
		replacement_world.queue_free()
	await process_frame
	if failures.is_empty():
		print("World inventory mining and vein persistence integration test passed.")
		_finish(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		_finish(1)

func _new_iron_vein(parent: Node) -> Node3D:
	var vein := MiningNode.new() as Node3D
	vein.name = "LifecycleTestIronVein"
	vein.set("mineral_id", "iron_ore")
	vein.set("remaining_units", 5)
	vein.set("max_units", 8)
	vein.set("units_per_hit", 2)
	vein.set("regen_interval_seconds", 86400)
	vein.set("last_regen_unix", int(Time.get_unix_time_from_system()))
	vein.set("inventory_bridge_path", NodePath("../SurvivalWorldBridge"))
	parent.add_child(vein)
	return vein

func _read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var parser := JSON.new()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not (parser.data is Dictionary):
		return {}
	return parser.data

func _write_save(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func _cleanup_save_files() -> void:
	for path in RELATED_PATHS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _on_timeout() -> void:
	failures.append("world inventory mining and vein persistence watchdog timed out")
	_cleanup_save_files()
	_finish(1)

func _finish(exit_code: int) -> void:
	if is_instance_valid(watchdog):
		watchdog.stop()
		watchdog.queue_free()
	quit(exit_code)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

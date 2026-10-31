extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const CHUNK_ID: String = "surface/chunk_0_0"
const STABLE_ID: String = "surface/chunk_0_0/object/Chunk_0_0/TerrainPatch"
var _test_time: int = 0
var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_time = int(Time.get_unix_time_from_system()) + 10
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld instantiates for terrain persistence coverage")
	if world == null:
		quit(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame

	var controller: Node = world.get("chunk_controller") as Node
	_expect(controller != null, "production world exposes its chunk controller")
	if controller == null:
		await _finish(1)
		return
	var original_patch: Node3D = _find_patch()
	_expect(original_patch != null, "origin surface chunk contains its terrain patch")
	if original_patch == null:
		await _finish(1)
		return
	_expect(str(controller.call("_make_world_object_stable_id", CHUNK_ID, "Chunk_0_0/TerrainPatch")) == STABLE_ID, "terrain patch uses its deterministic stable ID")
	var original_state: Dictionary = original_patch.call("get_world_object_state")
	_expect(not bool(original_patch.call("validate_world_object_state", {"height_level": 3, "surface_type": "soil", "revision": 0})), "terrain state rejects an out-of-range height")
	_expect(not bool(original_patch.call("validate_world_object_state", {"height_level": 0, "surface_type": "lava", "revision": 0})), "terrain state rejects an unknown surface material")
	_expect(original_state == {"height_level": 0, "surface_type": "soil", "revision": 0}, "terrain patch starts from its legacy-safe default state")
	var original_proxy: Area3D = original_patch.get_node_or_null("InteractionArea") as Area3D
	_expect(original_proxy != null and original_proxy.is_inside_tree(), "terrain patch registers an in-tree camera interaction proxy")
	if original_proxy == null:
		await _finish(1)
		return
	var old_patch_instance: int = original_patch.get_instance_id()
	var old_proxy_instance: int = original_proxy.get_instance_id()

	var player: CharacterBody3D = world.get("player") as CharacterBody3D
	var camera: Camera3D = world.get("camera") as Camera3D
	_expect(player != null and camera != null, "production player camera is available")
	if player == null or camera == null:
		await _finish(1)
		return
	player.global_position = Vector3(8.0, 2.0, 5.5)
	camera.global_position = player.global_position + Vector3(0.0, 1.48, 0.0)
	camera.look_at(original_patch.global_position + Vector3(0.0, 0.2, 0.0), Vector3.UP)
	await physics_frame
	var target: Dictionary = world.call("_cast_camera_interaction_target")
	_expect(str(target.get("kind", "")) == "terrain" and target.get("node") == original_patch, "camera ray resolves the terrain patch as a dedicated terrain target")
	if not target.is_empty():
		world.set("_camera_interaction_target_cache", target)
		var touch_buttons: Dictionary = world.get("touch_buttons")
		var touch_button: Button = touch_buttons.get("terrain") as Button
		_expect(touch_button != null, "surface world exposes a terrain touch control")
		if touch_button != null:
			touch_button.emit_signal("pressed")
	var edited_state: Dictionary = original_patch.call("get_world_object_state")
	_expect(edited_state == {"height_level": 1, "surface_type": "rock", "revision": 1}, "touch interaction changes height, material and revision together")
	var save_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not save_payload.is_empty(), "world serialization captures terrain patch state")
	var saved_objects: Dictionary = save_payload.get("world_objects", {}).get("objects", {})
	_expect(saved_objects.has(STABLE_ID), "world save contains the terrain patch stable ID")
	if saved_objects.has(STABLE_ID):
		_expect(saved_objects[STABLE_ID].get("state", {}) == edited_state, "world save contains the exact edited terrain state")
	original_patch.call("cycle_terrain_edit")
	_expect(int(original_patch.call("get_world_object_state").get("height_level", -1)) == 2, "second edit changes the live terrain before restore")
	_expect(bool(world.call("restore_stream_state", save_payload, _test_time)), "schema-1 world restore accepts the saved terrain state")
	_expect(original_patch.call("get_world_object_state") == edited_state, "world save restore reapplies terrain height and material atomically")

	var moved_away: bool = bool(world.call("debug_move_player_to", Vector3(21.5, 2.0, 7.5), _test_time))
	_expect(moved_away, "production director moves the active window away from the origin")
	_expect(not bool(controller.call("is_chunk_loaded", CHUNK_ID)), "controller unloads the edited origin chunk")
	await process_frame
	await process_frame
	_expect(not is_instance_valid(original_patch), "old terrain patch node is released after unload")
	_expect(not is_instance_valid(original_proxy), "old terrain interaction proxy is released after unload")
	var saved_record: Dictionary = world.get("object_state_registry").call("get_object_state", STABLE_ID)
	_expect(saved_record.get("state", {}) == edited_state, "registry retains the edited terrain state while unloaded")

	var returned: bool = bool(world.call("debug_move_player_to", Vector3(8.0, 2.0, 5.5), _test_time + 1))
	_expect(returned, "production director reloads the origin chunk")
	await process_frame
	await physics_frame
	var reloaded_patch: Node3D = _find_patch()
	_expect(reloaded_patch != null, "reloaded origin chunk creates a fresh terrain patch")
	if reloaded_patch != null:
		var reloaded_proxy: Area3D = reloaded_patch.get_node_or_null("InteractionArea") as Area3D
		_expect(reloaded_patch.get_instance_id() != old_patch_instance, "reload creates a new terrain node instance")
		_expect(reloaded_patch.call("get_world_object_state") == edited_state, "fresh terrain patch restores the edited height/material/revision")
		_expect(reloaded_proxy != null and reloaded_proxy.is_inside_tree(), "fresh terrain patch rebuilds its interaction proxy")
		_expect(reloaded_proxy != null and reloaded_proxy.get_instance_id() != old_proxy_instance, "reload creates a new interaction proxy instance")
		var retarget: Dictionary = world.call("_cast_camera_interaction_target")
		_expect(str(retarget.get("kind", "")) == "terrain" and retarget.get("node") == reloaded_patch, "camera ray can select the reloaded terrain patch")
		world.set("_camera_interaction_target_cache", retarget)
		var terrain_key := InputEventKey.new()
		terrain_key.pressed = true
		terrain_key.keycode = KEY_T
		world.call("_unhandled_input", terrain_key)
		_expect(int(reloaded_patch.call("get_world_object_state").get("revision", -1)) == 2, "T keyboard action edits the reloaded terrain through the production target route")
	await _finish(0)

func _find_patch() -> Node3D:
	var root_node: Node3D = world.get("chunk_controller").call("get_chunk_root", CHUNK_ID) as Node3D
	return root_node.get_node_or_null("TerrainPatch") as Node3D if root_node != null else null

func _finish(exit_code: int) -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty() and exit_code == 0:
		print("Production SurfaceWorld terrain patch reload tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const DirectorScript = preload("res://systems/UndergroundMineDirector.gd")
const MINE_CHUNK_ID: String = "underground/mine_0_0"
const INTERACTION_LAYER: int = 1 << 1
const MAX_LAYER_INDEX: int = DirectorScript.MAX_LAYER_INDEX

var failures: Array[String] = []
var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var chunk_controller: Node
var mine_director: Node
var stable_ids: Array[String] = []
var first_node_ids: Array[int] = []
var first_proxy_ids: Array[int] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld instantiates for all-layer lift lifecycle coverage")
	if world == null:
		quit(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	player = world.get("player") as CharacterBody3D
	camera = world.get("camera") as Camera3D
	chunk_controller = world.get("chunk_controller") as Node
	mine_director = world.get("mine_director") as Node
	_expect(player != null and camera != null and chunk_controller != null and mine_director != null, "production world binds player, camera, chunk controller and mine director")
	if player == null or camera == null or chunk_controller == null or mine_director == null:
		await _finish(1)
		return

	var shaft: Node3D = world.get_node_or_null("KrollMineShaftEntrance") as Node3D
	_expect(shaft != null, "surface world exposes the production mine shaft")
	if shaft == null:
		await _finish(1)
		return
	await _aim_at(shaft, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
	_expect(bool(world.call("_toggle_mine_access")), "camera-selected shaft enters the production mine")

	var registry: Node = world.get("object_state_registry") as Node
	_expect(registry != null, "production world binds the shared object-state registry")
	if registry == null:
		await _finish(1)
		return

	for layer_index in range(MAX_LAYER_INDEX + 1):
		var chunk_id: String = _chunk_id(layer_index)
		var chunk_root: Node3D = _get_chunk_root(chunk_id)
		var lift: Node3D = _find_lift(layer_index)
		_expect(chunk_root != null and lift != null, "mine layer %d exposes its stateful lift anchor" % layer_index)
		if chunk_root == null or lift == null:
			await _finish(1)
			return
		var proxy: Area3D = lift.get_node_or_null("InteractionArea") as Area3D
		_expect(_valid_proxy(proxy), "mine layer %d lift owns an in-tree interaction proxy" % layer_index)
		if not _valid_proxy(proxy):
			await _finish(1)
			return

		var stable_id: String = _stable_id(chunk_id, chunk_root, lift)
		stable_ids.append(stable_id)
		first_node_ids.append(lift.get_instance_id())
		first_proxy_ids.append(proxy.get_instance_id())
		_expect(int(lift.get("layer_index")) == layer_index, "mine layer %d lift stores its authored layer index" % layer_index)
		_expect(bool(lift.call("validate_world_object_state", lift.call("get_world_object_state"))), "mine layer %d lift validates its own state payload" % layer_index)

		if layer_index < MAX_LAYER_INDEX:
			await _aim_at(lift, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
			var target: Dictionary = world.call("get_camera_interaction_target")
			_expect(str(target.get("kind", "")) == "lift" and target.get("node") == lift, "camera ray selects layer %d lift" % layer_index)
			_expect(target.get("proxy") == proxy, "layer %d target references its exact live proxy" % layer_index)
			_expect(bool(world.call("_descend_mine_layer")), "V descends from mine layer %d to %d" % [layer_index, layer_index + 1])
			await process_frame
			_expect(not is_instance_valid(chunk_root) and not is_instance_valid(lift) and not is_instance_valid(proxy), "layer %d root, lift and proxy are freed after streaming out" % layer_index)
			var saved_record: Dictionary = registry.call("get_object_state", stable_id)
			_expect(int(saved_record.get("state", {}).get("layer_index", -1)) == layer_index, "layer %d lift state is saved under its stable ID" % layer_index)
			_expect(int(mine_director.call("get_layer_index", player.global_position)) == layer_index + 1, "player arrives at the next authored mine depth")

	var deepest_lift: Node3D = _find_lift(MAX_LAYER_INDEX)
	_expect(deepest_lift != null, "maximum supported mine layer is loaded")
	if deepest_lift != null:
		await _aim_at(deepest_lift, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
		var deepest_position: Vector3 = player.global_position
		var deepest_ids: PackedStringArray = chunk_controller.call("get_loaded_chunk_ids")
		_expect(not bool(world.call("_descend_mine_layer")), "V refuses to descend beyond the maximum supported depth")
		_expect(player.global_position == deepest_position, "rejected maximum-depth descent leaves player position unchanged")
		_expect(chunk_controller.call("get_loaded_chunk_ids") == deepest_ids, "rejected maximum-depth descent leaves the active chunk window unchanged")

	for layer_index in range(MAX_LAYER_INDEX, 0, -1):
		var current_root: Node3D = _get_chunk_root(_chunk_id(layer_index))
		var current_lift: Node3D = _find_lift(layer_index)
		_expect(current_root != null and current_lift != null, "return route has a live lift at layer %d" % layer_index)
		if current_root == null or current_lift == null:
			await _finish(1)
			return
		var current_proxy: Area3D = current_lift.get_node_or_null("InteractionArea") as Area3D
		_expect(_valid_proxy(current_proxy), "return route layer %d has a live interaction proxy" % layer_index)
		await _aim_at(current_lift, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
		var target: Dictionary = world.call("get_camera_interaction_target")
		_expect(str(target.get("kind", "")) == "lift" and target.get("node") == current_lift, "camera ray selects return lift at layer %d" % layer_index)
		_expect(bool(world.call("_toggle_mine_access")), "G ascends from layer %d to %d" % [layer_index, layer_index - 1])
		await process_frame
		_expect(not is_instance_valid(current_root) and not is_instance_valid(current_lift) and not is_instance_valid(current_proxy), "return layer %d root, lift and proxy are released" % layer_index)

		var restored_lift: Node3D = _find_lift(layer_index - 1)
		var restored_root: Node3D = _get_chunk_root(_chunk_id(layer_index - 1))
		_expect(restored_root != null and restored_lift != null, "ascending recreates the layer %d lift" % (layer_index - 1))
		if restored_lift == null:
			await _finish(1)
			return
		var restored_proxy: Area3D = restored_lift.get_node_or_null("InteractionArea") as Area3D
		_expect(_valid_proxy(restored_proxy), "restored layer %d lift receives a fresh proxy" % (layer_index - 1))
		_expect(restored_lift.get_instance_id() != first_node_ids[layer_index - 1], "restored layer %d lift is a new node instance" % (layer_index - 1))
		if _valid_proxy(restored_proxy):
			_expect(restored_proxy.get_instance_id() != first_proxy_ids[layer_index - 1], "restored layer %d lift is a new proxy instance" % (layer_index - 1))
			_expect((restored_proxy.collision_layer & INTERACTION_LAYER) != 0, "restored layer %d proxy retains the interaction collision layer" % (layer_index - 1))
		var restored_id: String = _stable_id(_chunk_id(layer_index - 1), restored_root, restored_lift)
		_expect(restored_id == stable_ids[layer_index - 1], "restored layer %d lift retains its original stable ID" % (layer_index - 1))
		_expect(int(restored_lift.get("layer_index")) == layer_index - 1, "restored layer %d lift restores the correct layer index" % (layer_index - 1))
		var restored_record: Dictionary = registry.call("get_object_state", restored_id)
		_expect(int(restored_record.get("state", {}).get("layer_index", -1)) == layer_index - 1, "restored layer %d registry record remains valid" % (layer_index - 1))

	var origin_lift: Node3D = _find_lift(0)
	_expect(origin_lift != null, "return route reaches the original layer-zero lift")
	if origin_lift != null:
		await _aim_at(origin_lift, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
		_expect(bool(world.call("_toggle_mine_access")), "G returns from layer zero to the surface")
		await process_frame
		_expect(not bool(world.get("_is_underground")), "surface return clears underground mode")

	var saved_ids: PackedStringArray = registry.call("get_saved_ids")
	for layer_index in range(MAX_LAYER_INDEX + 1):
		_expect(saved_ids.has(stable_ids[layer_index]), "world registry retains stable lift ID for layer %d" % layer_index)
		var record: Dictionary = registry.call("get_object_state", stable_ids[layer_index])
		_expect(int(record.get("state", {}).get("layer_index", -1)) == layer_index, "world registry retains layer %d payload after full traversal" % layer_index)

	var save_payload: Dictionary = world.call("serialize_stream_state")
	var world_object_payload: Dictionary = save_payload.get("world_objects", {})
	var saved_objects: Dictionary = world_object_payload.get("objects", {})
	for stable_id in stable_ids:
		_expect(saved_objects.has(stable_id), "world save contains lift state %s" % stable_id)

	await _finish(0 if failures.is_empty() else 1)

func _chunk_id(layer_index: int) -> String:
	return MINE_CHUNK_ID if layer_index == 0 else "underground/layer_%d/mine_0_0" % layer_index

func _get_chunk_root(chunk_id: String) -> Node3D:
	return chunk_controller.call("get_chunk_root", chunk_id) as Node3D

func _find_lift(layer_index: int) -> Node3D:
	var chunk_root: Node3D = _get_chunk_root(_chunk_id(layer_index))
	return chunk_root.get_node_or_null("MineLiftAnchor") as Node3D if chunk_root != null else null

func _stable_id(chunk_id: String, chunk_root: Node3D, lift: Node3D) -> String:
	var local_path: String = "%s/%s" % [str(chunk_root.name), str(lift.name)]
	return str(chunk_controller.call("_make_world_object_stable_id", chunk_id, local_path))

func _valid_proxy(proxy: Area3D) -> bool:
	return proxy != null and is_instance_valid(proxy) and proxy.is_inside_tree() and (proxy.collision_layer & INTERACTION_LAYER) != 0

func _aim_at(target: Node3D, player_offset: Vector3, target_offset: Vector3) -> void:
	player.global_position = target.global_position + player_offset
	camera.look_at(target.global_position + target_offset, Vector3.UP)
	await physics_frame
	await physics_frame

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func _finish(exit_code: int) -> void:
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("Production SurfaceWorld all mine-layers lift lifecycle tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

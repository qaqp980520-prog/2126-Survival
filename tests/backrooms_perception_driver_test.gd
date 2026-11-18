extends SceneTree

const DriverScript = preload("res://systems/BackroomsPerceptionDriver.gd")
const BrainScript = preload("res://systems/BackroomsEntityBrain.gd")

class FakeRuntime:
	extends Node
	var active: bool = true
	var cell_roots: Dictionary = {}
	var last_perceptions: Dictionary = {}

	func is_active() -> bool:
		return active

	func get_loaded_cell_keys() -> Array:
		var keys: Array = cell_roots.keys()
		keys.sort()
		return keys

	func get_cell_root(cell_key: String) -> Node3D:
		var value: Variant = cell_roots.get(cell_key, null)
		if value is Node3D and is_instance_valid(value):
			return value as Node3D
		return null

	func submit_entity_perception(
		cell_key: String,
		entity_id: String,
		perception: Dictionary,
		delta_seconds: float
	) -> Dictionary:
		var cell_root: Node3D = get_cell_root(cell_key)
		if cell_root == null:
			return {"ok": false, "reason": "cell_not_loaded"}
		for child in cell_root.get_children():
			if not (child is Node3D) or str(child.get_meta("backrooms_entity_id", "")) != entity_id:
				continue
			var brain: Node = child.get_node_or_null("AI")
			if brain == null:
				return {"ok": false, "reason": "brain_missing"}
			last_perceptions[cell_key + "|" + entity_id] = perception.duplicate(true)
			var result_value: Variant = brain.call("evaluate_perception", perception, delta_seconds)
			return result_value if result_value is Dictionary else {"ok": false, "reason": "brain_result_invalid"}
		return {"ok": false, "reason": "entity_not_found"}

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _assert_real_line_of_sight_and_noise()
	_assert_round_robin_budget()
	_assert_rejection_and_inactive_reset()
	if failures.is_empty():
		print("Backrooms perception driver tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _assert_real_line_of_sight_and_noise() -> void:
	var world_root := Node3D.new()
	world_root.name = "PerceptionDriverTestWorld"
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var player := CharacterBody3D.new()
	world_root.add_child(player)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.48, 0.0)
	camera.fov = 76.0
	player.add_child(camera)
	var brain: Node = _add_entity(runtime, "cell_0_0", "hound", "Level 2", Vector3(0.0, 0.6, -6.0))
	await physics_frame
	await physics_frame

	var driver = DriverScript.new()
	var throttled: Dictionary = driver.call(
		"tick", runtime, player, camera, world_root.get_world_3d(), 0.05, false, 0.0
	)
	_expect(bool(throttled.get("ok", false)) and int(throttled.get("sampled_count", -1)) == 0, "sensor cadence does not sample before 0.2 seconds")
	var visible_result: Dictionary = driver.call(
		"tick", runtime, player, camera, world_root.get_world_3d(), 0.15, false, 0.0
	)
	_expect(int(visible_result.get("sampled_count", 0)) == 1 and int(visible_result.get("accepted_count", 0)) == 1, "one loaded entity receives a bounded perception sample")
	var visible_perception: Dictionary = runtime.last_perceptions.get("cell_0_0|hound", {})
	_expect(bool(visible_perception.get("has_line_of_sight", false)), "unobstructed physics ray reports entity-to-player line of sight")
	_expect(bool(visible_perception.get("player_looking_at_entity", false)), "camera forward cone reports that the player is looking at the entity")
	_expect(str(brain.call("get_behavior_snapshot").get("state", "")) == "pursue", "visible Hound enters pursue state")

	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector3(0.0, 1.2, -3.0)
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 0.2)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	world_root.add_child(wall)
	await physics_frame
	await physics_frame

	var occluded_result: Dictionary = driver.call(
		"tick", runtime, player, camera, world_root.get_world_3d(), 0.2, false, 0.45
	)
	var occluded_perception: Dictionary = runtime.last_perceptions.get("cell_0_0|hound", {})
	_expect(int(occluded_result.get("accepted_count", 0)) == 1, "occluded entity still receives valid movement-noise perception")
	_expect(not bool(occluded_perception.get("has_line_of_sight", true)), "world geometry blocks entity-to-player line of sight")
	_expect(not bool(occluded_perception.get("player_looking_at_entity", true)), "world geometry blocks player gaze recognition")
	_expect(str(brain.call("get_behavior_snapshot").get("state", "")) == "investigate", "Hound investigates walking noise through an obstructed wall")

	var sprint_result: Dictionary = driver.call(
		"tick", runtime, player, camera, world_root.get_world_3d(), 0.2, false, 0.8
	)
	_expect(int(sprint_result.get("accepted_count", 0)) == 1, "strong movement noise is accepted")
	_expect(str(brain.call("get_behavior_snapshot").get("state", "")) == "pursue", "Hound pursues strong nearby sprint noise without line of sight")
	driver.call("reset")
	runtime.cell_roots.clear()
	runtime.last_perceptions.clear()
	driver = null
	brain = null
	world_root.free()
	await process_frame

func _assert_round_robin_budget() -> void:
	var world_root := Node3D.new()
	world_root.name = "PerceptionBudgetTestWorld"
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var player := CharacterBody3D.new()
	world_root.add_child(player)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.48, 0.0)
	player.add_child(camera)
	for index in range(13):
		_add_entity(
			runtime,
			"cell_%02d" % index,
			"hound",
			"Level 2",
			Vector3(float(index) * 0.25, 0.6, -6.0)
		)
	await physics_frame
	var driver = DriverScript.new()
	var first: Dictionary = driver.call(
		"tick", runtime, player, camera, world_root.get_world_3d(), 0.2, false, 0.8
	)
	_expect(int(first.get("sampled_count", 0)) == 12, "one sensor tick never exceeds the 12-entity work budget")
	_expect(int(first.get("pending_count", 0)) == 1, "round-robin scheduler reports the unsampled entity")
	var second: Dictionary = driver.call(
		"tick", runtime, player, camera, world_root.get_world_3d(), 0.2, false, 0.8
	)
	_expect(int(second.get("sampled_count", 0)) == 1, "next sensor tick services the remaining entity")
	_expect(int(second.get("pending_count", -1)) == 0, "round-robin scheduler drains the complete loaded entity set")
	driver.call("reset")
	runtime.cell_roots.clear()
	driver = null
	world_root.free()
	await process_frame

func _assert_rejection_and_inactive_reset() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var player := CharacterBody3D.new()
	world_root.add_child(player)
	var camera := Camera3D.new()
	player.add_child(camera)
	_add_entity(runtime, "cell", "hound", "Level 2", Vector3(0.0, 0.6, -5.0))
	var driver = DriverScript.new()
	var invalid: Dictionary = driver.call(
		"tick", runtime, player, camera, world_root.get_world_3d(), 0.2, false, NAN
	)
	_expect(not bool(invalid.get("ok", true)) and str(invalid.get("reason", "")) == "movement_noise_strength_invalid", "non-finite noise input is rejected before sampling")
	runtime.active = false
	var inactive: Dictionary = driver.call(
		"tick", runtime, player, camera, world_root.get_world_3d(), 0.2, false, 0.0
	)
	_expect(not bool(inactive.get("ok", true)) and str(inactive.get("reason", "")) == "runtime_inactive", "inactive Backrooms Runtime is rejected and scheduler state is reset")
	driver.call("reset")
	runtime.cell_roots.clear()
	driver = null
	world_root.free()
	await process_frame

func _add_entity(
	runtime: FakeRuntime,
	cell_key: String,
	entity_id: String,
	level_id: String,
	position: Vector3
) -> Node:
	var cell_root := Node3D.new()
	cell_root.name = "Cell_" + cell_key
	runtime.add_child(cell_root)
	runtime.cell_roots[cell_key] = cell_root
	var entity_root := Node3D.new()
	entity_root.name = "Entity_" + entity_id
	entity_root.position = position
	entity_root.set_meta("backrooms_entity_id", entity_id)
	cell_root.add_child(entity_root)
	var brain: Node = BrainScript.new()
	brain.name = "AI"
	brain.call("configure", entity_id, level_id, Vector2i.ZERO, 20261118)
	entity_root.add_child(brain)
	return brain

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

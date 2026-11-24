extends SceneTree

const DriverScript = preload("res://systems/BackroomsEntityCombatDriver.gd")
const BrainScript = preload("res://systems/BackroomsEntityBrain.gd")
const HealthScript = preload("res://systems/SurvivalHealth.gd")

class FakeRuntime extends Node:
	var active: bool = true
	var cell_roots: Dictionary = {}

	func is_active() -> bool:
		return active

	func get_loaded_cell_keys() -> Array:
		var keys: Array = cell_roots.keys()
		keys.sort()
		return keys

	func get_cell_root(cell_key: String) -> Node3D:
		var value: Variant = cell_roots.get(cell_key, null)
		return value as Node3D if value is Node3D and is_instance_valid(value) else null

	func add_cell(cell_key: String, cell_root: Node3D) -> void:
		cell_roots[cell_key] = cell_root
		add_child(cell_root)

class CountingHealth extends RefCounted:
	var total_damage: float = 0.0
	var events: int = 0

	func is_alive() -> bool:
		return true

	func apply_damage(amount: float, source_entity_id: String) -> Dictionary:
		if not is_finite(amount) or amount <= 0.0 or source_entity_id != "hound":
			return {"ok": false, "reason": "damage_contract_invalid"}
		total_damage += amount
		events += 1
		return {"ok": true, "applied": amount, "defeated": false}

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _assert_melee_cooldown_and_occlusion()
	await _assert_round_robin_budget()
	if failures.is_empty():
		print("Backrooms Hound combat driver tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _assert_melee_cooldown_and_occlusion() -> void:
	var world_root := Node3D.new()
	world_root.name = "HoundCombatTestWorld"
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root := Node3D.new()
	cell_root.name = "Cell_0_0"
	cell_root.set_meta("backrooms_level_id", "Level 2")
	cell_root.set_meta("backrooms_world_seed", 20261125)
	runtime.add_cell("0,0", cell_root)
	var player := CharacterBody3D.new()
	player.collision_layer = 1
	player.collision_mask = 1
	world_root.add_child(player)
	var hound: CharacterBody3D = _add_hound(cell_root, Vector2i.ZERO, Vector3(0.0, 0.0, -0.9))
	await physics_frame
	await physics_frame
	var brain: Node = hound.get_node("AI")
	var visible_noisy_snapshot: Dictionary = brain.call("get_behavior_snapshot")
	_expect(
		str(visible_noisy_snapshot.get("target_source", "")) == "player",
		"visible player remains the explicit melee target even while movement noise is present"
	)
	var driver: RefCounted = DriverScript.new()
	var health: RefCounted = HealthScript.new()
	var first: Dictionary = driver.call("tick", runtime, player, world_root.get_world_3d(), health, 0.1)
	_expect(int(first.get("attacked_count", 0)) == 1, "nearby pursuing Hound performs one melee attack")
	_expect(is_equal_approx(float(health.call("get_current_health")), 88.0), "first Hound attack applies twelve health damage")
	var target_root := Node3D.new()
	target_root.name = "Cell_1_0"
	target_root.set_meta("backrooms_level_id", "Level 2")
	target_root.set_meta("backrooms_world_seed", 20261125)
	runtime.add_cell("1,0", target_root)
	var hound_transform: Transform3D = hound.global_transform
	cell_root.remove_child(hound)
	target_root.add_child(hound)
	hound.global_transform = hound_transform
	hound.set_meta("backrooms_owner_cell_key", "1,0")
	await physics_frame
	var cooldown: Dictionary = driver.call("tick", runtime, player, world_root.get_world_3d(), health, 0.1)
	_expect(int(cooldown.get("attacked_count", -1)) == 0, "Hound transfer to a new owner cell preserves its immutable-identity cooldown")
	_expect(is_equal_approx(float(health.call("get_current_health")), 88.0), "cross-cell transfer cannot reset the Hound damage cooldown")

	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector3(0.0, 0.75, -0.45)
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(2.0, 2.0, 0.12)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	world_root.add_child(wall)
	await physics_frame
	await physics_frame
	for _wait_index in range(3):
		driver.call("tick", runtime, player, world_root.get_world_3d(), health, 0.5)
		await physics_frame
	_expect(is_equal_approx(float(health.call("get_current_health")), 88.0), "world geometry blocks Hound melee damage after cooldown expires")
	_expect(str(brain.call("get_behavior_snapshot").get("state", "")) == "pursue", "occlusion test retains the Hound pursuit state")
	wall.queue_free()
	await physics_frame
	await physics_frame
	var after_wall: Dictionary = driver.call("tick", runtime, player, world_root.get_world_3d(), health, 0.1)
	_expect(int(after_wall.get("attacked_count", 0)) == 1, "Hound attacks after the line of sight is restored")
	_expect(is_equal_approx(float(health.call("get_current_health")), 76.0), "second valid attack applies damage once")

	var patrol: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 20.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0,
		"player_position": player.global_position
	}, 0.2)
	_expect(bool(patrol.get("ok", false)) and str(patrol.get("state", "")) == "patrol", "Hound leaves pursuit when the player is no longer perceived")
	for _wait_index in range(3):
		driver.call("tick", runtime, player, world_root.get_world_3d(), health, 0.5)
		await physics_frame
	_expect(is_equal_approx(float(health.call("get_current_health")), 76.0), "patrolling Hound cannot damage the player")
	var distracted: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 0.9,
		"has_line_of_sight": false,
		"noise_strength": 1.0,
		"noise_distance": 0.5,
		"noise_position": Vector3(10.0, 0.0, 10.0),
		"player_position": player.global_position
	}, 0.2)
	_expect(bool(distracted.get("ok", false)) and str(distracted.get("state", "")) == "pursue", "Hound can pursue a non-player noise target")
	for _wait_index in range(3):
		driver.call("tick", runtime, player, world_root.get_world_3d(), health, 0.5)
		await physics_frame
	_expect(is_equal_approx(float(health.call("get_current_health")), 76.0), "Hound pursuing a distant noise target cannot damage the nearby player")
	var nearby_noise: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 0.9,
		"has_line_of_sight": false,
		"noise_strength": 1.0,
		"noise_distance": 0.5,
		"noise_position": player.global_position + Vector3(0.2, 0.0, 0.0),
		"player_position": player.global_position
	}, 0.2)
	var nearby_noise_target: Vector3 = nearby_noise.get("target_position", Vector3.ZERO)
	_expect(
		str(nearby_noise.get("state", "")) == "pursue"
		and str(nearby_noise.get("target_source", "")) == "noise"
		and nearby_noise_target.distance_to(player.global_position) <= 2.5,
		"nearby unrelated noise can place a Hound in pursue state with a target near the player"
	)
	for _wait_index in range(3):
		driver.call("tick", runtime, player, world_root.get_world_3d(), health, 0.5)
		await physics_frame
	_expect(is_equal_approx(float(health.call("get_current_health")), 76.0), "noise-driven pursuit near the player cannot trigger a false melee attack")
	var smiler := CharacterBody3D.new()
	smiler.name = "Smiler_NonCombat"
	smiler.collision_layer = 1 << 2
	smiler.collision_mask = 1
	smiler.position = Vector3(0.0, 0.0, -0.5)
	smiler.set_meta("backrooms_entity_id", "smiler")
	smiler.set_meta("spawn_cell", Vector2i(5, 5))
	var smiler_brain: Node = BrainScript.new()
	smiler_brain.name = "AI"
	smiler.add_child(smiler_brain)
	smiler_brain.call("configure", "smiler", "Level 1", Vector2i(5, 5), 20261125)
	smiler_brain.call("evaluate_perception", {
		"distance_to_player": 0.5,
		"has_line_of_sight": true,
		"is_dark": true,
		"player_position": player.global_position
	}, 0.2)
	target_root.add_child(smiler)
	await physics_frame
	for _wait_index in range(3):
		driver.call("tick", runtime, player, world_root.get_world_3d(), health, 0.5)
		await physics_frame
	_expect(is_equal_approx(float(health.call("get_current_health")), 76.0), "non-Hound entities do not use the Hound melee damage path")
	brain.call("evaluate_perception", {
		"distance_to_player": 0.9,
		"has_line_of_sight": true,
		"noise_strength": 0.0,
		"player_position": player.global_position
	}, 0.2)
	health.call("apply_damage", 200.0, "test")
	var defeated: Dictionary = driver.call("tick", runtime, player, world_root.get_world_3d(), health, 0.1)
	_expect(int(defeated.get("attacked_count", -1)) == 0, "defeated player receives no further Hound attacks")
	_expect(is_equal_approx(float(health.call("get_current_health")), 0.0), "combat driver preserves the defeated health state")
	world_root.queue_free()
	await process_frame

func _assert_round_robin_budget() -> void:
	var world_root := Node3D.new()
	world_root.name = "HoundCombatBudgetTestWorld"
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root := Node3D.new()
	cell_root.name = "Cell_0_0"
	runtime.add_cell("0,0", cell_root)
	var player := CharacterBody3D.new()
	player.collision_layer = 1
	player.collision_mask = 1
	world_root.add_child(player)
	for index in range(13):
		_add_hound(cell_root, Vector2i(index, 0), Vector3(0.0, 0.0, -0.9))
	await physics_frame
	await physics_frame
	var driver: RefCounted = DriverScript.new()
	var health := CountingHealth.new()
	var first: Dictionary = driver.call("tick", runtime, player, world_root.get_world_3d(), health, 0.1)
	_expect(int(first.get("sampled_count", -1)) == 12, "combat driver respects its twelve-entity per-tick budget")
	_expect(int(first.get("pending_count", -1)) == 1, "combat driver reports the unprocessed entity")
	_expect(int(first.get("attacked_count", -1)) == 12 and health.events == 12, "first round-robin batch processes twelve eligible Hounds")
	var second: Dictionary = driver.call("tick", runtime, player, world_root.get_world_3d(), health, 0.1)
	_expect(int(second.get("sampled_count", -1)) == 12 and int(second.get("pending_count", -1)) == 1, "round-robin cursor includes the thirteenth Hound in the next bounded batch")
	_expect(int(second.get("attacked_count", -1)) == 1 and health.events == 13, "thirteenth Hound is not starved by the bounded budget")
	_expect(is_equal_approx(health.total_damage, 156.0), "thirteen attacks apply exactly thirteen bounded damage events")
	world_root.queue_free()
	await process_frame

func _add_hound(cell_root: Node3D, spawn_cell: Vector2i, position: Vector3) -> CharacterBody3D:
	var hound := CharacterBody3D.new()
	hound.name = "Hound_%d_%d" % [spawn_cell.x, spawn_cell.y]
	hound.collision_layer = 1 << 2
	hound.collision_mask = 1
	hound.position = position
	hound.set_meta("backrooms_entity_id", "hound")
	hound.set_meta("spawn_cell", spawn_cell)
	var brain: Node = BrainScript.new()
	brain.name = "AI"
	hound.add_child(brain)
	brain.call("configure", "hound", "Level 2", spawn_cell, 20261125)
	brain.call("evaluate_perception", {
		"distance_to_player": 0.9,
		"has_line_of_sight": true,
		"noise_strength": 0.8,
		"noise_distance": 0.9,
		"noise_position": Vector3.ZERO,
		"player_position": Vector3.ZERO
	}, 0.2)
	cell_root.add_child(hound)
	return hound

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FAIL: " + message)

extends SceneTree

const BrainScript = preload("res://systems/BackroomsEntityBrain.gd")
const MovementDriverScript = preload("res://systems/BackroomsEntityMovementDriver.gd")

class FakeRuntime:
	extends Node
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
		if value is Node3D and is_instance_valid(value):
			return value as Node3D
		return null

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _assert_same_cell_pursuit_moves_toward_player()
	await _assert_smiler_approach_uses_unseen_player_target()
	await _assert_cross_cell_target_fails_closed()
	await _assert_avoidance_moves_away_from_player()
	await _assert_duller_retreat_moves_away_from_player()
	await _assert_patrol_moves_within_cell()
	await _assert_deathmoth_aerial_patrol_changes_height()
	await _assert_anchored_entities_remain_stationary()
	await _assert_round_robin_movement_budget()
	await _assert_invalid_and_inactive_runtime_rejection()
	if failures.is_empty():
		print("Backrooms entity movement driver tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _assert_same_cell_pursuit_moves_toward_player() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "hound", "Level 2", Vector2i.ZERO, 20261118, Vector3.ZERO)
	var brain: Node = entity["brain"] as Node as Node
	var entity_root: Node3D = entity["root"] as Node3D as Node3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 3.0,
		"has_line_of_sight": true,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"player_position": Vector3(3.0, 0.0, 0.0)
	}, 0.2)
	_expect(str(decision.get("state", "")) == "pursue", "visible nearby Hound receives a pursue movement intent")
	await process_frame
	var start_position: Vector3 = entity_root.global_position
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("moved_count", 0)) == 1, "bounded movement driver updates one eligible entity")
	_expect(entity_root.global_position.x > start_position.x, "Hound moves toward a same-cell player target")
	_expect(str(entity_root.get_meta("backrooms_movement_mode", "")) == "cell_local_kinematic_v1", "movement mode is explicitly marked as cell-local kinematic")
	driver.call("reset")
	world_root.free()
	await process_frame

func _assert_smiler_approach_uses_unseen_player_target() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "smiler", "Level 1", Vector2i.ZERO, 19, Vector3.ZERO)
	var brain: Node = entity["brain"] as Node as Node
	var entity_root: Node3D = entity["root"] as Node3D as Node3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 4.0,
		"has_line_of_sight": false,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"is_dark": true,
		"player_position": Vector3(3.0, 0.0, 0.0)
	}, 0.2)
	_expect(str(decision.get("state", "")) == "approach", "dark unseen Smiler receives an approach intent")
	_expect(bool(decision.get("has_target_position", false)), "unseen Smiler retains the current player position as its target")
	await process_frame
	var start_x: float = entity_root.global_position.x
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("moved_count", 0)) == 1, "Smiler receives a bounded approach movement update")
	_expect(entity_root.global_position.x > start_x, "Smiler approaches the unseen player while its cell is dark")
	driver.call("reset")
	world_root.free()
	await process_frame

func _assert_cross_cell_target_fails_closed() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "hound", "Level 2", Vector2i.ZERO, 7, Vector3.ZERO)
	var brain: Node = entity["brain"] as Node
	var entity_root: Node3D = entity["root"] as Node3D
	brain.call("evaluate_perception", {
		"distance_to_player": 8.0,
		"has_line_of_sight": true,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"player_position": Vector3(8.0, 0.0, 0.0)
	}, 0.2)
	await process_frame
	var start_position: Vector3 = entity_root.global_position
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("blocked_count", 0)) == 1, "cross-cell movement is rejected until roaming ownership is implemented")
	_expect(entity_root.global_position.is_equal_approx(start_position), "entity never crosses an unloaded or unowned cell boundary")
	driver.call("reset")
	world_root.free()
	await process_frame

func _assert_avoidance_moves_away_from_player() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "faceling", "Level 3", Vector2i.ZERO, 11, Vector3(0.5, 0.0, 0.0))
	var brain: Node = entity["brain"] as Node
	var entity_root: Node3D = entity["root"] as Node3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 2.0,
		"has_line_of_sight": false,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"player_position": Vector3(2.5, 0.0, 0.0)
	}, 0.2)
	_expect(str(decision.get("state", "")) == "avoid", "Faceling avoidance state retains the player position without line of sight")
	_expect(bool(decision.get("has_target_position", false)), "avoidance decision exposes a valid movement target")
	await process_frame
	var start_x: float = entity_root.global_position.x
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("moved_count", 0)) == 1, "Faceling receives a bounded avoidance movement update")
	_expect(entity_root.global_position.x < start_x, "Faceling moves away from the nearby player")
	driver.call("reset")
	world_root.free()
	await process_frame

func _assert_duller_retreat_moves_away_from_player() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "duller", "Level 4", Vector2i.ZERO, 23, Vector3(0.5, 0.0, 0.0))
	var brain: Node = entity["brain"] as Node as Node
	var entity_root: Node3D = entity["root"] as Node3D as Node3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 5.0,
		"has_line_of_sight": false,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"player_position": Vector3(2.5, 0.0, 0.0)
	}, 0.2)
	_expect(str(decision.get("state", "")) == "retreat", "Duller enters retreat without line of sight")
	await process_frame
	var start_x: float = entity_root.global_position.x
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("moved_count", 0)) == 1, "Duller receives a bounded retreat movement update")
	_expect(entity_root.global_position.x < start_x, "Duller withdraws from the nearby player")
	driver.call("reset")
	world_root.free()
	await process_frame

func _assert_patrol_moves_within_cell() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "hound", "Level 2", Vector2i(3, -2), 2026, Vector3.ZERO)
	var brain: Node = entity["brain"] as Node
	var entity_root: Node3D = entity["root"] as Node3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 30.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}, 0.2)
	_expect(str(decision.get("state", "")) == "patrol", "Hound selects patrol when no player or sound signal is available")
	await process_frame
	var start_position: Vector3 = entity_root.global_position
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("moved_count", 0)) == 1, "patrolling Hound receives a movement update")
	_expect(entity_root.global_position.distance_to(start_position) > 0.01, "patrol waypoint produces actual movement")
	var local_position: Vector3 = cell_root.to_local(entity_root.global_position)
	_expect(absf(local_position.x) <= 3.35 and absf(local_position.z) <= 3.35, "patrol remains inside the safe owning-cell bounds")
	driver.call("reset")
	world_root.free()
	await process_frame

func _assert_deathmoth_aerial_patrol_changes_height() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var entity: Dictionary = _add_entity(cell_root, "deathmoth", "Level 5", Vector2i.ZERO, 29, Vector3(0.0, 1.55, 0.0))
	var brain: Node = entity["brain"] as Node as Node
	var entity_root: Node3D = entity["root"] as Node3D as Node3D
	var decision: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 30.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}, 0.2)
	_expect(str(decision.get("state", "")) == "fly_patrol", "Deathmoth selects aerial patrol without a player signal")
	await process_frame
	var start_y: float = entity_root.global_position.y
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("moved_count", 0)) == 1, "Deathmoth receives a bounded aerial patrol update")
	_expect(entity_root.global_position.y > start_y, "Deathmoth changes altitude during its aerial patrol")
	driver.call("reset")
	world_root.free()
	await process_frame

func _assert_anchored_entities_remain_stationary() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var cell_root: Node3D = _add_cell(runtime, "0,0", Vector2i.ZERO)
	var window_entity: Dictionary = _add_entity(cell_root, "window", "Level 1", Vector2i.ZERO, 31, Vector3(0.0, 1.2, -3.9))
	var clump_entity: Dictionary = _add_entity(cell_root, "clump", "Level 3", Vector2i.ZERO, 37, Vector3(0.0, 0.42, 0.0))
	var window_root: Node3D = window_entity["root"] as Node3D
	var clump_root: Node3D = clump_entity["root"] as Node3D
	(window_entity["brain"] as Node).call("evaluate_perception", {
		"distance_to_player": 2.0,
		"has_line_of_sight": true,
		"player_looking_at_entity": true,
		"noise_strength": 0.0,
		"player_position": Vector3(1.0, 0.0, 0.0)
	}, 0.2)
	(clump_entity["brain"] as Node).call("evaluate_perception", {
		"distance_to_player": 4.0,
		"has_line_of_sight": true,
		"noise_strength": 0.0,
		"player_position": Vector3(1.0, 0.0, 0.0)
	}, 0.2)
	await process_frame
	var window_start: Vector3 = window_root.global_position
	var clump_start: Vector3 = clump_root.global_position
	var driver = MovementDriverScript.new()
	var result: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(result.get("total_count", 0)) == 0, "Window and Clump are excluded from mobile entity scheduling")
	_expect(window_root.global_position.is_equal_approx(window_start), "Window remains attached to its wall")
	_expect(clump_root.global_position.is_equal_approx(clump_start), "Clump remains anchored in its cell")
	driver.call("reset")
	world_root.free()
	await process_frame

func _assert_round_robin_movement_budget() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	for index in range(13):
		var cell := Vector2i(index, 0)
		var key: String = "%d,0" % index
		var cell_root: Node3D = _add_cell(runtime, key, cell)
		var entity: Dictionary = _add_entity(cell_root, "hound", "Level 2", cell, 100 + index, Vector3.ZERO)
		var brain: Node = entity["brain"] as Node
		brain.call("evaluate_perception", {
			"distance_to_player": 30.0,
			"has_line_of_sight": false,
			"noise_strength": 0.0
		}, 0.2)
	await process_frame
	var driver = MovementDriverScript.new()
	var first: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(first.get("sampled_count", 0)) == 12, "one movement tick never exceeds the 12-entity work budget")
	_expect(int(first.get("pending_count", -1)) == 1, "round-robin movement reports one deferred entity")
	var second: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(int(second.get("sampled_count", 0)) == 1, "the next movement tick services the deferred entity")
	_expect(int(second.get("pending_count", -1)) == 0, "round-robin movement drains the complete entity set")
	driver.call("reset")
	world_root.free()
	await process_frame

func _assert_invalid_and_inactive_runtime_rejection() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var runtime := FakeRuntime.new()
	world_root.add_child(runtime)
	var driver = MovementDriverScript.new()
	var invalid: Dictionary = driver.call("tick", runtime, NAN)
	_expect(not bool(invalid.get("ok", true)) and str(invalid.get("reason", "")) == "delta_seconds_invalid", "non-finite movement delta is rejected")
	var hitch: Dictionary = driver.call("tick", runtime, 2.0)
	_expect(bool(hitch.get("ok", false)) and int(hitch.get("tick_index", 0)) == 5, "large frame hitches are capped to half a second of movement scheduling")
	runtime.active = false
	var inactive: Dictionary = driver.call("tick", runtime, 0.1)
	_expect(not bool(inactive.get("ok", true)) and str(inactive.get("reason", "")) == "runtime_inactive", "inactive Backrooms Runtime is rejected and movement state resets")
	driver.call("reset")
	world_root.free()
	await process_frame

func _add_cell(runtime: FakeRuntime, cell_key: String, cell: Vector2i) -> Node3D:
	var cell_root := Node3D.new()
	cell_root.name = "Cell_" + cell_key.replace(",", "_")
	cell_root.position = Vector3(float(cell.x) * 8.0, 0.0, float(cell.y) * 8.0)
	cell_root.set_meta("backrooms_cell", cell)
	cell_root.set_meta("backrooms_cell_size", 8.0)
	cell_root.set_meta("backrooms_cell_key", cell_key)
	runtime.add_child(cell_root)
	runtime.cell_roots[cell_key] = cell_root
	return cell_root

func _add_entity(
	cell_root: Node3D,
	entity_id: String,
	level_id: String,
	spawn_cell: Vector2i,
	world_seed: int,
	local_position: Vector3
) -> Dictionary:
	var entity_root := Node3D.new()
	entity_root.name = "Entity_" + entity_id
	entity_root.position = local_position
	entity_root.set_meta("backrooms_entity_id", entity_id)
	entity_root.set_meta("spawn_cell", spawn_cell)
	entity_root.set_meta("spawn_world_seed", world_seed)
	cell_root.add_child(entity_root)
	var brain: Node = BrainScript.new()
	brain.name = "AI"
	_expect(bool(brain.call("configure", entity_id, level_id, spawn_cell, world_seed)), "%s brain configures for its allowed level" % entity_id)
	entity_root.add_child(brain)
	return {"root": entity_root, "brain": brain}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

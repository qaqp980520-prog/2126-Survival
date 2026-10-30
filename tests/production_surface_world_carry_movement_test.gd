extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld scene instantiates")
	if world == null:
		_finish(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	var bridge: Node = world.get("inventory_bridge") as Node
	_expect(bridge != null, "production world exposes the shared inventory bridge")
	if bridge == null:
		_finish(1)
		return

	var profile: Dictionary = world.call("get_player_movement_profile")
	_expect(is_equal_approx(float(profile.get("weight_kg", -1.0)), 0.0), "new world starts with zero carry weight")
	_expect(is_equal_approx(float(profile.get("move_speed", -1.0)), 5.0), "normal carry weight preserves the 5 m/s base speed")
	_expect(bool(profile.get("can_jump", false)), "normal carry weight permits jumping")

	world.call("_set_touch_direction", "forward")
	await physics_frame
	_expect(_horizontal_speed() > 4.8 and _horizontal_speed() < 5.2, "actual production movement uses the normal base speed")

	_expect(bool(bridge.call("collect_world_item", "iron_ore", 21)), "21 iron ore can be collected through the shared bridge")
	profile = world.call("get_player_movement_profile")
	_expect(is_equal_approx(float(profile.get("weight_kg", -1.0)), 63.0), "63 kg remains below the 65 kg day-one carry limit")
	_expect(is_equal_approx(float(profile.get("movement_multiplier", -1.0)), 1.0), "weight at 63 kg has no movement penalty")

	_expect(bool(bridge.call("collect_world_item", "iron_ore", 1)), "the 22nd iron ore can be collected")
	profile = world.call("get_player_movement_profile")
	_expect(is_equal_approx(float(profile.get("weight_kg", -1.0)), 66.0), "66 kg crosses the day-one carry limit")
	_expect(is_equal_approx(float(profile.get("movement_multiplier", -1.0)), 0.68), "overweight movement multiplier is 0.68")
	_expect(bool(profile.get("can_jump", false)), "ordinary overweight does not disable jumping")
	await physics_frame
	_expect(absf(_horizontal_speed() - 3.4) < 0.08, "actual movement speed drops immediately to 3.4 m/s")

	_expect(bool(bridge.call("collect_world_item", "iron_ore", 8)), "inventory can reach exactly 90 kg")
	profile = world.call("get_player_movement_profile")
	_expect(is_equal_approx(float(profile.get("weight_kg", -1.0)), 90.0), "exactly 90 kg is not classified as super-heavy")
	_expect(is_equal_approx(float(profile.get("movement_multiplier", -1.0)), 0.68), "exactly 90 kg retains the overweight multiplier")
	_expect(bool(profile.get("can_jump", false)), "exactly 90 kg still permits jumping")

	_expect(bool(bridge.call("collect_world_item", "iron_ore", 1)), "one more ore crosses the super-heavy threshold")
	profile = world.call("get_player_movement_profile")
	_expect(is_equal_approx(float(profile.get("weight_kg", -1.0)), 93.0), "super-heavy test weight is 93 kg")
	_expect(is_equal_approx(float(profile.get("movement_multiplier", -1.0)), 0.42), "super-heavy movement multiplier is 0.42")
	_expect(not bool(profile.get("can_jump", true)), "weight above 90 kg disables jumping")
	await physics_frame
	_expect(absf(_horizontal_speed() - 2.1) < 0.08, "actual production movement speed drops to 2.1 m/s")

	world.call("_clear_touch_direction", "forward")
	world.player.global_position = Vector3(1.0, 0.0, 1.0)
	world.player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	_expect(not bool(world.call("can_player_jump_now")), "super-heavy player jump gate is closed")
	world.call("_set_touch_jump", true)
	await physics_frame
	_expect(world.player.velocity.y <= 0.1, "super-heavy touch jump does not launch the player")

	_expect(bool(bridge.call("drop_item", "iron_ore", 1)), "dropping one ore succeeds")
	profile = world.call("get_player_movement_profile")
	_expect(is_equal_approx(float(profile.get("weight_kg", -1.0)), 90.0), "dropping one ore immediately returns weight to 90 kg")
	_expect(is_equal_approx(float(profile.get("movement_multiplier", -1.0)), 0.68), "dropping below the super-heavy threshold restores the overweight multiplier immediately")
	_expect(bool(profile.get("can_jump", false)), "dropping to 90 kg immediately restores jump permission")
	world.call("_set_touch_jump", false)
	await physics_frame
	world.call("_set_touch_jump", true)
	await physics_frame
	_expect(world.player.velocity.y > 0.1, "jump becomes available again after the weight threshold is crossed downward")
	world.call("_set_touch_jump", false)
	_expect(absf(float(world.call("get_effective_move_speed")) - 3.4) < 0.001, "effective movement speed is recalculated immediately after dropping weight")

	var hud: Label = world.get("hud") as Label
	_expect(hud != null and hud.text.contains("Move: 68%") and hud.text.contains("JUMP READY"), "HUD reports live movement penalty and jump status")
	_finish(0 if failures.is_empty() else 1)

func _horizontal_speed() -> float:
	return Vector2(world.player.velocity.x, world.player.velocity.z).length()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish(exit_code: int) -> void:
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("Production surface world carry movement tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

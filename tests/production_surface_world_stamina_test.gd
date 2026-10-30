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
	var stamina: RefCounted = world.get("stamina") as RefCounted
	var bridge: Node = world.get("inventory_bridge") as Node
	_expect(stamina != null and bridge != null, "production world binds stamina and the shared inventory bridge")
	if stamina == null or bridge == null:
		_finish(1)
		return
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 100.0), "production stamina starts full")
	var profile: Dictionary = world.call("get_player_movement_profile")
	_expect(bool(profile.get("can_jump", false)), "full stamina and normal carry weight permit jumping")

	world.call("_tick_stamina", 1.0, true)
	var normal_remaining: float = float(stamina.get("current_stamina"))
	_expect(is_equal_approx(normal_remaining, 98.0), "production activity hook applies normal movement drain")
	_expect(bool(bridge.call("collect_world_item", "iron_ore", 22)), "inventory accepts 66 kg of iron ore")
	world.call("_tick_stamina", 1.0, true)
	var overweight_remaining: float = float(stamina.get("current_stamina"))
	var overweight_drain: float = normal_remaining - overweight_remaining
	_expect(overweight_drain > 2.8 and overweight_drain < 3.1, "production overweight movement drains more stamina than normal movement")
	_expect(bool(bridge.call("collect_world_item", "iron_ore", 9)), "inventory reaches 93 kg")
	world.call("_tick_stamina", 1.0, true)
	var super_heavy_remaining: float = float(stamina.get("current_stamina"))
	var super_heavy_drain: float = overweight_remaining - super_heavy_remaining
	_expect(super_heavy_drain > overweight_drain, "production super-heavy movement has the highest stamina drain")
	_expect(not bool(world.call("can_player_jump_now")), "super-heavy carry state blocks jumping")

	_expect(bool(bridge.call("drop_item", "iron_ore", 10)), "dropping ten ore returns weight to 63 kg")
	profile = world.call("get_player_movement_profile")
	_expect(is_equal_approx(float(profile.get("weight_kg", -1.0)), 63.0), "weight recalculates immediately after dropping cargo")
	_expect(bool(profile.get("can_jump", false)), "normal carry weight restores the jump gate")
	var save_payload: Dictionary = world.call("serialize_stream_state")
	_expect(save_payload.has("stamina") and save_payload["stamina"] is Dictionary, "production world save includes stamina")
	var saved_stamina: float = float(save_payload["stamina"].get("current", -1.0))
	stamina.call("add_stamina", 5.0)
	_expect(float(stamina.get("current_stamina")) > saved_stamina, "test changes stamina after taking a save snapshot")
	_expect(bool(world.call("restore_stream_state", save_payload, int(Time.get_unix_time_from_system()))), "production world restores the schema-1 save with stamina")
	_expect(is_equal_approx(float(stamina.get("current_stamina")), saved_stamina), "world restore recovers the saved stamina value")

	var legacy_payload: Dictionary = save_payload.duplicate(true)
	legacy_payload.erase("stamina")
	stamina.call("tick", 20.0, true, 1.0)
	_expect(float(stamina.get("current_stamina")) < 100.0, "legacy restore setup changes current stamina")
	_expect(bool(world.call("restore_stream_state", legacy_payload, int(Time.get_unix_time_from_system()))), "legacy schema-1 world save without stamina remains compatible")
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 100.0), "legacy save without stamina defaults the player to full stamina")

	stamina.set("current_stamina", 55.0)
	var invalid_payload: Dictionary = world.call("serialize_stream_state")
	invalid_payload["stamina"]["current"] = 100.01
	var position_before: Vector3 = world.player.global_position
	var weight_before: float = float(bridge.call("get_weight_kg"))
	_expect(not bool(world.call("restore_stream_state", invalid_payload, int(Time.get_unix_time_from_system()))), "invalid stamina payload is rejected before world mutation")
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 55.0), "invalid stamina payload preserves current stamina")
	_expect(world.player.global_position.is_equal_approx(position_before), "invalid stamina payload preserves player position")
	_expect(is_equal_approx(float(bridge.call("get_weight_kg")), weight_before), "invalid stamina payload preserves inventory weight")
	_finish(0 if failures.is_empty() else 1)

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
		print("Production surface world stamina tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

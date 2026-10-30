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
	var frame_start_stamina: float = float(stamina.get("current_stamina"))
	world.call("_set_touch_direction", "forward")
	await physics_frame
	world.call("_clear_touch_direction", "forward")
	_expect(float(stamina.get("current_stamina")) < frame_start_stamina, "actual production physics movement drains stamina")
	stamina.call("reset")
	var sprint_button: Button = (world.get("touch_buttons") as Dictionary).get("sprint") as Button
	_expect(sprint_button != null, "production world exposes a touch sprint button")
	if sprint_button != null:
		sprint_button.button_down.emit()
		world.call("_set_touch_direction", "forward")
		await physics_frame
		_expect(bool(world.get("_sprint_active")), "touch sprint button activates sprint during real physics")
		var sprint_profile: Dictionary = world.call("get_player_movement_profile", true)
		_expect(is_equal_approx(float(sprint_profile.get("move_speed", 0.0)), 6.75), "normal-weight production sprint speed is 6.75 m/s")
		sprint_button.button_up.emit()
		world.call("_clear_touch_direction", "forward")
		await physics_frame
		_expect(not bool(world.get("_sprint_active")), "releasing touch sprint returns production movement to walking")
	stamina.call("reset")

	world.call("_tick_stamina", 1.0, true)
	var normal_remaining: float = float(stamina.get("current_stamina"))
	_expect(is_equal_approx(normal_remaining, 98.0), "production activity hook applies normal movement drain")
	stamina.call("reset")
	world.call("_tick_stamina", 1.0, true, true)
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 95.5), "production sprint hook applies the 2.25x stamina drain")
	stamina.call("reset")
	_expect(bool(bridge.call("collect_world_item", "iron_ore", 22)), "inventory accepts 66 kg of iron ore")
	world.call("_tick_stamina", 1.0, true)
	var overweight_remaining: float = float(stamina.get("current_stamina"))
	var overweight_drain: float = 100.0 - overweight_remaining
	_expect(overweight_drain > 2.8 and overweight_drain < 3.1, "production overweight movement drains more stamina than normal movement")
	_expect(bool(bridge.call("collect_world_item", "iron_ore", 9)), "inventory reaches 93 kg")
	world.call("_tick_stamina", 1.0, true)
	var super_heavy_remaining: float = float(stamina.get("current_stamina"))
	var super_heavy_drain: float = overweight_remaining - super_heavy_remaining
	_expect(super_heavy_drain > overweight_drain, "production super-heavy movement has the highest stamina drain")
	var super_heavy_sprint_profile: Dictionary = world.call("get_player_movement_profile", true)
	_expect(is_equal_approx(float(super_heavy_sprint_profile.get("move_speed", 0.0)), 2.835), "super-heavy sprint still respects the inventory movement multiplier")
	_expect(not bool(world.call("can_player_jump_now")), "super-heavy carry state blocks jumping")

	_expect(bool(bridge.call("drop_item", "iron_ore", 10)), "dropping ten ore returns weight to 63 kg")
	profile = world.call("get_player_movement_profile")
	_expect(is_equal_approx(float(profile.get("weight_kg", -1.0)), 63.0), "weight recalculates immediately after dropping cargo")
	_expect(bool(profile.get("can_jump", false)), "normal carry weight restores the jump gate")
	stamina.set("current_stamina", 0.0)
	profile = world.call("get_player_movement_profile")
	_expect(bool(profile.get("exhausted", false)), "production profile reports exhausted state at zero stamina")
	_expect(is_equal_approx(float(profile.get("move_speed", 0.0)), 3.25), "production exhausted walking speed is 65 percent of base speed")
	_expect(not bool(profile.get("can_sprint", true)), "production exhausted state blocks sprint")
	stamina.call("tick", 1.0, false, 1.0)
	profile = world.call("get_player_movement_profile", true)
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 6.0), "production idle recovery restores stamina after exhaustion")
	_expect(bool(profile.get("sprinting", false)), "production sprint is available after recovery crosses the threshold")
	_expect(is_equal_approx(float(profile.get("move_speed", 0.0)), 6.75), "production sprint speed returns after recovery")
	var stamina_before_boundary: float = float(stamina.get("current_stamina"))
	stamina.set("current_stamina", 10.0)
	_expect(bool(world.call("can_player_jump_now")), "production jump gate accepts exactly ten stamina")
	stamina.set("current_stamina", 9.99)
	_expect(not bool(world.call("can_player_jump_now")), "production jump gate rejects stamina below the jump cost")
	stamina.set("current_stamina", stamina_before_boundary)
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
	var chunks_before: PackedStringArray = world.chunk_controller.get_loaded_chunk_ids()
	_expect(not bool(world.call("restore_stream_state", invalid_payload, int(Time.get_unix_time_from_system()))), "invalid stamina payload is rejected before world mutation")
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 55.0), "invalid stamina payload preserves current stamina")
	_expect(world.player.global_position.is_equal_approx(position_before), "invalid stamina payload preserves player position")
	_expect(is_equal_approx(float(bridge.call("get_weight_kg")), weight_before), "invalid stamina payload preserves inventory weight")
	_expect(world.chunk_controller.get_loaded_chunk_ids() == chunks_before, "invalid stamina payload preserves the active chunk window")
	var restore_report: Dictionary = world.call("get_last_restore_report")
	_expect(str(restore_report.get("phase", "")) == "stamina_validation" and bool(restore_report.get("rollback_complete", false)), "invalid stamina rejection reports a non-mutating validation failure")
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

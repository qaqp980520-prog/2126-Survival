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
	var quick_use: RefCounted = world.get("quick_use") as RefCounted
	var stamina: RefCounted = world.get("stamina") as RefCounted
	var bridge: Node = world.get("inventory_bridge") as Node
	_expect(quick_use != null and stamina != null and bridge != null, "production world binds quick-use, stamina and inventory")
	if quick_use == null or stamina == null or bridge == null:
		_finish(1)
		return
	var buttons: Dictionary = world.get("touch_buttons")
	_expect(bool(bridge.call("collect_world_item", "berries", 2)), "inventory accepts two berries")
	var berry_button: Button = buttons.get("quick_1") as Button
	_expect(berry_button != null and berry_button.text.contains("x2"), "inventory_changed immediately refreshes the stocked slot count")
	_expect(berry_button != null and berry_button.disabled, "full stamina keeps a stocked hotbar slot disabled to prevent wasting a ration")
	stamina.set("current_stamina", 40.0)
	await physics_frame
	_expect(berry_button != null and not berry_button.disabled, "stamina deficit enables the stocked hotbar slot on the next HUD refresh")
	var result: Dictionary = world.call("_consume_quick_slot", 0)
	_expect(bool(result.get("ok", false)), "production quick-use action consumes the selected ration")
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 48.0), "production ration restores stamina")
	var inventory: RefCounted = bridge.get("inventory") as RefCounted
	_expect(int(inventory.get("counts").get("berries", 0)) == 1, "production use decrements the shared inventory exactly once")
	_expect(berry_button != null and berry_button.text.contains("x1"), "consumption signal immediately refreshes the remaining berry count")

	_expect(bool(bridge.call("collect_world_item", "herbs", 1)), "inventory accepts an herb ration")
	stamina.set("current_stamina", 50.0)
	await physics_frame
	_expect(buttons.has("quick_2") and not (buttons["quick_2"] as Button).disabled, "inventory change and stamina refresh enable the herb touch slot")
	(buttons["quick_2"] as Button).pressed.emit()
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 62.0), "touch quick-use button restores stamina through the real signal")
	_expect(int(inventory.get("counts").get("herbs", 0)) == 0, "touch quick-use removes exactly one herb")

	stamina.reset()
	await physics_frame
	_expect(berry_button != null and berry_button.disabled, "full stamina disables the stocked hotbar slot again")
	var berries_before: int = int(inventory.get("counts").get("berries", 0))
	result = world.call("_consume_quick_slot", 0)
	_expect(not bool(result.get("ok", false)) and str(result.get("reason", "")) == "stamina_full", "full stamina blocks quick-use in production")
	_expect(int(inventory.get("counts").get("berries", 0)) == berries_before, "full stamina preserves the production inventory item")

	quick_use.call("assign_slot", 2, "food")
	quick_use.call("select_slot", 2)
	var save_payload: Dictionary = world.call("serialize_stream_state")
	_expect(save_payload.has("quick_use"), "production world save includes the optional quick-use payload")
	quick_use.call("select_slot", 0)
	stamina.set("current_stamina", 70.0)
	_expect(bool(world.call("restore_stream_state", save_payload, int(Time.get_unix_time_from_system()))), "production world restores a valid quick-use save")
	_expect(int(quick_use.get("selected_slot")) == 2 and str(quick_use.call("get_slot_item", 2)) == "food", "world restore recovers hotbar selection and assignment")

	var invalid: Dictionary = save_payload.duplicate(true)
	invalid["quick_use"]["selected_slot"] = 9
	var position_before: Vector3 = world.player.global_position
	var stamina_before: float = float(stamina.get("current_stamina"))
	var weight_before: float = float(bridge.call("get_weight_kg"))
	var selected_before: int = int(quick_use.get("selected_slot"))
	_expect(not bool(world.call("restore_stream_state", invalid, int(Time.get_unix_time_from_system()))), "invalid quick-use payload is rejected")
	_expect(world.player.global_position.is_equal_approx(position_before), "invalid quick-use payload preserves player position")
	_expect(is_equal_approx(float(stamina.get("current_stamina")), stamina_before), "invalid quick-use payload preserves stamina")
	_expect(is_equal_approx(float(bridge.call("get_weight_kg")), weight_before), "invalid quick-use payload preserves inventory weight")
	_expect(int(quick_use.get("selected_slot")) == selected_before, "invalid quick-use payload preserves hotbar state")

	var legacy: Dictionary = save_payload.duplicate(true)
	legacy.erase("quick_use")
	_expect(bool(world.call("restore_stream_state", legacy, int(Time.get_unix_time_from_system()))), "legacy world save without quick-use remains compatible")
	_expect(int(quick_use.get("selected_slot")) == 0 and str(quick_use.call("get_slot_item", 2)) == "meat", "legacy world save resets quick-use to the default hotbar")
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
		print("Production SurfaceWorld quick-use integration tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

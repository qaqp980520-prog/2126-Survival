extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")

var _failures: Array[String] = []
var _world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_world = WorldScene.instantiate() as Node3D
	_expect(_world != null, "production SurfaceWorld scene instantiates")
	if _world == null:
		_finish(1)
		return
	root.add_child(_world)
	await process_frame
	var player: CharacterBody3D = _world.get("player") as CharacterBody3D
	_expect(player != null, "production player remains a CharacterBody3D")
	if player == null:
		_finish(1)
		return

	var collision: CollisionShape3D = null
	for child in player.get_children():
		if child is CollisionShape3D:
			collision = child as CollisionShape3D
			break
	var capsule: CapsuleShape3D = null
	if collision != null:
		capsule = collision.shape as CapsuleShape3D
	_expect(capsule != null, "existing player collision capsule remains present")
	if capsule != null:
		_expect(is_equal_approx(capsule.radius, 0.35) and is_equal_approx(capsule.height, 1.8), "player collision dimensions remain unchanged")
	_expect(_world.camera != null and _world.camera.position.is_equal_approx(Vector3(0.0, 1.48, 0.0)), "first-person camera keeps its original local position")
	_expect(_world.camera != null and (_world.camera.cull_mask & (1 << 19)) == 0, "first-person camera excludes the dedicated helmet visibility layer")

	_world.call("_build_player_visual_rig")
	var visual_root: Node3D = player.get_node_or_null("PlayerVisualRoot") as Node3D
	_expect(visual_root != null, "procedural player visual rig attaches to the existing player root")
	if visual_root == null:
		_finish(1)
		return
	_world.call("_build_player_visual_rig")
	var visual_root_count: int = 0
	for child in player.get_children():
		if child.name == "PlayerVisualRoot":
			visual_root_count += 1
	_expect(visual_root_count == 1, "rebuilding the player visual rig does not duplicate its root")
	_expect(_has_visual_descriptor(visual_root, "TorsoPivot/Torso", "capsule"), "rig includes a separate torso mesh")
	_expect(_has_visual_descriptor(visual_root, "TorsoPivot/HelmetPivot/Helmet", "sphere"), "rig includes a helmet and head assembly")
	_expect(_has_visual_descriptor(visual_root, "TorsoPivot/HelmetPivot/Visor", "box"), "rig includes a distinct visor")
	_expect(_has_first_person_hidden_layer(visual_root, "TorsoPivot/HelmetPivot/Helmet"), "helmet geometry is assigned to the external-camera-only layer")
	_expect(_has_first_person_hidden_layer(visual_root, "TorsoPivot/HelmetPivot/Visor"), "visor geometry is assigned to the external-camera-only layer")
	_expect(_has_first_person_hidden_layer(visual_root, "TorsoPivot/HelmetPivot/HelmetBeacon"), "helmet beacon is assigned to the external-camera-only layer")
	_expect(_has_visual_descriptor(visual_root, "TorsoPivot/LeftArmPivot/LeftArm", "capsule"), "rig includes an independently pivoted left arm")
	_expect(_has_visual_descriptor(visual_root, "TorsoPivot/RightArmPivot/RightArm", "capsule"), "rig includes an independently pivoted right arm")
	_expect(_has_visual_descriptor(visual_root, "LeftLegPivot/LeftLeg", "capsule"), "rig includes an independently pivoted left leg")
	_expect(_has_visual_descriptor(visual_root, "RightLegPivot/RightLeg", "capsule"), "rig includes an independently pivoted right leg")
	_expect(_has_visual_descriptor(visual_root, "TorsoPivot/Backpack", "box"), "rig includes a survival backpack")

	_expect(str(_world.call("_resolve_player_visual_animation_state", 0.0, 0.0, true, false)) == "idle", "grounded stationary player resolves to idle")
	_expect(str(_world.call("_resolve_player_visual_animation_state", 2.0, 0.0, true, false)) == "walk", "grounded movement resolves to walk")
	_expect(str(_world.call("_resolve_player_visual_animation_state", 5.0, 0.0, true, true)) == "sprint", "grounded sprint resolves to sprint")
	_expect(str(_world.call("_resolve_player_visual_animation_state", 0.0, 3.0, false, false)) == "jump", "upward airborne movement resolves to jump")
	_expect(str(_world.call("_resolve_player_visual_animation_state", 0.0, -3.0, false, false)) == "fall", "downward airborne movement resolves to fall")

	_world.set("_player_visual_clock", 0.25)
	_world.call("_apply_player_visual_pose", "walk", 1.0)
	var left_leg: Node3D = _world.get("_player_left_leg_pivot") as Node3D
	var right_leg: Node3D = _world.get("_player_right_leg_pivot") as Node3D
	_expect(left_leg != null and right_leg != null and is_equal_approx(left_leg.position.y, 0.86) and is_equal_approx(right_leg.position.y, 0.86), "leg pivots anchor at hip height above the ground plane")
	var torso: Node3D = _world.get("_player_torso_pivot") as Node3D
	var left_arm: Node3D = _world.get("_player_left_arm_pivot") as Node3D
	var right_arm: Node3D = _world.get("_player_right_arm_pivot") as Node3D
	_expect(left_leg != null and right_leg != null and left_leg.rotation.x * right_leg.rotation.x < 0.0, "walk pose swings the legs in opposite directions")
	_expect(left_arm != null and right_arm != null and left_arm.rotation.x * right_arm.rotation.x < 0.0, "walk pose counter-swings the arms")
	_expect(str(_world.call("get_player_visual_animation_state")) == "walk", "walk pose reports its active state")

	_world.call("_apply_player_visual_pose", "sprint", 1.0)
	_expect(torso != null and torso.rotation.x < -0.05, "sprint pose leans the torso forward")
	_expect(absf(left_leg.rotation.x) > 0.05 and absf(right_leg.rotation.x) > 0.05, "sprint pose drives a stronger running stride")
	_expect(str(_world.call("get_player_visual_animation_state")) == "sprint", "sprint pose reports its active state")

	_world.call("_apply_player_visual_pose", "jump", 1.0)
	_expect(left_arm.rotation.x > 0.5 and right_arm.rotation.x > 0.5, "jump pose raises both arms")
	_world.call("_apply_player_visual_pose", "fall", 1.0)
	_expect(left_arm.rotation.x > 0.8 and right_arm.rotation.x > 0.8, "fall pose spreads both arms farther than the jump pose")
	_expect(str(_world.call("get_player_visual_animation_state")) == "fall", "fall pose reports its active state")

	_world.call("_apply_player_visual_pose", "idle", 1.0)
	_expect(absf(left_leg.rotation.x) < 0.001 and absf(right_leg.rotation.x) < 0.001, "idle pose returns both legs to neutral")
	_expect(absf(torso.rotation.x) < 0.001, "idle pose removes the running lean")
	_expect(str(_world.call("get_player_visual_animation_state")) == "idle", "idle pose reports its active state")

	player.velocity = Vector3(2.0, 0.0, -1.0)
	_world.set("_sprint_active", true)
	var velocity_before_animation: Vector3 = player.velocity
	var camera_position_before_animation: Vector3 = _world.camera.position
	var expected_state: String = str(_world.call(
		"_resolve_player_visual_animation_state",
		Vector2(player.velocity.x, player.velocity.z).length(),
		player.velocity.y,
		player.is_on_floor(),
		true
	))
	_world.call("_update_player_visual_animation", 0.016)
	_expect(str(_world.call("get_player_visual_animation_state")) == expected_state, "runtime animation update uses the current physics movement state")
	_expect((player.velocity - velocity_before_animation).length_squared() < 0.000001, "visual animation does not modify player velocity")
	_expect(_world.camera.position.is_equal_approx(camera_position_before_animation), "visual animation does not move the first-person camera")
	_finish(0 if _failures.is_empty() else 1)

func _has_visual_descriptor(parent: Node, path: String, expected_type: String) -> bool:
	var node: Node = parent.get_node_or_null(path)
	return node is Node3D and str(node.get_meta("visual_mesh_type", "")) == expected_type

func _has_first_person_hidden_layer(parent: Node, path: String) -> bool:
	var node: Node = parent.get_node_or_null(path)
	if not (node is Node3D) or int(node.get_meta("first_person_visibility_layer", 0)) != 20:
		return false
	if node is VisualInstance3D:
		return (node as VisualInstance3D).layers == (1 << 19)
	return true

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)

func _finish(exit_code: int) -> void:
	if is_instance_valid(_world):
		_world.queue_free()
	await process_frame
	if exit_code == 0 and _failures.is_empty():
		print("Production SurfaceWorld player visual tests passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAILED: " + failure)
		quit(1)

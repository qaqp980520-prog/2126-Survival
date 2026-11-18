extends SceneTree

const CollisionFactoryScript = preload("res://systems/BackroomsEntityCollisionFactory.gd")
const MOBILE_ENTITY_IDS := [
	"smiler",
	"hound",
	"skin_stealer",
	"faceling",
	"duller",
	"deathmoth"
]
const STATIONARY_ENTITY_IDS := ["window", "clump"]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	for entity_id in MOBILE_ENTITY_IDS:
		var body := CharacterBody3D.new()
		_expect(
			CollisionFactoryScript.attach_collision(body, entity_id, true),
			"%s receives a valid collision proxy" % entity_id
		)
		holder.add_child(body)
		var shape := body.get_node_or_null("EntityCollision") as CollisionShape3D
		_expect(shape != null and shape.shape != null, "%s collision shape is present" % entity_id)
		_expect(body.collision_layer == 4, "%s occupies the dedicated entity collision layer" % entity_id)
		_expect(body.collision_mask == 9, "%s collides with world geometry and the player, not other entities" % entity_id)
		_expect(shape != null and not shape.disabled, "%s collision is enabled in an active runtime" % entity_id)
		if shape != null:
			if entity_id in ["smiler", "deathmoth"]:
				_expect(shape.shape is SphereShape3D, "%s uses a spherical collision proxy" % entity_id)
			else:
				_expect(shape.shape is CapsuleShape3D, "%s uses a capsule collision proxy" % entity_id)
		_expect(
			body.motion_mode == CharacterBody3D.MOTION_MODE_FLOATING,
			"%s uses floating kinematic motion without implicit gravity" % entity_id
		)
		_expect(
			CollisionFactoryScript.set_collision_enabled(body, false),
			"%s collision can be disabled during destination deactivation" % entity_id
		)
		_expect(body.collision_layer == 0 and body.collision_mask == 0, "%s is isolated while inactive" % entity_id)
		_expect(
			CollisionFactoryScript.set_collision_enabled(body, true),
			"%s collision can be re-enabled after destination activation" % entity_id
		)
		_expect(body.collision_layer == 4 and body.collision_mask == 9, "%s restores its collision contract" % entity_id)

	for entity_id in STATIONARY_ENTITY_IDS:
		var body := CharacterBody3D.new()
		_expect(
			CollisionFactoryScript.attach_collision(body, entity_id, true),
			"%s accepts an anchored collision configuration" % entity_id
		)
		holder.add_child(body)
		_expect(body.get_node_or_null("EntityCollision") == null, "%s remains without a mobile collision shape" % entity_id)
		_expect(body.collision_layer == 0 and body.collision_mask == 0, "%s never enters the mobile collision world" % entity_id)

	var invalid_body := CharacterBody3D.new()
	_expect(
		not CollisionFactoryScript.attach_collision(invalid_body, "unknown_entity", true),
		"unknown entity IDs are rejected"
	)
	invalid_body.free()
	holder.free()
	await process_frame
	if failures.is_empty():
		print("Backrooms entity collision factory tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

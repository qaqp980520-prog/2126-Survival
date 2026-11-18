extends RefCounted
class_name BackroomsEntityCollisionFactory

## Builds bounded CharacterBody3D collision proxies for production Backrooms entities.
## Collision is disabled while a destination is prepared and enabled only after activation.
const COLLISION_FACTORY_VERSION: int = 1
const WORLD_GEOMETRY_LAYER: int = 1
const ENTITY_COLLISION_LAYER: int = 1 << 1
const MOBILE_ENTITY_IDS := [
	"smiler",
	"hound",
	"skin_stealer",
	"faceling",
	"duller",
	"deathmoth"
]
const SUPPORTED_ENTITY_IDS := [
	"window",
	"smiler",
	"hound",
	"skin_stealer",
	"clump",
	"faceling",
	"duller",
	"deathmoth"
]

static func attach_collision(
	entity_body: CharacterBody3D,
	entity_id: String,
	runtime_enabled: bool = false
) -> bool:
	if entity_body == null or not is_instance_valid(entity_body):
		return false
	if not SUPPORTED_ENTITY_IDS.has(entity_id):
		return false
	if entity_body.get_node_or_null("EntityCollision") != null:
		return false
	entity_body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	entity_body.safe_margin = 0.02
	entity_body.set_meta("backrooms_entity_id", entity_id)
	entity_body.set_meta("backrooms_entity_collision_version", COLLISION_FACTORY_VERSION)
	var collision_shape: CollisionShape3D = _create_collision_shape(entity_id)
	if MOBILE_ENTITY_IDS.has(entity_id) and collision_shape == null:
		return false
	if collision_shape != null:
		entity_body.add_child(collision_shape)
	return set_collision_enabled(entity_body, runtime_enabled)

static func set_collision_enabled(entity_body: CharacterBody3D, enabled: bool) -> bool:
	if entity_body == null or not is_instance_valid(entity_body):
		return false
	var entity_id: String = str(entity_body.get_meta("backrooms_entity_id", ""))
	if not SUPPORTED_ENTITY_IDS.has(entity_id):
		return false
	if not MOBILE_ENTITY_IDS.has(entity_id):
		entity_body.collision_layer = 0
		entity_body.collision_mask = 0
		return entity_body.get_node_or_null("EntityCollision") == null
	var collision_shape: CollisionShape3D = entity_body.get_node_or_null("EntityCollision") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return false
	collision_shape.disabled = not enabled
	entity_body.collision_layer = ENTITY_COLLISION_LAYER if enabled else 0
	entity_body.collision_mask = WORLD_GEOMETRY_LAYER if enabled else 0
	return true

static func _create_collision_shape(entity_id: String) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	node.name = "EntityCollision"
	match entity_id:
		"smiler":
			var sphere := SphereShape3D.new()
			sphere.radius = 0.3
			node.shape = sphere
		"hound":
			var hound_capsule := CapsuleShape3D.new()
			hound_capsule.radius = 0.32
			hound_capsule.height = 0.9
			node.shape = hound_capsule
			node.position = Vector3(0.0, -0.05, 0.0)
		"skin_stealer":
			var skin_capsule := CapsuleShape3D.new()
			skin_capsule.radius = 0.3
			skin_capsule.height = 1.75
			node.shape = skin_capsule
			node.position = Vector3(0.0, 0.875, 0.0)
		"faceling":
			var faceling_capsule := CapsuleShape3D.new()
			faceling_capsule.radius = 0.28
			faceling_capsule.height = 1.7
			node.shape = faceling_capsule
			node.position = Vector3(0.0, 0.85, 0.0)
		"duller":
			var duller_capsule := CapsuleShape3D.new()
			duller_capsule.radius = 0.3
			duller_capsule.height = 1.75
			node.shape = duller_capsule
			node.position = Vector3(0.0, 0.875, 0.0)
		"deathmoth":
			var moth_sphere := SphereShape3D.new()
			moth_sphere.radius = 0.38
			node.shape = moth_sphere
		"window", "clump":
			node.free()
			return null
		_:
			node.free()
			return null
	return node

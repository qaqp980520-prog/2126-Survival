extends Node3D
class_name SurfaceTerrainPatch

## Small raised terrain tile whose material and height survive chunk unload/reload.
const SURFACE_TYPES: Array[String] = ["soil", "rock", "metal"]
const MAX_HEIGHT_LEVEL: int = 2
const MAX_REVISION: int = 1000000
const PATCH_SIZE: float = 2.0

var _height_level: int = 0
var _surface_type: String = "soil"
var _revision: int = 0
var _collision_body: StaticBody3D
var _collision_shape: CollisionShape3D
var _surface_mesh: MeshInstance3D
var _interaction_area: Area3D

func _ready() -> void:
	_build_collision()
	_build_interaction_area()
	if DisplayServer.get_name() != "headless":
		_build_visual()
	_refresh_geometry()

func get_world_object_state() -> Dictionary:
	return {
		"height_level": _height_level,
		"surface_type": _surface_type,
		"revision": _revision
	}

func validate_world_object_state(state: Dictionary) -> bool:
	if state.size() != 3 or not state.has("height_level") or not state.has("surface_type") or not state.has("revision"):
		return false
	var height_value: Variant = state.get("height_level", null)
	var surface_value: Variant = state.get("surface_type", null)
	var revision_value: Variant = state.get("revision", null)
	if not (height_value is int) or not (surface_value is String) or not (revision_value is int):
		return false
	if int(height_value) < 0 or int(height_value) > MAX_HEIGHT_LEVEL:
		return false
	if not SURFACE_TYPES.has(str(surface_value)):
		return false
	return int(revision_value) >= 0 and int(revision_value) <= MAX_REVISION

func apply_world_object_state(state: Dictionary) -> bool:
	if not validate_world_object_state(state):
		return false
	_height_level = int(state["height_level"])
	_surface_type = str(state["surface_type"])
	_revision = int(state["revision"])
	_refresh_geometry()
	return true

func cycle_terrain_edit() -> Dictionary:
	if _revision >= MAX_REVISION:
		return {"ok": false, "reason": "revision_limit", "state": get_world_object_state()}
	var surface_index: int = SURFACE_TYPES.find(_surface_type)
	_height_level = (_height_level + 1) % (MAX_HEIGHT_LEVEL + 1)
	_surface_type = SURFACE_TYPES[posmod(surface_index + 1, SURFACE_TYPES.size())]
	_revision += 1
	_refresh_geometry()
	return {"ok": true, "reason": "edited", "state": get_world_object_state()}

func get_top_height() -> float:
	return 0.05 + float(_height_level) * 0.25

func _build_collision() -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.name = "TerrainCollisionBody"
	_collision_body.collision_layer = 1
	_collision_body.collision_mask = 0
	add_child(_collision_body)
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "TerrainCollisionShape"
	_collision_body.add_child(_collision_shape)

func _build_interaction_area() -> void:
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 2
	_interaction_area.collision_mask = 0
	_interaction_area.monitoring = false
	var proxy_shape := CollisionShape3D.new()
	proxy_shape.name = "InteractionShape"
	var box := BoxShape3D.new()
	box.size = Vector3(PATCH_SIZE * 1.2, 3.4, PATCH_SIZE * 1.2)
	proxy_shape.shape = box
	proxy_shape.position = Vector3(0.0, 1.7, 0.0)
	_interaction_area.add_child(proxy_shape)
	add_child(_interaction_area)

func _build_visual() -> void:
	_surface_mesh = MeshInstance3D.new()
	_surface_mesh.name = "TerrainSurfaceMesh"
	_collision_body.add_child(_surface_mesh)

func _refresh_geometry() -> void:
	var height: float = get_top_height()
	var box_height: float = maxf(0.05, height)
	var box := BoxShape3D.new()
	box.size = Vector3(PATCH_SIZE, box_height, PATCH_SIZE)
	_collision_shape.shape = box
	_collision_shape.position = Vector3(0.0, box_height * 0.5, 0.0)
	if _surface_mesh == null or not is_instance_valid(_surface_mesh):
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(PATCH_SIZE, box_height, PATCH_SIZE)
	_surface_mesh.mesh = mesh
	_surface_mesh.position = _collision_shape.position
	var material := StandardMaterial3D.new()
	match _surface_type:
		"soil": material.albedo_color = Color("#8b6848")
		"rock": material.albedo_color = Color("#78828b")
		"metal": material.albedo_color = Color("#39a6b8")
	_surface_mesh.material_override = material

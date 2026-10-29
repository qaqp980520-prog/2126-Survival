extends Node3D
class_name WorldObjectStatefulProp

## Small interactable prop used to exercise the stable-ID world-object lifecycle.
## The registry stores only the primitive state returned by get_world_object_state().
const MAX_LOOT: int = 2

var opened: bool = false
var loot_remaining: int = MAX_LOOT
var _body_mesh: MeshInstance3D
var _lid_mesh: MeshInstance3D

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_build_visuals()
	_refresh_visuals()

func get_world_object_state() -> Dictionary:
	return {
		"opened": opened,
		"loot_remaining": loot_remaining
	}

func apply_world_object_state(state: Dictionary) -> bool:
	var opened_value: Variant = state.get("opened", null)
	var loot_value: Variant = state.get("loot_remaining", null)
	if not (opened_value is bool) or not (loot_value is int):
		return false
	if int(loot_value) < 0 or int(loot_value) > MAX_LOOT:
		return false
	# A never-opened crate cannot already have been marked open with its full contents.
	if bool(opened_value) and int(loot_value) == MAX_LOOT:
		return false
	opened = bool(opened_value)
	loot_remaining = int(loot_value)
	_refresh_visuals()
	return true

func interact() -> bool:
	if loot_remaining <= 0:
		return false
	opened = true
	loot_remaining -= 1
	_refresh_visuals()
	return true

func _build_visuals() -> void:
	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "CrateBody"
	var body := BoxMesh.new()
	body.size = Vector3(1.1, 0.65, 0.8)
	_body_mesh.mesh = body
	_body_mesh.position = Vector3(0.0, 0.34, 0.0)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#8c633e")
	body_material.metallic = 0.18
	_body_mesh.material_override = body_material
	add_child(_body_mesh)

	_lid_mesh = MeshInstance3D.new()
	_lid_mesh.name = "CrateLid"
	var lid := BoxMesh.new()
	lid.size = Vector3(1.16, 0.14, 0.86)
	_lid_mesh.mesh = lid
	_lid_mesh.position = Vector3(0.0, 0.72, 0.0)
	var lid_material := StandardMaterial3D.new()
	lid_material.albedo_color = Color("#d49a50")
	lid_material.metallic = 0.22
	_lid_mesh.material_override = lid_material
	add_child(_lid_mesh)

func _refresh_visuals() -> void:
	if _lid_mesh == null or not is_instance_valid(_lid_mesh):
		return
	_lid_mesh.rotation.x = -0.95 if opened else 0.0
	_lid_mesh.position = Vector3(0.0, 0.72, -0.28 if opened else 0.0)
	if _body_mesh != null and is_instance_valid(_body_mesh):
		var material := _body_mesh.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = Color("#6d5038") if loot_remaining == 0 else Color("#8c633e")

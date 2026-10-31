extends Node3D
class_name UndergroundMineLift

## Stateful, streamed mine-lift anchor. Its stable-ID record validates the authored layer.
const MAX_LAYER_INDEX: int = 8

var layer_index: int = 0
var _interaction_area: Area3D
var _platform: MeshInstance3D
var _label: Label3D

func _ready() -> void:
	_build_interaction_area()
	if DisplayServer.get_name() != "headless":
		_build_visuals()
	_refresh_visuals()

func get_world_object_state() -> Dictionary:
	return {"layer_index": layer_index}

func validate_world_object_state(state: Dictionary) -> bool:
	if state.size() != 1 or not state.has("layer_index"):
		return false
	var raw_layer: Variant = state.get("layer_index", null)
	return raw_layer is int and int(raw_layer) >= 0 and int(raw_layer) <= MAX_LAYER_INDEX and int(raw_layer) == layer_index

func apply_world_object_state(state: Dictionary) -> bool:
	if not validate_world_object_state(state):
		return false
	layer_index = int(state["layer_index"])
	_refresh_visuals()
	return true

func _build_interaction_area() -> void:
	if get_node_or_null("InteractionArea") != null:
		_interaction_area = get_node("InteractionArea") as Area3D
		return
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 2
	_interaction_area.collision_mask = 0
	_interaction_area.monitoring = false
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.35
	shape.height = 2.2
	collision.shape = shape
	collision.position.y = 0.9
	_interaction_area.add_child(collision)
	add_child(_interaction_area)

func _build_visuals() -> void:
	_platform = MeshInstance3D.new()
	_platform.name = "LiftPlatform"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.05
	mesh.bottom_radius = 1.05
	mesh.height = 0.12
	_platform.mesh = mesh
	_platform.position.y = 0.08
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.32, 0.42)
	material.metallic = 0.8
	material.emission_enabled = true
	material.emission = Color(0.02, 0.35, 0.55)
	material.emission_energy_multiplier = 0.85
	_platform.material_override = material
	add_child(_platform)

	_label = Label3D.new()
	_label.name = "LiftLabel"
	_label.position = Vector3(0.0, 1.35, 0.0)
	_label.font_size = 24
	_label.modulate = Color(0.55, 0.92, 1.0)
	add_child(_label)

func _refresh_visuals() -> void:
	if _label != null and is_instance_valid(_label):
		_label.text = "KROLL LIFT · LEVEL %02d · V DOWN / G UP" % (layer_index + 1)

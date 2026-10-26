extends Node3D
class_name MineralOreVisual

## Procedural low-poly ore cluster. Set mineral_id before adding this node to the scene.
const Catalog = preload("res://systems/MineralCatalog.gd")
@export_enum("copper_ore", "iron_ore", "gold_ore", "silver_ore", "aluminium_ore", "coal_ore", "uranium_ore") var mineral_id: String = "iron_ore"
@export_range(0.5, 4.0, 0.1) var visual_scale: float = 1.0
@export var random_seed: int = 2126

func _ready() -> void:
	build_model()

func build_model() -> void:
	# A headless/dedicated server should not allocate renderer-backed mesh nodes.
	if DisplayServer.get_name() == "headless":
		return
	for child in get_children():
		child.queue_free()
	var data: Dictionary = Catalog.get_mineral(mineral_id)
	if data.is_empty():
		push_warning("Unknown mineral ID: " + mineral_id)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = data["rock_color"]
	rock_material.roughness = 0.92
	var vein_material := StandardMaterial3D.new()
	vein_material.albedo_color = data["vein_color"]
	vein_material.metallic = float(data["vein_metallic"])
	vein_material.roughness = 0.28
	if mineral_id == "uranium_ore":
		vein_material.emission_enabled = true
		vein_material.emission = data["particle_color"]
		vein_material.emission_energy_multiplier = 1.3
	# Several irregularly scaled chunks create a readable ore silhouette without external assets.
	for i in range(7):
		var chunk := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radial_segments = 8
		mesh.rings = 5
		var s := rng.randf_range(0.34, 0.62) * visual_scale
		mesh.radius = s
		mesh.height = s * rng.randf_range(1.25, 1.8)
		chunk.mesh = mesh
		chunk.material_override = vein_material if i in [1, 3, 5] else rock_material
		chunk.position = Vector3(
			rng.randf_range(-0.42, 0.42),
			rng.randf_range(-0.12, 0.42),
			rng.randf_range(-0.38, 0.38)
		) * visual_scale
		chunk.rotation = Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.0, TAU), rng.randf_range(-0.7, 0.7))
		chunk.scale = Vector3(rng.randf_range(0.8, 1.2), rng.randf_range(0.65, 1.15), rng.randf_range(0.8, 1.2))
		add_child(chunk)

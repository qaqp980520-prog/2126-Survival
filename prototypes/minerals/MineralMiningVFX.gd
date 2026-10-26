extends Node3D
class_name MineralMiningVFX

## Call play_hit(mineral_id, impact_position) from a mining tool's hit event.
const Catalog = preload("res://systems/MineralCatalog.gd")
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func play_hit(mineral_id: String, impact_position: Vector3) -> void:
	# Dedicated/headless runs validate mining logic, not GPU particle rendering.
	if DisplayServer.get_name() == "headless":
		return
	var data: Dictionary = Catalog.get_mineral(mineral_id)
	if data.is_empty():
		return
	var color: Color = data["particle_color"]
	_spawn_burst(impact_position, color, 18 if mineral_id != "coal_ore" else 12)
	# Metallic ores get a small warm spark accent; uranium gets a short green glow burst.
	if mineral_id in ["copper_ore", "iron_ore", "gold_ore", "silver_ore", "aluminium_ore"]:
		_spawn_burst(impact_position, Color(1.0, 0.72, 0.34), 5)
	elif mineral_id == "uranium_ore":
		_spawn_burst(impact_position, Color(0.15, 1.0, 0.32), 8)

func _spawn_burst(at_position: Vector3, tint: Color, amount: int) -> void:
	var particles := GPUParticles3D.new()
	particles.position = at_position
	particles.amount = amount
	particles.lifetime = 0.42
	particles.one_shot = true
	particles.explosiveness = 0.96
	particles.emitting = false
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 0.65, 0.0)
	process.spread = 70.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 4.2
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.scale_min = 0.025
	process.scale_max = 0.075
	process.color = tint
	particles.process_material = process
	var draw_mesh := SphereMesh.new()
	draw_mesh.radius = 0.035
	draw_mesh.height = 0.07
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.4 if tint.g > 0.8 else 0.6
	draw_mesh.material = mat
	particles.draw_pass_1 = draw_mesh
	add_child(particles)
	if particles.is_inside_tree():
		particles.global_position = at_position
	else:
		particles.position = at_position
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

extends RefCounted
class_name BackroomsLightingProfile

## Deterministic level lighting profiles shared by cell construction and perception.
## The same descriptor drives both the OmniLight3D and the darkness sampler.
const LEVEL_PROFILES := {
	"Level 0": {
		"ambient_color": Color(0.76, 0.72, 0.52),
		"ambient_energy": 0.34,
		"background_color": Color(0.19, 0.17, 0.10),
		"tonemap_exposure": 1.0,
		"light_period": 1,
		"light_phase": 0,
		"light_energy": 1.35,
		"light_range": 11.0,
		"light_color": Color(1.0, 0.96, 0.78),
		"darkness_threshold": 0.12
	},
	"Level 1": {
		"ambient_color": Color(0.48, 0.38, 0.22),
		"ambient_energy": 0.035,
		"background_color": Color(0.012, 0.009, 0.004),
		"tonemap_exposure": 0.82,
		"light_period": 2,
		"light_phase": 0,
		"light_energy": 1.2,
		"light_range": 8.0,
		"light_color": Color(1.0, 0.91, 0.68),
		"darkness_threshold": 0.12
	},
	"Level 2": {
		"ambient_color": Color(0.20, 0.25, 0.32),
		"ambient_energy": 0.025,
		"background_color": Color(0.004, 0.006, 0.010),
		"tonemap_exposure": 0.74,
		"light_period": 3,
		"light_phase": 1,
		"light_energy": 0.9,
		"light_range": 7.0,
		"light_color": Color(0.70, 0.82, 1.0),
		"darkness_threshold": 0.11
	},
	"Level 3": {
		"ambient_color": Color(0.25, 0.13, 0.10),
		"ambient_energy": 0.015,
		"background_color": Color(0.006, 0.003, 0.003),
		"tonemap_exposure": 0.68,
		"light_period": 4,
		"light_phase": 0,
		"light_energy": 0.75,
		"light_range": 6.0,
		"light_color": Color(1.0, 0.50, 0.34),
		"darkness_threshold": 0.10
	},
	"Level 4": {
		"ambient_color": Color(0.72, 0.68, 0.54),
		"ambient_energy": 0.20,
		"background_color": Color(0.10, 0.085, 0.052),
		"tonemap_exposure": 0.96,
		"light_period": 1,
		"light_phase": 0,
		"light_energy": 1.15,
		"light_range": 10.0,
		"light_color": Color(1.0, 0.94, 0.78),
		"darkness_threshold": 0.16
	},
	"Level 5": {
		"ambient_color": Color(0.15, 0.20, 0.27),
		"ambient_energy": 0.03,
		"background_color": Color(0.004, 0.006, 0.011),
		"tonemap_exposure": 0.72,
		"light_period": 3,
		"light_phase": 2,
		"light_energy": 0.85,
		"light_range": 7.0,
		"light_color": Color(0.66, 0.78, 1.0),
		"darkness_threshold": 0.11
	}
}

static func get_supported_levels() -> Array[String]:
	var result: Array[String] = []
	for level_id in LEVEL_PROFILES.keys():
		result.append(str(level_id))
	result.sort()
	return result

static func get_level_profile(level_id: String) -> Dictionary:
	var value: Variant = LEVEL_PROFILES.get(level_id, null)
	if not (value is Dictionary):
		return {}
	return value.duplicate(true)

static func get_cell_light_descriptor(
	level_id: String,
	cell: Vector2i,
	world_seed: int,
	wall_height: float = 3.2
) -> Dictionary:
	var profile: Dictionary = get_level_profile(level_id)
	if profile.is_empty() or not is_finite(wall_height) or wall_height <= 0.5:
		return {}
	var period: int = maxi(1, int(profile.get("light_period", 1)))
	var seed_phase: int = posmod(world_seed, period)
	var cell_phase: int = posmod(cell.x + cell.y * 2 + seed_phase, period)
	var enabled: bool = cell_phase == int(profile.get("light_phase", 0))
	return {
		"enabled": enabled,
		"local_position": Vector3(0.0, wall_height - 0.22, 0.0),
		"energy": float(profile.get("light_energy", 0.0)),
		"range": float(profile.get("light_range", 0.0)),
		"color": profile.get("light_color", Color.WHITE),
		"ambient_energy": float(profile.get("ambient_energy", 0.0)),
		"darkness_threshold": float(profile.get("darkness_threshold", 0.12))
	}

static func is_position_dark(
	cell_root: Node3D,
	world_position: Vector3,
	fallback: bool = false
) -> bool:
	if cell_root == null or not is_instance_valid(cell_root):
		return fallback
	if not _is_finite_vector3(world_position):
		return fallback
	var descriptor_value: Variant = cell_root.get_meta("backrooms_light_descriptor", null)
	if not (descriptor_value is Dictionary):
		return fallback
	var descriptor: Dictionary = descriptor_value
	var ambient_energy: float = float(descriptor.get("ambient_energy", 0.0))
	var darkness_threshold: float = float(descriptor.get("darkness_threshold", 0.12))
	if not is_finite(ambient_energy) or not is_finite(darkness_threshold) or darkness_threshold <= 0.0:
		return fallback
	if ambient_energy >= darkness_threshold:
		return false
	if not bool(descriptor.get("enabled", false)):
		return true

	var local_position_value: Variant = descriptor.get("local_position", null)
	if not (local_position_value is Vector3):
		return true
	var light_position: Vector3 = cell_root.to_global(local_position_value)
	var light_energy: float = float(descriptor.get("energy", 0.0))
	var light_range: float = float(descriptor.get("range", 0.0))
	if not _is_finite_vector3(light_position) or not is_finite(light_energy) or not is_finite(light_range):
		return true
	if light_energy <= 0.0 or light_range <= 0.0:
		return true

	# In graphical mode, use the live light node so disabling/removing it immediately
	# changes perception. Headless tests use the identical saved descriptor.
	if cell_root.is_inside_tree() and DisplayServer.get_name() != "headless":
		var light_node: OmniLight3D = cell_root.get_node_or_null("BackroomsCeilingLight") as OmniLight3D
		if light_node == null or not is_instance_valid(light_node) or not light_node.visible:
			return true
		light_position = light_node.global_position
		light_energy = light_node.light_energy
		light_range = light_node.omni_range
		if light_energy <= 0.0 or light_range <= 0.0:
			return true

	var normalized_distance: float = clampf(light_position.distance_to(world_position) / light_range, 0.0, 1.0)
	var attenuation: float = 1.0 - normalized_distance
	var estimated_illumination: float = light_energy * attenuation * attenuation
	return estimated_illumination < darkness_threshold

static func _is_finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

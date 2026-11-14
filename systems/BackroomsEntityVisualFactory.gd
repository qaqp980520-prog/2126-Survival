extends RefCounted
class_name BackroomsEntityVisualFactory

## Builds the renderer-side appearance for deterministic production entity roots.
## Spawn selection, position, level whitelist and lifecycle remain owned by the
## BackroomsEntityDirector and BackroomsMazeCellRuntime.
const VISUAL_FACTORY_VERSION: int = 1

static func get_geometry_specs(entity_id: String) -> Array[Dictionary]:
	match entity_id:
		"window":
			return _window_specs()
		"smiler":
			return _smiler_specs()
		"hound":
			return _hound_specs()
		"skin_stealer":
			return _skin_stealer_specs()
		"clump":
			return _clump_specs()
		"faceling":
			return _faceling_specs()
		"duller":
			return _duller_specs()
		"deathmoth":
			return _deathmoth_specs()
	return []

static func attach_visuals(entity_root: Node3D) -> bool:
	return _attach_visuals(entity_root, false)

## Explicit test seam: exercises the same MeshInstance3D builder under the
## headless dummy renderer. Production callers must use attach_visuals().
static func attach_visuals_for_testing(entity_root: Node3D) -> bool:
	return _attach_visuals(entity_root, true)

static func are_geometry_specs_valid_for_testing(entity_id: String, specs: Array[Dictionary]) -> bool:
	return _are_geometry_specs_valid(specs, _material_keys_for_entity(entity_id))

static func _attach_visuals(entity_root: Node3D, allow_headless: bool) -> bool:
	if entity_root == null or not is_instance_valid(entity_root):
		return false
	if not entity_root.has_meta("backrooms_entity_id") or entity_root.get_child_count() != 0:
		return false
	if DisplayServer.get_name() == "headless" and not allow_headless:
		return false

	var entity_id: String = str(entity_root.get_meta("backrooms_entity_id", ""))
	var specs: Array[Dictionary] = get_geometry_specs(entity_id)
	var material_keys: Array[String] = _material_keys_for_entity(entity_id)
	if not _are_geometry_specs_valid(specs, material_keys):
		return false

	var window_yaw: float = entity_root.rotation.y
	if entity_id == "window":
		var wall_value: Variant = entity_root.get_meta("backrooms_wall_direction", null)
		if not (wall_value is Vector2i):
			return false
		var wall_direction: Vector2i = wall_value
		if wall_direction == Vector2i(0, -1):
			window_yaw = 0.0
		elif wall_direction == Vector2i(-1, 0):
			window_yaw = PI * 0.5
		else:
			return false

	var materials: Dictionary = _create_materials(entity_id)
	for key in material_keys:
		if not (materials.get(key, null) is Material):
			return false

	# Build off-tree and publish one complete visual subtree. The entity root
	# remains unchanged if validation or resource construction fails.
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	for spec in specs:
		var mesh_instance: MeshInstance3D = _build_mesh_instance(spec, materials)
		if mesh_instance == null:
			visuals.free()
			return false
		visuals.add_child(mesh_instance)
	entity_root.rotation.y = window_yaw
	entity_root.add_child(visuals)
	entity_root.set_meta("backrooms_entity_visual_version", VISUAL_FACTORY_VERSION)
	entity_root.set_meta("backrooms_entity_visual_state", "attached")
	return true

static func _build_mesh_instance(spec: Dictionary, materials: Dictionary) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = str(spec.get("name", "EntityPart"))
	var kind: String = str(spec.get("kind", ""))
	if kind == "box":
		var box := BoxMesh.new()
		box.size = spec["size"]
		mesh_instance.mesh = box
	elif kind == "sphere":
		var sphere := SphereMesh.new()
		sphere.radius = float(spec["radius"])
		sphere.height = float(spec["height"])
		mesh_instance.mesh = sphere
	else:
		mesh_instance.free()
		return null
	mesh_instance.position = spec["position"]
	mesh_instance.rotation = spec.get("rotation", Vector3.ZERO)
	mesh_instance.material_override = materials[str(spec["material"])] as Material
	if mesh_instance.mesh == null or mesh_instance.material_override == null:
		mesh_instance.free()
		return null
	return mesh_instance

static func _are_geometry_specs_valid(specs: Array[Dictionary], material_keys: Array[String]) -> bool:
	if specs.is_empty() or material_keys.is_empty():
		return false
	var names: Dictionary = {}
	for spec in specs:
		var part_name: String = str(spec.get("name", ""))
		if part_name.is_empty() or names.has(part_name):
			return false
		names[part_name] = true
		if typeof(spec.get("position", null)) != TYPE_VECTOR3:
			return false
		if typeof(spec.get("rotation", Vector3.ZERO)) != TYPE_VECTOR3:
			return false
		var position: Vector3 = spec["position"]
		var rotation: Vector3 = spec.get("rotation", Vector3.ZERO)
		if not _is_finite_vector3(position) or not _is_finite_vector3(rotation):
			return false
		if not material_keys.has(str(spec.get("material", ""))):
			return false
		match str(spec.get("kind", "")):
			"box":
				if typeof(spec.get("size", null)) != TYPE_VECTOR3:
					return false
				var size: Vector3 = spec["size"]
				if not _is_finite_vector3(size) or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
					return false
			"sphere":
				var radius: float = float(spec.get("radius", 0.0))
				var height: float = float(spec.get("height", 0.0))
				if not is_finite(radius) or not is_finite(height) or radius <= 0.0 or height <= 0.0:
					return false
			_:
				return false
	return true

static func _is_finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

static func _material_keys_for_entity(entity_id: String) -> Array[String]:
	match entity_id:
		"window":
			return ["frame", "glass"]
		"smiler":
			return ["body", "eye"]
		"hound":
			return ["body", "eye"]
		"skin_stealer", "clump", "faceling", "duller":
			return ["body"]
		"deathmoth":
			return ["body", "wing", "eye"]
	return []

static func _create_materials(entity_id: String) -> Dictionary:
	var materials: Dictionary = {}
	match entity_id:
		"window":
			var frame := _new_material(Color(0.18, 0.19, 0.17), 0.9)
			var glass := _new_material(Color(0.008, 0.012, 0.014), 0.2)
			glass.metallic = 0.25
			materials = {"frame": frame, "glass": glass}
		"smiler":
			var darkness := _new_material(Color(0.002, 0.002, 0.004), 1.0)
			darkness.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var smile_eyes := _new_material(Color(1.0, 0.93, 0.68), 0.5)
			smile_eyes.emission_enabled = true
			smile_eyes.emission = Color(1.0, 0.82, 0.42)
			smile_eyes.emission_energy_multiplier = 2.2
			materials = {"body": darkness, "eye": smile_eyes}
		"hound":
			var hide := _new_material(Color(0.055, 0.035, 0.03), 0.95)
			var red_eye := _new_material(Color(0.9, 0.18, 0.08), 0.5)
			red_eye.emission_enabled = true
			red_eye.emission = Color(0.8, 0.08, 0.02)
			red_eye.emission_energy_multiplier = 1.2
			materials = {"body": hide, "eye": red_eye}
		"skin_stealer":
			materials = {"body": _new_material(Color(0.28, 0.19, 0.16), 0.95)}
		"clump":
			materials = {"body": _new_material(Color(0.018, 0.014, 0.012), 1.0)}
		"faceling":
			materials = {"body": _new_material(Color(0.62, 0.57, 0.48), 0.92)}
		"duller":
			materials = {"body": _new_material(Color(0.075, 0.085, 0.095), 1.0)}
		"deathmoth":
			var body := _new_material(Color(0.12, 0.085, 0.055), 0.9)
			var wings := _new_material(Color(0.38, 0.32, 0.25, 0.9), 1.0)
			wings.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var eyes := _new_material(Color(0.72, 0.18, 0.08), 0.5)
			eyes.emission_enabled = true
			eyes.emission = Color(0.45, 0.06, 0.015)
			eyes.emission_energy_multiplier = 0.8
			materials = {"body": body, "wing": wings, "eye": eyes}
	return materials

static func _new_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

static func _box_spec(
	part_name: String,
	position: Vector3,
	size: Vector3,
	material_key: String,
	rotation: Vector3 = Vector3.ZERO
) -> Dictionary:
	return {
		"name": part_name,
		"kind": "box",
		"position": position,
		"rotation": rotation,
		"size": size,
		"material": material_key
	}

static func _sphere_spec(
	part_name: String,
	position: Vector3,
	radius: float,
	material_key: String,
	height: float = -1.0
) -> Dictionary:
	return {
		"name": part_name,
		"kind": "sphere",
		"position": position,
		"rotation": Vector3.ZERO,
		"radius": radius,
		"height": radius * 2.0 if height <= 0.0 else height,
		"material": material_key
	}

static func _window_specs() -> Array[Dictionary]:
	return [
		_box_spec("DarkWindowPane", Vector3.ZERO, Vector3(1.45, 1.45, 0.07), "glass"),
		_box_spec("FrameTop", Vector3(0.0, 0.78, 0.0), Vector3(1.65, 0.12, 0.16), "frame"),
		_box_spec("FrameBottom", Vector3(0.0, -0.78, 0.0), Vector3(1.65, 0.12, 0.16), "frame"),
		_box_spec("FrameLeft", Vector3(-0.78, 0.0, 0.0), Vector3(0.12, 1.45, 0.16), "frame"),
		_box_spec("FrameRight", Vector3(0.78, 0.0, 0.0), Vector3(0.12, 1.45, 0.16), "frame")
	]

static func _smiler_specs() -> Array[Dictionary]:
	return [
		_sphere_spec("DarkSilhouette", Vector3.ZERO, 0.48, "body", 0.96),
		_sphere_spec("Eye_0", Vector3(-0.14, 0.08, -0.43), 0.055, "eye"),
		_sphere_spec("Eye_1", Vector3(0.14, 0.08, -0.43), 0.055, "eye")
	]

static func _hound_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = [
		_box_spec("Body", Vector3(0.0, 0.0, 0.0), Vector3(0.95, 0.42, 0.48), "body"),
		_box_spec("Head", Vector3(0.0, 0.16, -0.38), Vector3(0.42, 0.38, 0.36), "body")
	]
	for x_index in range(2):
		var x_offset: float = -0.32 if x_index == 0 else 0.32
		for z_index in range(2):
			var z_offset: float = -0.16 if z_index == 0 else 0.16
			specs.append(_box_spec(
				"Leg_%d_%d" % [x_index, z_index],
				Vector3(x_offset, -0.25, z_offset),
				Vector3(0.14, 0.5, 0.14),
				"body"
			))
	for eye_index in range(2):
		var eye_x: float = -0.12 if eye_index == 0 else 0.12
		specs.append(_sphere_spec("Eye_%d" % eye_index, Vector3(eye_x, 0.24, -0.57), 0.045, "eye"))
	return specs

static func _skin_stealer_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = [
		_box_spec("Torso", Vector3(0.0, 1.05, 0.0), Vector3(0.48, 0.9, 0.28), "body"),
		_sphere_spec("Head", Vector3(0.0, 1.68, 0.0), 0.2, "body", 0.4)
	]
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		specs.append(_box_spec("Arm_%d" % side_index, Vector3(side * 0.32, 1.05, 0.0), Vector3(0.16, 0.82, 0.2), "body"))
		specs.append(_box_spec("Leg_%d" % side_index, Vector3(side * 0.1536, 0.34, 0.0), Vector3(0.18, 0.68, 0.22), "body"))
	return specs

static func _clump_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for index in range(7):
		var radius: float = 0.28 + float(index % 3) * 0.07
		var angle: float = float(index) * TAU / 7.0
		specs.append(_sphere_spec(
			"Mass_%d" % index,
			Vector3(cos(angle) * 0.28, float(index % 2) * 0.24, sin(angle) * 0.28),
			radius,
			"body"
		))
	return specs

static func _faceling_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = [
		_box_spec("Torso", Vector3(0.0, 1.0, 0.0), Vector3(0.42, 0.82, 0.25), "body"),
		_sphere_spec("FeaturelessHead", Vector3(0.0, 1.62, 0.0), 0.2, "body", 0.4)
	]
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		specs.append(_box_spec("Arm_%d" % side_index, Vector3(side * 0.29, 1.02, 0.0), Vector3(0.14, 0.72, 0.18), "body"))
		specs.append(_box_spec("Leg_%d" % side_index, Vector3(side * 0.1392, 0.35, 0.0), Vector3(0.16, 0.68, 0.2), "body"))
	return specs

static func _duller_specs() -> Array[Dictionary]:
	return [
		_box_spec("Torso", Vector3(0.0, 1.02, 0.0), Vector3(0.42, 0.9, 0.24), "body"),
		_sphere_spec("FeaturelessHead", Vector3(0.0, 1.68, 0.0), 0.19, "body", 0.38),
		_box_spec("LongArmLeft", Vector3(-0.33, 1.05, 0.0), Vector3(0.13, 0.92, 0.18), "body"),
		_box_spec("LegLeft", Vector3(-0.1584, 0.34, 0.0), Vector3(0.16, 0.68, 0.2), "body"),
		_box_spec("LongArmRight", Vector3(0.33, 1.05, 0.0), Vector3(0.13, 0.92, 0.18), "body"),
		_box_spec("LegRight", Vector3(0.1584, 0.34, 0.0), Vector3(0.16, 0.68, 0.2), "body")
	]

static func _deathmoth_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for wing_index in range(2):
		var wing_side: float = -1.0 if wing_index == 0 else 1.0
		specs.append(_box_spec(
			"Wing_%d" % wing_index,
			Vector3(wing_side * 0.48, 0.08, 0.0),
			Vector3(0.86, 0.045, 0.54),
			"wing",
			Vector3(0.0, 0.0, wing_side * 0.18)
		))
		specs.append(_box_spec(
			"RearWing_%d" % wing_index,
			Vector3(wing_side * 0.34, 0.02, -0.28),
			Vector3(0.58, 0.04, 0.38),
			"wing",
			Vector3(0.0, 0.0, wing_side * 0.12)
		))
	specs.append(_box_spec("Abdomen", Vector3(0.0, 0.0, -0.22), Vector3(0.32, 0.34, 0.55), "body"))
	specs.append(_box_spec("Thorax", Vector3(0.0, 0.02, 0.15), Vector3(0.36, 0.38, 0.36), "body"))
	specs.append(_box_spec("Head", Vector3(0.0, 0.05, 0.42), Vector3(0.24, 0.24, 0.22), "body"))
	for eye_index in range(2):
		var eye_side: float = -1.0 if eye_index == 0 else 1.0
		specs.append(_sphere_spec("CompoundEye_%d" % eye_index, Vector3(eye_side * 0.1, 0.08, 0.53), 0.055, "eye", 0.11))
		specs.append(_box_spec("Antenna_%d" % eye_index, Vector3(eye_side * 0.09, 0.24, 0.57), Vector3(0.035, 0.28, 0.035), "body"))
		for leg_index in range(3):
			var leg_z: float = 0.24 - float(leg_index) * 0.22
			specs.append(_box_spec(
				"Leg_%d_%d" % [eye_index, leg_index],
				Vector3(eye_side * 0.16, -0.2, leg_z),
				Vector3(0.045, 0.3, 0.045),
				"body"
			))
	return specs

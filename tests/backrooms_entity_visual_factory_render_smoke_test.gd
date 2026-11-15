extends SceneTree

const FactoryScript = preload("res://systems/BackroomsEntityVisualFactory.gd")

const ENTITY_PART_COUNTS := {
	"window": 5,
	"smiler": 3,
	"hound": 8,
	"skin_stealer": 6,
	"clump": 7,
	"faceling": 6,
	"duller": 6,
	"deathmoth": 17
}

const BACKGROUND_COLOR := Color(0.012, 0.018, 0.026, 1.0)
const SCREENSHOT_PATH := "/tmp/backrooms-visual-factory-render-smoke.png"

var failures: Array[String] = []
var built_mesh_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(DisplayServer.get_name() != "headless", "graphical DisplayServer is active under Xvfb")
	if DisplayServer.get_name() == "headless":
		_finish_with_failure()
		return

	var viewport: Window = get_root()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = false
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)

	var stage := Node3D.new()
	stage.name = "BackroomsVisualFactoryRenderStage"
	viewport.add_child(stage)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.62, 0.62, 1.0)
	environment.ambient_light_energy = 0.75
	environment_node.environment = environment
	stage.add_child(environment_node)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0
	camera.position = Vector3(0.0, 2.8, 18.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	stage.add_child(camera)
	camera.make_current()

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38.0, -24.0, 0.0)
	key_light.light_energy = 1.4
	stage.add_child(key_light)

	for entity_index in range(ENTITY_PART_COUNTS.size()):
		var entity_id: String = str(ENTITY_PART_COUNTS.keys()[entity_index])
		var entity_root := Node3D.new()
		entity_root.name = "RenderSmoke_%s" % entity_id
		var column: int = entity_index % 4
		var row: int = int(entity_index / 4)
		entity_root.position = Vector3((float(column) - 1.5) * 2.5, 0.0, (float(row) - 0.5) * 2.0)
		entity_root.set_meta("backrooms_entity_id", entity_id)
		if entity_id == "window":
			entity_root.set_meta("backrooms_wall_direction", Vector2i(0, -1))
		stage.add_child(entity_root)

		var attached: bool = FactoryScript.attach_visuals(entity_root)
		_expect(attached, "%s attaches its production visual subtree in graphical mode" % entity_id)
		var visuals := entity_root.get_node_or_null("Visuals") as Node3D
		_expect(visuals != null, "%s publishes a Visuals Node3D" % entity_id)
		if visuals == null:
			continue

		var expected_parts: int = int(ENTITY_PART_COUNTS[entity_id])
		_expect(visuals.get_child_count() == expected_parts, "%s builds all %d expected mesh parts" % [entity_id, expected_parts])
		for part in visuals.get_children():
			var mesh_instance := part as MeshInstance3D
			_expect(mesh_instance != null, "%s child is a MeshInstance3D" % entity_id)
			if mesh_instance == null:
				continue
			_expect(mesh_instance.mesh != null, "%s mesh resource is assigned" % entity_id)
			_expect(mesh_instance.mesh.get_surface_count() > 0, "%s mesh has at least one renderable surface" % entity_id)
			_expect(mesh_instance.material_override is Material, "%s material override is assigned" % entity_id)
			var bounds: AABB = mesh_instance.get_aabb()
			_expect(
				bounds.size.x > 0.0 and bounds.size.y > 0.0 and bounds.size.z > 0.0,
				"%s mesh has non-zero local bounds" % entity_id
			)
			built_mesh_count += 1

		if entity_id == "window":
			_expect(
				is_equal_approx(entity_root.rotation.y, 0.0),
				"north-owned Window retains the expected production orientation"
			)

	_expect(built_mesh_count == 58, "all eight entities build exactly 58 MeshInstance3D parts")

	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw

	var rendered_image: Image = viewport.get_texture().get_image()
	_expect(rendered_image != null and not rendered_image.is_empty(), "root viewport returns a rendered image")
	if rendered_image != null and not rendered_image.is_empty():
		var visible_samples: int = _count_non_background_samples(rendered_image)
		_expect(visible_samples > 80, "rendered frame contains visible entity pixels (samples=%d)" % visible_samples)
		var save_error: Error = rendered_image.save_png(SCREENSHOT_PATH)
		_expect(save_error == OK, "rendered frame screenshot is saved for artifact inspection")

	stage.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw

	if failures.is_empty():
		print("Backrooms entity visual factory graphical smoke test passed.")
		print("DisplayServer: %s" % DisplayServer.get_name())
		print("MeshInstance3D parts: %d" % built_mesh_count)
		quit(0)
	else:
		_finish_with_failure()

func _count_non_background_samples(image: Image) -> int:
	var visible_samples: int = 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var pixel: Color = image.get_pixel(x, y)
			var delta: float = absf(pixel.r - BACKGROUND_COLOR.r) + absf(pixel.g - BACKGROUND_COLOR.g) + absf(pixel.b - BACKGROUND_COLOR.b)
			if delta > 0.08:
				visible_samples += 1
	return visible_samples

func _finish_with_failure() -> void:
	for failure in failures:
		push_error("FAILED: " + failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)

extends SceneTree

const RuntimeScript = preload("res://systems/BackroomsMazeCellRuntime.gd")
const EntityDirectorScript = preload("res://systems/BackroomsEntityDirector.gd")

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

const LEVEL_ENTITY_RULES := {
	"Level 1": ["window", "smiler"],
	"Level 2": ["hound", "skin_stealer"],
	"Level 3": ["clump", "faceling"],
	"Level 4": ["duller"],
	"Level 5": ["deathmoth"]
}

const WORLD_SEED: int = 20261115
const CELL_SIZE: float = 8.0
const BACKGROUND_COLOR := Color(0.035, 0.045, 0.060, 1.0)
const SCREENSHOT_PATH := "/tmp/backrooms-visual-factory-render-smoke.png"

var failures: Array[String] = []
var built_mesh_count: int = 0
var rendered_entities: Array[Node3D] = []
var rendered_entity_ids: Array[String] = []
var smoke_camera: Camera3D

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
	stage.name = "BackroomsProductionEntityRenderStage"
	viewport.add_child(stage)
	_add_lighting(stage)

	_assert_level_zero_is_entity_free(stage)
	var slot: int = 0
	for level_id in LEVEL_ENTITY_RULES.keys():
		for entity_id_value in LEVEL_ENTITY_RULES[level_id]:
			var entity_id: String = str(entity_id_value)
			var entity_root: Node3D = _build_production_entity(stage, str(level_id), entity_id, slot)
			_expect(entity_root != null, "%s production maze runtime creates %s with real visuals" % [level_id, entity_id])
			if entity_root != null:
				_assert_entity_meshes(entity_id, entity_root)
				rendered_entities.append(entity_root)
				rendered_entity_ids.append(entity_id)
			slot += 1

	_expect(built_mesh_count == 58, "production runtime publishes all eight entities with exactly 58 target MeshInstance3D parts")

	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw

	var rendered_image: Image = viewport.get_texture().get_image()
	_expect(rendered_image != null and not rendered_image.is_empty(), "root viewport returns a rendered image")
	if rendered_image != null and not rendered_image.is_empty():
		var visible_samples: int = _count_non_background_samples(rendered_image)
		_expect(visible_samples > 80, "rendered frame contains visible production entity pixels (samples=%d)" % visible_samples)


	var entity_montage := Image.create(1280, 360, false, Image.FORMAT_RGBA8)
	entity_montage.fill(BACKGROUND_COLOR)
	for entity_index in range(rendered_entities.size()):
		for other_index in range(rendered_entities.size()):
			rendered_entities[other_index].visible = other_index == entity_index
		if rendered_entity_ids[entity_index] == "window":
			var wall_direction: Vector2i = rendered_entities[entity_index].get_meta("backrooms_wall_direction", Vector2i.ZERO)
			if wall_direction == Vector2i(-1, 0):
				smoke_camera.position = Vector3(18.0, 4.5, 0.0)
			else:
				smoke_camera.position = Vector3(0.0, 4.5, 18.0)
		else:
			smoke_camera.position = Vector3(0.0, 4.5, 18.0)
		smoke_camera.size = 4.8
		smoke_camera.look_at(Vector3(0.0, 2.6, 0.0), Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var isolated_image: Image = viewport.get_texture().get_image()
		_expect(isolated_image != null and not isolated_image.is_empty(), "%s isolated render returns an image" % rendered_entity_ids[entity_index])
		if isolated_image != null and not isolated_image.is_empty():
			var isolated_samples: int = _count_non_background_samples(isolated_image, 4)
			_expect(isolated_samples > 3, "%s independently contributes visible pixels (samples=%d)" % [rendered_entity_ids[entity_index], isolated_samples])
			print("RENDERED_ENTITY: %s visible_samples=%d" % [rendered_entity_ids[entity_index], isolated_samples])
			var thumbnail: Image = isolated_image.duplicate()
			thumbnail.resize(320, 180, Image.INTERPOLATE_LANCZOS)
			entity_montage.blit_rect(thumbnail, Rect2i(Vector2i.ZERO, thumbnail.get_size()), Vector2i((entity_index % 4) * 320, int(entity_index / 4) * 180))

	for entity_root in rendered_entities:
		entity_root.visible = true
	var montage_save_error: Error = entity_montage.save_png(SCREENSHOT_PATH)
	_expect(montage_save_error == OK, "eight isolated entity frames are saved as a 4-by-2 montage artifact")

	stage.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw

	if failures.is_empty():
		print("Backrooms entity visual factory graphical smoke test passed.")
		print("DisplayServer: %s" % DisplayServer.get_name())
		print("Production entity target mesh parts: %d" % built_mesh_count)
		quit(0)
	else:
		_finish_with_failure()

func _add_lighting(stage: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.62, 0.62, 1.0)
	environment.ambient_light_energy = 1.15
	environment_node.environment = environment
	stage.add_child(environment_node)

	smoke_camera = Camera3D.new()
	var camera := smoke_camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.5
	stage.add_child(camera)
	camera.position = Vector3(0.0, 4.5, 18.0)
	camera.look_at(Vector3(0.0, 2.6, 0.0), Vector3.UP)
	camera.make_current()

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38.0, -24.0, 0.0)
	key_light.light_energy = 1.8
	stage.add_child(key_light)

func _assert_level_zero_is_entity_free(stage: Node3D) -> void:
	var runtime: Variant = RuntimeScript.new()
	runtime.name = "LevelZeroEntityWhitelistSmoke"
	stage.add_child(runtime)
	var prepared: Dictionary = runtime.call("prepare_destination", "Level 0", WORLD_SEED, Vector3.ZERO, CELL_SIZE, 0)
	_expect(bool(prepared.get("ok", false)), "Level 0 production runtime prepares in graphical mode")
	var cell_root: Node3D = runtime.call("get_cell_root", "0,0") as Node3D
	_expect(cell_root != null, "Level 0 production cell root exists")
	if cell_root != null:
		_expect(cell_root.get_meta("backrooms_entity_spawn_ids", []).is_empty(), "Level 0 spawn identity list remains empty")
		_expect(_find_entity_root(cell_root, "window") == null, "Level 0 never creates a Window entity")
		_expect(_find_entity_root(cell_root, "smiler") == null, "Level 0 never creates a Smiler entity")
	runtime.queue_free()

func _build_production_entity(stage: Node3D, level_id: String, entity_id: String, slot: int) -> Node3D:
	var runtime: Variant = RuntimeScript.new()
	runtime.name = "RenderSmokeRuntime_%s" % entity_id
	stage.add_child(runtime)

	var target_position := Vector3((float(slot % 4) - 1.5) * 2.0, float(int(slot / 4)) * 3.0, 0.0)
	if entity_id == "window":
		target_position = Vector3(0.0, 1.2, 0.0)
	for z in range(-40, 41):
		for x in range(-40, 41):
			var cell := Vector2i(x, z)
			if not EntityDirectorScript.get_cell_spawns(level_id, cell).has(entity_id):
				continue
			var cell_origin := Vector3(float(x) * CELL_SIZE, 0.0, float(z) * CELL_SIZE)
			runtime.position = target_position - cell_origin
			var prepared: Dictionary = runtime.call(
				"prepare_destination",
				level_id,
				WORLD_SEED,
				cell_origin,
				CELL_SIZE,
				0
			)
			if not bool(prepared.get("ok", false)):
				continue
			var cell_key: String = "%d,%d" % [x, z]
			var cell_root: Node3D = runtime.call("get_cell_root", cell_key) as Node3D
			var entity_root: Node3D = _find_entity_root(cell_root, entity_id)
			if entity_root == null:
				continue

			runtime.global_position += target_position - entity_root.global_position
			_expect(entity_root.global_position.is_equal_approx(target_position), "%s smoke target is centered in the render stage" % entity_id)
			_expect(entity_root.get_meta("backrooms_entity_id", "") == entity_id, "%s root preserves its production entity identity" % entity_id)
			_expect(entity_root.get_meta("spawn_level_id", "") == level_id, "%s root preserves its production level identity" % entity_id)
			_expect(entity_root.get_meta("spawn_world_seed", -1) == WORLD_SEED, "%s root preserves its deterministic world seed" % entity_id)
			_expect(entity_root.get_meta("spawn_cell", null) is Vector2i, "%s root preserves its owning maze cell" % entity_id)
			_expect(int(entity_root.get_meta("spawn_algorithm_version", 0)) == EntityDirectorScript.SPAWN_ALGORITHM_VERSION, "%s root preserves its spawn algorithm version" % entity_id)
			_expect(entity_root.get_meta("backrooms_entity_visual_state", "") == "attached", "%s production root records attached visual state" % entity_id)
			_expect(int(entity_root.get_meta("backrooms_entity_visual_version", 0)) == 1, "%s production root records visual factory version one" % entity_id)
			_expect(int(runtime.call("get_loaded_cell_count")) == 1, "%s graphical runtime stages exactly its target cell" % entity_id)
			if entity_id == "window":
				var wall_direction: Vector2i = entity_root.get_meta("backrooms_wall_direction", Vector2i.ZERO)
				var expected_yaw: float = 0.0 if wall_direction == Vector2i(0, -1) else PI * 0.5
				_expect(wall_direction in [Vector2i(0, -1), Vector2i(-1, 0)], "Window production spawn owns a supported north or west wall")
				_expect(is_equal_approx(entity_root.rotation.y, expected_yaw), "Window production visual follows its owned wall orientation")

			for cell_child in cell_root.get_children():
				if cell_child.name == "Floor" or str(cell_child.name).begins_with("Wall_"):
					cell_child.visible = false

			_expect(bool(runtime.call("activate_destination")), "%s production runtime activates its rendered cell" % entity_id)
			return entity_root

	runtime.queue_free()
	return null

func _find_entity_root(cell_root: Node3D, entity_id: String) -> Node3D:
	if cell_root == null:
		return null
	for child in cell_root.get_children():
		if child is Node3D and child.get_meta("backrooms_entity_id", "") == entity_id:
			return child as Node3D
	return null

func _assert_entity_meshes(entity_id: String, entity_root: Node3D) -> void:
	var visuals := entity_root.get_node_or_null("Visuals") as Node3D
	_expect(visuals != null, "%s production entity exposes a Visuals subtree" % entity_id)
	if visuals == null:
		return
	var expected_parts: int = int(ENTITY_PART_COUNTS[entity_id])
	_expect(visuals.get_child_count() == expected_parts, "%s production visual subtree has %d parts" % [entity_id, expected_parts])
	for part in visuals.get_children():
		var mesh_instance := part as MeshInstance3D
		_expect(mesh_instance != null, "%s production visual child is a MeshInstance3D" % entity_id)
		if mesh_instance == null:
			continue
		_expect(mesh_instance.mesh != null, "%s production mesh resource is assigned" % entity_id)
		_expect(mesh_instance.mesh.get_surface_count() > 0, "%s production mesh has a renderable surface" % entity_id)
		_expect(mesh_instance.material_override is Material, "%s production material override is assigned" % entity_id)
		var bounds: AABB = mesh_instance.get_aabb()
		_expect(bounds.size.x > 0.0 and bounds.size.y > 0.0 and bounds.size.z > 0.0, "%s production mesh has non-zero local bounds" % entity_id)
		built_mesh_count += 1

func _count_non_background_samples(image: Image, stride: int = 8) -> int:
	var visible_samples: int = 0
	for y in range(0, image.get_height(), stride):
		for x in range(0, image.get_width(), stride):
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

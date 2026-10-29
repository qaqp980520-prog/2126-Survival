extends "res://scripts/world.gd"

const MiningNodeScript = preload("res://systems/MineralMiningNode.gd")
const CropPlotVisualScene = preload("res://systems/CropPlotVisual.tscn")
const StatefulPropScript = preload("res://systems/WorldObjectStatefulProp.gd")
const MineralCatalogScript = preload("res://systems/MineralCatalog.gd")

const CHUNK_SIZE: float = 10.0
const MINERAL_IDS: Array[String] = ["iron_ore", "copper_ore", "gold_ore"]
const SALVAGE_LOOT_IDS: Array[String] = ["copper_ore", "iron_ore", "coal_ore", "silver_ore"]

var camera: Camera3D
var hud: Label
var _yaw: float = 0.0
var _pitch: float = -0.12
var _mouse_look_active: bool = false
var _jump_was_down: bool = false
var _crop_action_message: String = "E: crop · F: salvage crate."
var _world_object_action_message: String = "F: interact with a nearby salvage crate."

func _ready() -> void:
	if not initialize_world_session():
		return
	_build_environment()
	_build_player()
	_build_hud()
	_sync_streaming(int(Time.get_unix_time_from_system()))

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.032, 0.052)
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "KrollSun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(1.0, 2.0, 1.0)
	add_child(player)
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.35
	capsule_shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule_shape
	collision.position = Vector3(0.0, 0.9, 0.0)
	player.add_child(collision)
	if DisplayServer.get_name() != "headless":
		var body_mesh := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.35
		capsule_mesh.height = 1.8
		body_mesh.mesh = capsule_mesh
		body_mesh.position = Vector3(0.0, 0.9, 0.0)
		var body_material := StandardMaterial3D.new()
		body_material.albedo_color = Color(0.16, 0.78, 0.9)
		body_mesh.material_override = body_material
		player.add_child(body_mesh)
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.position = Vector3(0.0, 1.48, 0.0)
	camera.rotation.x = _pitch
	camera.current = true
	camera.fov = 76.0
	player.add_child(camera)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(16.0, 16.0)
	hud.size = Vector2(900.0, 150.0)
	hud.add_theme_color_override("font_color", Color(0.62, 0.94, 1.0))
	hud.add_theme_font_size_override("font_size", 16)
	layer.add_child(hud)
	_refresh_hud()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var move_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_input.x += 1.0
	if Input.is_key_pressed(KEY_W):
		move_input.y += 1.0
	if Input.is_key_pressed(KEY_S):
		move_input.y -= 1.0
	if move_input.length() > 1.0:
		move_input = move_input.normalized()
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var movement := (right * move_input.x + forward * move_input.y).normalized()
	var speed: float = 5.0
	player.velocity.x = movement.x * speed
	player.velocity.z = movement.z * speed
	if not player.is_on_floor():
		player.velocity.y -= 20.0 * delta
	elif player.velocity.y < 0.0:
		player.velocity.y = 0.0
	var jump_down := Input.is_key_pressed(KEY_SPACE)
	if jump_down and not _jump_was_down and player.is_on_floor():
		player.velocity.y = 7.0
	_jump_was_down = jump_down
	player.move_and_slide()
	var current_grid: Vector2i = director.get_grid_coordinate(player.global_position)
	if current_grid != _last_grid:
		_sync_streaming(int(Time.get_unix_time_from_system()))
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_F10:
				_mouse_look_active = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_tree().change_scene_to_file("res://prototypes/SurvivalTestHub.tscn")
			elif key_event.keycode == KEY_E:
				_interact_nearest_crop_plot()
			elif key_event.keycode == KEY_F:
				_interact_nearest_world_prop()
			elif key_event.keycode == KEY_ESCAPE:
				_mouse_look_active = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_look_active = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and _mouse_look_active:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.003
		_pitch = clampf(_pitch - motion.relative.y * 0.003, -1.05, 1.05)
		player.rotation.y = _yaw
		camera.rotation.x = _pitch

func _interact_nearest_crop_plot(now_unix: int = -1) -> Dictionary:
	if player == null or chunk_controller == null or crop_controller == null:
		return {"ok": false, "action": "unavailable", "message": "Crop interaction is unavailable."}
	var nearest: Node3D = null
	var nearest_distance: float = 3.25
	for plot in chunk_controller.get_loaded_crop_plots():
		if not is_instance_valid(plot):
			continue
		var distance: float = player.global_position.distance_to(plot.global_position)
		if distance <= nearest_distance:
			nearest = plot
			nearest_distance = distance
	if nearest == null:
		_crop_action_message = "No crop plot within reach."
		_refresh_hud()
		return {"ok": false, "action": "out_of_reach", "message": _crop_action_message}
	var timestamp: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var result: Dictionary = nearest.call("interact", timestamp)
	_crop_action_message = str(result.get("message", "Crop action completed."))
	_refresh_hud()
	return result

func _interact_nearest_world_prop(now_unix: int = -1) -> Dictionary:
	if player == null or chunk_controller == null:
		return {"ok": false, "action": "unavailable", "message": "World-object interaction is unavailable."}
	var nearest: Node3D = null
	var nearest_distance: float = 3.25
	for prop in chunk_controller.get_loaded_world_state_nodes():
		if not is_instance_valid(prop):
			continue
		var distance: float = player.global_position.distance_to(prop.global_position)
		if distance <= nearest_distance:
			nearest = prop
			nearest_distance = distance
	if nearest == null:
		_world_object_action_message = "No salvage crate within reach."
		_refresh_hud()
		return {"ok": false, "action": "out_of_reach", "message": _world_object_action_message}
	var result: Dictionary = nearest.call("interact_with_inventory", inventory_bridge)
	var ok: bool = bool(result.get("ok", false))
	var reason: String = str(result.get("reason", "unknown"))
	var item_id: String = str(result.get("item_id", "iron_ore"))
	var mineral_data: Dictionary = MineralCatalogScript.get_mineral(item_id)
	var display_name: String = str(mineral_data.get("display_name", item_id))
	if ok:
		_world_object_action_message = "Recovered 1 %s; %d salvage units remain." % [display_name, int(result.get("remaining", 0))]
	elif reason == "inventory_rejected":
		_world_object_action_message = "Inventory cannot accept %s; crate unchanged." % display_name
	elif reason == "empty":
		_world_object_action_message = "Crate is empty."
	else:
		_world_object_action_message = "Crate interaction blocked: %s." % reason
	result["action"] = "interacted" if ok else reason
	result["message"] = _world_object_action_message
	_refresh_hud()
	return result


func _make_chunk(coord: Vector2i) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk.position = Vector3(float(coord.x) * CHUNK_SIZE, 0.0, float(coord.y) * CHUNK_SIZE)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	chunk.add_child(ground)
	var box_size := Vector3(CHUNK_SIZE, 0.5, CHUNK_SIZE)
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box_size
	collision.shape = box_shape
	collision.position = Vector3(CHUNK_SIZE * 0.5, -0.25, CHUNK_SIZE * 0.5)
	ground.add_child(collision)
	if DisplayServer.get_name() != "headless":
		var ground_mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = box_size
		ground_mesh.mesh = box_mesh
		ground_mesh.position = collision.position
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.10, 0.15, 0.19) if (coord.x + coord.y) % 2 == 0 else Color(0.13, 0.18, 0.22)
		ground_mesh.material_override = material
		ground.add_child(ground_mesh)
	var ore: Node3D = MiningNodeScript.new()
	ore.name = "Ore_%d_%d" % [coord.x, coord.y]
	ore.mineral_id = str(MINERAL_IDS[posmod(coord.x + coord.y, MINERAL_IDS.size())])
	ore.max_units = 6
	ore.remaining_units = 6
	ore.regen_interval_seconds = 60
	ore.last_regen_unix = _stream_clock_unix if _stream_clock_unix > 0 else int(Time.get_unix_time_from_system())
	ore.inventory_bridge_path = NodePath("../../../SurvivalWorldBridge")
	ore.position = Vector3(CHUNK_SIZE * 0.5, -3.0, CHUNK_SIZE * 0.5)
	chunk.add_child(ore)
	var crate: Node3D = StatefulPropScript.new()
	crate.name = "SalvageCrate"
	var loot_index: int = posmod(coord.x * 31 + coord.y * 17 + 1009, SALVAGE_LOOT_IDS.size())
	crate.call("set_loot_item", SALVAGE_LOOT_IDS[loot_index])
	crate.position = Vector3(CHUNK_SIZE * 0.55, 0.0, CHUNK_SIZE * 0.62)
	chunk.add_child(crate)
	var crop_kinds: Array[String] = ["wheat", "tomato"]
	for plot_index in range(crop_kinds.size()):
		var plot := CropPlotVisualScene.instantiate() as Node3D
		plot.name = "CropPlot_" + str(plot_index)
		plot.set("crop_id", crop_kinds[plot_index])
		plot.set("plot_index", plot_index + 1)
		plot.position = Vector3(2.4 + float(plot_index) * 5.0, 0.0, 2.4)
		chunk.add_child(plot)
	return chunk

func _refresh_hud() -> void:
	if hud == null:
		return
	var active_count: int = chunk_controller.get_loaded_chunk_ids().size() if chunk_controller != null else 0
	var record_count: int = registry.get_saved_ids().size() if registry != null else 0
	var grid_text := str(director.get_grid_coordinate(player.global_position)) if director != null and player != null else "n/a"
	var inventory_summary: Dictionary = inventory_bridge.call("get_summary") if inventory_bridge != null else {}
	var weight := float(inventory_summary.get("weight_kg", 0.0))
	var limit := float(inventory_summary.get("limit_kg", 65.0))
	var crop_record_count: int = crop_registry.get_saved_ids().size() if crop_registry != null else 0
	hud.text = "KROLL // SURFACE STREAM PLAYGROUND\nWASD move · SPACE jump · RMB look · E crop · F crate · F10 test menu\nGrid: %s   Active chunks: %d   Vein records: %d   Crops: %d\nCarry: %.1f / %.1f kg\n%s\n%s" % [grid_text, active_count, record_count, crop_record_count, weight, limit, _crop_action_message, _world_object_action_message]

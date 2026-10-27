extends Node3D

const RegistryScript = preload("res://systems/MineralVeinRegistry.gd")
const ChunkControllerScript = preload("res://systems/MineralChunkController.gd")
const MiningNodeScript = preload("res://systems/MineralMiningNode.gd")
const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const HUB_SCENE := "res://prototypes/SurvivalTestHub.tscn"
const CAVE_CHUNK_ID := "underground/cave_0_0"
const CAVE_FLOOR_Y: float = -8.0
const MINE_RANGE: float = 3.5

var registry: Node
var chunk_controller: Node3D
var inventory_bridge: Node
var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var veins: Array[Node3D] = []
var _yaw: float = 0.0
var _pitch: float = -0.08
var _mouse_look_active: bool = false
var _jump_was_down: bool = false
var _last_mined_id: String = ""

func _ready() -> void:
	_build_streaming_stack()
	_build_environment()
	_build_player()
	_build_cave_chunk()
	_build_hud()
	_refresh_hud()

func _build_streaming_stack() -> void:
	registry = RegistryScript.new()
	registry.name = "MineralVeinRegistry"
	add_child(registry)
	inventory_bridge = BridgeScript.new()
	inventory_bridge.name = "SurvivalWorldBridge"
	add_child(inventory_bridge)
	chunk_controller = ChunkControllerScript.new()
	chunk_controller.name = "MineralChunkController"
	add_child(chunk_controller)
	if not chunk_controller.bind_registry(registry):
		push_error("Underground mining scene could not bind the mineral registry.")

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.018, 0.028)
	world_environment.environment = environment
	add_child(world_environment)
	var cave_light := OmniLight3D.new()
	cave_light.name = "CaveLamp"
	cave_light.position = Vector3(0.0, -4.2, 0.0)
	cave_light.light_color = Color(0.58, 0.78, 1.0)
	cave_light.light_energy = 2.2
	cave_light.omni_range = 18.0
	cave_light.shadow_enabled = false
	add_child(cave_light)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0.0, CAVE_FLOOR_Y, 0.0)
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.9, 0.0)
	player.add_child(collision)
	if DisplayServer.get_name() != "headless":
		var body_mesh := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.35
		capsule_mesh.height = 1.8
		body_mesh.mesh = capsule_mesh
		body_mesh.position = Vector3(0.0, 0.9, 0.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.18, 0.82, 0.95)
		body_mesh.material_override = material
		player.add_child(body_mesh)
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.position = Vector3(0.0, 1.52, 0.0)
	camera.rotation.x = _pitch
	camera.current = true
	camera.fov = 76.0
	player.add_child(camera)

func _build_cave_chunk() -> void:
	var chunk_root := Node3D.new()
	chunk_root.name = "CaveChunk_0_0"
	_add_box_body(chunk_root, "CaveFloor", Vector3(0.0, -8.25, 0.0), Vector3(24.0, 0.5, 24.0), Color(0.12, 0.14, 0.17))
	_add_box_body(chunk_root, "CaveCeiling", Vector3(0.0, -2.0, 0.0), Vector3(24.0, 0.5, 24.0), Color(0.075, 0.085, 0.10))
	_add_box_body(chunk_root, "WallWest", Vector3(-12.0, -5.125, 0.0), Vector3(0.5, 6.25, 24.0), Color(0.10, 0.12, 0.15))
	_add_box_body(chunk_root, "WallEast", Vector3(12.0, -5.125, 0.0), Vector3(0.5, 6.25, 24.0), Color(0.10, 0.12, 0.15))
	_add_box_body(chunk_root, "WallNorth", Vector3(0.0, -5.125, -12.0), Vector3(24.0, 6.25, 0.5), Color(0.10, 0.12, 0.15))
	_add_box_body(chunk_root, "WallSouth", Vector3(0.0, -5.125, 12.0), Vector3(24.0, 6.25, 0.5), Color(0.10, 0.12, 0.15))

	var mineral_specs: Array[Dictionary] = [
		{"id": "iron_ore", "name": "Vein_Iron", "position": Vector3(3.0, -7.7, 0.0)},
		{"id": "copper_ore", "name": "Vein_Copper", "position": Vector3(-3.0, -7.7, 2.0)},
		{"id": "uranium_ore", "name": "Vein_Uranium", "position": Vector3(0.0, -7.7, -4.0)}
	]
	for spec in mineral_specs:
		var vein: Node3D = MiningNodeScript.new()
		vein.name = str(spec["name"])
		vein.mineral_id = str(spec["id"])
		vein.max_units = 8
		vein.remaining_units = 8
		vein.units_per_hit = 2
		vein.regen_interval_seconds = 300
		vein.last_regen_unix = int(Time.get_unix_time_from_system())
		vein.inventory_bridge_path = NodePath("../../../SurvivalWorldBridge")
		vein.position = spec["position"]
		chunk_root.add_child(vein)
		veins.append(vein)

	if not chunk_controller.load_chunk(CAVE_CHUNK_ID, chunk_root, int(Time.get_unix_time_from_system())):
		push_error("Underground cave chunk could not be registered with the mineral lifecycle controller.")

func _add_box_body(parent: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	if DisplayServer.get_name() != "headless":
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.94
		mesh_instance.material_override = material
		body.add_child(mesh_instance)
	parent.add_child(body)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Label.new()
	hud.name = "Status"
	hud.position = Vector2(16.0, 16.0)
	hud.size = Vector2(1000.0, 130.0)
	hud.add_theme_font_size_override("font_size", 16)
	hud.add_theme_color_override("font_color", Color(0.66, 0.91, 1.0))
	layer.add_child(hud)

func _physics_process(delta: float) -> void:
	if player == null or camera == null:
		return
	var input_axis := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_axis.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_axis.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_axis.y += 1.0
	if Input.is_key_pressed(KEY_S):
		input_axis.y -= 1.0
	if input_axis.length() > 1.0:
		input_axis = input_axis.normalized()
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var movement := (right * input_axis.x + forward * input_axis.y).normalized()
	var speed: float = 4.5
	player.velocity.x = movement.x * speed
	player.velocity.z = movement.z * speed
	if not player.is_on_floor():
		player.velocity.y -= 20.0 * delta
	elif player.velocity.y < 0.0:
		player.velocity.y = 0.0
	var jump_down := Input.is_key_pressed(KEY_SPACE)
	if jump_down and not _jump_was_down and player.is_on_floor():
		player.velocity.y = 6.5
	_jump_was_down = jump_down
	player.move_and_slide()
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_F:
					mine_nearest_vein()
				KEY_G:
					drop_last_mined_ore()
				KEY_F10:
					_mouse_look_active = false
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					get_tree().change_scene_to_file(HUB_SCENE)
				KEY_ESCAPE:
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

func get_nearest_vein() -> Node3D:
	if player == null:
		return null
	var nearest: Node3D = null
	var nearest_distance := MINE_RANGE
	for vein in veins:
		if not is_instance_valid(vein) or not vein.visible or int(vein.get("remaining_units")) <= 0:
			continue
		var distance := player.global_position.distance_to(vein.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = vein
	return nearest

func mine_nearest_vein() -> int:
	var vein := get_nearest_vein()
	if vein == null:
		_refresh_hud()
		return 0
	var accepted := int(vein.call("mine_hit", Vector3.ZERO))
	if accepted > 0:
		_last_mined_id = str(vein.get("mineral_id"))
	_refresh_hud()
	return accepted

func drop_last_mined_ore() -> bool:
	if _last_mined_id.is_empty() or inventory_bridge == null:
		return false
	var dropped := bool(inventory_bridge.call("drop_item", _last_mined_id, 1))
	_refresh_hud()
	return dropped

func serialize_mineral_state() -> Dictionary:
	if chunk_controller == null:
		return {}
	return chunk_controller.to_save_dict()

func restore_mineral_state(payload: Dictionary, now_unix: int = -1) -> bool:
	if chunk_controller == null or not chunk_controller.restore_save_dict(payload, now_unix):
		return false
	_refresh_hud()
	return true

func _refresh_hud() -> void:
	if hud == null:
		return
	var summary: Dictionary = inventory_bridge.call("get_summary") if inventory_bridge != null else {}
	var nearest := get_nearest_vein()
	var vein_text := "範圍內沒有可開採礦脈"
	if nearest != null:
		vein_text = "%s：剩餘 %d 單位（F 開採）" % [str(nearest.get("mineral_id")), int(nearest.get("remaining_units"))]
	hud.text = "2126 SURVIVAL // UNDERGROUND MINE\nWASD 移動 · Space 跳躍 · 右鍵轉視角 · F 開採 · G 丟棄一個剛開採的礦石 · F10 返回測試選單\n%s\n背包重量：%.1f / %.1f kg · 負重倍率：%.2f · 可跳躍：%s" % [
		vein_text,
		float(summary.get("weight_kg", 0.0)),
		float(summary.get("limit_kg", 65.0)),
		float(summary.get("movement_multiplier", 1.0)),
		"是" if bool(summary.get("can_jump", true)) else "否"
	]

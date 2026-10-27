extends Node3D

const RegistryScript = preload("res://systems/MineralVeinRegistry.gd")
const ControllerScript = preload("res://systems/MineralChunkController.gd")
const DirectorScript = preload("res://systems/MineralGridStreamingDirector.gd")
const MiningNodeScript = preload("res://systems/MineralMiningNode.gd")
const InventoryBridgeScript = preload("res://systems/SurvivalWorldBridge.gd")

const CHUNK_SIZE: float = 10.0
const MINERAL_IDS: Array[String] = ["iron_ore", "copper_ore", "gold_ore"]

var registry: Node
var chunk_controller: Node3D
var director: Node
var inventory_bridge: Node
var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var _stream_clock_unix: int = -1
var _last_grid: Vector2i = Vector2i(999999, 999999)
var _yaw: float = 0.0
var _pitch: float = -0.12
var _mouse_look_active: bool = false
var _jump_was_down: bool = false
var _last_restore_report: Dictionary = {}

func _ready() -> void:
	_build_streaming_stack()
	_build_environment()
	_build_player()
	_build_hud()
	_sync_streaming(int(Time.get_unix_time_from_system()))

func _build_streaming_stack() -> void:
	registry = RegistryScript.new()
	registry.name = "MineralVeinRegistry"
	add_child(registry)
	inventory_bridge = InventoryBridgeScript.new()
	inventory_bridge.name = "SurvivalWorldBridge"
	add_child(inventory_bridge)
	chunk_controller = ControllerScript.new()
	chunk_controller.name = "MineralChunkController"
	add_child(chunk_controller)
	if not chunk_controller.bind_registry(registry):
		push_error("Surface playground could not bind the mineral registry.")
	director = DirectorScript.new()
	director.name = "MineralGridStreamingDirector"
	director.chunk_size_x = CHUNK_SIZE
	director.chunk_size_z = CHUNK_SIZE
	director.load_radius = 1
	add_child(director)
	if not director.bind_controller(chunk_controller) or not director.bind_chunk_factory(Callable(self, "_make_chunk")):
		push_error("Surface playground could not bind the streaming director.")

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
	hud.size = Vector2(780.0, 110.0)
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
			elif key_event.keycode == KEY_ESCAPE:
				_mouse_look_active = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			elif key_event.keycode == KEY_E:
				_mine_nearest_vein()
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

func _mine_nearest_vein() -> void:
	if player == null or chunk_controller == null:
		return
	var nearest: Node3D = null
	var nearest_distance := 2.8
	for chunk_id in chunk_controller.get_loaded_chunk_ids():
		var chunk: Node = chunk_controller.get_chunk_root(str(chunk_id))
		if chunk == null:
			continue
		for child in chunk.get_children():
			if child is MineralMiningNode:
				var vein := child as Node3D
				var distance := player.global_position.distance_to(vein.global_position)
				if distance < nearest_distance:
					nearest = vein
					nearest_distance = distance
	if nearest == null:
		return
	var mined: int = int(nearest.call("mine_hit", nearest.global_position))
	if mined <= 0:
		push_warning("Mining failed: inventory full or vein depleted.")
	_refresh_hud()

func _sync_streaming(now_unix: int = -1) -> bool:
	if player == null or director == null:
		return false
	_stream_clock_unix = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var success: bool = director.sync_to_world_position(player.global_position, _stream_clock_unix)
	if success:
		_last_grid = director.get_grid_coordinate(player.global_position)
		_refresh_hud()
	return success

func debug_move_player_to(position: Vector3, now_unix: int = -1) -> bool:
	if player == null:
		return false
	player.global_position = position
	return _sync_streaming(now_unix)

func serialize_stream_state() -> Dictionary:
	if chunk_controller == null or player == null:
		return {}
	return {
		"schema_version": 1,
		"player_position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"minerals": chunk_controller.to_save_dict()
	}

func restore_stream_state(payload: Dictionary, now_unix: int = -1) -> bool:
	_set_restore_report(false, "validation", "Restore payload has not been accepted.", true)
	if player == null or chunk_controller == null or director == null:
		_set_restore_report(false, "validation", "Player, controller, or director is unavailable.", true)
		return false
	var schema_value: Variant = payload.get("schema_version", null)
	var position_value: Variant = payload.get("player_position", null)
	var minerals_value: Variant = payload.get("minerals", null)
	if not (schema_value is int) or int(schema_value) != 1:
		_set_restore_report(false, "validation", "Unsupported stream-save schema.", true)
		return false
	if not (position_value is Array) or position_value.size() != 3:
		_set_restore_report(false, "validation", "Player position must contain three components.", true)
		return false
	if not (minerals_value is Dictionary):
		_set_restore_report(false, "validation", "Mineral save payload must be a dictionary.", true)
		return false
	for component in position_value:
		if not (component is int or component is float) or not is_finite(float(component)):
			_set_restore_report(false, "validation", "Player position contains a non-finite component.", true)
			return false

	var now: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var previous_position: Vector3 = player.global_position
	var previous_minerals: Dictionary = chunk_controller.to_save_dict()
	if not previous_minerals.has("schema_version") or not previous_minerals.has("veins"):
		_set_restore_report(false, "snapshot", "Could not snapshot the current mineral state before restore.", true)
		return false
	if not chunk_controller.restore_save_dict(minerals_value, now):
		_set_restore_report(false, "mineral_restore", "Mineral registry rejected the candidate save.", true)
		return false

	player.global_position = Vector3(float(position_value[0]), float(position_value[1]), float(position_value[2]))
	_last_grid = Vector2i(999999, 999999)
	if _sync_streaming(now):
		_set_restore_report(true, "complete", "", true, {
			"active_chunk_ids": chunk_controller.get_loaded_chunk_ids()
		})
		return true

	# A failed target stream must not leave the candidate mineral payload applied.
	# Reconcile the old chunk window first, then restore the exact pre-attempt mineral snapshot.
	var target_sync_report: Dictionary = director.get_last_sync_report()
	player.global_position = previous_position
	_last_grid = Vector2i(999999, 999999)
	var recovery_success: bool = false
	if director.has_method("recover_to_world_position"):
		recovery_success = bool(director.recover_to_world_position(previous_position, now))
	else:
		recovery_success = _sync_streaming(now)
	var recovery_report: Dictionary = director.get_last_sync_report()
	if recovery_success:
		_last_grid = director.get_grid_coordinate(previous_position)

	var minerals_restored: bool = chunk_controller.restore_save_dict(previous_minerals, now)
	var ids_consistent: bool = director.get_managed_chunk_ids() == chunk_controller.get_loaded_chunk_ids()
	var position_restored: bool = player.global_position.is_equal_approx(previous_position)
	var rollback_complete: bool = recovery_success and minerals_restored and ids_consistent and position_restored
	_refresh_hud()
	_set_restore_report(false, "stream_sync", "Target stream sync failed; rollback status is reported in details.", rollback_complete, {
		"target_sync_report": target_sync_report,
		"recovery_report": recovery_report,
		"recovery_success": recovery_success,
		"minerals_restored": minerals_restored,
		"ids_consistent": ids_consistent,
		"position_restored": position_restored
	})
	if not rollback_complete:
		push_warning("Surface stream restore rollback was incomplete; inspect get_last_restore_report().")
	return false

func get_last_restore_report() -> Dictionary:
	return _last_restore_report.duplicate(true)

func _set_restore_report(success: bool, phase: String, message: String, rollback_complete: bool, details: Dictionary = {}) -> void:
	_last_restore_report = {
		"success": success,
		"phase": phase,
		"message": message,
		"rollback_complete": rollback_complete,
		"details": details.duplicate(true)
	}

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
	ore.position = Vector3(CHUNK_SIZE * 0.5, 0.2, CHUNK_SIZE * 0.5)
	chunk.add_child(ore)
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
	hud.text = "KROLL // SURFACE STREAM PLAYGROUND\nWASD move · SPACE jump · RMB look · E mine nearby ore · F10 test menu\nGrid: %s   Active chunks: %d   Vein records: %d\nCarry: %.1f / %.1f kg" % [grid_text, active_count, record_count, weight, limit]

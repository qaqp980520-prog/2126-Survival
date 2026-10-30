extends "res://scripts/world.gd"

const SurfaceChunkFactoryScript = preload("res://systems/SurfaceChunkFactory.gd")
const MineralCatalogScript = preload("res://systems/MineralCatalog.gd")
const UndergroundMineFactoryScript = preload("res://systems/UndergroundMineFactory.gd")
const UndergroundMineDirectorScript = preload("res://systems/UndergroundMineDirector.gd")
const MINE_CHUNK_ID: String = "underground/mine_0_0"
const MINE_ENTRY_SURFACE: Vector3 = Vector3(1.5, 0.0, 7.5)
const MINE_ENTRY_SURFACE_RETURN: Vector3 = Vector3(1.5, 2.0, 7.5)
const MINE_ENTRY_UNDERGROUND: Vector3 = Vector3(1.5, -8.25, 7.5)
const MINE_ACCESS_RANGE: float = 2.75
const MINE_INTERACTION_RANGE: float = 3.5
const BASE_MOVE_SPEED: float = 5.0
const BASE_JUMP_SPEED: float = 7.0
var camera: Camera3D
var hud: Label
var touch_buttons: Dictionary = {}
var _touch_directions: Dictionary = {}
var _touch_jump: bool = false
var _yaw: float = 0.0
var _pitch: float = -0.12
var _mouse_look_active: bool = false
var _jump_was_down: bool = false
var _crop_action_message: String = "E / CROP: plant, water, grow or harvest."
var _world_object_action_message: String = "F / CRATE: recover nearby salvage."
var _is_underground: bool = false
var _mine_chunk_ready: bool = false
var mine_director: Node
var _last_mine_grid: Vector2i = Vector2i(999999, 999999)
var _surface_return_position: Vector3 = MINE_ENTRY_SURFACE_RETURN

func _ready() -> void:
	if not initialize_world_session():
		return
	_build_environment()
	_build_player()
	_build_hud()
	if not _sync_streaming(int(Time.get_unix_time_from_system())):
		push_error("Surface world could not create its initial chunk window.")
	if not _build_underground_mine():
		push_error("Surface world could not register its underground mine chunk.")
	_build_mine_entrance_visual()

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
	hud.name = "WorldStatus"
	hud.position = Vector2(16.0, 14.0)
	hud.size = Vector2(900.0, 128.0)
	hud.add_theme_color_override("font_color", Color(0.62, 0.94, 1.0))
	hud.add_theme_font_size_override("font_size", 15)
	layer.add_child(hud)
	var panel := PanelContainer.new()
	panel.name = "TouchControls"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -146.0
	panel.offset_right = 146.0
	panel.offset_top = -112.0
	panel.offset_bottom = -10.0
	layer.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	panel.add_child(grid)
	_add_touch_button(grid, "left", "A")
	_add_touch_button(grid, "forward", "W")
	_add_touch_button(grid, "back", "S")
	_add_touch_button(grid, "right", "D")
	_add_touch_button(grid, "jump", "JUMP")
	_add_touch_button(grid, "crop", "CROP")
	_add_touch_button(grid, "crate", "CRATE")
	_add_touch_button(grid, "shaft", "DESCEND")
	_refresh_hud()

func _add_touch_button(parent: GridContainer, key: String, label_text: String) -> void:
	var button := Button.new()
	button.name = "Touch_" + key
	button.text = label_text
	button.custom_minimum_size = Vector2(66.0, 42.0)
	button.add_theme_font_size_override("font_size", 12)
	parent.add_child(button)
	touch_buttons[key] = button
	match key:
		"left", "right", "forward", "back":
			button.button_down.connect(_set_touch_direction.bind(key))
			button.button_up.connect(_clear_touch_direction.bind(key))
		"jump":
			button.button_down.connect(_set_touch_jump.bind(true))
			button.button_up.connect(_set_touch_jump.bind(false))
		"crop":
			button.pressed.connect(_on_touch_crop_pressed)
		"crate":
			button.pressed.connect(_on_touch_crate_pressed)
		"shaft":
			button.pressed.connect(_on_touch_shaft_pressed)

func _on_touch_crop_pressed() -> void:
	_interact_nearest_crop_plot()

func _on_touch_crate_pressed() -> void:
	_interact_nearest_world_prop()

func _on_touch_shaft_pressed() -> void:
	_toggle_mine_access()

func _set_touch_direction(direction: String) -> void:
	_touch_directions[direction] = true

func _clear_touch_direction(direction: String) -> void:
	_touch_directions.erase(direction)

func _set_touch_jump(value: bool) -> void:
	_touch_jump = value

## Read movement penalties from the same inventory model used by mining and salvage.
func get_player_movement_profile() -> Dictionary:
	var summary: Dictionary = inventory_bridge.call("get_summary") if inventory_bridge != null and inventory_bridge.has_method("get_summary") else {}
	var multiplier: float = clampf(float(summary.get("movement_multiplier", 1.0)), 0.0, 1.0)
	return {
		"weight_kg": float(summary.get("weight_kg", 0.0)),
		"limit_kg": float(summary.get("limit_kg", 65.0)),
		"movement_multiplier": multiplier,
		"move_speed": BASE_MOVE_SPEED * multiplier,
		"can_jump": bool(summary.get("can_jump", true))
	}

func get_effective_move_speed() -> float:
	return float(get_player_movement_profile().get("move_speed", BASE_MOVE_SPEED))

func can_player_jump_now() -> bool:
	return bool(get_player_movement_profile().get("can_jump", true))

func _try_start_jump() -> bool:
	if player == null or not player.is_on_floor() or not can_player_jump_now():
		return false
	player.velocity.y = BASE_JUMP_SPEED
	return true

func _physics_process(delta: float) -> void:
	if player == null or camera == null:
		return
	var move_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or _touch_directions.has("left"):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or _touch_directions.has("right"):
		move_input.x += 1.0
	if Input.is_key_pressed(KEY_W) or _touch_directions.has("forward"):
		move_input.y += 1.0
	if Input.is_key_pressed(KEY_S) or _touch_directions.has("back"):
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
	var movement_profile: Dictionary = get_player_movement_profile()
	var move_speed: float = float(movement_profile.get("move_speed", BASE_MOVE_SPEED))
	player.velocity.x = movement.x * move_speed
	player.velocity.z = movement.z * move_speed
	if not player.is_on_floor():
		player.velocity.y -= 20.0 * delta
	elif player.velocity.y < 0.0:
		player.velocity.y = 0.0
	var jump_down: bool = Input.is_key_pressed(KEY_SPACE) or _touch_jump
	if jump_down and not _jump_was_down:
		_try_start_jump()
	_jump_was_down = jump_down
	var previous_position: Vector3 = player.global_position
	player.move_and_slide()
	if _is_underground:
		var current_mine_grid: Vector2i = mine_director.get_grid_coordinate(player.global_position)
		if current_mine_grid != _last_mine_grid:
			if mine_director.sync_to_world_position(player.global_position, int(Time.get_unix_time_from_system())):
				_last_mine_grid = current_mine_grid
			else:
				player.global_position = previous_position
				player.velocity = Vector3.ZERO
				_world_object_action_message = "Underground streaming failed; movement was rolled back."
	else:
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
			elif key_event.keycode == KEY_G:
				_toggle_mine_access()
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
	if _is_underground:
		return _interact_nearest_mineral(now_unix)
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

func _build_underground_mine() -> bool:
	if chunk_controller == null or not is_instance_valid(chunk_controller):
		return false
	if mine_director == null:
		mine_director = UndergroundMineDirectorScript.new()
		mine_director.name = "UndergroundMineDirector"
		add_child(mine_director)
		if not mine_director.bind_controller(chunk_controller):
			return false
		if not mine_director.bind_chunk_factory(Callable(self, "_make_underground_chunk")):
			return false
	var now: int = _stream_clock_unix if _stream_clock_unix > 0 else int(Time.get_unix_time_from_system())
	if not mine_director.sync_to_world_position(MINE_ENTRY_UNDERGROUND, now):
		return false
	_last_mine_grid = mine_director.get_grid_coordinate(MINE_ENTRY_UNDERGROUND)
	_mine_chunk_ready = chunk_controller.is_chunk_loaded(MINE_CHUNK_ID)
	return _mine_chunk_ready

func _make_underground_chunk(coord: Vector2i, now_unix: int) -> Node3D:
	return UndergroundMineFactoryScript.make_chunk(now_unix, coord)

func _build_mine_entrance_visual() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var marker := Node3D.new()
	marker.name = "KrollMineShaftEntrance"
	marker.position = MINE_ENTRY_SURFACE
	add_child(marker)
	var hatch := MeshInstance3D.new()
	hatch.name = "ShaftHatch"
	var hatch_mesh := BoxMesh.new()
	hatch_mesh.size = Vector3(2.2, 0.12, 2.2)
	hatch.mesh = hatch_mesh
	hatch.position.y = 0.06
	var hatch_material := StandardMaterial3D.new()
	hatch_material.albedo_color = Color(0.12, 0.28, 0.34)
	hatch_material.metallic = 0.72
	hatch_material.emission_enabled = true
	hatch_material.emission = Color(0.04, 0.42, 0.56)
	hatch_material.emission_energy_multiplier = 0.7
	hatch.material_override = hatch_material
	marker.add_child(hatch)
	for offset in [Vector3(-1.0, 0.72, -1.0), Vector3(1.0, 0.72, -1.0), Vector3(-1.0, 0.72, 1.0), Vector3(1.0, 0.72, 1.0)]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.14, 1.44, 0.14)
		post.mesh = post_mesh
		post.position = offset
		post.material_override = hatch_material
		marker.add_child(post)
	var sign := Label3D.new()
	sign.text = "KROLL MINE SHAFT  [G]"
	sign.position = Vector3(0.0, 1.8, 0.0)
	sign.font_size = 32
	sign.modulate = Color(0.55, 0.92, 1.0)
	marker.add_child(sign)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 1.25, 0.0)
	lamp.light_color = Color(0.18, 0.72, 1.0)
	lamp.light_energy = 1.1
	lamp.omni_range = 7.0
	lamp.shadow_enabled = false
	marker.add_child(lamp)

func _toggle_mine_access() -> bool:
	if player == null or mine_director == null:
		_world_object_action_message = "Mine shaft is unavailable."
		_refresh_hud()
		return false
	var horizontal_distance := Vector2(
		player.global_position.x - MINE_ENTRY_SURFACE.x,
		player.global_position.z - MINE_ENTRY_SURFACE.z
	).length()
	if horizontal_distance > MINE_ACCESS_RANGE:
		_world_object_action_message = "Return to the KROLL mine shaft before changing layers."
		_refresh_hud()
		return false
	var now: int = int(Time.get_unix_time_from_system())
	if _is_underground:
		var previous_underground_position: Vector3 = player.global_position
		if not mine_director.sync_to_world_position(MINE_ENTRY_UNDERGROUND, now):
			_world_object_action_message = "Could not restore the mine-shaft area."
			_refresh_hud()
			return false
		_is_underground = false
		player.global_position = _surface_return_position
		if not _sync_streaming(now):
			_is_underground = true
			player.global_position = previous_underground_position
			if not mine_director.sync_to_world_position(previous_underground_position, now):
				push_error("Underground window rollback failed after surface return streaming rejection.")
			_world_object_action_message = "Surface streaming failed; the layer transition was rolled back."
			_refresh_hud()
			return false
		_last_mine_grid = mine_director.get_grid_coordinate(MINE_ENTRY_UNDERGROUND)
		_world_object_action_message = "Returned to the surface."
	else:
		if not _mine_chunk_ready or not chunk_controller.is_chunk_loaded(MINE_CHUNK_ID):
			_world_object_action_message = "Mine shaft is unavailable."
			_refresh_hud()
			return false
		_surface_return_position = player.global_position
		_is_underground = true
		player.global_position = MINE_ENTRY_UNDERGROUND
		if not mine_director.sync_to_world_position(MINE_ENTRY_UNDERGROUND, now):
			_is_underground = false
			player.global_position = _surface_return_position
			_world_object_action_message = "Could not load the underground mine window."
			_refresh_hud()
			return false
		_last_mine_grid = mine_director.get_grid_coordinate(player.global_position)
		_world_object_action_message = "Entered the underground mine. Follow open doorways; F mines nearby veins."
	_mine_chunk_ready = chunk_controller.is_chunk_loaded(MINE_CHUNK_ID)
	player.velocity = Vector3.ZERO
	_jump_was_down = false
	_refresh_hud()
	return true

func _interact_nearest_mineral(_now_unix: int = -1) -> Dictionary:
	if not _is_underground:
		return {"ok": false, "action": "underground_only", "message": "Mineral veins can only be mined underground."}
	if player == null or chunk_controller == null or not chunk_controller.has_method("get_loaded_mineral_nodes"):
		return {"ok": false, "action": "unavailable", "message": "Underground mining is unavailable."}
	var nearest: Node3D = null
	var nearest_distance: float = MINE_INTERACTION_RANGE
	for vein in chunk_controller.call("get_loaded_mineral_nodes"):
		if not is_instance_valid(vein) or not bool(vein.get("visible")) or int(vein.get("remaining_units")) <= 0:
			continue
		var distance: float = player.global_position.distance_to(vein.global_position)
		if distance <= nearest_distance:
			nearest = vein
			nearest_distance = distance
	if nearest == null:
		_world_object_action_message = "No mineable vein within reach."
		_refresh_hud()
		return {"ok": false, "action": "out_of_reach", "message": _world_object_action_message}
	var accepted: int = int(nearest.call("mine_hit", Vector3.ZERO))
	var item_id: String = str(nearest.get("mineral_id"))
	var mineral_data: Dictionary = MineralCatalogScript.get_mineral(item_id)
	var display_name: String = str(mineral_data.get("display_name", item_id))
	if accepted > 0:
		_world_object_action_message = "Mined %d %s; %d units remain." % [accepted, display_name, int(nearest.get("remaining_units"))]
	else:
		_world_object_action_message = "Mining rejected: inventory full or vein depleted."
	_refresh_hud()
	return {"ok": accepted > 0, "action": "mined" if accepted > 0 else "rejected", "item_id": item_id, "amount": accepted, "remaining": int(nearest.get("remaining_units")), "message": _world_object_action_message}

func serialize_stream_state() -> Dictionary:
	var payload: Dictionary = super.serialize_stream_state()
	if payload.is_empty():
		return {}
	payload["location_layer"] = "underground" if _is_underground else "surface"
	payload["surface_return_position"] = [
		_surface_return_position.x,
		_surface_return_position.y,
		_surface_return_position.z
	]
	return payload

func restore_stream_state(payload: Dictionary, now_unix: int = -1) -> bool:
	var layer_value: Variant = payload.get("location_layer", "surface")
	if not (layer_value is String) or not ["surface", "underground"].has(str(layer_value)):
		return false
	var position_value: Variant = payload.get("player_position", null)
	if not (position_value is Array) or position_value.size() != 3:
		return false
	for component in position_value:
		if not (component is int or component is float) or not is_finite(float(component)):
			return false
	var target_position := Vector3(float(position_value[0]), float(position_value[1]), float(position_value[2]))
	var target_underground: bool = str(layer_value) == "underground"
	var next_return_position: Vector3 = MINE_ENTRY_SURFACE_RETURN
	if payload.has("surface_return_position"):
		var return_value: Variant = payload.get("surface_return_position")
		if not (return_value is Array) or return_value.size() != 3:
			return false
		for component in return_value:
			if not (component is int or component is float) or not is_finite(float(component)):
				return false
		next_return_position = Vector3(float(return_value[0]), float(return_value[1]), float(return_value[2]))
	if player == null or mine_director == null:
		return false
	var previous_position: Vector3 = player.global_position
	var previous_underground: bool = _is_underground
	var now: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var mine_target: Vector3 = target_position if target_underground else MINE_ENTRY_UNDERGROUND
	if not mine_director.sync_to_world_position(mine_target, now):
		return false
	if not super.restore_stream_state(payload, now):
		var rollback_target: Vector3 = previous_position if previous_underground else MINE_ENTRY_UNDERGROUND
		if not mine_director.sync_to_world_position(rollback_target, now):
			push_error("Underground mine window rollback failed after world-session restore rejection.")
		return false
	_is_underground = target_underground
	_surface_return_position = next_return_position
	_last_mine_grid = mine_director.get_grid_coordinate(player.global_position if target_underground else MINE_ENTRY_UNDERGROUND)
	_mine_chunk_ready = chunk_controller.is_chunk_loaded(MINE_CHUNK_ID)
	_refresh_hud()
	return true

func _make_chunk(coord: Vector2i) -> Node3D:
	return SurfaceChunkFactoryScript.make_chunk(coord, _stream_clock_unix)

func _refresh_hud() -> void:
	if hud == null:
		return
	var status: Dictionary = get_world_session_status()
	var active_count: int = chunk_controller.get_loaded_chunk_ids().size() if chunk_controller != null else 0
	var grid_text := str(mine_director.get_grid_coordinate(player.global_position)) if _is_underground and mine_director != null and player != null else (str(director.get_grid_coordinate(player.global_position)) if director != null and player != null else "n/a")
	var movement_profile: Dictionary = get_player_movement_profile()
	var weight := float(movement_profile.get("weight_kg", 0.0))
	var limit := float(movement_profile.get("limit_kg", 65.0))
	var movement_percent: int = roundi(float(movement_profile.get("movement_multiplier", 1.0)) * 100.0)
	var jump_status: String = "JUMP READY" if bool(movement_profile.get("can_jump", true)) else "JUMP LOCKED (>90 kg)"
	var layer_name: String = "UNDERGROUND MINE" if _is_underground else "SURFACE WORLD"
	if touch_buttons.has("crate"):
		(touch_buttons["crate"] as Button).text = "MINE" if _is_underground else "CRATE"
	if touch_buttons.has("shaft"):
		(touch_buttons["shaft"] as Button).text = "ASCEND" if _is_underground else "DESCEND"
	if touch_buttons.has("crop"):
		(touch_buttons["crop"] as Button).disabled = _is_underground
	var action_help: String = "F mine · G shaft" if _is_underground else "E crop · F crate · G mine shaft"
	hud.text = "2126 SURVIVAL // %s\nWASD move · SPACE jump · RMB look · %s · F10 test hub\nGrid: %s   Chunks: %d   Veins: %d   Crops: %d   Objects: %d\nCarry: %.1f / %.1f kg   Move: %d%%   %s\n%s\n%s" % [
		layer_name, action_help, grid_text, active_count, int(status.get("saved_vein_count", 0)),
		int(status.get("saved_crop_count", 0)), int(status.get("saved_world_object_count", 0)),
		weight, limit, movement_percent, jump_status, _crop_action_message, _world_object_action_message
	]

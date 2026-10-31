extends "res://scripts/world.gd"

const SurfaceChunkFactoryScript = preload("res://systems/SurfaceChunkFactory.gd")
const MineralCatalogScript = preload("res://systems/MineralCatalog.gd")
const UndergroundMineFactoryScript = preload("res://systems/UndergroundMineFactory.gd")
const UndergroundMineDirectorScript = preload("res://systems/UndergroundMineDirector.gd")
const StaminaScript = preload("res://systems/SurvivalStamina.gd")
const QuickUseScript = preload("res://systems/SurvivalQuickUse.gd")
const MINE_CHUNK_ID: String = "underground/mine_0_0"
const MINE_ENTRY_SURFACE: Vector3 = Vector3(1.5, 0.0, 7.5)
const MINE_ENTRY_SURFACE_RETURN: Vector3 = Vector3(1.5, 2.0, 7.5)
const MINE_ENTRY_UNDERGROUND: Vector3 = Vector3(1.5, -8.25, 7.5)
const MINE_ACCESS_RANGE: float = 2.75
const MINE_INTERACTION_RANGE: float = 3.5
const INTERACTION_RAY_DISTANCE: float = 5.0
const INTERACTION_PROXY_COLLISION_MASK: int = 1 << 1
const WORLD_GEOMETRY_COLLISION_MASK: int = 1
const BASE_MOVE_SPEED: float = 5.0
const BASE_JUMP_SPEED: float = 7.0
const LEGACY_WORLD_SEED: int = 0
const MAX_WORLD_SEED: int = 2147483647
@export_range(0, MAX_WORLD_SEED, 1) var world_seed: int = LEGACY_WORLD_SEED
var stamina: RefCounted = StaminaScript.new()
var quick_use: RefCounted = QuickUseScript.new()
var camera: Camera3D
var hud: Label
var interaction_prompt: Label
var touch_buttons: Dictionary = {}
var _touch_directions: Dictionary = {}
var _touch_jump: bool = false
var _touch_sprint: bool = false
var _sprint_active: bool = false
var _yaw: float = 0.0
var _pitch: float = -0.12
var _mouse_look_active: bool = false
var _camera_interaction_target_cache: Dictionary = {}
var _jump_was_down: bool = false
var _crop_action_message: String = "E / CROP: plant, water, grow or harvest."
var _world_object_action_message: String = "F / CRATE: recover nearby salvage."
var _is_underground: bool = false
var _mine_chunk_ready: bool = false
var mine_director: Node
var _last_mine_grid: Vector2i = Vector2i(999999, 999999)
var _mine_layer_index: int = 0
var _last_mine_layer_index: int = 0
var _surface_return_position: Vector3 = MINE_ENTRY_SURFACE_RETURN

func _ready() -> void:
	if not initialize_world_session():
		return
	if inventory_bridge != null and inventory_bridge.has_signal("inventory_changed"):
		inventory_bridge.connect("inventory_changed", Callable(self, "_on_inventory_changed"))
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
	hud.size = Vector2(900.0, 160.0)
	hud.add_theme_color_override("font_color", Color(0.62, 0.94, 1.0))
	hud.add_theme_font_size_override("font_size", 15)
	layer.add_child(hud)
	interaction_prompt = Label.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.anchor_left = 0.5
	interaction_prompt.anchor_right = 0.5
	interaction_prompt.anchor_top = 1.0
	interaction_prompt.anchor_bottom = 1.0
	interaction_prompt.offset_left = -260.0
	interaction_prompt.offset_right = 260.0
	interaction_prompt.offset_top = -282.0
	interaction_prompt.offset_bottom = -250.0
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_prompt.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0))
	interaction_prompt.add_theme_font_size_override("font_size", 18)
	interaction_prompt.add_theme_color_override("font_shadow_color", Color(0.01, 0.05, 0.08, 0.9))
	interaction_prompt.add_theme_constant_override("shadow_offset_x", 2)
	interaction_prompt.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(interaction_prompt)
	var panel := PanelContainer.new()
	panel.name = "TouchControls"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -116.0
	panel.offset_right = 116.0
	panel.offset_top = -240.0
	panel.offset_bottom = -10.0
	layer.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 3
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
	_add_touch_button(grid, "deeper", "DOWN ONE")
	_add_touch_button(grid, "sprint", "SPRINT")
	_add_touch_button(grid, "quick_1", "1 BERRIES")
	_add_touch_button(grid, "quick_2", "2 HERBS")
	_add_touch_button(grid, "quick_3", "3 MEAT")
	_add_touch_button(grid, "quick_4", "4 FOOD")
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
		"deeper":
			button.pressed.connect(_on_touch_deeper_pressed)
		"sprint":
			button.button_down.connect(_set_touch_sprint.bind(true))
			button.button_up.connect(_set_touch_sprint.bind(false))
		"quick_1", "quick_2", "quick_3", "quick_4":
			var slot_index: int = int(key.substr(6, 1)) - 1
			button.pressed.connect(_consume_quick_slot.bind(slot_index))

func _on_touch_crop_pressed() -> void:
	_interact_nearest_crop_plot()

func _on_touch_crate_pressed() -> void:
	_interact_nearest_world_prop()

func _on_touch_shaft_pressed() -> void:
	_toggle_mine_access()

func _on_touch_deeper_pressed() -> void:
	_descend_mine_layer()

func _set_touch_direction(direction: String) -> void:
	_touch_directions[direction] = true

func _clear_touch_direction(direction: String) -> void:
	_touch_directions.erase(direction)

func _set_touch_jump(value: bool) -> void:
	_touch_jump = value

func _set_touch_sprint(value: bool) -> void:
	_touch_sprint = value

func _on_inventory_changed(_summary: Dictionary) -> void:
	_refresh_hud()

func _select_quick_slot(slot_index: int) -> bool:
	if quick_use == null or not bool(quick_use.call("select_slot", slot_index)):
		return false
	_refresh_hud()
	return true

func _consume_quick_slot(slot_index: int) -> Dictionary:
	if not _select_quick_slot(slot_index):
		return {"ok": false, "reason": "invalid_slot"}
	return _consume_selected_quick_slot()

func _consume_selected_quick_slot() -> Dictionary:
	if quick_use == null or inventory_bridge == null:
		return {"ok": false, "reason": "unavailable"}
	var result: Dictionary = quick_use.call("consume_selected", inventory_bridge, stamina)
	if bool(result.get("ok", false)):
		_world_object_action_message = "Used %s; restored %.1f stamina." % [
			str(result.get("item_id", "ration")),
			float(result.get("restored", 0.0))
		]
	elif str(result.get("reason", "")) == "stamina_full":
		_world_object_action_message = "Stamina is already full; ration preserved."
	elif str(result.get("reason", "")) == "empty":
		_world_object_action_message = "Selected quick slot is empty."
	else:
		_world_object_action_message = "Quick-use rejected: %s." % str(result.get("reason", "unknown"))
	_refresh_hud()
	return result

## Read carry penalties from the inventory model and stamina penalties from SurvivalStamina.
func get_player_movement_profile(sprinting: bool = false) -> Dictionary:
	var summary: Dictionary = inventory_bridge.call("get_summary") if inventory_bridge != null and inventory_bridge.has_method("get_summary") else {}
	var multiplier: float = clampf(float(summary.get("movement_multiplier", 1.0)), 0.0, 1.0)
	var stamina_value: float = float(stamina.get("current_stamina")) if stamina != null else 100.0
	var stamina_can_jump: bool = bool(stamina.call("can_jump")) if stamina != null else true
	var stamina_can_sprint: bool = bool(stamina.call("can_sprint")) if stamina != null else true
	var sprint_active: bool = sprinting and stamina_can_sprint
	var stamina_speed_multiplier: float = float(stamina.call("get_movement_speed_multiplier", sprint_active)) if stamina != null else 1.0
	var inventory_can_jump: bool = bool(summary.get("can_jump", true))
	return {
		"weight_kg": float(summary.get("weight_kg", 0.0)),
		"limit_kg": float(summary.get("limit_kg", 65.0)),
		"movement_multiplier": multiplier,
		"stamina_movement_multiplier": stamina_speed_multiplier,
		"move_speed": BASE_MOVE_SPEED * multiplier * stamina_speed_multiplier,
		"stamina": stamina_value,
		"stamina_max": float(stamina.call("get_max_stamina")) if stamina != null else 100.0,
		"inventory_can_jump": inventory_can_jump,
		"stamina_can_jump": stamina_can_jump,
		"can_sprint": stamina_can_sprint,
		"sprinting": sprint_active,
		"exhausted": stamina_value <= 0.0,
		"can_jump": inventory_can_jump and stamina_can_jump
	}

func get_effective_move_speed(sprinting: bool = false) -> float:
	return float(get_player_movement_profile(sprinting).get("move_speed", BASE_MOVE_SPEED))

func can_player_jump_now() -> bool:
	return bool(get_player_movement_profile().get("can_jump", true))

func _try_start_jump() -> bool:
	if player == null or not player.is_on_floor() or not can_player_jump_now():
		return false
	if stamina == null or not bool(stamina.call("spend_jump")):
		return false
	player.velocity.y = BASE_JUMP_SPEED
	_refresh_hud()
	return true

func _tick_stamina(delta: float, moving: bool, sprinting: bool = false) -> void:
	if stamina == null:
		return
	var profile: Dictionary = get_player_movement_profile(sprinting)
	stamina.call(
		"tick",
		delta,
		moving,
		float(profile.get("movement_multiplier", 1.0)),
		bool(profile.get("sprinting", false))
	)

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
	var sprint_requested: bool = (Input.is_key_pressed(KEY_SHIFT) or _touch_sprint) and movement.length_squared() > 0.0001
	var movement_profile: Dictionary = get_player_movement_profile(sprint_requested)
	_sprint_active = bool(movement_profile.get("sprinting", false))
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
	# Resolve a same-frame jump before movement drain so exactly JUMP_COST remains sufficient.
	_tick_stamina(delta, movement.length_squared() > 0.0001, _sprint_active)
	var previous_position: Vector3 = player.global_position
	player.move_and_slide()
	if _is_underground:
		var current_mine_grid: Vector2i = mine_director.get_grid_coordinate(player.global_position)
		var current_mine_layer: int = mine_director.get_layer_index(player.global_position)
		if current_mine_grid != _last_mine_grid or current_mine_layer != _last_mine_layer_index:
			if mine_director.sync_to_world_position(player.global_position, int(Time.get_unix_time_from_system())):
				_last_mine_grid = current_mine_grid
				_last_mine_layer_index = current_mine_layer
				_mine_layer_index = current_mine_layer
				_mine_chunk_ready = chunk_controller.is_chunk_loaded(MINE_CHUNK_ID)
			else:
				player.global_position = previous_position
				player.velocity = Vector3.ZERO
				_world_object_action_message = "Underground streaming failed; movement was rolled back."
	else:
		var current_grid: Vector2i = director.get_grid_coordinate(player.global_position)
		if current_grid != _last_grid:
			_sync_streaming(int(Time.get_unix_time_from_system()))
	_camera_interaction_target_cache = _cast_camera_interaction_target()
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_1: _select_quick_slot(0)
				KEY_2: _select_quick_slot(1)
				KEY_3: _select_quick_slot(2)
				KEY_4: _select_quick_slot(3)
				KEY_C: _consume_selected_quick_slot()
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
			elif key_event.keycode == KEY_V:
				_descend_mine_layer()
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
	var target: Dictionary = get_camera_interaction_target()
	var selected_plot: Node3D = null
	if str(target.get("kind", "")) == "crop":
		selected_plot = target.get("node") as Node3D
	if selected_plot == null:
		_crop_action_message = "Aim at a crop plot within reach."
		_refresh_hud()
		return {"ok": false, "action": "out_of_reach", "message": _crop_action_message}
	var timestamp: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var result: Dictionary = selected_plot.call("interact", timestamp)
	_crop_action_message = str(result.get("message", "Crop action completed."))
	_refresh_hud()
	return result
func _interact_nearest_world_prop(now_unix: int = -1) -> Dictionary:
	if player == null or chunk_controller == null:
		return {"ok": false, "action": "unavailable", "message": "World-object interaction is unavailable."}
	var target: Dictionary = get_camera_interaction_target()
	var target_kind: String = str(target.get("kind", ""))
	var selected: Node3D = target.get("node") as Node3D
	if target_kind == "vein":
		return _interact_nearest_mineral(now_unix, selected)
	if target_kind != "prop" or selected == null:
		_world_object_action_message = "Aim at a salvage cache or mineable vein within reach."
		_refresh_hud()
		return {"ok": false, "action": "out_of_reach", "message": _world_object_action_message}
	var result: Dictionary = selected.call("interact_with_inventory", inventory_bridge)
	var ok: bool = bool(result.get("ok", false))
	var reason: String = str(result.get("reason", "unknown"))
	var item_id: String = str(result.get("item_id", "iron_ore"))
	var mineral_data: Dictionary = MineralCatalogScript.get_mineral(item_id)
	var display_name: String = str(mineral_data.get("display_name", item_id))
	if ok:
		_world_object_action_message = "Recovered 1 %s; %d salvage units remain." % [display_name, int(result.get("remaining", 0))]
	elif reason == "inventory_rejected":
		_world_object_action_message = "Inventory cannot accept %s; cache unchanged." % display_name
	elif reason == "empty":
		_world_object_action_message = "Cache is empty."
	else:
		_world_object_action_message = "Cache interaction blocked: %s." % reason
	result["action"] = "interacted" if ok else reason
	result["message"] = _world_object_action_message
	_refresh_hud()
	return result
func _get_nearest_mineable_vein() -> Node3D:
	if not _is_underground or player == null or chunk_controller == null or not chunk_controller.has_method("get_loaded_mineral_nodes"):
		return null
	var nearest: Node3D = null
	var nearest_distance: float = MINE_INTERACTION_RANGE
	for vein in chunk_controller.call("get_loaded_mineral_nodes"):
		if not is_instance_valid(vein) or not bool(vein.get("visible")) or int(vein.get("remaining_units")) <= 0:
			continue
		var distance: float = player.global_position.distance_to(vein.global_position)
		if distance <= nearest_distance:
			nearest = vein
			nearest_distance = distance
	return nearest

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
	_mine_layer_index = 0
	_last_mine_layer_index = 0
	_mine_chunk_ready = chunk_controller.is_chunk_loaded(MINE_CHUNK_ID)
	return _mine_chunk_ready

func _make_underground_chunk(coord: Vector2i, layer_index: int, now_unix: int) -> Node3D:
	return UndergroundMineFactoryScript.make_chunk(now_unix, coord, layer_index, world_seed)

func _build_mine_entrance_visual() -> void:
	var marker := Node3D.new()
	marker.name = "KrollMineShaftEntrance"
	marker.position = MINE_ENTRY_SURFACE
	var interaction_area := Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 2
	interaction_area.collision_mask = 0
	interaction_area.monitoring = false
	var interaction_collision := CollisionShape3D.new()
	var interaction_shape := CylinderShape3D.new()
	interaction_shape.radius = 1.4
	interaction_shape.height = 2.2
	interaction_collision.shape = interaction_shape
	interaction_collision.position.y = 0.9
	interaction_area.add_child(interaction_collision)
	marker.add_child(interaction_area)
	add_child(marker)
	if DisplayServer.get_name() == "headless":
		return
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
		_world_object_action_message = "Return to the KROLL mine lift before changing levels."
		_refresh_hud()
		return false
	var aimed_target: Dictionary = get_camera_interaction_target()
	if str(aimed_target.get("kind", "")) != "lift":
		_world_object_action_message = "Aim at the KROLL mine lift before changing levels."
		_refresh_hud()
		return false
	var now: int = int(Time.get_unix_time_from_system())
	if _is_underground:
		var current_layer: int = mine_director.get_layer_index(player.global_position)
		if current_layer < 0 or absf(player.global_position.y - mine_director.get_layer_floor_y(current_layer)) > 3.0:
			_world_object_action_message = "Stand on the KROLL lift platform before ascending."
			_refresh_hud()
			return false
		if current_layer > 0:
			var target_position: Vector3 = player.global_position
			target_position.y = mine_director.get_layer_floor_y(current_layer - 1)
			if not mine_director.sync_to_world_position(target_position, now):
				_world_object_action_message = "The upper mine level could not be loaded."
				_refresh_hud()
				return false
			player.global_position = target_position
			_mine_layer_index = current_layer - 1
			_last_mine_layer_index = _mine_layer_index
			_last_mine_grid = mine_director.get_grid_coordinate(target_position)
			_mine_chunk_ready = chunk_controller.is_chunk_loaded(MINE_CHUNK_ID)
			_world_object_action_message = "Lift ascended to mine level %02d." % (_mine_layer_index + 1)
		else:
			var previous_underground_position: Vector3 = player.global_position
			if not mine_director.sync_to_world_position(MINE_ENTRY_UNDERGROUND, now):
				_world_object_action_message = "Could not restore the mine-shaft area."
				_refresh_hud()
				return false
			_is_underground = false
			_mine_layer_index = 0
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
			_last_mine_layer_index = 0
			_mine_chunk_ready = chunk_controller.is_chunk_loaded(MINE_CHUNK_ID)
			_world_object_action_message = "Returned to the surface."
	else:
		if not _mine_chunk_ready or not chunk_controller.is_chunk_loaded(MINE_CHUNK_ID):
			_world_object_action_message = "Mine shaft is unavailable."
			_refresh_hud()
			return false
		_surface_return_position = player.global_position
		_is_underground = true
		_mine_layer_index = 0
		player.global_position = MINE_ENTRY_UNDERGROUND
		if not mine_director.sync_to_world_position(MINE_ENTRY_UNDERGROUND, now):
			_is_underground = false
			player.global_position = _surface_return_position
			_world_object_action_message = "Could not load the underground mine window."
			_refresh_hud()
			return false
		_last_mine_grid = mine_director.get_grid_coordinate(player.global_position)
		_last_mine_layer_index = 0
		_mine_chunk_ready = chunk_controller.is_chunk_loaded(MINE_CHUNK_ID)
		_world_object_action_message = "Entered mine level 01. V descends; G ascends."
	player.velocity = Vector3.ZERO
	_jump_was_down = false
	_camera_interaction_target_cache.clear()
	_refresh_hud()
	return true

func _descend_mine_layer() -> bool:
	if not _is_underground or player == null or mine_director == null:
		_world_object_action_message = "The deeper lift is only available underground."
		_refresh_hud()
		return false
	var current_layer: int = mine_director.get_layer_index(player.global_position)
	var aimed_target: Dictionary = get_camera_interaction_target()
	if str(aimed_target.get("kind", "")) != "lift":
		_world_object_action_message = "Aim at the KROLL lift platform before descending."
		_refresh_hud()
		return false
	if current_layer < 0 or current_layer >= UndergroundMineDirectorScript.MAX_LAYER_INDEX:
		_world_object_action_message = "The maximum supported mine depth has been reached."
		_refresh_hud()
		return false
	var horizontal_distance := Vector2(
		player.global_position.x - MINE_ENTRY_UNDERGROUND.x,
		player.global_position.z - MINE_ENTRY_UNDERGROUND.z
	).length()
	if horizontal_distance > MINE_ACCESS_RANGE or absf(player.global_position.y - mine_director.get_layer_floor_y(current_layer)) > 3.0:
		_world_object_action_message = "Return to the KROLL lift platform before descending."
		_refresh_hud()
		return false
	var target_position: Vector3 = player.global_position
	target_position.y = mine_director.get_layer_floor_y(current_layer + 1)
	var now: int = int(Time.get_unix_time_from_system())
	if not mine_director.sync_to_world_position(target_position, now):
		_world_object_action_message = "The next mine level could not be loaded; the current level was preserved."
		_refresh_hud()
		return false
	player.global_position = target_position
	player.velocity = Vector3.ZERO
	_mine_layer_index = current_layer + 1
	_last_mine_layer_index = _mine_layer_index
	_last_mine_grid = mine_director.get_grid_coordinate(target_position)
	_mine_chunk_ready = chunk_controller.is_chunk_loaded(MINE_CHUNK_ID)
	_jump_was_down = false
	_camera_interaction_target_cache.clear()
	_world_object_action_message = "Lift descended to mine level %02d." % (_mine_layer_index + 1)
	_refresh_hud()
	return true

func _interact_nearest_mineral(_now_unix: int = -1, selected_vein: Node3D = null) -> Dictionary:
	if not _is_underground:
		return {"ok": false, "action": "underground_only", "message": "Mineral veins can only be mined underground."}
	if player == null or chunk_controller == null or not chunk_controller.has_method("get_loaded_mineral_nodes"):
		return {"ok": false, "action": "unavailable", "message": "Underground mining is unavailable."}
	var nearest: Node3D = selected_vein
	if nearest == null:
		var target: Dictionary = get_camera_interaction_target()
		if str(target.get("kind", "")) == "vein":
			nearest = target.get("node") as Node3D
	var loaded_veins: Array = chunk_controller.call("get_loaded_mineral_nodes")
	if nearest == null or not loaded_veins.has(nearest):
		_world_object_action_message = "Aim at a mineable vein within reach."
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
	payload["mine_depth"] = mine_director.get_layer_index(player.global_position) if _is_underground and mine_director != null and player != null else 0
	payload["world_seed"] = world_seed
	payload["stamina"] = stamina.call("to_save_dict") if stamina != null else {"schema_version": 1, "current": 100.0}
	payload["quick_use"] = quick_use.call("to_save_dict") if quick_use != null else {"schema_version": 1, "slots": ["berries", "herbs", "meat", "food"], "selected_slot": 0}
	payload["surface_return_position"] = [
		_surface_return_position.x,
		_surface_return_position.y,
		_surface_return_position.z
	]
	return payload

func restore_stream_state(payload: Dictionary, now_unix: int = -1) -> bool:
	var world_seed_value: Variant = payload.get("world_seed", LEGACY_WORLD_SEED)
	if not (world_seed_value is int or world_seed_value is float) or not is_finite(float(world_seed_value)) or float(world_seed_value) < 0.0 or float(world_seed_value) > float(MAX_WORLD_SEED) or not is_equal_approx(float(world_seed_value), roundf(float(world_seed_value))):
		return false
	var next_world_seed: int = int(roundf(float(world_seed_value)))
	var has_stamina: bool = payload.has("stamina")
	var stamina_value: Variant = payload.get("stamina", null)
	if has_stamina:
		var stamina_probe: RefCounted = StaminaScript.new()
		if not (stamina_value is Dictionary) or not bool(stamina_probe.call("validate_save_dict", stamina_value)):
			_set_restore_report(false, "stamina_validation", "Stamina save payload is invalid; no world state was changed.", true)
			return false
	var has_quick_use: bool = payload.has("quick_use")
	var quick_use_value: Variant = payload.get("quick_use", null)
	if has_quick_use:
		var quick_use_probe: RefCounted = QuickUseScript.new()
		if not (quick_use_value is Dictionary) or not bool(quick_use_probe.call("validate_save_dict", quick_use_value)):
			_set_restore_report(false, "quick_use_validation", "Quick-use hotbar payload is invalid; no world state was changed.", true)
			return false
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
	var target_depth: int = 0
	if target_underground:
		if payload.has("mine_depth"):
			var depth_value: Variant = payload.get("mine_depth")
			if not (depth_value is int) or int(depth_value) < 0 or int(depth_value) > UndergroundMineDirectorScript.MAX_LAYER_INDEX:
				return false
			target_depth = int(depth_value)
		else:
			target_depth = mine_director.get_layer_index(target_position) if mine_director != null else -1
		if mine_director == null or target_depth < 0 or mine_director.get_layer_index(target_position) != target_depth:
			return false
	elif payload.has("mine_depth") and (not (payload.get("mine_depth") is int) or int(payload.get("mine_depth")) != 0):
		return false
	var next_return_position: Vector3 = MINE_ENTRY_SURFACE_RETURN
	if payload.has("surface_return_position"):
		var return_value: Variant = payload.get("surface_return_position")
		if not (return_value is Array) or return_value.size() != 3:
			return false
		for component in return_value:
			if not (component is int or component is float) or not is_finite(float(component)):
				return false
		next_return_position = Vector3(float(return_value[0]), float(return_value[1]), float(return_value[2]))
	if player == null or mine_director == null or chunk_controller == null or object_state_registry == null:
		return false
	if chunk_controller.has_method("capture_loaded_world_object_states") and not bool(chunk_controller.call("capture_loaded_world_object_states")):
		return false
	var previous_minerals: Dictionary = chunk_controller.call("to_save_dict")
	var previous_world_objects: Dictionary = object_state_registry.call("to_save_dict") if object_state_registry != null else {}
	if not previous_minerals.has("schema_version") or not previous_minerals.has("veins") or not previous_world_objects.has("schema_version") or not previous_world_objects.has("objects"):
		return false
	var previous_position: Vector3 = player.global_position
	var previous_underground: bool = _is_underground
	var previous_world_seed: int = world_seed
	var previous_mine_position: Vector3 = previous_position if previous_underground else MINE_ENTRY_UNDERGROUND
	var now: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var mine_target: Vector3 = target_position if target_underground else MINE_ENTRY_UNDERGROUND
	if next_world_seed != previous_world_seed and not _clear_underground_window(previous_mine_position, now):
		if not _restore_mine_snapshots(previous_minerals, previous_world_objects, now):
			push_error("Mine registry snapshot restoration failed after a seed-change unload rejection.")
		return false
	world_seed = next_world_seed
	if not mine_director.sync_to_world_position(mine_target, now):
		if next_world_seed != previous_world_seed:
			if not _recover_underground_window(previous_world_seed, previous_mine_position, now, previous_minerals, previous_world_objects):
				push_error("Underground mine window rollback failed after world-seed stream rejection.")
		else:
			world_seed = previous_world_seed
			if not mine_director.recover_to_world_position(previous_mine_position, now):
				push_error("Underground mine window rollback failed after world-session restore rejection.")
		return false
	if not super.restore_stream_state(payload, now):
		if next_world_seed != previous_world_seed:
			if not _recover_underground_window(previous_world_seed, previous_mine_position, now, previous_minerals, previous_world_objects):
				push_error("Underground mine window rollback failed after world-session restore rejection.")
		else:
			world_seed = previous_world_seed
			if not mine_director.recover_to_world_position(previous_mine_position, now):
				push_error("Underground mine window rollback failed after world-session restore rejection.")
		return false
	if has_stamina:
		if not bool(stamina.call("load_save_dict", stamina_value)):
			_set_restore_report(false, "stamina_restore", "Validated stamina payload could not be applied.", false)
			return false
	else:
		stamina.call("reset")
	if has_quick_use:
		if not bool(quick_use.call("load_save_dict", quick_use_value)):
			_set_restore_report(false, "quick_use_restore", "Validated quick-use payload could not be applied.", false)
			return false
	else:
		quick_use.call("reset")
	_is_underground = target_underground
	_mine_layer_index = target_depth
	_surface_return_position = next_return_position
	_last_mine_grid = mine_director.get_grid_coordinate(player.global_position if target_underground else MINE_ENTRY_UNDERGROUND)
	_last_mine_layer_index = target_depth
	_mine_chunk_ready = chunk_controller.is_chunk_loaded(MINE_CHUNK_ID)
	_camera_interaction_target_cache.clear()
	_refresh_hud()
	return true

func _clear_underground_window(recovery_position: Vector3, now_unix: int) -> bool:
	if chunk_controller == null or not is_instance_valid(chunk_controller) or mine_director == null:
		return false
	var raw_ids: Variant = chunk_controller.call("get_loaded_chunk_ids")
	if not (raw_ids is Array or raw_ids is PackedStringArray):
		return false
	for raw_id in raw_ids:
		var chunk_id: String = str(raw_id)
		if not chunk_id.begins_with("underground/") or not chunk_controller.is_chunk_loaded(chunk_id):
			continue
		if not bool(chunk_controller.call("unload_chunk", chunk_id, now_unix)):
			if not mine_director.recover_to_world_position(recovery_position, now_unix):
				push_error("Underground window could not recover after a seed-change unload rejection.")
			return false
	return true

func _restore_mine_snapshots(mineral_snapshot: Dictionary, object_snapshot: Dictionary, now_unix: int) -> bool:
	if not bool(chunk_controller.call("restore_save_dict", mineral_snapshot, now_unix)):
		return false
	return bool(chunk_controller.call("restore_world_object_states", object_snapshot))

func _recover_underground_window(previous_seed: int, recovery_position: Vector3, now_unix: int, mineral_snapshot: Dictionary, object_snapshot: Dictionary) -> bool:
	world_seed = previous_seed
	if not _clear_underground_window(recovery_position, now_unix):
		return false
	if not bool(mine_director.recover_to_world_position(recovery_position, now_unix)):
		return false
	return _restore_mine_snapshots(mineral_snapshot, object_snapshot, now_unix)

func _make_chunk(coord: Vector2i) -> Node3D:
	return SurfaceChunkFactoryScript.make_chunk(coord, _stream_clock_unix)

func get_camera_interaction_target() -> Dictionary:
	var target: Dictionary = _camera_interaction_target_cache.duplicate()
	if target.is_empty():
		return {}
	if not _is_camera_interaction_target_current(target):
		_camera_interaction_target_cache.clear()
		return {}
	return target

func _is_camera_interaction_target_current(target: Dictionary) -> bool:
	var target_node: Node3D = target.get("node") as Node3D
	var proxy: Area3D = target.get("proxy") as Area3D
	if target_node == null or proxy == null:
		return false
	if not is_instance_valid(target_node) or not is_instance_valid(proxy):
		return false
	if not target_node.is_inside_tree() or target_node.is_queued_for_deletion():
		return false
	if not proxy.is_inside_tree() or proxy.is_queued_for_deletion():
		return false
	if (proxy.collision_layer & INTERACTION_PROXY_COLLISION_MASK) == 0:
		return false
	var ancestor: Node = target_node
	while ancestor != null and ancestor != self:
		if not ancestor.is_inside_tree() or ancestor.is_queued_for_deletion():
			return false
		ancestor = ancestor.get_parent()
	if ancestor != self:
		return false
	var proxy_ancestor: Node = proxy
	while proxy_ancestor != null and proxy_ancestor != target_node:
		if not proxy_ancestor.is_inside_tree() or proxy_ancestor.is_queued_for_deletion():
			return false
		proxy_ancestor = proxy_ancestor.get_parent()
	if proxy_ancestor != target_node or chunk_controller == null:
		return false
	match str(target.get("kind", "")):
		"crop":
			if not chunk_controller.has_method("get_loaded_crop_plots"):
				return false
			var crop_plots: Array = chunk_controller.call("get_loaded_crop_plots")
			return crop_plots.has(target_node)
		"prop":
			if not chunk_controller.has_method("get_loaded_world_state_nodes"):
				return false
			var world_props: Array = chunk_controller.call("get_loaded_world_state_nodes")
			return world_props.has(target_node)
		"vein":
			if not chunk_controller.has_method("get_loaded_mineral_nodes"):
				return false
			var mineral_nodes: Array = chunk_controller.call("get_loaded_mineral_nodes")
			return mineral_nodes.has(target_node) and bool(target_node.get("visible")) and int(target_node.get("remaining_units")) > 0
		"lift":
			if target_node.name == "MineLiftAnchor":
				if not chunk_controller.has_method("get_loaded_world_state_nodes"):
					return false
				var loaded_lifts: Array = chunk_controller.call("get_loaded_world_state_nodes")
				return loaded_lifts.has(target_node)
			return target_node.name == "KrollMineShaftEntrance"
	return false


func _cast_camera_interaction_target() -> Dictionary:
	if player == null or camera == null or not is_instance_valid(camera) or chunk_controller == null:
		return {}
	var world_3d: World3D = get_world_3d()
	if world_3d == null:
		return {}
	var ray_origin: Vector3 = camera.global_position
	var ray_direction: Vector3 = (-camera.global_basis.z).normalized()
	if ray_direction.length_squared() <= 0.0001:
		return {}
	var ray_end: Vector3 = ray_origin + ray_direction * INTERACTION_RAY_DISTANCE
	# Interactable proxies live on physics layer 2. Query only those areas so
	# unrelated trigger areas cannot hide a valid target farther down the ray.
	var target_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	target_query.collision_mask = INTERACTION_PROXY_COLLISION_MASK
	target_query.collide_with_areas = true
	target_query.collide_with_bodies = false
	target_query.hit_from_inside = true
	target_query.exclude = [player.get_rid()]
	var target_hit: Dictionary = world_3d.direct_space_state.intersect_ray(target_query)
	if target_hit.is_empty():
		return {}
	# World collision bodies remain opaque. A second body-only ray preserves
	# occlusion without allowing non-interactive Area3D triggers to steal the hit.
	var occlusion_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	occlusion_query.collision_mask = WORLD_GEOMETRY_COLLISION_MASK
	occlusion_query.collide_with_areas = false
	occlusion_query.collide_with_bodies = true
	occlusion_query.hit_from_inside = true
	occlusion_query.exclude = [player.get_rid()]
	var occlusion_hit: Dictionary = world_3d.direct_space_state.intersect_ray(occlusion_query)
	if not occlusion_hit.is_empty():
		var target_hit_distance: float = ray_origin.distance_to(target_hit.get("position", ray_origin))
		var occlusion_distance: float = ray_origin.distance_to(occlusion_hit.get("position", ray_origin))
		if occlusion_distance <= target_hit_distance + 0.001:
			return {}
	var target: Dictionary = _resolve_camera_interaction_target(target_hit.get("collider"))
	if target.is_empty():
		return {}
	var target_node: Node3D = target.get("node") as Node3D
	if target_node == null or not is_instance_valid(target_node):
		return {}
	target["proxy"] = target_hit.get("collider")
	var max_range: float = 3.25
	match str(target.get("kind", "")):
		"vein":
			max_range = MINE_INTERACTION_RANGE
		"lift":
			max_range = MINE_ACCESS_RANGE
	var player_distance: float = player.global_position.distance_to(target_node.global_position)
	if player_distance > max_range:
		return {}
	target["distance"] = player_distance
	target["hit_position"] = target_hit.get("position", ray_origin)
	return target
func _resolve_camera_interaction_target(collider: Object) -> Dictionary:
	var candidate: Node = collider as Node
	while candidate != null and candidate != self:
		# Lift anchors are stateful world objects too, but their G/V actions must
		# retain the dedicated lift interaction kind rather than generic prop routing.
		if candidate.name == "KrollMineShaftEntrance" or candidate.name == "MineLiftAnchor":
			return {"kind": "lift", "node": candidate}
		if chunk_controller != null:
			var crop_plots: Array = chunk_controller.call("get_loaded_crop_plots")
			if crop_plots.has(candidate):
				return {"kind": "crop", "node": candidate}
			var world_props: Array = chunk_controller.call("get_loaded_world_state_nodes")
			if world_props.has(candidate):
				return {"kind": "prop", "node": candidate}
			if chunk_controller.has_method("get_loaded_mineral_nodes"):
				var mineral_nodes: Array = chunk_controller.call("get_loaded_mineral_nodes")
				if mineral_nodes.has(candidate) and bool(candidate.get("visible")) and int(candidate.get("remaining_units")) > 0:
					return {"kind": "vein", "node": candidate}
		candidate = candidate.get_parent()
	return {}

func get_interaction_prompt_text() -> String:
	var target: Dictionary = get_camera_interaction_target()
	if target.is_empty():
		return "NO INTERACTION IN SIGHT"
	var target_node: Node3D = target.get("node") as Node3D
	match str(target.get("kind", "")):
		"crop":
			return "E  MANAGE CROP PLOT"
		"vein":
			var vein_id: String = str(target_node.get("mineral_id"))
			var vein_data: Dictionary = MineralCatalogScript.get_mineral(vein_id)
			return "F  MINE %s" % str(vein_data.get("display_name", vein_id)).to_upper()
		"prop":
			var cache_id: String = str(target_node.get("loot_item_id"))
			var cache_data: Dictionary = MineralCatalogScript.get_mineral(cache_id)
			return "F  OPEN %s CACHE · %d LEFT" % [
				str(cache_data.get("display_name", cache_id)).to_upper(),
				int(target_node.get("loot_remaining"))
			]
		"lift":
			if _is_underground:
				var current_layer: int = mine_director.get_layer_index(player.global_position) if mine_director != null else 0
				return "G  ASCEND · V  DESCEND" if current_layer > 0 else "G  SURFACE · V  DESCEND"
			return "G  ENTER KROLL MINE LIFT"
	return "NO INTERACTION IN SIGHT"
func _refresh_hud() -> void:
	if hud == null:
		return
	if interaction_prompt != null:
		interaction_prompt.text = get_interaction_prompt_text()
	var status: Dictionary = get_world_session_status()
	var active_count: int = chunk_controller.get_loaded_chunk_ids().size() if chunk_controller != null else 0
	var grid_text := str(mine_director.get_grid_coordinate(player.global_position)) if _is_underground and mine_director != null and player != null else (str(director.get_grid_coordinate(player.global_position)) if director != null and player != null else "n/a")
	var movement_profile: Dictionary = get_player_movement_profile(_sprint_active)
	var weight := float(movement_profile.get("weight_kg", 0.0))
	var limit := float(movement_profile.get("limit_kg", 65.0))
	var movement_percent: int = roundi(
		float(movement_profile.get("movement_multiplier", 1.0))
		* float(movement_profile.get("stamina_movement_multiplier", 1.0)) * 100.0
	)
	var movement_mode: String = "SPRINT" if bool(movement_profile.get("sprinting", false)) else ("EXHAUSTED" if bool(movement_profile.get("exhausted", false)) else "WALK")
	var jump_status: String = "JUMP READY"
	if not bool(movement_profile.get("inventory_can_jump", true)):
		jump_status = "JUMP LOCKED (>90 kg)"
	elif not bool(movement_profile.get("stamina_can_jump", true)):
		jump_status = "JUMP LOCKED (LOW STAMINA)"
	var stamina_value: float = float(movement_profile.get("stamina", 100.0))
	var stamina_max: float = float(movement_profile.get("stamina_max", 100.0))
	_mine_layer_index = mine_director.get_layer_index(player.global_position) if _is_underground and mine_director != null and player != null else 0
	var layer_name: String = "UNDERGROUND MINE · LEVEL %02d" % (_mine_layer_index + 1) if _is_underground else "SURFACE WORLD"
	if touch_buttons.has("crate"):
		(touch_buttons["crate"] as Button).text = "CACHE" if _is_underground else "CRATE"
	if touch_buttons.has("shaft"):
		(touch_buttons["shaft"] as Button).text = ("UP ONE LEVEL" if _mine_layer_index > 0 else "SURFACE") if _is_underground else "DESCEND"
	if touch_buttons.has("deeper"):
		(touch_buttons["deeper"] as Button).disabled = not _is_underground or _mine_layer_index >= UndergroundMineDirectorScript.MAX_LAYER_INDEX
	if touch_buttons.has("crop"):
		(touch_buttons["crop"] as Button).disabled = _is_underground
	if touch_buttons.has("sprint"):
		(touch_buttons["sprint"] as Button).text = "SPRINT ON" if _sprint_active else "SPRINT"
	for slot_index in range(QuickUseScript.SLOT_COUNT):
		var quick_key: String = "quick_%d" % (slot_index + 1)
		if not touch_buttons.has(quick_key):
			continue
		var item_id: String = str(quick_use.call("get_slot_item", slot_index))
		var item_count: int = int(quick_use.call("get_slot_count", slot_index, inventory_bridge))
		var selected: bool = int(quick_use.get("selected_slot")) == slot_index
		var quick_button: Button = touch_buttons[quick_key] as Button
		quick_button.text = "%s%d %s x%d" % [">" if selected else "", slot_index + 1, item_id.to_upper(), item_count]
		quick_button.disabled = item_count <= 0 or stamina_value >= stamina_max
	var action_help: String = "E crop · F crate · G shaft · 1-4 ration · C use" if not _is_underground else "F cache / mine · G up · V down at lift · 1-4 ration · C use"
	hud.text = "2126 SURVIVAL // %s\nWASD move · SHIFT sprint · SPACE jump · RMB look · %s · F10 test hub\nGrid: %s   Chunks: %d   Veins: %d   Crops: %d   Objects: %d\nCarry: %.1f / %.1f kg   Move: %d%% (%s)   %s\nStamina: %.0f / %.0f\n%s\n%s" % [
		layer_name, action_help, grid_text, active_count, int(status.get("saved_vein_count", 0)),
		int(status.get("saved_crop_count", 0)), int(status.get("saved_world_object_count", 0)),
		weight, limit, movement_percent, movement_mode, jump_status, stamina_value, stamina_max, _crop_action_message, _world_object_action_message
	]

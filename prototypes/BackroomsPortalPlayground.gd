extends Node3D

const Director = preload("res://systems/BackroomsPortalDirector.gd")
const PortalScene = preload("res://systems/BackroomsPortalVisual.tscn")
const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const SaveAdapter = preload("res://systems/SurvivalInventorySaveAdapter.gd")
const SettingsProfile = preload("res://systems/BackroomsSettingsProfile.gd")
const BACKROOMS_WALLPAPER = preload("res://assets/textures/backrooms_wallpaper.svg")
const WORLD_BOUNDS := Rect2(-30.0, -30.0, 60.0, 60.0)
const WORLD_SEED: int = 20261026
const SAFE_DISTANCE: float = 7.0
const SAVE_PATH: String = "user://backrooms_playground_save.json"
const CELL_SIZE: float = 8.0
const WALL_HEIGHT: float = 3.4
const STREAM_RADIUS: int = 2

@onready var player: CharacterBody3D = $Player
@onready var main_world: Node3D = $MainWorld
@onready var backrooms_world: Node3D = $BackroomsWorld
@onready var status_label: Label = $HUD/Status
@onready var help_label: Label = $HUD/Help

var director
var bridge
var active_portal_visual: Area3D
var backrooms_room: Node3D
var in_backrooms: bool = false
var current_level: String = "Surface"
var _hud_elapsed: float = 0.0
var _loaded_cells: Dictionary = {}
var _cell_material_floor: StandardMaterial3D
var _cell_material_wall: StandardMaterial3D
var _maze_rng := RandomNumberGenerator.new()
var _flicker_lights: Array[OmniLight3D] = []
var _flicker_clock: float = 0.0
var _high_graphics: bool = true
var _shadows_enabled: bool = false
var _flicker_enabled: bool = true
var _settings_panel: PanelContainer
var _settings_button: Button
var _settings_status: Label
var _settings_path: String = SettingsProfile.DEFAULT_PATH
var _settings: Dictionary = {}

func _ready() -> void:
    _settings = SettingsProfile.load_settings(_settings_path)
    _high_graphics = bool(_settings.get("high_graphics", true))
    _shadows_enabled = bool(_settings.get("shadows_enabled", false))
    _flicker_enabled = true # Fluorescent flicker is automatic, not a user setting.
    player.set_camera_mode(int(_settings.get("camera_mode", 0)) == 1)
    player.set_mouse_sensitivity(float(_settings.get("mouse_sensitivity", 2.5)) * 0.001)
    _configure_display()
    if DisplayServer.get_name() != "headless":
        _build_player_visual()
    director = Director.new(WORLD_SEED, WORLD_BOUNDS, SAFE_DISTANCE)
    director.next_spawn_in = 2.0
    bridge = BridgeScript.new()
    bridge.name = "SurvivalWorldBridge"
    add_child(bridge)
    player.bind_world_bridge(bridge)
    _build_surface()
    _prepare_maze_materials()
    _build_settings_ui()
    backrooms_world.visible = false
    _update_hud()
    if help_label != null:
        help_label.text = "WASD move | Shift sprint | Space jump | Hold RIGHT MOUSE + drag to look | V camera mode | Esc release mouse | F11 fullscreen | T portal test | B return | G collect | H drop | F5 save | F9 load"

func _build_settings_ui() -> void:
    var hud := get_node_or_null("HUD") as CanvasLayer
    if hud == null:
        return
    _settings_button = Button.new()
    _settings_button.name = "SettingsButton"
    _settings_button.text = "設定"
    _settings_button.position = Vector2(1150, 16)
    _settings_button.size = Vector2(100, 42)
    _settings_button.pressed.connect(_toggle_settings_panel)
    hud.add_child(_settings_button)

    _settings_panel = PanelContainer.new()
    _settings_panel.name = "SettingsPanel"
    _settings_panel.set_anchors_preset(Control.PRESET_CENTER)
    _settings_panel.custom_minimum_size = Vector2(380, 380)
    # Keep the settings panel visually readable as render resolution rises.
    # The 3D viewport uses the selected resolution, so fixed-size UI otherwise
    # occupies a progressively smaller fraction of the screen.
    _settings_panel.pivot_offset = Vector2(190, 190)
    _apply_settings_panel_scale()
    hud.add_child(_settings_panel)
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 12)
    _settings_panel.add_child(layout)
    var title := Label.new()
    title.text = "遊戲設定"
    title.add_theme_font_size_override("font_size", 24)
    layout.add_child(title)

    var camera_label := Label.new()
    camera_label.text = "視角"
    layout.add_child(camera_label)
    var camera_option := OptionButton.new()
    camera_option.add_item("第一人稱", 0)
    camera_option.add_item("第三人稱", 1)
    camera_option.select(int(_settings.get("camera_mode", 0)))
    camera_option.item_selected.connect(_on_camera_setting_changed)
    layout.add_child(camera_option)

    var sensitivity_label := Label.new()
    sensitivity_label.text = "滑鼠靈敏度"
    layout.add_child(sensitivity_label)
    var sensitivity_slider := HSlider.new()
    sensitivity_slider.name = "SensitivitySlider"
    sensitivity_slider.min_value = 0.5
    sensitivity_slider.max_value = 6.0
    sensitivity_slider.step = 0.1
    sensitivity_slider.value = float(_settings.get("mouse_sensitivity", 2.5))
    sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
    layout.add_child(sensitivity_slider)

    var resolution_label := Label.new()
    resolution_label.text = "解析度"
    layout.add_child(resolution_label)
    var resolution_option := OptionButton.new()
    resolution_option.name = "ResolutionOption"
    resolution_option.add_item("1280 × 720（流暢）", 0)
    resolution_option.add_item("1600 × 900", 1)
    resolution_option.add_item("1920 × 1080", 2)
    var saved_resolution: int = clampi(int(_settings.get("resolution_index", 0)), 0, 2)
    resolution_option.select(saved_resolution)
    resolution_option.item_selected.connect(_on_resolution_changed)
    layout.add_child(resolution_option)

    var shadows_button := Button.new()
    shadows_button.name = "GraphicsButton"
    shadows_button.text = "光影：開" if _shadows_enabled else "光影：關"
    shadows_button.pressed.connect(_toggle_shadows)
    layout.add_child(shadows_button)

    _settings_status = Label.new()
    _settings_status.text = "光影已開啟：啟用動態陰影，效能負擔較高。" if _shadows_enabled else "光影已關閉：停用動態陰影，優先提升流暢度。"
    _settings_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(_settings_status)
    var close_button := Button.new()
    close_button.text = "關閉"
    close_button.pressed.connect(_toggle_settings_panel)
    layout.add_child(close_button)
    _settings_panel.visible = false

func _apply_settings_panel_scale() -> void:
    if _settings_panel == null:
        return
    var resolution_index: int = clampi(int(_settings.get("resolution_index", 0)), 0, 2)
    var scale_factor: float = [1.0, 1.25, 1.5][resolution_index]
    _settings_panel.scale = Vector2.ONE * scale_factor
    _settings_panel.position = Vector2(-190.0, -190.0)

func _toggle_settings_panel() -> void:
    if _settings_panel != null:
        _settings_panel.visible = not _settings_panel.visible
        if _settings_panel.visible:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_camera_setting_changed(index: int) -> void:
    var selected_mode: int = 1 if index == 1 else 0
    _settings["camera_mode"] = selected_mode
    player.set_camera_mode(selected_mode == 1)
    _save_settings()

func _on_sensitivity_changed(value: float) -> void:
    var selected_sensitivity: float = clampf(value, 0.5, 6.0)
    _settings["mouse_sensitivity"] = selected_sensitivity
    player.set_mouse_sensitivity(selected_sensitivity * 0.001)
    _save_settings()

func _save_settings() -> void:
    if not SettingsProfile.save_settings(_settings, _settings_path) and _settings_status != null:
        _settings_status.text = "設定儲存失敗；目前值只在本次執行有效。"

func _on_resolution_changed(index: int) -> void:
    var sizes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
    var selected: int = clampi(index, 0, sizes.size() - 1)
    _settings["resolution_index"] = selected
    _apply_settings_panel_scale()
    if DisplayServer.get_name() != "headless":
        var window := get_window()
        # With stretch/mode="viewport", changing only Window.size scales the same
        # 1280x720 render target. Update the viewport's base size as well so the
        # selected resolution changes the actual 3D render resolution.
        window.content_scale_size = sizes[selected]
        window.content_scale_factor = 1.0
        window.mode = Window.MODE_WINDOWED
        window.size = sizes[selected]
        window.move_to_center()
    _save_settings()
    if _settings_status != null:
        _settings_status.text = "解析度已切換為 %d × %d（視窗模式）。" % [sizes[selected].x, sizes[selected].y]

func _toggle_shadows() -> void:
    _shadows_enabled = not _shadows_enabled
    _settings["shadows_enabled"] = _shadows_enabled
    var button := _settings_panel.find_child("GraphicsButton", true, false) as Button
    if button != null:
        button.text = "光影：開" if _shadows_enabled else "光影：關"
    for light in _flicker_lights:
        if is_instance_valid(light):
            light.shadow_enabled = _shadows_enabled
    if _settings_status != null:
        _settings_status.text = "光影已開啟：啟用動態陰影，效能負擔較高。" if _shadows_enabled else "光影已關閉：停用動態陰影，優先提升流暢度。"
    _save_settings()

# Compatibility entry point used by older integration tests and saved workflows.
func _toggle_graphics_quality() -> void:
    _toggle_shadows()
    _rebuild_maze_for_settings()

func _rebuild_maze_for_settings() -> void:
    if in_backrooms and backrooms_room != null and is_instance_valid(backrooms_room):
        for cell_value in _loaded_cells.values():
            var cell_node := cell_value as Node
            if cell_node != null and is_instance_valid(cell_node):
                var cell_parent: Node = cell_node.get_parent()
                if cell_parent != null:
                    cell_parent.remove_child(cell_node)
                cell_node.queue_free()
        _loaded_cells.clear()
        _flicker_lights.clear()
        _stream_maze_cells(true)

func _configure_display() -> void:
    if DisplayServer.get_name() != "headless":
        var window := get_window()
        window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
        window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
        var sizes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
        var resolution_index: int = clampi(int(_settings.get("resolution_index", 0)), 0, sizes.size() - 1)
        # Keep the base viewport resolution in sync with the saved selection;
        # otherwise Godot merely scales the original render target to the window.
        window.content_scale_size = sizes[resolution_index]
        window.content_scale_factor = 1.0
        window.mode = Window.MODE_WINDOWED
        window.size = sizes[resolution_index]
        window.move_to_center()

func _build_player_visual() -> void:
    # Readable primitive humanoid placeholder for third-person exploration.
    var old_avatar := player.get_node_or_null("AvatarVisual")
    if old_avatar != null:
        old_avatar.queue_free()
    var avatar := Node3D.new()
    avatar.name = "AvatarVisual"
    player.add_child(avatar)
    _add_player_part(avatar, "Torso", BoxMesh.new(), Vector3(0.0, 1.12, 0.0), Vector3(0.62, 0.72, 0.34), Color(0.12, 0.48, 0.62))
    _add_player_part(avatar, "Head", SphereMesh.new(), Vector3(0.0, 1.72, 0.0), Vector3(0.34, 0.36, 0.32), Color(0.82, 0.68, 0.52))
    _add_player_part(avatar, "LeftArm", BoxMesh.new(), Vector3(-0.43, 1.12, 0.0), Vector3(0.2, 0.68, 0.24), Color(0.16, 0.4, 0.52))
    _add_player_part(avatar, "RightArm", BoxMesh.new(), Vector3(0.43, 1.12, 0.0), Vector3(0.2, 0.68, 0.24), Color(0.16, 0.4, 0.52))
    _add_player_part(avatar, "LeftLeg", BoxMesh.new(), Vector3(-0.17, 0.42, 0.0), Vector3(0.23, 0.72, 0.28), Color(0.12, 0.16, 0.2))
    _add_player_part(avatar, "RightLeg", BoxMesh.new(), Vector3(0.17, 0.42, 0.0), Vector3(0.23, 0.72, 0.28), Color(0.12, 0.16, 0.2))
    player.bind_avatar_visual(avatar)

func _add_player_part(parent: Node3D, part_name: String, mesh_resource: PrimitiveMesh, part_position: Vector3, part_size: Vector3, color: Color) -> void:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = part_name
    if mesh_resource is BoxMesh:
        (mesh_resource as BoxMesh).size = part_size
    elif mesh_resource is SphereMesh:
        (mesh_resource as SphereMesh).radius = part_size.x * 0.5
        (mesh_resource as SphereMesh).height = part_size.y
    mesh_instance.mesh = mesh_resource
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.78
    mesh_instance.material_override = material
    mesh_instance.position = part_position
    parent.add_child(mesh_instance)

func _process(delta: float) -> void:
    if _flicker_enabled:
        _update_flickering_lights(delta)
    if director == null:
        return
    if in_backrooms:
        _stream_maze_cells()
    else:
        # Natural portals belong to the surface world in this prototype.
        # Pausing the director here prevents portals spawning inside Backrooms.
        var player_position := Vector2(player.global_position.x, player.global_position.z)
        var result: Dictionary = director.tick(delta, player_position)
        if result.get("event", "none") == "spawned":
            _spawn_portal(result["portal"])
    _hud_elapsed += delta
    if _hud_elapsed >= 0.2:
        _hud_elapsed = 0.0
        _update_hud()

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_F10:
            get_tree().change_scene_to_file("res://prototypes/SurvivalTestHub.tscn")
        KEY_T:
            debug_spawn_portal()
        KEY_B:
            debug_return_to_surface()
        KEY_G:
            debug_collect_berries(1)
        KEY_H:
            debug_drop_berries(1)
        KEY_F5:
            save_game()
        KEY_F9:
            load_game()

func _build_surface() -> void:
    _add_box(main_world, "SurfaceFloor", Vector3(0, -0.5, 0), Vector3(70, 1, 70), Color(0.07, 0.12, 0.15))
    var wall_color := Color(0.12, 0.2, 0.23)
    _add_box(main_world, "NorthBoundary", Vector3(0, 2, -35), Vector3(70, 4, 1), wall_color)
    _add_box(main_world, "SouthBoundary", Vector3(0, 2, 35), Vector3(70, 4, 1), wall_color)
    _add_box(main_world, "WestBoundary", Vector3(-35, 2, 0), Vector3(1, 4, 70), wall_color)
    _add_box(main_world, "EastBoundary", Vector3(35, 2, 0), Vector3(1, 4, 70), wall_color)

func _prepare_maze_materials() -> void:
    var floor_color := Color(0.57, 0.51, 0.31)
    var wall_color := Color(0.76, 0.69, 0.42)
    match current_level:
        "Level 1":
            floor_color = Color(0.24, 0.27, 0.28)
            wall_color = Color(0.42, 0.45, 0.44)
        "Level 2":
            floor_color = Color(0.28, 0.16, 0.12)
            wall_color = Color(0.47, 0.27, 0.19)
        "Level 3":
            floor_color = Color(0.12, 0.19, 0.27)
            wall_color = Color(0.27, 0.37, 0.49)
    _cell_material_floor = StandardMaterial3D.new()
    _cell_material_floor.albedo_color = floor_color
    _cell_material_floor.roughness = 0.94
    _cell_material_wall = StandardMaterial3D.new()
    _cell_material_wall.roughness = 0.88
    # Preserve the original wallpaper asset and UV scale, but prevent the maze
    # lighting from turning its yellow surface nearly black.
    _cell_material_wall.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _cell_material_wall.albedo_color = Color.WHITE
    _cell_material_wall.cull_mode = BaseMaterial3D.CULL_DISABLED
    _cell_material_wall.albedo_texture = BACKROOMS_WALLPAPER
    _cell_material_wall.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    _cell_material_wall.uv1_triplanar = false
    _cell_material_wall.uv1_scale = Vector3(1.0, 1.0, 1.0)
    if _cell_material_wall.albedo_texture == null:
        push_error("Backrooms wallpaper preload is null: res://assets/textures/backrooms_wallpaper.svg")

func _build_backrooms_room(level_name: String) -> void:
    if backrooms_room != null and is_instance_valid(backrooms_room):
        backrooms_room.queue_free()
    _loaded_cells.clear()
    _flicker_lights.clear()
    backrooms_room = Node3D.new()
    backrooms_room.name = "EndlessMaze_" + level_name.replace(" ", "")
    backrooms_world.add_child(backrooms_room)
    _prepare_maze_materials()
    _stream_maze_cells(true)

func _stream_maze_cells(force: bool = false) -> void:
    if backrooms_room == null or not is_instance_valid(backrooms_room):
        return
    var player_cell := _maze_cell_for_position(player.global_position)
    var center_x: int = player_cell.x
    var center_z: int = player_cell.y
    var needed: Dictionary = {}
    for z in range(center_z - STREAM_RADIUS, center_z + STREAM_RADIUS + 1):
        for x in range(center_x - STREAM_RADIUS, center_x + STREAM_RADIUS + 1):
            var key := Vector2i(x, z)
            needed[key] = true
            if force or not _loaded_cells.has(key):
                _create_maze_cell(key)
    for key in _loaded_cells.keys():
        if not needed.has(key):
            var cell: Node = _loaded_cells[key]
            if is_instance_valid(cell):
                cell.queue_free()
            _loaded_cells.erase(key)

func _maze_cell_for_position(world_position: Vector3) -> Vector2i:
    # Cells are centered on multiples of CELL_SIZE, so their boundaries are
    # at half-cell offsets. Plain floor(position / CELL_SIZE) switches late.
    return Vector2i(
        floori((world_position.x + CELL_SIZE * 0.5) / CELL_SIZE),
        floori((world_position.z + CELL_SIZE * 0.5) / CELL_SIZE)
    )

func _create_maze_cell(cell: Vector2i) -> void:
    var root := Node3D.new()
    root.name = "Cell_%d_%d" % [cell.x, cell.y]
    root.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
    backrooms_room.add_child(root)
    _loaded_cells[cell] = root
    _add_box(root, "Floor", Vector3(0, -0.12, 0), Vector3(CELL_SIZE, 0.24, CELL_SIZE), _cell_material_floor.albedo_color)
    var floor_mesh := root.get_node_or_null("FloorMesh") as MeshInstance3D
    if floor_mesh != null:
        floor_mesh.material_override = _make_surface_material(true, cell)
    # Flat carpet: no overlay seams, raised wear marks or patches.
    var ceiling_material := StandardMaterial3D.new()
    # Backrooms ceilings should remain readable even in cells without a light.
    # Give the ceiling a bright warm tile surface instead of nearly-black flat color.
    ceiling_material.albedo_color = Color(0.92, 0.88, 0.68)
    ceiling_material.emission_enabled = true
    ceiling_material.emission = Color(0.18, 0.15, 0.08)
    ceiling_material.emission_energy_multiplier = 0.45
    ceiling_material.roughness = 1.0
    ceiling_material.metallic = 0.0
    if _high_graphics:
        _add_decor_box(root, "Ceiling", Vector3(0, WALL_HEIGHT + 0.18, 0), Vector3(CELL_SIZE, 0.28, CELL_SIZE), ceiling_material)
    # No bright ceiling-edge trim: it created a distracting grid between streamed cells.
    # Every cell uses a coordinate-derived random stream, so the maze is stable
    # as it unloads and reloads while the player explores indefinitely.
    var north_open := _edge_is_open(cell, Vector2i(0, -1))
    var west_open := _edge_is_open(cell, Vector2i(-1, 0))
    # Each shared edge has one owner: the cell to its south/east builds it as
    # its north/west edge. This avoids duplicate collision bodies on every seam.
    if not north_open:
        _add_maze_wall(root, "NorthWall", Vector3(0, WALL_HEIGHT * 0.5, -CELL_SIZE * 0.5), Vector3(CELL_SIZE, WALL_HEIGHT, 0.22))
    if not west_open:
        _add_maze_wall(root, "WestWall", Vector3(-CELL_SIZE * 0.5, WALL_HEIGHT * 0.5, 0), Vector3(0.22, WALL_HEIGHT, CELL_SIZE))

    # Add deterministic interior baffles so cells feel like winding corridors,
    # not just empty squares. Both ends stay open for navigation.
    var partition_style := _hash_value(cell.x, cell.y, 29) % 3
    if partition_style == 0:
        var offset_z := -0.7 if _hash_value(cell.x, cell.y, 30) % 2 == 0 else 0.7
        _add_maze_wall(root, "InteriorBaffle", Vector3(0, WALL_HEIGHT * 0.5, offset_z), Vector3(CELL_SIZE - 2.2, WALL_HEIGHT, 0.18))
    elif partition_style == 1:
        var offset_x := -0.7 if _hash_value(cell.x, cell.y, 31) % 2 == 0 else 0.7
        _add_maze_wall(root, "InteriorBaffle", Vector3(offset_x, WALL_HEIGHT * 0.5, 0), Vector3(0.18, WALL_HEIGHT, CELL_SIZE - 2.2))

    # More frequent, brighter warm fluorescent fixtures improve readability without
    # turning the Backrooms into a brightly lit office.
    if _hash_value(cell.x, cell.y, 71) % (3 if _high_graphics else 5) == 0:
        var panel_material := StandardMaterial3D.new()
        panel_material.albedo_color = Color(1.0, 0.96, 0.78)
        panel_material.emission_enabled = true
        panel_material.emission = Color(1.0, 0.82, 0.48)
        panel_material.emission_energy_multiplier = 1.35
        _add_decor_box(root, "CeilingLightPanel", Vector3(0, WALL_HEIGHT + 0.025, 0), Vector3(1.8, 0.045, 0.7), panel_material)
        if DisplayServer.get_name() != "headless":
            var ceiling_light := OmniLight3D.new()
            ceiling_light.name = "CeilingOmniLight"
            ceiling_light.position = Vector3(0, WALL_HEIGHT - 0.2, 0)
            ceiling_light.light_color = Color(1.0, 0.88, 0.65)
            ceiling_light.light_energy = 1.65
            ceiling_light.omni_range = 11.0
            ceiling_light.shadow_enabled = false
            root.add_child(ceiling_light)
            _flicker_lights.append(ceiling_light)
            ceiling_light.light_energy = 1.45 if _high_graphics else 1.2
            ceiling_light.omni_range = 10.0 if _high_graphics else 8.5

func _edge_is_open(cell: Vector2i, direction: Vector2i) -> bool:
    var neighbor := cell + direction
    var ax := mini(cell.x, neighbor.x)
    var az := mini(cell.y, neighbor.y)
    var bx := maxi(cell.x, neighbor.x)
    var bz := maxi(cell.y, neighbor.y)
    # Random extra passages make the maze twisty; a deterministic spanning
    # tree edge guarantees every generated cell can ultimately reach the origin.
    if _parent_toward_origin(cell) == direction:
        return true
    if _parent_toward_origin(neighbor) == -direction:
        return true
    return _hash_value(ax * 31 + bx, az * 31 + bz, 13) % 100 < 34

func _parent_toward_origin(cell: Vector2i) -> Vector2i:
    if cell == Vector2i.ZERO:
        return Vector2i.ZERO
    if absi(cell.x) >= absi(cell.y) and cell.x != 0:
        return Vector2i(-1 if cell.x > 0 else 1, 0)
    return Vector2i(0, -1 if cell.y > 0 else 1)

func _hash_value(x: int, z: int, salt: int) -> int:
    var value: int = abs((x * 73856093) ^ (z * 19349663) ^ (salt * 83492791) ^ WORLD_SEED)
    return value

func _should_enable_light_shadows(cell: Vector2i) -> bool:
    # Dynamic shadows are independent from procedural geometry quality.
    return _shadows_enabled and (_hash_value(cell.x, cell.y, 77) % 5 == 0)

func _make_surface_material(is_floor: bool, seed_cell: Vector2i) -> Material:
    var material := StandardMaterial3D.new()
    material.roughness = 1.0
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
    material.albedo_color = Color.WHITE
    # BoxMesh already provides face UVs. Triplanar projection was overriding
    # the intended wallpaper mapping and made the wall pattern appear flat at
    # the scale used here. Use the mesh UVs directly so the supplied repeating
    # wallpaper SVG is actually sampled on every wall face.
    material.uv1_triplanar = false
    if is_floor:
        material.albedo_texture = load("res://assets/textures/backrooms_carpet.svg") as Texture2D
        material.uv1_scale = Vector3(1.0, 1.0, 1.0)
    else:
        var wallpaper := load("res://assets/textures/backrooms_wallpaper.svg") as Texture2D
        if wallpaper == null:
            push_error("Wallpaper texture failed to load: res://assets/textures/backrooms_wallpaper.svg")
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.albedo_color = Color.WHITE
        material.albedo_texture = wallpaper
        material.uv1_scale = Vector3(1.0, 1.0, 1.0)
    return material

func _add_carpet_texture(parent: Node3D) -> void:
    if DisplayServer.get_name() == "headless":
        return
    var carpet := MeshInstance3D.new()
    carpet.name = "CarpetFibers"
    var plane := PlaneMesh.new()
    plane.size = Vector2(CELL_SIZE - 0.08, CELL_SIZE - 0.08)
    plane.subdivide_width = 32
    plane.subdivide_depth = 32
    carpet.mesh = plane
    carpet.position = Vector3(0, 0.008, 0)
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 carpet_color : source_color = vec4(0.57, 0.51, 0.31, 1.0);
uniform vec4 fiber_color : source_color = vec4(0.72, 0.65, 0.42, 1.0);
void vertex() {
    VERTEX.y += sin(VERTEX.x * 19.0 + TIME * 0.7) * cos(VERTEX.z * 17.0 + TIME * 0.45) * 0.009;
}
void fragment() {
    float grain = fract(sin(dot(UV * vec2(431.7, 283.1), vec2(12.9898, 78.233))) * 43758.5453);
    float fibers = sin(UV.x * 1100.0 + sin(UV.y * 80.0)) * 0.035;
    float variation = (grain - 0.5) * 0.12 + fibers;
    ALBEDO = mix(carpet_color.rgb, fiber_color.rgb, clamp(0.22 + variation, 0.0, 0.45));
    ROUGHNESS = 1.0;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("carpet_color", _cell_material_floor.albedo_color)
    material.set_shader_parameter("fiber_color", _cell_material_floor.albedo_color.lightened(0.18))
    carpet.material_override = material
    parent.add_child(carpet)

func _update_flickering_lights(delta: float) -> void:
    _flicker_clock += delta
    for index in range(_flicker_lights.size() - 1, -1, -1):
        var light := _flicker_lights[index]
        if not is_instance_valid(light):
            _flicker_lights.remove_at(index)
            continue
        var seed := float(light.get_instance_id() % 97)
        var pulse := sin(_flicker_clock * (8.0 + seed * 0.07) + seed) * 0.06
        # Keep subtle fluorescent variation, but remove deep random blackouts:
        # they caused nearby walls to suddenly become almost unlit.
        light.light_energy = 1.05 + pulse

func _add_decor_box(parent: Node3D, object_name: String, box_position: Vector3, box_size: Vector3, material: StandardMaterial3D) -> void:
    if DisplayServer.get_name() == "headless":
        return
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = object_name
    var mesh := BoxMesh.new()
    mesh.size = box_size
    mesh_instance.mesh = mesh
    mesh_instance.material_override = material
    mesh_instance.position = box_position
    parent.add_child(mesh_instance)

func _add_maze_wall(parent: Node3D, object_name: String, wall_position: Vector3, wall_size: Vector3) -> void:
    var material := _cell_material_wall
    if material == null:
        material = StandardMaterial3D.new()
        material.albedo_color = Color(0.76, 0.69, 0.42)
    if DisplayServer.get_name() != "headless":
        var mesh_instance := MeshInstance3D.new()
        mesh_instance.name = object_name + "Mesh"
        var mesh := BoxMesh.new()
        mesh.size = wall_size
        mesh_instance.mesh = mesh
        # Assign the same verified wallpaper material used by the maze setup;
        # avoid a second load path that could silently fall back to a flat wall.
        mesh_instance.material_override = _cell_material_wall
        mesh_instance.position = wall_position
        parent.add_child(mesh_instance)
    var body := StaticBody3D.new()
    body.name = object_name + "Collision"
    body.position = wall_position
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = wall_size
    collision.shape = shape
    body.add_child(collision)
    parent.add_child(body)

func _set_collision_enabled(root_node: Node, enabled: bool) -> void:
    for child in root_node.get_children():
        if child is CollisionObject3D:
            var collision_object: CollisionObject3D = child
            collision_object.collision_layer = 1 if enabled else 0
            collision_object.collision_mask = 1 if enabled else 0
        _set_collision_enabled(child, enabled)

func _contains_enabled_collision(root_node: Node) -> bool:
    for child in root_node.get_children():
        if child is CollisionObject3D and child.collision_layer > 0:
            return true
        if _contains_enabled_collision(child):
            return true
    return false

func is_surface_collision_enabled() -> bool:
    return _contains_enabled_collision(main_world)

func is_backrooms_collision_enabled() -> bool:
    return backrooms_room != null and is_instance_valid(backrooms_room) and _contains_enabled_collision(backrooms_room)

func _add_box(parent: Node3D, object_name: String, box_position: Vector3, box_size: Vector3, color: Color) -> void:
    if DisplayServer.get_name() != "headless":
        var material := StandardMaterial3D.new()
        material.albedo_color = color
        material.roughness = 0.82
        var mesh_instance := MeshInstance3D.new()
        mesh_instance.name = object_name + "Mesh"
        var mesh := BoxMesh.new()
        mesh.size = box_size
        mesh_instance.mesh = mesh
        mesh_instance.material_override = material
        mesh_instance.position = box_position
        parent.add_child(mesh_instance)
    var body := StaticBody3D.new()
    body.name = object_name + "Collision"
    body.position = box_position
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = box_size
    collision.shape = shape
    body.add_child(collision)
    parent.add_child(body)

func _spawn_portal(portal_data: Dictionary) -> bool:
    _remove_portal_visual()
    if DisplayServer.get_name() == "headless":
        active_portal_visual = null
        return not portal_data.is_empty()
    var portal: Area3D = PortalScene.instantiate() as Area3D
    add_child(portal)
    if not bool(portal.call("configure_from_director", portal_data, 0.0)):
        portal.queue_free()
        return false
    portal.connect("portal_entered", Callable(self, "_on_portal_entered"))
    active_portal_visual = portal
    return true

func _remove_portal_visual() -> void:
    if active_portal_visual != null and is_instance_valid(active_portal_visual):
        active_portal_visual.queue_free()
    active_portal_visual = null

func _on_portal_entered(body: Node3D, portal_id: int) -> void:
    if body != player:
        return
    var result: Dictionary = director.consume_portal(portal_id)
    if not bool(result.get("ok", false)):
        return
    _remove_portal_visual()
    current_level = str(result["destination_level"])
    in_backrooms = true
    main_world.visible = false
    _set_collision_enabled(main_world, false)
    backrooms_world.visible = true
    player.global_position = Vector3.ZERO
    player.velocity = Vector3.ZERO
    _build_backrooms_room(current_level)
    _update_hud()

func debug_spawn_portal() -> bool:
    if not director.active_portal.is_empty():
        return false
    director.next_spawn_in = 0.0
    var result: Dictionary = director.tick(0.01, Vector2(player.global_position.x, player.global_position.z))
    if result.get("event", "none") != "spawned":
        return false
    return _spawn_portal(result["portal"])

func debug_enter_active_portal() -> bool:
    if director.active_portal.is_empty():
        return false
    _on_portal_entered(player, int(director.active_portal["id"]))
    return in_backrooms

func debug_return_to_surface() -> void:
    _remove_portal_visual()
    director.active_portal.clear()
    director.next_spawn_in = 2.0
    in_backrooms = false
    current_level = "Surface"
    if backrooms_room != null and is_instance_valid(backrooms_room):
        backrooms_room.queue_free()
    backrooms_room = null
    _loaded_cells.clear()
    backrooms_world.visible = false
    main_world.visible = true
    _set_collision_enabled(main_world, true)
    _set_collision_enabled(backrooms_world, false)
    player.global_position = Vector3.ZERO
    player.velocity = Vector3.ZERO
    _update_hud()

func debug_collect_berries(amount: int = 1) -> bool:
    return bridge != null and bridge.collect_world_item("berries", amount)

func debug_drop_berries(amount: int = 1) -> bool:
    return bridge != null and bridge.drop_item("berries", amount)

func get_inventory_count(item_id: String) -> int:
    if bridge == null:
        return 0
    var payload: Dictionary = bridge.serialize_inventory()
    var counts: Dictionary = payload.get("inventory", {})
    return int(counts.get(item_id, 0))

func get_current_level() -> String:
    return current_level

func has_active_portal() -> bool:
    return not director.active_portal.is_empty()

func get_active_portal_id() -> int:
    return int(director.active_portal.get("id", 0))

func serialize_world_state() -> Dictionary:
    if bridge == null or director == null:
        return {}
    var inventory_payload: Dictionary = bridge.serialize_inventory()
    var envelope := {
        "version": 2,
        "game_day": int(inventory_payload.get("game_day", 1)),
        "inventory": inventory_payload.get("inventory", {}),
        "world_seed": WORLD_SEED,
        "stamina": 100.0,
        "hotbar_slots": ["", "", "", "", "", "", "", "", "", ""],
        "selected_hotbar": 0,
        "player_position": [player.global_position.x, player.global_position.y, player.global_position.z],
        "crops": [],
        "world_state": {}
    }
    var result: Dictionary = bridge.serialize_world_save(envelope)
    if not bool(result.get("ok", false)):
        return {}
    var save: Dictionary = result["world_save"]
    save["player_position"] = [player.global_position.x, player.global_position.y, player.global_position.z]
    save["backrooms_portal_state"] = director.to_save_dict()
    save["current_level"] = current_level
    save["in_backrooms"] = in_backrooms
    return save

func load_world_state_from_dictionary(world_save: Dictionary) -> bool:
    var converted: Dictionary = SaveAdapter.world_save_to_inventory_payload(world_save)
    if not bool(converted.get("ok", false)):
        return false
    var portal_payload: Variant = world_save.get("backrooms_portal_state", null)
    if not (portal_payload is Dictionary):
        return false
    var candidate_director = Director.new(WORLD_SEED, WORLD_BOUNDS, SAFE_DISTANCE)
    if not candidate_director.load_save_dict(portal_payload):
        return false
    var raw_level: Variant = world_save.get("current_level", null)
    var raw_backrooms: Variant = world_save.get("in_backrooms", null)
    if not (raw_level is String) or not (raw_backrooms is bool):
        return false
    if bool(raw_backrooms):
        if not Director.TARGET_LEVELS.has(raw_level):
            return false
        # In this prototype, a live surface portal cannot coexist with a
        # Backrooms save. Reject mismatched/tampered envelopes before mutation.
        if not candidate_director.active_portal.is_empty():
            return false
    elif raw_level != "Surface":
        return false
    var raw_position: Variant = world_save.get("player_position", null)
    if not (raw_position is Array) or raw_position.size() != 3:
        return false
    for component in raw_position:
        if not (component is int or component is float) or not is_finite(float(component)):
            return false
    var restored_position := Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
    if not WORLD_BOUNDS.has_point(Vector2(restored_position.x, restored_position.z)) and not bool(raw_backrooms):
        return false
    if restored_position.y < -5.0 or restored_position.y > 20.0:
        return false
    if not bridge.restore_world_save(world_save):
        return false
    if not director.load_save_dict(portal_payload):
        return false
    in_backrooms = bool(raw_backrooms)
    current_level = str(raw_level)
    player.global_position = restored_position
    player.velocity = Vector3.ZERO
    main_world.visible = not in_backrooms
    _set_collision_enabled(main_world, not in_backrooms)
    backrooms_world.visible = in_backrooms
    if in_backrooms:
        _build_backrooms_room(current_level)
    else:
        _set_collision_enabled(backrooms_world, false)
        if backrooms_room != null and is_instance_valid(backrooms_room):
            backrooms_room.queue_free()
            backrooms_room = null
            _loaded_cells.clear()
    _remove_portal_visual()
    if not director.active_portal.is_empty():
        var active: Dictionary = director.active_portal
        _spawn_portal({"id": int(active["id"]), "position": active["position"]})
    _update_hud()
    return true

func _write_save_atomically(destination_path: String, data: Dictionary) -> bool:
    if destination_path.strip_edges().is_empty():
        return false
    var temporary_path := destination_path + ".tmp"
    var backup_path := destination_path + ".bak"
    var destination_absolute := ProjectSettings.globalize_path(destination_path)
    var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
    var backup_absolute := ProjectSettings.globalize_path(backup_path)

    # A directory at the temporary path is an obstruction; never touch the current save.
    if DirAccess.dir_exists_absolute(temporary_absolute):
        return false
    if FileAccess.file_exists(temporary_path):
        if DirAccess.remove_absolute(temporary_absolute) != OK:
            return false

    var temporary_file := FileAccess.open(temporary_path, FileAccess.WRITE)
    if temporary_file == null:
        return false
    temporary_file.store_string(JSON.stringify(data))
    temporary_file.flush()
    var write_error := temporary_file.get_error()
    temporary_file.close()
    if write_error != OK:
        if FileAccess.file_exists(temporary_path):
            DirAccess.remove_absolute(temporary_absolute)
        return false

    # Validate the complete temporary payload before moving the current save.
    var verification_file := FileAccess.open(temporary_path, FileAccess.READ)
    if verification_file == null:
        if FileAccess.file_exists(temporary_path):
            DirAccess.remove_absolute(temporary_absolute)
        return false
    var parsed: Variant = JSON.parse_string(verification_file.get_as_text())
    verification_file.close()
    if not (parsed is Dictionary):
        if FileAccess.file_exists(temporary_path):
            DirAccess.remove_absolute(temporary_absolute)
        return false

    var moved_existing_save := false
    if FileAccess.file_exists(destination_path):
        if DirAccess.dir_exists_absolute(backup_absolute):
            DirAccess.remove_absolute(temporary_absolute)
            return false
        if FileAccess.file_exists(backup_path):
            if DirAccess.remove_absolute(backup_absolute) != OK:
                DirAccess.remove_absolute(temporary_absolute)
                return false
        if DirAccess.rename_absolute(destination_absolute, backup_absolute) != OK:
            DirAccess.remove_absolute(temporary_absolute)
            return false
        moved_existing_save = true
    elif DirAccess.dir_exists_absolute(destination_absolute):
        DirAccess.remove_absolute(temporary_absolute)
        return false

    if DirAccess.rename_absolute(temporary_absolute, destination_absolute) != OK:
        if moved_existing_save:
            DirAccess.rename_absolute(backup_absolute, destination_absolute)
        if FileAccess.file_exists(temporary_path):
            DirAccess.remove_absolute(temporary_absolute)
        return false

    # Once the new primary file is in place, any older backup is superseded.
    if FileAccess.file_exists(backup_path):
        DirAccess.remove_absolute(backup_absolute)
    return true

func save_game() -> bool:
    var data := serialize_world_state()
    if data.is_empty():
        return false
    if not _write_save_atomically(SAVE_PATH, data):
        return false
    _update_hud()
    return true

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        var backup_path := SAVE_PATH + ".bak"
        if not FileAccess.file_exists(backup_path):
            return false
        if DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(SAVE_PATH)) != OK:
            return false
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return false
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not (parsed is Dictionary):
        return false
    return load_world_state_from_dictionary(parsed)

func _update_hud() -> void:
    if status_label == null:
        return
    var summary: Dictionary = bridge.get_summary() if bridge != null else {}
    var weight: float = float(summary.get("weight_kg", 0.0))
    var limit: float = float(summary.get("limit_kg", 65.0))
    var portal_status := "none"
    if director != null and not director.active_portal.is_empty():
        portal_status = "#" + str(director.active_portal.get("id", "?"))
    var maze_status := "ENDLESS MAZE" if in_backrooms else "SURFACE"
    status_label.text = "2126 SURVIVAL // KROLL PORTAL LAB\nZone: %s | Portal: %s | Carry: %.1f / %.1f kg | %s\nG collect berries: %d | H drop one | T spawn test portal" % [current_level, portal_status, weight, limit, maze_status, get_inventory_count("berries")]

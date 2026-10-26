extends Node3D

const Director = preload("res://systems/BackroomsPortalDirector.gd")
const PortalScene = preload("res://systems/BackroomsPortalVisual.tscn")
const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const SaveAdapter = preload("res://systems/SurvivalInventorySaveAdapter.gd")
const WORLD_BOUNDS := Rect2(-30.0, -30.0, 60.0, 60.0)
const WORLD_SEED: int = 20261026
const SAFE_DISTANCE: float = 7.0
const SAVE_PATH: String = "user://backrooms_playground_save.json"
const CELL_SIZE: float = 8.0
const WALL_HEIGHT: float = 3.4
const STREAM_RADIUS: int = 4

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

func _ready() -> void:
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
    backrooms_world.visible = false
    _update_hud()
    if help_label != null:
        help_label.text = "WASD move | Shift sprint | Space jump | Hold RIGHT MOUSE + drag to look | Esc release mouse | F11 fullscreen | T portal test | B return | G collect | H drop | F5 save | F9 load"

func _configure_display() -> void:
    if DisplayServer.get_name() != "headless":
        get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
        get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
        get_window().size = Vector2i(1280, 720)

func _build_player_visual() -> void:
    # A first-person camera should never show the player's own placeholder body.
    var old_body := player.get_node_or_null("BodyMesh")
    if old_body != null:
        old_body.queue_free()

func _process(delta: float) -> void:
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
    _cell_material_wall.albedo_color = wall_color
    _cell_material_wall.roughness = 0.88

func _build_backrooms_room(level_name: String) -> void:
    if backrooms_room != null and is_instance_valid(backrooms_room):
        backrooms_room.queue_free()
    _loaded_cells.clear()
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

    if _hash_value(cell.x, cell.y, 71) % 5 == 0:
        _add_box(root, "CeilingLightPanel", Vector3(0, WALL_HEIGHT + 0.08, 0), Vector3(1.8, 0.12, 0.7), Color(0.95, 0.91, 0.72))
        if DisplayServer.get_name() != "headless":
            var ceiling_light := OmniLight3D.new()
            ceiling_light.name = "CeilingOmniLight"
            ceiling_light.position = Vector3(0, WALL_HEIGHT - 0.18, 0)
            ceiling_light.light_color = Color(1.0, 0.91, 0.72)
            ceiling_light.light_energy = 0.65
            ceiling_light.omni_range = 6.0
            ceiling_light.shadow_enabled = false
            root.add_child(ceiling_light)

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
        mesh_instance.material_override = material
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

func save_game() -> bool:
    var data := serialize_world_state()
    if data.is_empty():
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(data))
    file.close()
    _update_hud()
    return true

func load_game() -> bool:
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

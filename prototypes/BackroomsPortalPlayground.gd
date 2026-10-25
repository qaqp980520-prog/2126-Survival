extends Node3D

const Director = preload("res://systems/BackroomsPortalDirector.gd")
const PortalScene = preload("res://systems/BackroomsPortalVisual.tscn")
const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const SaveAdapter = preload("res://systems/SurvivalInventorySaveAdapter.gd")
const WORLD_BOUNDS := Rect2(-30.0, -30.0, 60.0, 60.0)
const WORLD_SEED: int = 20261026
const SAFE_DISTANCE: float = 7.0
const SAVE_PATH: String = "user://backrooms_playground_save.json"

@onready var player: CharacterBody3D = $Player
@onready var main_world: Node3D = $MainWorld
@onready var backrooms_world: Node3D = $BackroomsWorld
@onready var status_label: Label = $HUD/Status

var director
var bridge
var active_portal_visual: Area3D
var backrooms_room: Node3D
var in_backrooms: bool = false
var current_level: String = "Surface"
var _hud_elapsed: float = 0.0

func _ready() -> void:
    director = Director.new(WORLD_SEED, WORLD_BOUNDS, SAFE_DISTANCE)
    director.next_spawn_in = 2.0
    bridge = BridgeScript.new()
    bridge.name = "SurvivalWorldBridge"
    add_child(bridge)
    _build_surface()
    backrooms_world.visible = false
    _update_hud()

func _process(delta: float) -> void:
    if director == null:
        return
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

func _build_backrooms_room(level_name: String) -> void:
    if backrooms_room != null and is_instance_valid(backrooms_room):
        _set_collision_enabled(backrooms_room, false)
        backrooms_room.queue_free()
    backrooms_room = Node3D.new()
    backrooms_room.name = "Room_" + level_name.replace(" ", "")
    backrooms_world.add_child(backrooms_room)

    var floor_color := Color(0.54, 0.47, 0.24)
    var wall_color := Color(0.76, 0.69, 0.37)
    match level_name:
        "Level 1":
            floor_color = Color(0.19, 0.23, 0.25)
            wall_color = Color(0.35, 0.39, 0.41)
        "Level 2":
            floor_color = Color(0.22, 0.12, 0.09)
            wall_color = Color(0.39, 0.2, 0.14)
        "Level 3":
            floor_color = Color(0.1, 0.16, 0.23)
            wall_color = Color(0.22, 0.31, 0.42)

    _add_box(backrooms_room, "RoomFloor", Vector3(0, -0.5, 0), Vector3(60, 1, 60), floor_color)
    _add_box(backrooms_room, "NorthWall", Vector3(0, 2, -30), Vector3(60, 4, 1), wall_color)
    _add_box(backrooms_room, "SouthWall", Vector3(0, 2, 30), Vector3(60, 4, 1), wall_color)
    _add_box(backrooms_room, "WestWall", Vector3(-30, 2, 0), Vector3(1, 4, 60), wall_color)
    _add_box(backrooms_room, "EastWall", Vector3(30, 2, 0), Vector3(1, 4, 60), wall_color)
    if level_name == "Level 0":
        _add_box(backrooms_room, "OfficePartitionA", Vector3(-10, 1.8, -7), Vector3(1, 3.6, 24), wall_color)
        _add_box(backrooms_room, "OfficePartitionB", Vector3(7, 1.8, 8), Vector3(22, 3.6, 1), wall_color)
    elif level_name == "Level 1":
        _add_box(backrooms_room, "WarehouseDividerA", Vector3(-12, 2, -4), Vector3(1.5, 4, 22), wall_color)
        _add_box(backrooms_room, "WarehouseDividerB", Vector3(10, 2, 9), Vector3(20, 4, 1.5), wall_color)
    elif level_name == "Level 2":
        _add_box(backrooms_room, "PipeWallA", Vector3(-8, 2, -8), Vector3(1.2, 4, 26), wall_color)
        _add_box(backrooms_room, "PipeWallB", Vector3(8, 2, 8), Vector3(1.2, 4, 26), wall_color)
    else:
        _add_box(backrooms_room, "ServerAisleA", Vector3(-12, 2, 0), Vector3(1.2, 4, 24), wall_color)
        _add_box(backrooms_room, "ServerAisleB", Vector3(12, 2, 0), Vector3(1.2, 4, 24), wall_color)

    _set_collision_enabled(backrooms_room, true)

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
    _build_backrooms_room(current_level)
    player.global_position = Vector3.ZERO
    player.velocity = Vector3.ZERO
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
    if not WORLD_BOUNDS.has_point(Vector2(restored_position.x, restored_position.z)) or restored_position.y < -5.0 or restored_position.y > 20.0:
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
    status_label.text = "2126 SURVIVAL // KROLL PORTAL LAB\nZone: %s | Portal: %s | Carry: %.1f / %.1f kg\nG collect berries: %d | H drop one | T spawn test portal" % [current_level, portal_status, weight, limit, get_inventory_count("berries")]

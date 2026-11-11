extends SceneTree

const PlaygroundScene = preload("res://prototypes/BackroomsPortalPlayground.tscn")
const EntityDirector = preload("res://systems/BackroomsEntityDirector.gd")
const TARGET_LEVELS: Array[String] = ["Level 0", "Level 1", "Level 2", "Level 3", "Level 4", "Level 5"]

var failures: Array[String] = []
var watchdog: Timer

func _initialize() -> void:
    watchdog = Timer.new()
    watchdog.one_shot = true
    watchdog.wait_time = 25.0
    root.add_child(watchdog)
    watchdog.timeout.connect(_on_timeout)
    call_deferred("_start_watchdog")
    call_deferred("_run_integration_test")

func _start_watchdog() -> void:
    if is_instance_valid(watchdog) and watchdog.is_inside_tree():
        watchdog.start()

func _run_integration_test() -> void:
    var world = PlaygroundScene.instantiate()
    root.add_child(world)
    await process_frame
    _expect(str(world.call("get_current_level")) == "Surface", "starts in surface world")
    var player: Node = world.get_node("Player")
    var camera: Camera3D = player.get_node("Camera3D")
    _expect(camera.position.is_equal_approx(Vector3(0.0, 1.62, 0.0)), "starts in first-person camera mode")
    player.call("toggle_camera_mode")
    _expect(camera.position.is_equal_approx(Vector3(0.0, 2.3, 5.5)), "camera toggle switches to third-person mode")
    player.call("toggle_camera_mode")
    _expect(camera.position.is_equal_approx(Vector3(0.0, 1.62, 0.0)), "camera toggle returns to first-person mode")
    if DisplayServer.get_name() != "headless":
        var avatar: Node3D = player.get_node("AvatarVisual")
        _expect(not avatar.visible, "first-person mode hides the avatar to prevent camera clipping")
        player.call("toggle_camera_mode")
        _expect(avatar.visible, "third-person mode shows the avatar")
        player.call("toggle_camera_mode")
        _expect(not avatar.visible, "returning to first-person hides the avatar")
    _expect(bool(world.call("debug_collect_berries", 2)), "collects items through shared world bridge")
    _expect(bool(world.call("debug_spawn_portal")), "test shortcut spawns portal through director")
    await process_frame
    _expect(bool(world.call("has_active_portal")), "portal director has the spawned portal state")
    if DisplayServer.get_name() == "headless":
        _expect(world.get("active_portal_visual") == null, "headless mode keeps portal state without render-only visual nodes")
    else:
        _expect(world.get("active_portal_visual") != null, "graphical mode creates the portal visual")
    _expect(bool(world.call("debug_enter_active_portal")), "entering portal changes world")
    await process_frame
    var entered_level: String = str(world.call("get_current_level"))
    print("Backrooms integration entered: %s" % entered_level)
    _expect(TARGET_LEVELS.has(entered_level), "destination belongs to supported Level 0-5 list")
    _expect(_entity_visual_source_contract_is_present(), "Level 4 and Level 5 visual factories are wired into the playground")
    _expect(_headless_entity_visual_guard_is_respected(world), "headless Level 4 and Level 5 spawns avoid dummy-renderer mesh errors")
    var director: Object = world.get("director")
    director.set("next_spawn_in", 0.0)
    await process_frame
    _expect(not bool(world.call("has_active_portal")), "surface portal director does not spawn portals inside Backrooms")
    _expect(_maze_edges_are_symmetric(world), "maze edge openings match from both adjacent cells")
    _expect(_maze_region_is_connected(world), "procedural maze region remains connected to the origin")
    _expect(_maze_streaming_cell_boundaries(world), "streaming cell selection changes at actual half-cell boundaries")
    _expect(_window_wall_placement_contract_is_valid(world), "Level 1 windows choose a closed owned wall and sit flush with its inner face")
    _expect(not bool(world.call("is_surface_collision_enabled")), "hidden surface collisions are disabled")
    _expect(bool(world.call("is_backrooms_collision_enabled")), "active Backrooms room collisions are enabled")

    var saved: Dictionary = world.call("serialize_world_state")
    _expect(not saved.is_empty(), "serializes world envelope with portal state")
    _expect(bool(world.call("debug_collect_berries", 3)), "collects another stack after entering")
    _expect(int(world.call("get_inventory_count", "berries")) == 5, "inventory reflects bridge changes")
    _expect(bool(world.call("load_world_state_from_dictionary", saved)), "restores valid world envelope")
    _expect(int(world.call("get_inventory_count", "berries")) == 2, "load restores prior inventory count")
    _expect(str(world.call("get_current_level")) == entered_level, "load restores current Backrooms level")
    _expect(int(saved["backrooms_portal_state"].get("schema_version", 0)) == 1, "Backrooms portal save schema remains v1")
    for level_name in ["Level 4", "Level 5"]:
        var level_save: Dictionary = saved.duplicate(true)
        level_save["current_level"] = level_name
        var restored_level := bool(world.call("load_world_state_from_dictionary", level_save))
        _expect(restored_level, "%s save passes world-level validation" % level_name)
        if restored_level:
            _expect(str(world.call("get_current_level")) == level_name, "%s save restores the selected level" % level_name)
            await process_frame
    _expect(bool(world.call("load_world_state_from_dictionary", saved)), "restores original save after Level 4/5 compatibility checks")
    await process_frame
    _expect(str(world.call("get_current_level")) == entered_level, "restoring original save returns to entered level")

    var bridge: Node = world.get("bridge")
    _expect(bool(bridge.call("collect_world_item", "rock", 40)), "rock pickup updates shared inventory")
    _expect(is_equal_approx(float(player.call("get_effective_movement_multiplier")), 0.42), "super-heavy inventory slows player movement")
    _expect(not bool(player.call("can_jump_with_current_load")), "super-heavy inventory disables jumping")
    _expect(bool(bridge.call("drop_item", "rock", 15)), "dropping rocks updates shared inventory")
    _expect(is_equal_approx(float(player.call("get_effective_movement_multiplier")), 1.0), "dropping below carry limit immediately restores movement")
    _expect(bool(player.call("can_jump_with_current_load")), "dropping below super-heavy threshold immediately restores jumping")

    var before_count: int = int(world.call("get_inventory_count", "berries"))
    var before_level: String = str(world.call("get_current_level"))
    var invalid_save: Dictionary = saved.duplicate(true)
    invalid_save["backrooms_portal_state"]["schema_version"] = 99
    _expect(not bool(world.call("load_world_state_from_dictionary", invalid_save)), "rejects invalid portal schema")
    _expect(int(world.call("get_inventory_count", "berries")) == before_count, "invalid restore leaves inventory unchanged")
    _expect(str(world.call("get_current_level")) == before_level, "invalid restore leaves current level unchanged")

    var mismatched_save: Dictionary = world.call("serialize_world_state")
    var mismatched_portal_state: Dictionary = mismatched_save["backrooms_portal_state"]
    mismatched_portal_state["active_portal"] = {
        "id": int(mismatched_portal_state.get("portal_serial", 1)),
        "position": [0.0, 0.0]
    }
    mismatched_save["backrooms_portal_state"] = mismatched_portal_state
    _expect(not bool(world.call("load_world_state_from_dictionary", mismatched_save)), "rejects a surface portal saved inside Backrooms")
    _expect(int(world.call("get_inventory_count", "rock")) == 25, "mismatched save rejection preserves inventory state")
    world.call("debug_return_to_surface")
    await process_frame
    _expect(bool(world.call("is_surface_collision_enabled")), "surface collisions re-enable on return")
    _expect(not bool(world.call("is_backrooms_collision_enabled")), "Backrooms collisions disable on return")

    var exit_code: int = 0
    if failures.is_empty():
        print("Backrooms portal playground integration test passed.")
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        exit_code = 1
    world.queue_free()
    if is_instance_valid(watchdog):
        watchdog.stop()
        watchdog.queue_free()
    await process_frame
    quit(exit_code)

func _entity_visual_source_contract_is_present() -> bool:
    var source_file := FileAccess.open("res://prototypes/BackroomsPortalPlayground.gd", FileAccess.READ)
    if source_file == null:
        return false
    var source := source_file.get_as_text()
    var required_tokens: Array[String] = [
        "func _create_duller_entity",
        "func _create_deathmoth_entity",
        "root.position = Vector3(float(posmod(_hash_value(cell.x, cell.y, 2710), 5) - 2) * 0.58, 0.42,",
        "\"duller\":",
        "\"deathmoth\":",
        "root.set_meta(\"backrooms_entity_id\", \"duller\")",
        "root.set_meta(\"backrooms_entity_id\", \"deathmoth\")",
        "func _window_wall_direction_for_cell",
        "func _window_entity_transform_for_wall",
        "window_root.transform = _window_entity_transform_for_wall(wall_direction)",
        "window_root.set_meta(\"wall_direction\", wall_direction)"
    ]
    for token in required_tokens:
        if not source.contains(token):
            return false
    return true


func _headless_entity_visual_guard_is_respected(world: Node) -> bool:
    if DisplayServer.get_name() != "headless":
        return true
    var room := world.get("backrooms_room") as Node3D
    if room == null or _contains_mesh_instance(room):
        return false

    var original_level := str(world.get("current_level"))
    var checks := [
        {"level": "Level 4", "entity": "duller"},
        {"level": "Level 5", "entity": "deathmoth"}
    ]
    for check in checks:
        var level_name: String = str(check["level"])
        var entity_id: String = str(check["entity"])
        var found_cell := Vector2i.ZERO
        var found := false
        for z in range(-40, 41):
            for x in range(-40, 41):
                var candidate := Vector2i(x, z)
                if EntityDirector.get_cell_spawns(level_name, candidate).has(entity_id):
                    found_cell = candidate
                    found = true
                    break
            if found:
                break
        if not found:
            world.set("current_level", original_level)
            return false

        world.set("current_level", level_name)
        var cell_root := Node3D.new()
        room.add_child(cell_root)
        world.call("_spawn_level_entities_for_cell", cell_root, found_cell)
        var contains_mesh := _contains_mesh_instance(cell_root)
        cell_root.queue_free()
        if contains_mesh:
            world.set("current_level", original_level)
            return false

    world.set("current_level", original_level)
    return true


func _contains_mesh_instance(node: Node) -> bool:
    if node is MeshInstance3D:
        return true
    for child in node.get_children():
        if _contains_mesh_instance(child):
            return true
    return false



func _window_wall_placement_contract_is_valid(world: Node) -> bool:
    var north := Vector2i(0, -1)
    var west := Vector2i(-1, 0)
    var saw_north := false
    var saw_west := false
    for z in range(-40, 41):
        for x in range(-40, 41):
            var cell := Vector2i(x, z)
            var north_closed: bool = not bool(world.call("_edge_is_open", cell, north))
            var west_closed: bool = not bool(world.call("_edge_is_open", cell, west))
            var direction: Vector2i = world.call("_window_wall_direction_for_cell", cell)
            var repeated_direction: Vector2i = world.call("_window_wall_direction_for_cell", cell)
            if direction != repeated_direction:
                return false
            if direction == Vector2i.ZERO:
                if north_closed or west_closed:
                    return false
                continue

            var expected_position := Vector3.ZERO
            var expected_yaw: float = 0.0
            if direction == north and north_closed:
                expected_position = Vector3(0.0, 1.85, -4.0 + 0.19)
                saw_north = true
            elif direction == west and west_closed:
                expected_position = Vector3(-4.0 + 0.19, 1.85, 0.0)
                expected_yaw = PI * 0.5
                saw_west = true
            else:
                return false

            var transform: Transform3D = world.call("_window_entity_transform_for_wall", direction)
            if not transform.origin.is_equal_approx(expected_position):
                return false
            var expected_normal := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, expected_yaw)
            if not transform.basis.z.is_equal_approx(expected_normal):
                return false

            var frame_wall_edge: float = transform.origin.z - 0.08 if direction == north else transform.origin.x - 0.08
            if not is_equal_approx(frame_wall_edge, -4.0 + 0.11):
                return false
    return saw_north and saw_west

func _maze_edges_are_symmetric(world: Node) -> bool:
    var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    for z in range(-3, 4):
        for x in range(-3, 4):
            var cell := Vector2i(x, z)
            for direction in directions:
                var neighbor := cell + direction
                var from_cell := bool(world.call("_edge_is_open", cell, direction))
                var from_neighbor := bool(world.call("_edge_is_open", neighbor, -direction))
                if from_cell != from_neighbor:
                    return false
    return true

func _maze_region_is_connected(world: Node) -> bool:
    var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    var visited: Dictionary = {Vector2i.ZERO: true}
    var queue: Array[Vector2i] = [Vector2i.ZERO]
    while not queue.is_empty():
        var cell: Vector2i = queue.pop_front()
        for direction in directions:
            var neighbor: Vector2i = cell + direction
            if abs(neighbor.x) > 3 or abs(neighbor.y) > 3 or visited.has(neighbor):
                continue
            if bool(world.call("_edge_is_open", cell, direction)):
                visited[neighbor] = true
                queue.append(neighbor)
    return visited.size() == 49

func _maze_streaming_cell_boundaries(world: Node) -> bool:
    var cases: Array = [
        [Vector3(3.99, 0.0, 0.0), Vector2i(0, 0)],
        [Vector3(4.01, 0.0, 0.0), Vector2i(1, 0)],
        [Vector3(-3.99, 0.0, 0.0), Vector2i(0, 0)],
        [Vector3(-4.01, 0.0, 0.0), Vector2i(-1, 0)],
        [Vector3(0.0, 0.0, 4.01), Vector2i(0, 1)],
        [Vector3(0.0, 0.0, -4.01), Vector2i(0, -1)]
    ]
    for entry in cases:
        var actual: Vector2i = world.call("_maze_cell_for_position", entry[0])
        if actual != entry[1]:
            return false
    return true

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)

func _on_timeout() -> void:
    push_error("Backrooms portal playground integration test timed out.")
    quit(2)

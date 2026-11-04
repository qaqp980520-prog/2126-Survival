extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for level_index in range(Rules.level_count()):
        var scene: Node = load("res://main.tscn").instantiate()
        root.add_child(scene)
        await process_frame
        scene.set("_state", Rules.new_state(level_index))
        var level: Dictionary = Rules.level_at(level_index)
        var next_hazard: int = 0
        var completed: bool = false
        for frame in range(900):
            var state: Dictionary = scene.call("get_game_state")
            var position: Vector2 = state["player_position"]
            var player_bounds: Rect2 = Rules.player_rect(position)
            var interact_pressed: bool = false
            if not bool(state["carrying"]) and Rules.rects_overlap(player_bounds, state["package_rect"]):
                interact_pressed = true
            elif bool(state["carrying"]) and Rules.rects_overlap(player_bounds, state["exit_rect"]):
                interact_pressed = true

            var jump_pressed: bool = false
            var hazards: Array = level["hazards"]
            if bool(state["carrying"]) and next_hazard < hazards.size():
                var hazard: Rect2 = hazards[next_hazard]
                if bool(state["grounded"]) and position.x >= hazard.position.x - 130.0:
                    jump_pressed = true
                    next_hazard += 1

            scene.call("_simulate_step", 1.0 / 60.0, 1, jump_pressed, interact_pressed)
            state = scene.call("get_game_state")
            if int(state["lives"]) < 3:
                _expect(false, "route %d can cross every vent without losing a suit charge" % (level_index + 1))
                break
            if str(state["status"]) == "complete":
                completed = true
                break

        var final_state: Dictionary = scene.call("get_game_state")
        _expect(completed, "route %d is completable through actual movement and jumps" % (level_index + 1))
        _expect(int(final_state["lives"]) == 3, "route %d preserves all suit charges on the reference route" % (level_index + 1))
        _expect(int(final_state["campaign_score"]) == 100, "route %d awards the on-time completion score" % (level_index + 1))
        scene.queue_free()
        await process_frame

    if failures.is_empty():
        print("KROLL Moonbase Courier route simulation passed.")
        quit(0)
    else:
        push_error("KROLL Moonbase Courier route simulation failures: " + str(failures))
        quit(1)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures.append(message)
        push_error("FAIL: " + message)

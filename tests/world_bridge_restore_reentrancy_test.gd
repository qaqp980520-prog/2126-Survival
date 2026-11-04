extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")

class ReentrantInventory extends RefCounted:
    var bridge: Node
    var replacement: RefCounted
    var counts: Dictionary = {"meat": 3}
    var game_day: int = 4
    var load_calls: int = 0
    var nested_restore_accepted: bool = false
    var nested_collect_accepted: bool = false
    var bind_replacement_accepted: bool = false
    var direct_rebind_blocked: bool = false

    func add_item(_item_id: String, _amount: int = 1) -> int:
        return 0
    func remove_item(_item_id: String, _amount: int = 1) -> int:
        return 0
    func total_weight_kg() -> float:
        return float(counts.get("meat", 0)) * 0.75
    func carry_limit_kg() -> float:
        return 65.0
    func movement_multiplier() -> float:
        return 1.0
    func can_jump() -> bool:
        return true
    func is_overweight() -> bool:
        return false
    func is_super_heavy() -> bool:
        return false
    func to_save_dict() -> Dictionary:
        return {"schema_version": 1, "game_day": game_day, "inventory": counts.duplicate(true)}
    func load_save_dict(data: Dictionary) -> bool:
        load_calls += 1
        if load_calls == 1:
            nested_restore_accepted = bool(bridge.call("restore_inventory", data))
            nested_collect_accepted = bool(bridge.call("collect_world_item", "meat", 1))
            bind_replacement_accepted = bool(bridge.call("bind_inventory", replacement))
            bridge.set("inventory", replacement)
            direct_rebind_blocked = bridge.get("inventory") == null
        counts = data.get("inventory", {}).duplicate(true)
        game_day = int(data.get("game_day", 1))
        return true

class RefreshListener extends Node:
    var count: int = 0
    func on_changed(_summary: Dictionary) -> void:
        count += 1

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var bridge: Node = BridgeScript.new()
    root.add_child(bridge)
    await process_frame
    var fixture := ReentrantInventory.new()
    fixture.bridge = bridge
    fixture.replacement = ReentrantInventory.new()
    _expect(bool(bridge.call("bind_inventory", fixture)), "reentrant fixture satisfies the inventory contract")
    var listener := RefreshListener.new()
    root.add_child(listener)
    bridge.inventory_changed.connect(Callable(listener, "on_changed"))

    var payload := {"schema_version": 1, "game_day": 9, "inventory": {"meat": 40}}
    _expect(bool(bridge.call("restore_inventory", payload)), "outer restore succeeds despite rejected reentrant attempts")
    _expect(fixture.load_calls == 1, "nested restore never invokes the custom loader a second time")
    _expect(not fixture.nested_restore_accepted, "nested restore is rejected while a restore transaction is active")
    _expect(not fixture.nested_collect_accepted, "collect mutation is rejected during the restore callback")
    _expect(not fixture.bind_replacement_accepted, "bind_inventory cannot replace the active inventory during restore")
    _expect(fixture.direct_rebind_blocked and bridge.get("inventory") == fixture, "direct inventory property assignment is blocked during restore")
    _expect(fixture.counts == {"meat": 40} and fixture.game_day == 9, "outer restore applies only its requested snapshot")
    _expect(listener.count == 1, "only the completed outer restore emits inventory_changed")

    bridge.queue_free()
    listener.queue_free()
    await process_frame
    if failures.is_empty():
        print("World bridge restore reentrancy tests passed.")
        quit(0)
    else:
        push_error("World bridge restore reentrancy failures: " + str(failures))
        quit(1)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures.append(message)
        push_error("FAIL: " + message)

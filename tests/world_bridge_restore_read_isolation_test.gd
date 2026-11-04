extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")

class ReadProbeInventory extends RefCounted:
    var bridge: Node
    var counts: Dictionary = {"meat": 3}
    var game_day: int = 4
    var load_calls: int = 0
    var to_save_calls: int = 0
    var calls_at_reentrant_probe: int = -1
    var blocked_inventory_snapshot: Dictionary = {}
    var blocked_world_snapshot: Dictionary = {}
    var count_during_restore: int = -1
    var summary_during_restore: Dictionary = {}
    var inventory_reference_hidden: bool = false

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
        to_save_calls += 1
        return {"schema_version": 1, "game_day": game_day, "inventory": counts.duplicate(true)}
    func load_save_dict(data: Dictionary) -> bool:
        load_calls += 1
        if load_calls == 1:
            # Deliberately expose a partial state before asking the bridge to read it.
            counts = {"meat": 999}
            game_day = 99
            calls_at_reentrant_probe = to_save_calls
            inventory_reference_hidden = bridge.get("inventory") == null
            blocked_inventory_snapshot = bridge.call("serialize_inventory")
            blocked_world_snapshot = bridge.call("serialize_world_save", {"version": 2, "player": {}})
            count_during_restore = int(bridge.call("get_item_count", "meat"))
            summary_during_restore = bridge.call("get_summary")
            calls_at_reentrant_probe = to_save_calls
        counts = data.get("inventory", {}).duplicate(true)
        game_day = int(data.get("game_day", 1))
        return true

class SignalReadListener extends Node:
    var bridge: Node
    var count: int = 0
    var snapshot: Dictionary = {}
    func on_changed(_summary: Dictionary) -> void:
        count += 1
        snapshot = bridge.call("serialize_inventory")

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var bridge: Node = BridgeScript.new()
    root.add_child(bridge)
    await process_frame

    var fixture := ReadProbeInventory.new()
    fixture.bridge = bridge
    _expect(bool(bridge.call("bind_inventory", fixture)), "read-probe custom inventory satisfies the bridge contract")

    var listener := SignalReadListener.new()
    listener.bridge = bridge
    root.add_child(listener)
    bridge.inventory_changed.connect(Callable(listener, "on_changed"))

    var payload := {"schema_version": 1, "game_day": 9, "inventory": {"meat": 40}}
    _expect(bool(bridge.call("restore_inventory", payload)), "outer restore completes after reentrant reads are blocked")
    _expect(not bool(fixture.blocked_inventory_snapshot.get("ok", true)), "serialize_inventory returns an explicit failure during restore")
    _expect(str(fixture.blocked_inventory_snapshot.get("error", "")) == "inventory_restore_in_progress", "inventory snapshot failure identifies the active transaction")
    _expect(not bool(fixture.blocked_world_snapshot.get("ok", true)), "serialize_world_save refuses an intermediate snapshot")
    _expect(str(fixture.blocked_world_snapshot.get("error", "")) == "inventory_restore_in_progress", "world-save failure identifies the active transaction")
    _expect(fixture.inventory_reference_hidden, "public inventory getter hides the partially restored object")
    _expect(fixture.count_during_restore == 0, "get_item_count fails closed during restore")
    _expect(float(fixture.summary_during_restore.get("weight_kg", -1.0)) == 0.0, "get_summary does not expose partial weight")
    _expect(fixture.calls_at_reentrant_probe == 1, "reentrant read APIs do not call the custom serializer during restore")
    _expect(fixture.counts == {"meat": 40} and fixture.game_day == 9, "outer restore applies the requested final snapshot")
    _expect(bridge.get("inventory") == fixture, "public inventory getter is restored after the transaction")
    _expect(listener.count == 1, "successful outer restore emits one notification after releasing the lock")
    _expect(listener.snapshot.get("inventory", {}).get("meat", -1) == 40, "notification listeners can serialize the completed snapshot")

    var after_snapshot: Dictionary = bridge.call("serialize_inventory")
    _expect(after_snapshot.get("inventory", {}).get("meat", -1) == 40, "normal inventory serialization resumes after restore")
    var after_world: Dictionary = bridge.call("serialize_world_save", {"version": 2, "player": {}})
    _expect(bool(after_world.get("ok", false)), "normal world-save serialization resumes after restore")

    bridge.queue_free()
    listener.queue_free()
    await process_frame
    if failures.is_empty():
        print("World bridge restore read isolation tests passed.")
        quit(0)
    else:
        push_error("World bridge restore read isolation failures: " + str(failures))
        quit(1)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures.append(message)
        push_error("FAIL: " + message)

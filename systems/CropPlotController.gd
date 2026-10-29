extends Node
class_name CropPlotController

## World-facing adapter for stable crop IDs. CropRegistry remains the source of truth.
const MAX_BATCH_ELAPSED_SECONDS := 86400.0
var registry: Node

func bind_registry(value: Node) -> bool:
    if value == null:
        return false
    for method_name in ["register_crop", "get_crop", "to_save_dict", "restore_save_dict", "water_crop", "advance_growth", "advance_to_time", "harvest_crop", "remove_crop"]:
        if not value.has_method(method_name):
            return false
    registry = value
    return true

func plant_crop(stable_id: String, crop_id: String, initial_moisture: float = 40.0, now_unix: int = -1) -> bool:
    if registry == null or not is_finite(initial_moisture) or initial_moisture < 0.0 or initial_moisture > 100.0:
        return false
    var timestamp: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
    return bool(registry.call("register_crop", stable_id, crop_id, 0, 0.0, initial_moisture, timestamp, 0))

func water_crop(stable_id: String, amount: float, now_unix: int = -1) -> bool:
    if registry == null:
        return false
    return bool(registry.call("water_crop", stable_id, amount, now_unix))

func advance_crop(stable_id: String, elapsed_seconds: float, now_unix: int = -1) -> bool:
    if registry == null:
        return false
    return bool(registry.call("advance_growth", stable_id, elapsed_seconds, now_unix))

func advance_crop_to_time(stable_id: String, now_unix: int = -1) -> bool:
    if registry == null:
        return false
    return bool(registry.call("advance_to_time", stable_id, now_unix))

## Advance multiple plots atomically. If any tick fails, restore the complete prior registry.
func advance_crops(stable_ids: Array, elapsed_seconds: float, now_unix: int = -1) -> Dictionary:
    if registry == null or stable_ids.is_empty():
        return _result(false, "empty_batch", [])
    if not is_finite(elapsed_seconds) or elapsed_seconds <= 0.0 or elapsed_seconds > MAX_BATCH_ELAPSED_SECONDS:
        return _result(false, "invalid_elapsed", [])
    var seen: Dictionary = {}
    var ids: Array[String] = []
    for value in stable_ids:
        if not (value is String) or str(value).is_empty() or seen.has(value):
            return _result(false, "invalid_or_duplicate_id", [])
        var stable_id: String = value
        var existing: Dictionary = registry.call("get_crop", stable_id)
        if existing.is_empty():
            return _result(false, "unknown_crop", [])
        seen[stable_id] = true
        ids.append(stable_id)
    var timestamp: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
    var snapshot: Dictionary = registry.call("to_save_dict")
    for stable_id in ids:
        if not bool(registry.call("advance_growth", stable_id, elapsed_seconds, timestamp)):
            var restored: bool = bool(registry.call("restore_save_dict", snapshot))
            return _result(false, "tick_failed_rollback_%s" % str(restored), [])
    return _result(true, "advanced", ids)

## Catch up every existing crop in a chunk as one transaction. If the wall clock moved
## backwards for any record, leave the entire batch untouched rather than partially advancing it.
func advance_crops_to_time(stable_ids: Array, now_unix: int = -1) -> Dictionary:
    if registry == null:
        return _result(false, "unbound", [])
    if stable_ids.is_empty():
        return _result(true, "no_crops", [])
    var seen: Dictionary = {}
    var ids: Array[String] = []
    var latest_record_time: int = 0
    for value in stable_ids:
        if not (value is String) or str(value).is_empty() or seen.has(value):
            return _result(false, "invalid_or_duplicate_id", [])
        var stable_id: String = value
        var record: Dictionary = registry.call("get_crop", stable_id)
        if record.is_empty():
            return _result(false, "unknown_crop", [])
        latest_record_time = maxi(latest_record_time, int(record.get("last_updated_unix", 0)))
        seen[stable_id] = true
        ids.append(stable_id)
    var timestamp: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
    if timestamp < latest_record_time:
        return _result(true, "clock_rollback_noop", [])
    var snapshot: Dictionary = registry.call("to_save_dict")
    for stable_id in ids:
        if not bool(registry.call("advance_to_time", stable_id, timestamp)):
            var restored: bool = bool(registry.call("restore_save_dict", snapshot))
            return _result(false, "catch_up_failed_rollback_%s" % str(restored), [])
    return _result(true, "caught_up", ids)

func harvest_crop(stable_id: String, now_unix: int = -1) -> Dictionary:
    if registry == null:
        return {}
    var receipt: Dictionary = registry.call("harvest_crop", stable_id, now_unix)
    return receipt

func get_crop(stable_id: String) -> Dictionary:
    if registry == null:
        return {}
    var record: Dictionary = registry.call("get_crop", stable_id)
    return record

func remove_crop(stable_id: String) -> bool:
    if registry == null:
        return false
    return bool(registry.call("remove_crop", stable_id))

func to_save_dict() -> Dictionary:
    if registry == null:
        return {}
    return registry.call("to_save_dict")

func restore_save_dict(payload: Dictionary) -> bool:
    if registry == null:
        return false
    return bool(registry.call("restore_save_dict", payload))

func _result(ok: bool, reason: String, ids: Array) -> Dictionary:
    return {"ok": ok, "reason": reason, "advanced_ids": ids.duplicate()}

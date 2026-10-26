extends Node
class_name MineralVeinRegistry

## Stable-ID registry for mineral veins across save/load and streamed chunk boundaries.
## The chunk/world owner should register each vein before restoring its saved state.
const MiningNode = preload("res://systems/MineralMiningNode.gd")

@export var auto_apply_elapsed_time_on_restore: bool = true
var _veins: Dictionary = {}

func register_vein(stable_id: String, vein: Node) -> bool:
	var key := stable_id.strip_edges()
	if key.is_empty() or vein == null or not (vein is MiningNode):
		return false
	if _veins.has(key) and is_instance_valid(_veins[key]) and _veins[key] != vein:
		return false
	_veins[key] = vein
	return true

func unregister_vein(stable_id: String, expected_vein: Node = null) -> bool:
	var key := stable_id.strip_edges()
	if not _veins.has(key):
		return false
	if expected_vein != null and _veins[key] != expected_vein:
		return false
	_veins.erase(key)
	return true

func get_registered_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in _veins.keys():
		if is_instance_valid(_veins[key]):
			ids.append(str(key))
	ids.sort()
	return ids

func to_save_dict() -> Dictionary:
	var saved_veins: Dictionary = {}
	for key in get_registered_ids():
		saved_veins[key] = _veins[key].to_save_dict()
	return {"schema_version": 1, "veins": saved_veins}

## Validate every record on temporary nodes first, so bad data never partially mutates live veins.
## The world/chunk owner controls which streamed chunks are currently registered.
func restore_save_dict(data: Dictionary, now_unix: int = -1) -> bool:
	var schema: Variant = data.get("schema_version", null)
	var records: Variant = data.get("veins", null)
	if not (schema is int) or int(schema) != 1 or not (records is Dictionary):
		return false
	for key in records.keys():
		if not (key is String) or not _veins.has(key) or not is_instance_valid(_veins[key]):
			return false
		var record: Variant = records[key]
		if not (record is Dictionary):
			return false
		var probe = MiningNode.new()
		probe.mineral_id = _veins[key].mineral_id
		var valid: bool = probe.load_save_dict(record, now_unix)
		probe.free()
		if not valid:
			return false
	for key in records.keys():
		if not _veins[key].load_save_dict(records[key], now_unix):
			return false
		if auto_apply_elapsed_time_on_restore:
			_veins[key].apply_elapsed_regeneration(now_unix)
	return true

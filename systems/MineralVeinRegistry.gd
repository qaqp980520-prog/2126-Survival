extends Node
class_name MineralVeinRegistry

## Stable-ID registry for mineral veins across save/load and streamed chunk boundaries.
## Unloaded records remain in the registry until the world save is replaced.
const MiningNode = preload("res://systems/MineralMiningNode.gd")
const Catalog = preload("res://systems/MineralCatalog.gd")

@export var auto_apply_elapsed_time_on_restore: bool = true
var _veins: Dictionary = {} # stable ID -> currently loaded MineralMiningNode
var _saved_records: Dictionary = {} # stable ID -> schema-v2 record, including unloaded chunks

func register_vein(stable_id: String, vein: Node, now_unix: int = -1) -> bool:
	var key := stable_id.strip_edges()
	if key.is_empty() or key != stable_id or vein == null or not (vein is MiningNode):
		return false
	var mining_vein: Variant = vein
	if _veins.has(key) and is_instance_valid(_veins[key]):
		if _veins[key] != mining_vein:
			return false
		# Idempotent registration of the same live node must not reload a stale snapshot.
		return true
	var now: int = now_unix if now_unix >= 0 else Time.get_unix_time_from_system()
	if now <= 0 or not Catalog.has_mineral(mining_vein.mineral_id):
		return false

	if _saved_records.has(key):
		var saved_record: Variant = _saved_records[key]
		if not (saved_record is Dictionary) or not _validate_record(key, saved_record, mining_vein.mineral_id, now):
			return false
		if not mining_vein.load_save_dict(saved_record, now, false):
			return false
		if auto_apply_elapsed_time_on_restore:
			mining_vein.apply_elapsed_regeneration(now)
		else:
			# Suppress offline catch-up even after _process() resumes on the next frame.
			mining_vein.last_regen_unix = now
	else:
		if mining_vein.last_regen_unix <= 0:
			mining_vein.last_regen_unix = now
		var initial_record: Dictionary = mining_vein.to_save_dict()
		if not _validate_record(key, initial_record, mining_vein.mineral_id, now):
			return false
		_saved_records[key] = initial_record.duplicate(true)

	_veins[key] = mining_vein
	_saved_records[key] = mining_vein.to_save_dict()
	return true

## Capture the final state before a chunk releases its live node. The record remains
## serializable and can restore a new node with the same stable ID later.
func unregister_vein(stable_id: String, expected_vein: Node = null, now_unix: int = -1) -> bool:
	var key := stable_id.strip_edges()
	if not _veins.has(key) or not is_instance_valid(_veins[key]):
		return false
	var vein: Variant = _veins[key]
	if vein == null or (expected_vein != null and vein != expected_vein):
		return false
	var now: int = now_unix if now_unix >= 0 else Time.get_unix_time_from_system()
	var current_record: Dictionary = vein.to_save_dict()
	if not _validate_record(key, current_record, vein.mineral_id, now):
		return false
	vein.apply_elapsed_regeneration(now)
	_saved_records[key] = vein.to_save_dict()
	_veins.erase(key)
	return true

func get_registered_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in _veins.keys():
		if is_instance_valid(_veins[key]):
			ids.append(str(key))
	ids.sort()
	return ids

## Includes IDs belonging to currently unloaded chunks.
func get_saved_ids() -> PackedStringArray:
	var unique_ids: Dictionary = {}
	for key in _saved_records.keys():
		unique_ids[str(key)] = true
	for key in get_registered_ids():
		unique_ids[key] = true
	var ids := PackedStringArray()
	for key in unique_ids.keys():
		ids.append(str(key))
	ids.sort()
	return ids

func to_save_dict() -> Dictionary:
	# Refresh loaded records without forcing time advancement; restore applies elapsed
	# time once using the caller's clock, keeping deterministic tests and save behavior.
	for key in get_registered_ids():
		_saved_records[key] = _veins[key].to_save_dict()
	var saved_veins: Dictionary = {}
	for key in get_saved_ids():
		if _saved_records.has(key):
			saved_veins[key] = _saved_records[key].duplicate(true)
	return {"schema_version": 1, "veins": saved_veins}

## Validate the complete payload before changing live nodes or stored records.
## Valid records for IDs not currently loaded are retained for later chunk registration.
func validate_save_dict(data: Dictionary, now_unix: int = -1) -> bool:
	return bool(_prepare_restore(data, now_unix).get("ok", false))

## Validate the full payload before changing live nodes or stored records.
## Records for currently unloaded chunks remain available for later registration.
func restore_save_dict(data: Dictionary, now_unix: int = -1) -> bool:
	var prepared := _prepare_restore(data, now_unix)
	if not bool(prepared.get("ok", false)):
		return false
	var next_records: Dictionary = prepared["records"]
	var now: int = int(prepared["now"])

	# Prevalidation above guarantees these loads use the same mineral and valid fields.
	for key in get_registered_ids():
		if next_records.has(key):
			if not _veins[key].load_save_dict(next_records[key], now, false):
				return false
			if auto_apply_elapsed_time_on_restore:
				_veins[key].apply_elapsed_regeneration(now)
			else:
				# Reset the clock so the node's next _process() cannot apply skipped offline time.
				_veins[key].last_regen_unix = now
	_saved_records = next_records
	for key in get_registered_ids():
		_saved_records[key] = _veins[key].to_save_dict()
	return true

## Restore a transaction snapshot exactly, without offline regeneration or clock advancement.
## Use only for rolling back an in-flight chunk transaction; normal world loads use restore_save_dict().
func restore_snapshot_exact(data: Dictionary, now_unix: int = -1) -> bool:
	var prepared := _prepare_restore(data, now_unix)
	if not bool(prepared.get("ok", false)):
		return false
	var next_records: Dictionary = prepared["records"]
	var now: int = int(prepared["now"])
	for key in get_registered_ids():
		if next_records.has(key):
			var record: Dictionary = next_records[key]
			if not _veins[key].load_save_dict(record, now, false):
				return false
	_saved_records = next_records
	for key in get_registered_ids():
		_saved_records[key] = _veins[key].to_save_dict()
	return true

func _prepare_restore(data: Dictionary, now_unix: int = -1) -> Dictionary:
	var schema: Variant = data.get("schema_version", null)
	var records: Variant = data.get("veins", null)
	if not (schema is int or schema is float) or not is_finite(float(schema)) or float(schema) != 1.0 or not (records is Dictionary):
		return {}
	var now: int = now_unix if now_unix >= 0 else Time.get_unix_time_from_system()
	if now <= 0:
		return {}

	var next_records: Dictionary = {}
	for raw_key in records.keys():
		if not (raw_key is String):
			return {}
		var key: String = raw_key
		if key.is_empty() or key != key.strip_edges():
			return {}
		var record: Variant = records[raw_key]
		if not (record is Dictionary):
			return {}
		var expected_mineral := ""
		if _veins.has(key) and is_instance_valid(_veins[key]):
			expected_mineral = _veins[key].mineral_id
		if not _validate_record(key, record, expected_mineral, now):
			return {}
		next_records[key] = record.duplicate(true)

	# New live veins omitted from an older/partial world save keep their current state.
	# Existing unloaded records are authoritative only when present in the payload.
	for key in get_registered_ids():
		if not next_records.has(key):
			var current_record: Dictionary = _veins[key].to_save_dict()
			if not _validate_record(key, current_record, _veins[key].mineral_id, now):
				return {}
			next_records[key] = current_record.duplicate(true)
	return {"ok": true, "records": next_records, "now": now}

func _validate_record(stable_id: String, record: Dictionary, expected_mineral_id: String = "", now_unix: int = -1) -> bool:
	if stable_id.is_empty() or stable_id != stable_id.strip_edges():
		return false
	var mineral_value: Variant = record.get("mineral_id", null)
	if not (mineral_value is String) or not Catalog.has_mineral(str(mineral_value)):
		return false
	if not expected_mineral_id.is_empty() and str(mineral_value) != expected_mineral_id:
		return false
	var probe = MiningNode.new()
	probe.mineral_id = str(mineral_value)
	var valid: bool = probe.load_save_dict(record, now_unix, false)
	probe.free()
	return valid

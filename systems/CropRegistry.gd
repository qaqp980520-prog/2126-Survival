extends Node
class_name CropRegistry

## Data-only stable-ID registry for crop state across saves and unloaded chunks.
## It deliberately does not claim to implement crop visuals, planting, or growth simulation.
const SCHEMA_VERSION := 1
const SUPPORTED_CROP_IDS := ["wheat", "corn", "tomato", "potato", "carrot"]
const MIN_STAGE := 0
const MAX_STAGE := 4

var _records: Dictionary = {}

func register_crop(stable_id: String, crop_id: String, growth_stage: int, growth_progress: float, moisture: float, now_unix: int = -1, harvest_count: int = 0) -> bool:
	if not _is_valid_stable_id(stable_id) or _records.has(stable_id):
		return false
	var now: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var record := {
		"crop_id": crop_id,
		"growth_stage": growth_stage,
		"growth_progress": growth_progress,
		"moisture": moisture,
		"last_updated_unix": now,
		"harvest_count": harvest_count
	}
	if not _is_valid_record(stable_id, record):
		return false
	_records[stable_id] = record
	return true

func update_crop(stable_id: String, growth_stage: int, growth_progress: float, moisture: float, now_unix: int = -1, harvest_count: int = -1) -> bool:
	if not _records.has(stable_id):
		return false
	var candidate: Dictionary = _records[stable_id].duplicate(true)
	candidate["growth_stage"] = growth_stage
	candidate["growth_progress"] = growth_progress
	candidate["moisture"] = moisture
	candidate["last_updated_unix"] = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	if harvest_count >= 0:
		candidate["harvest_count"] = harvest_count
	if not _is_valid_record(stable_id, candidate):
		return false
	_records[stable_id] = candidate
	return true

func remove_crop(stable_id: String) -> bool:
	if not _records.has(stable_id):
		return false
	_records.erase(stable_id)
	return true

func get_crop(stable_id: String) -> Dictionary:
	if not _records.has(stable_id):
		return {}
	return _records[stable_id].duplicate(true)

func get_saved_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in _records.keys():
		ids.append(str(key))
	ids.sort()
	return ids

func to_save_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "crops": _records.duplicate(true)}

func validate_save_dict(data: Dictionary) -> bool:
	return bool(_prepare_restore(data).get("ok", false))

## Validate all records before replacing the current dictionary.
func restore_save_dict(data: Dictionary) -> bool:
	var prepared: Dictionary = _prepare_restore(data)
	if not bool(prepared.get("ok", false)):
		return false
	_records = prepared["records"]
	return true

func _prepare_restore(data: Dictionary) -> Dictionary:
	var raw_schema: Variant = data.get("schema_version", null)
	if not _is_integer_value(raw_schema) or int(raw_schema) != SCHEMA_VERSION:
		return {"ok": false, "error": "unsupported_schema"}
	var raw_records: Variant = data.get("crops", null)
	if not (raw_records is Dictionary):
		return {"ok": false, "error": "invalid_records"}
	var prepared: Dictionary = {}
	for raw_id in raw_records.keys():
		if not (raw_id is String):
			return {"ok": false, "error": "invalid_stable_id"}
		var stable_id: String = raw_id
		var raw_record: Variant = raw_records[raw_id]
		if not (raw_record is Dictionary) or not _is_valid_record(stable_id, raw_record):
			return {"ok": false, "error": "invalid_crop_record"}
		prepared[stable_id] = raw_record.duplicate(true)
	return {"ok": true, "records": prepared}

func _is_valid_record(stable_id: String, record: Dictionary) -> bool:
	if not _is_valid_stable_id(stable_id):
		return false
	var crop_id: Variant = record.get("crop_id", null)
	if not (crop_id is String) or not SUPPORTED_CROP_IDS.has(crop_id):
		return false
	var stage: Variant = record.get("growth_stage", null)
	if not _is_integer_value(stage) or int(stage) < MIN_STAGE or int(stage) > MAX_STAGE:
		return false
	var progress: Variant = record.get("growth_progress", null)
	if not (progress is int or progress is float) or not is_finite(float(progress)) or float(progress) < 0.0 or float(progress) > 1.0:
		return false
	var moisture: Variant = record.get("moisture", null)
	if not (moisture is int or moisture is float) or not is_finite(float(moisture)) or float(moisture) < 0.0 or float(moisture) > 100.0:
		return false
	var last_updated: Variant = record.get("last_updated_unix", null)
	if not _is_integer_value(last_updated) or int(last_updated) <= 0:
		return false
	var harvest_count: Variant = record.get("harvest_count", null)
	if not _is_integer_value(harvest_count) or int(harvest_count) < 0:
		return false
	return true

func _is_valid_stable_id(stable_id: String) -> bool:
	return not stable_id.is_empty() and stable_id == stable_id.strip_edges() and stable_id.length() <= 160 and stable_id.find("/") > 0 and not stable_id.contains(" ") and not stable_id.contains("\t") and not stable_id.contains("\n") and not stable_id.contains("..")

func _is_integer_value(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(float(value)) and floorf(float(value)) == float(value)
	return false

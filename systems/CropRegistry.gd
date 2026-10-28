extends Node
class_name CropRegistry

## Stable-ID crop registry with deterministic watering, growth and harvest lifecycle.
## Scene visuals and world interaction remain the responsibility of a world controller.
const SCHEMA_VERSION := 1
const SUPPORTED_CROP_IDS := ["wheat", "corn", "tomato", "potato", "carrot"]
const MIN_STAGE := 0
const MAX_STAGE := 4
const GROWTH_SECONDS_PER_STAGE := 120.0
const MOISTURE_DRAIN_PER_SECOND := 0.25
const MAX_ADVANCE_SECONDS := 86400.0
const HARVEST_MOISTURE_COST := 20.0


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

## Add water to an existing crop. Saturated crops and invalid amounts are no-ops.
func water_crop(stable_id: String, amount: float, now_unix: int = -1) -> bool:
	if not _records.has(stable_id) or not is_finite(amount) or amount <= 0.0:
		return false
	var candidate: Dictionary = _records[stable_id].duplicate(true)
	var timestamp: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	if timestamp < int(candidate.get("last_updated_unix", 1)):
		return false
	var old_moisture: float = float(candidate.get("moisture", 0.0))
	var next_moisture: float = minf(100.0, old_moisture + amount)
	if next_moisture <= old_moisture:
		return false
	candidate["moisture"] = next_moisture
	candidate["last_updated_unix"] = timestamp
	if not _is_valid_record(stable_id, candidate):
		return false
	_records[stable_id] = candidate
	return true

## Advance crop growth deterministically; callers own the clock and decide when to tick.
## Growth pauses when soil dries. Large or invalid elapsed intervals are rejected.
func advance_growth(stable_id: String, elapsed_seconds: float, now_unix: int = -1) -> bool:
	if not _records.has(stable_id):
		return false
	if not is_finite(elapsed_seconds) or elapsed_seconds <= 0.0 or elapsed_seconds > MAX_ADVANCE_SECONDS:
		return false
	var candidate: Dictionary = _records[stable_id].duplicate(true)
	var timestamp: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	if timestamp < int(candidate.get("last_updated_unix", 1)):
		return false
	var moisture: float = float(candidate.get("moisture", 0.0))
	var stage: int = int(candidate.get("growth_stage", 0))
	var progress: float = float(candidate.get("growth_progress", 0.0))
	var effective_seconds: float = 0.0
	if stage < MAX_STAGE and moisture > 0.0:
		effective_seconds = minf(elapsed_seconds, moisture / MOISTURE_DRAIN_PER_SECOND)
		var total_progress: float = progress + effective_seconds / GROWTH_SECONDS_PER_STAGE
		while total_progress >= 1.0 - 0.000001 and stage < MAX_STAGE:
			stage += 1
			total_progress = maxf(0.0, total_progress - 1.0)
		if stage >= MAX_STAGE:
			progress = 1.0
		else:
			progress = clampf(total_progress, 0.0, 1.0)
	candidate["growth_stage"] = stage
	candidate["growth_progress"] = progress
	candidate["moisture"] = maxf(0.0, moisture - elapsed_seconds * MOISTURE_DRAIN_PER_SECOND)
	candidate["last_updated_unix"] = timestamp
	if not _is_valid_record(stable_id, candidate):
		return false
	_records[stable_id] = candidate
	return true

## Harvest only a mature crop. The record is reset for a new cycle and harvest_count is retained.
## Returns a small receipt dictionary, or an empty dictionary if the crop is not harvestable.
func harvest_crop(stable_id: String, now_unix: int = -1) -> Dictionary:
	if not _records.has(stable_id):
		return {}
	var candidate: Dictionary = _records[stable_id].duplicate(true)
	if int(candidate.get("growth_stage", 0)) < MAX_STAGE or float(candidate.get("growth_progress", 0.0)) < 1.0:
		return {}
	var timestamp: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	if timestamp < int(candidate.get("last_updated_unix", 1)):
		return {}
	candidate["harvest_count"] = int(candidate.get("harvest_count", 0)) + 1
	candidate["growth_stage"] = MIN_STAGE
	candidate["growth_progress"] = 0.0
	candidate["moisture"] = maxf(0.0, float(candidate.get("moisture", 0.0)) - HARVEST_MOISTURE_COST)
	candidate["last_updated_unix"] = timestamp
	if not _is_valid_record(stable_id, candidate):
		return {}
	_records[stable_id] = candidate
	return {
		"ok": true,
		"stable_id": stable_id,
		"crop_id": str(candidate.get("crop_id", "")),
		"harvest_count": int(candidate.get("harvest_count", 0))
	}

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

extends Node
class_name WorldObjectStateRegistry

## Stores compact, stable-ID state for interactive world objects across chunk unloads.
## Values are intentionally primitive so saves remain bounded and safely serializable.
const SCHEMA_VERSION: int = 1
const MAX_RECORDS: int = 50000
const MAX_STABLE_ID_LENGTH: int = 192
const MAX_CHUNK_ID_LENGTH: int = 128
const MAX_PROPERTY_NAME_LENGTH: int = 64
const MAX_PROPERTIES_PER_OBJECT: int = 64
const MAX_STRING_VALUE_LENGTH: int = 256
const MAX_TOTAL_PROPERTIES: int = 100000
const MAX_TOTAL_STRING_CHARS: int = 1000000

var _records: Dictionary = {}
var _total_properties: int = 0
var _total_string_chars: int = 0

func set_object_state(stable_id: String, chunk_id: String, state: Dictionary) -> bool:
	var candidate: Dictionary = {"chunk_id": chunk_id, "state": state}
	if not _is_valid_record(stable_id, candidate):
		return false
	if _records.has(stable_id) and str(_records[stable_id].get("chunk_id", "")) != chunk_id:
		return false
	if not _records.has(stable_id) and _records.size() >= MAX_RECORDS:
		return false
	var new_usage: Dictionary = _measure_state(state)
	var old_usage: Dictionary = {"properties": 0, "string_chars": 0}
	if _records.has(stable_id):
		old_usage = _measure_state(_records[stable_id]["state"])
	var next_properties: int = _total_properties - int(old_usage["properties"]) + int(new_usage["properties"])
	var next_string_chars: int = _total_string_chars - int(old_usage["string_chars"]) + int(new_usage["string_chars"])
	if next_properties > MAX_TOTAL_PROPERTIES or next_string_chars > MAX_TOTAL_STRING_CHARS:
		return false
	candidate["state"] = state.duplicate(true)
	_records[stable_id] = candidate
	_total_properties = next_properties
	_total_string_chars = next_string_chars
	return true

func set_property(stable_id: String, chunk_id: String, property_name: String, value: Variant) -> bool:
	if property_name.is_empty() or property_name.length() > MAX_PROPERTY_NAME_LENGTH or not _is_valid_value(value):
		return false
	var current: Dictionary = get_object_state(stable_id)
	var state_value: Dictionary = current.get("state", {}) if not current.is_empty() else {}
	state_value[property_name] = value
	return set_object_state(stable_id, chunk_id, state_value)

func get_object_state(stable_id: String) -> Dictionary:
	if not _records.has(stable_id):
		return {}
	return _records[stable_id].duplicate(true)

func get_chunk_states(chunk_id: String) -> Dictionary:
	var result: Dictionary = {}
	for stable_id in _records.keys():
		var record: Dictionary = _records[stable_id]
		if str(record.get("chunk_id", "")) == chunk_id:
			result[stable_id] = record.duplicate(true)
	return result

func forget_object_state(stable_id: String) -> bool:
	if not _records.has(stable_id):
		return false
	var usage: Dictionary = _measure_state(_records[stable_id]["state"])
	_total_properties -= int(usage["properties"])
	_total_string_chars -= int(usage["string_chars"])
	_records.erase(stable_id)
	return true

func get_saved_ids() -> PackedStringArray:
	var ids: Array = _records.keys()
	ids.sort()
	var result := PackedStringArray()
	for stable_id in ids:
		result.append(str(stable_id))
	return result

func to_save_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "objects": _records.duplicate(true)}

func validate_save_dict(data: Dictionary) -> bool:
	return bool(_prepare_restore(data).get("ok", false))

func restore_save_dict(data: Dictionary) -> bool:
	var prepared: Dictionary = _prepare_restore(data)
	if not bool(prepared.get("ok", false)):
		return false
	_records = prepared["records"]
	_total_properties = int(prepared["total_properties"])
	_total_string_chars = int(prepared["total_string_chars"])
	return true

func _prepare_restore(data: Dictionary) -> Dictionary:
	var raw_schema: Variant = data.get("schema_version", null)
	if not _is_integer_value(raw_schema) or int(raw_schema) != SCHEMA_VERSION:
		return {"ok": false, "error": "unsupported_schema"}
	var raw_records: Variant = data.get("objects", null)
	if not (raw_records is Dictionary) or raw_records.size() > MAX_RECORDS:
		return {"ok": false, "error": "invalid_records"}
	var prepared: Dictionary = {}
	var total_properties: int = 0
	var total_string_chars: int = 0
	for raw_id in raw_records.keys():
		if not (raw_id is String):
			return {"ok": false, "error": "invalid_stable_id"}
		var stable_id: String = raw_id
		var record: Variant = raw_records[raw_id]
		if not (record is Dictionary) or not _is_valid_record(stable_id, record):
			return {"ok": false, "error": "invalid_object_record"}
		var normalized_record: Dictionary = record.duplicate(true)
		var usage: Dictionary = _measure_state(normalized_record["state"])
		total_properties += int(usage["properties"])
		total_string_chars += int(usage["string_chars"])
		if total_properties > MAX_TOTAL_PROPERTIES or total_string_chars > MAX_TOTAL_STRING_CHARS:
			return {"ok": false, "error": "total_payload_limit"}
		prepared[stable_id] = normalized_record
	return {
		"ok": true,
		"records": prepared,
		"total_properties": total_properties,
		"total_string_chars": total_string_chars
	}

func _is_valid_record(stable_id: String, record: Dictionary) -> bool:
	if stable_id.is_empty() or stable_id.length() > MAX_STABLE_ID_LENGTH or stable_id.contains("\n") or stable_id.contains("\r"):
		return false
	var chunk_id: Variant = record.get("chunk_id", null)
	var state_value: Variant = record.get("state", null)
	if not (chunk_id is String) or chunk_id.is_empty() or chunk_id.length() > MAX_CHUNK_ID_LENGTH:
		return false
	if chunk_id.contains("\n") or chunk_id.contains("\r") or not (state_value is Dictionary):
		return false
	if state_value.size() > MAX_PROPERTIES_PER_OBJECT:
		return false
	for property_name in state_value.keys():
		if not (property_name is String) or property_name.is_empty() or property_name.length() > MAX_PROPERTY_NAME_LENGTH:
			return false
		if not _is_valid_value(state_value[property_name]):
			return false
	return true

func _measure_state(state: Dictionary) -> Dictionary:
	var string_chars: int = 0
	for value in state.values():
		if value is String:
			string_chars += value.length()
	return {"properties": state.size(), "string_chars": string_chars}

func _is_valid_value(value: Variant) -> bool:
	if value is String:
		return value.length() <= MAX_STRING_VALUE_LENGTH
	if value is bool or value is int:
		return true
	if value is float:
		return is_finite(value)
	return false

func _is_integer_value(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return is_finite(number) and floorf(number) == number

extends Node
class_name MineralVeinRegistry

## Stable-ID registry for mineral veins across save/load and streamed chunk boundaries.
## Unloaded records remain in the registry until the world save is replaced.
const MiningNode = preload("res://systems/MineralMiningNode.gd")
const Catalog = preload("res://systems/MineralCatalog.gd")

@export var auto_apply_elapsed_time_on_restore: bool = true
var _veins: Dictionary = {} # stable ID -> currently loaded MineralMiningNode
var _saved_records: Dictionary = {} # stable ID -> schema-v2 record, including unloaded chunks
var _last_atomic_registration_report: Dictionary = {}
var _pending_atomic_registration_recovery: Dictionary = {}

func register_vein(stable_id: String, vein: Node, now_unix: int = -1) -> bool:
	if not _pending_atomic_registration_recovery.is_empty():
		return false
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

## Atomically register every vein owned by one chunk. Saved state and offline
## regeneration are prepared on detached probes before any live node or registry
## entry changes. A rejected later participant cannot advance an earlier vein.
func register_veins_atomic(chunk_id: String, veins_by_local_id: Dictionary, now_unix: int = -1) -> bool:
	if not _pending_atomic_registration_recovery.is_empty():
		_last_atomic_registration_report = {"success": false, "phase": "recovery_required", "error": "pending_live_vein_recovery", "rollback_complete": false, "recovery_required": true}
		return false
	_last_atomic_registration_report = {"success": false, "phase": "preflight", "error": "preflight_rejected", "rollback_complete": true, "recovery_required": false}
	if chunk_id.is_empty() or chunk_id != chunk_id.strip_edges() or chunk_id.contains("//") or veins_by_local_id.is_empty():
		return false
	var now: int = now_unix if now_unix >= 0 else Time.get_unix_time_from_system()
	if now <= 0:
		return false

	# Validate key types before sorting: Array.sort() must never compare mixed
	# String and non-String Variant keys from an untrusted Dictionary.
	var local_ids: Array[String] = []
	for raw_local_id in veins_by_local_id.keys():
		if not (raw_local_id is String):
			return false
		var local_id: String = raw_local_id
		if local_id.is_empty() or local_id != local_id.strip_edges() or local_id.contains("//"):
			return false
		local_ids.append(local_id)
	local_ids.sort()

	var stable_ids: Array[String] = []
	var seen_instance_ids: Dictionary = {}
	var live_veins: Dictionary = {}
	var prepared_records: Dictionary = {}
	var original_states: Dictionary = {}

	for local_id in local_ids:
		var stable_id: String = chunk_id + "/vein/" + local_id
		var candidate: Variant = veins_by_local_id[local_id]
		if not is_instance_valid(candidate) or not (candidate is MiningNode):
			return false
		var live_vein: Node = candidate as Node
		var instance_id: int = live_vein.get_instance_id()
		if seen_instance_ids.has(instance_id):
			return false
		seen_instance_ids[instance_id] = true
		if not live_vein.has_method("can_register") or not bool(live_vein.call("can_register")):
			return false
		if _veins.has(stable_id) and is_instance_valid(_veins[stable_id]):
			return false
		var live_mineral_id: String = str(live_vein.get("mineral_id"))

		# Match register_vein() defaults for legacy schema-v1 records by seeding
		# the detached probe with the incoming node's authored capacities first.
		var probe: Node = MiningNode.new()
		probe.set("mineral_id", live_mineral_id)
		probe.set("max_units", int(live_vein.get("max_units")))
		probe.set("remaining_units", int(live_vein.get("remaining_units")))
		probe.set("units_per_hit", int(live_vein.get("units_per_hit")))
		probe.set("regen_interval_seconds", int(live_vein.get("regen_interval_seconds")))
		probe.set("last_regen_unix", int(live_vein.get("last_regen_unix")))

		var has_saved_record: bool = _saved_records.has(stable_id)
		var source_record: Dictionary = {}
		if has_saved_record:
			var saved_value: Variant = _saved_records[stable_id]
			if not (saved_value is Dictionary) or not _validate_record(stable_id, saved_value, live_mineral_id, now):
				probe.free()
				return false
			source_record = saved_value.duplicate(true)
		else:
			source_record = live_vein.call("to_save_dict")
			if int(source_record.get("last_regen_unix", 0)) <= 0:
				source_record["last_regen_unix"] = now

		if not bool(probe.call("load_save_dict", source_record, now, false)):
			probe.free()
			return false
		if has_saved_record:
			if auto_apply_elapsed_time_on_restore:
				probe.call("apply_elapsed_regeneration", now)
			else:
				probe.set("last_regen_unix", now)
		elif bool(live_vein.call("is_chunk_load_restore_pending")):
			# Controller deferred _ready() catch-up so a rejected load cannot mutate
			# the caller-owned root. Apply it to the detached probe at the explicit clock.
			probe.call("apply_elapsed_regeneration", now)

		var next_record: Dictionary = probe.call("to_save_dict")
		if not _validate_record(stable_id, next_record, live_mineral_id, now):
			probe.free()
			return false
		prepared_records[stable_id] = next_record.duplicate(true)
		live_veins[stable_id] = live_vein
		original_states[stable_id] = _snapshot_live_vein_state(live_vein)
		stable_ids.append(stable_id)
		probe.free()

	if stable_ids.size() != veins_by_local_id.size():
		return false

	# Apply only fully prepared schema-v2 records. load_save_dict validates all
	# fields before assigning them; retain exact live snapshots for defensive
	# rollback if a participant unexpectedly rejects during this apply phase.
	for stable_id in stable_ids:
		var live_vein: Node = live_veins[stable_id] as Node
		if not bool(live_vein.call("load_save_dict", prepared_records[stable_id], now, false)):
			# Include the rejecting participant: a subclass or injected failure may
			# mutate before returning false, even though the base implementation
			# validates before assignment.
			var rollback_complete: bool = true
			for rollback_id in stable_ids:
				var rollback_vein: Node = live_veins[rollback_id] as Node
				if not is_instance_valid(rollback_vein):
					rollback_complete = false
					continue
				_restore_live_vein_state(rollback_vein, original_states[rollback_id])
				if _snapshot_live_vein_state(rollback_vein) != original_states[rollback_id]:
					rollback_complete = false
			if not rollback_complete:
				_pending_atomic_registration_recovery = {
					"live_veins": live_veins.duplicate(),
					"original_states": original_states.duplicate(true)
				}
			_last_atomic_registration_report = {
				"success": false,
				"phase": "live_apply",
				"error": "live_vein_apply_rejected",
				"rollback_complete": rollback_complete,
				"recovery_required": not rollback_complete,
				"participant_count": stable_ids.size()
			}
			return false

	# Registry commit point: no registry map changes occur until every live node
	# has accepted its already-validated state.
	for stable_id in stable_ids:
		_veins[stable_id] = live_veins[stable_id]
		_saved_records[stable_id] = prepared_records[stable_id].duplicate(true)
	_last_atomic_registration_report = {
		"success": true,
		"phase": "complete",
		"error": "",
		"rollback_complete": true,
		"recovery_required": false,
		"participant_count": stable_ids.size()
	}
	return true

func get_last_atomic_registration_report() -> Dictionary:
	return _last_atomic_registration_report.duplicate(true)

func has_pending_atomic_registration_recovery() -> bool:
	return not _pending_atomic_registration_recovery.is_empty()

func recover_last_atomic_registration() -> bool:
	if _pending_atomic_registration_recovery.is_empty():
		return true
	var live_veins: Dictionary = _pending_atomic_registration_recovery.get("live_veins", {})
	var original_states: Dictionary = _pending_atomic_registration_recovery.get("original_states", {})
	var rollback_complete: bool = true
	for stable_id in original_states.keys():
		var vein: Node = live_veins.get(stable_id) as Node
		if not is_instance_valid(vein):
			rollback_complete = false
			continue
		_restore_live_vein_state(vein, original_states[stable_id])
		if _snapshot_live_vein_state(vein) != original_states[stable_id]:
			rollback_complete = false
	if rollback_complete:
		_pending_atomic_registration_recovery.clear()
	_last_atomic_registration_report = {
		"success": rollback_complete,
		"phase": "recovery_complete" if rollback_complete else "recovery_incomplete",
		"error": "" if rollback_complete else "live_vein_state_restore_failed",
		"rollback_complete": rollback_complete,
		"recovery_required": not rollback_complete,
		"participant_count": original_states.size()
	}
	return rollback_complete

func _snapshot_live_vein_state(vein: Node) -> Dictionary:
	var interaction_area: Area3D = vein.get_node_or_null("InteractionArea") as Area3D
	return {
		"max_units": int(vein.get("max_units")),
		"remaining_units": int(vein.get("remaining_units")),
		"regen_interval_seconds": int(vein.get("regen_interval_seconds")),
		"last_regen_unix": int(vein.get("last_regen_unix")),
		"depleted_signal_sent": bool(vein.get("_depleted_signal_sent")),
		"visible": bool(vein.get("visible")),
		"interaction_collision_layer": interaction_area.collision_layer if interaction_area != null else -1
	}

func _restore_live_vein_state(vein: Node, snapshot: Dictionary) -> void:
	vein.set("max_units", int(snapshot.get("max_units", vein.get("max_units"))))
	vein.set("remaining_units", int(snapshot.get("remaining_units", vein.get("remaining_units"))))
	vein.set("regen_interval_seconds", int(snapshot.get("regen_interval_seconds", vein.get("regen_interval_seconds"))))
	vein.set("last_regen_unix", int(snapshot.get("last_regen_unix", vein.get("last_regen_unix"))))
	vein.set("_depleted_signal_sent", bool(snapshot.get("depleted_signal_sent", false)))
	vein.set("visible", bool(snapshot.get("visible", vein.get("visible"))))
	var interaction_area: Area3D = vein.get_node_or_null("InteractionArea") as Area3D
	var collision_layer: int = int(snapshot.get("interaction_collision_layer", -1))
	if interaction_area != null and collision_layer >= 0:
		interaction_area.collision_layer = collision_layer

func unregister_vein(stable_id: String, expected_vein: Node = null, now_unix: int = -1) -> bool:
	if not _pending_atomic_registration_recovery.is_empty():
		return false
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

## Atomically unregisters every vein owned by one chunk. All nodes and save
## records are validated and their elapsed-regeneration results are prepared on
## detached probes before the live registry is changed.
func unregister_veins_atomic(chunk_id: String, veins_by_local_id: Dictionary, now_unix: int = -1) -> bool:
	if not _pending_atomic_registration_recovery.is_empty():
		return false
	if chunk_id.is_empty() or chunk_id != chunk_id.strip_edges() or chunk_id.contains("//") or veins_by_local_id.is_empty():
		return false
	var now: int = now_unix if now_unix >= 0 else Time.get_unix_time_from_system()
	if now <= 0:
		return false

	var stable_ids: Array[String] = []
	var next_records: Dictionary = {}
	for raw_local_id in veins_by_local_id.keys():
		if not (raw_local_id is String):
			return false
		var local_id: String = raw_local_id
		if local_id.is_empty() or local_id != local_id.strip_edges() or local_id.contains("//"):
			return false
		var stable_id: String = chunk_id + "/vein/" + local_id
		var expected_vein: Variant = veins_by_local_id[raw_local_id]
		if not _veins.has(stable_id) or not is_instance_valid(_veins[stable_id]) or _veins[stable_id] != expected_vein:
			return false
		var vein: Node = _veins[stable_id] as Node
		var mineral_id: String = str(vein.get("mineral_id"))
		if not (vein is MiningNode) or not Catalog.has_mineral(mineral_id):
			return false
		var current_record: Dictionary = vein.call("to_save_dict")
		var probe: Node = MiningNode.new()
		probe.set("mineral_id", mineral_id)
		if not bool(probe.call("load_save_dict", current_record, now, false)):
			probe.free()
			return false
		probe.call("apply_elapsed_regeneration", now)
		var next_record: Dictionary = probe.call("to_save_dict")
		next_records[stable_id] = next_record.duplicate(true)
		probe.free()
		stable_ids.append(stable_id)

	if stable_ids.size() != veins_by_local_id.size():
		return false

	# Commit point: every participant is valid and every future record is ready.
	# No live vein or registry entry was changed during preparation.
	for stable_id in stable_ids:
		_saved_records[stable_id] = next_records[stable_id]
	for stable_id in stable_ids:
		_veins.erase(stable_id)
	return true

## Capture only records owned by the selected chunks. Loaded veins in unrelated
## chunks are refreshed from their current live state; unloaded records are preserved.
func to_chunk_set_snapshot(chunk_ids: Array) -> Dictionary:
	if not _pending_atomic_registration_recovery.is_empty():
		return {}
	var normalized: Dictionary = _normalize_chunk_ids(chunk_ids)
	if not bool(normalized.get("ok", false)):
		return {}
	var selected: Dictionary = {}
	for chunk_id in normalized["ids"]:
		selected[chunk_id] = true
	for stable_id in get_registered_ids():
		if selected.has(_chunk_id_from_stable_id(stable_id)):
			_saved_records[stable_id] = _veins[stable_id].call("to_save_dict")
	var records: Dictionary = {}
	for raw_key in _saved_records.keys():
		var stable_id: String = str(raw_key)
		if selected.has(_chunk_id_from_stable_id(stable_id)):
			records[stable_id] = _saved_records[raw_key].duplicate(true)
	return {"schema_version": 1, "chunk_ids": normalized["ids"].duplicate(), "veins": records}

func validate_chunk_set_snapshot(chunk_ids: Array, data: Dictionary, now_unix: int = -1) -> bool:
	return bool(_prepare_chunk_set_snapshot(chunk_ids, data, now_unix).get("ok", false))

## Restore only the selected chunk set. Current records and live state from every
## unrelated chunk are merged at restore time, so newer unrelated writes survive.
func restore_chunk_set_snapshot(chunk_ids: Array, data: Dictionary, now_unix: int = -1) -> bool:
	if not _pending_atomic_registration_recovery.is_empty():
		return false
	var prepared: Dictionary = _prepare_chunk_set_snapshot(chunk_ids, data, now_unix)
	if not bool(prepared.get("ok", false)):
		_last_atomic_registration_report = {"success": false, "phase": "chunk_set_preflight", "error": str(prepared.get("error", "invalid_chunk_set_snapshot")), "rollback_complete": true, "recovery_required": false}
		return false
	var selected: Dictionary = prepared["selected"]
	var next_records: Dictionary = prepared["records"]
	var now: int = int(prepared["now"])
	var live_veins: Dictionary = {}
	var original_states: Dictionary = {}

	for stable_id in get_registered_ids():
		if not selected.has(_chunk_id_from_stable_id(stable_id)):
			continue
		var live_vein: Node = _veins[stable_id] as Node
		if not next_records.has(stable_id):
			return false
		var record: Dictionary = next_records[stable_id]
		var probe: Node = MiningNode.new()
		probe.set("mineral_id", str(live_vein.get("mineral_id")))
		probe.set("max_units", int(live_vein.get("max_units")))
		probe.set("remaining_units", int(live_vein.get("remaining_units")))
		probe.set("units_per_hit", int(live_vein.get("units_per_hit")))
		probe.set("regen_interval_seconds", int(live_vein.get("regen_interval_seconds")))
		probe.set("last_regen_unix", int(live_vein.get("last_regen_unix")))
		var probe_ok: bool = bool(probe.call("load_save_dict", record, now, false))
		probe.free()
		if not probe_ok:
			return false
		live_veins[stable_id] = live_vein
		original_states[stable_id] = _snapshot_live_vein_state(live_vein)

	for stable_id in live_veins.keys():
		var live_vein: Node = live_veins[stable_id] as Node
		if not bool(live_vein.call("load_save_dict", next_records[stable_id], now, false)):
			var rollback_complete: bool = true
			for rollback_id in live_veins.keys():
				var rollback_vein: Node = live_veins[rollback_id] as Node
				if not is_instance_valid(rollback_vein):
					rollback_complete = false
					continue
				_restore_live_vein_state(rollback_vein, original_states[rollback_id])
				if _snapshot_live_vein_state(rollback_vein) != original_states[rollback_id]:
					rollback_complete = false
			if not rollback_complete:
				_pending_atomic_registration_recovery = {
					"live_veins": live_veins.duplicate(),
					"original_states": original_states.duplicate(true)
				}
			_last_atomic_registration_report = {
				"success": false,
				"phase": "chunk_set_live_apply",
				"error": "live_vein_apply_rejected",
				"rollback_complete": rollback_complete,
				"recovery_required": not rollback_complete,
				"participant_count": live_veins.size()
			}
			return false

	_saved_records = next_records
	for stable_id in live_veins.keys():
		_saved_records[stable_id] = live_veins[stable_id].call("to_save_dict")
	_last_atomic_registration_report = {
		"success": true,
		"phase": "chunk_set_restore_complete",
		"error": "",
		"rollback_complete": true,
		"recovery_required": false,
		"participant_count": live_veins.size(),
		"chunk_count": selected.size()
	}
	return true

func _prepare_chunk_set_snapshot(chunk_ids: Array, data: Dictionary, now_unix: int = -1) -> Dictionary:
	var normalized: Dictionary = _normalize_chunk_ids(chunk_ids)
	if not bool(normalized.get("ok", false)):
		return normalized
	var supplied: Variant = data.get("chunk_ids", null)
	if not (supplied is Array):
		return {"ok": false, "error": "missing_chunk_set"}
	var normalized_supplied: Dictionary = _normalize_chunk_ids(supplied)
	if not bool(normalized_supplied.get("ok", false)) or normalized_supplied["ids"] != normalized["ids"]:
		return {"ok": false, "error": "chunk_set_mismatch"}
	var schema: Variant = data.get("schema_version", null)
	if not (schema is int or schema is float) or not is_finite(float(schema)) or float(schema) != 1.0:
		return {"ok": false, "error": "unsupported_schema"}
	var raw_records: Variant = data.get("veins", null)
	if not (raw_records is Dictionary):
		return {"ok": false, "error": "invalid_vein_records"}
	var now: int = now_unix if now_unix >= 0 else Time.get_unix_time_from_system()
	if now <= 0:
		return {"ok": false, "error": "invalid_timestamp"}
	var selected: Dictionary = {}
	for chunk_id in normalized["ids"]:
		selected[chunk_id] = true
	var restored_records: Dictionary = {}
	for raw_key in raw_records.keys():
		if not (raw_key is String):
			return {"ok": false, "error": "invalid_stable_id"}
		var stable_id: String = raw_key
		var chunk_id: String = _chunk_id_from_stable_id(stable_id)
		var record: Variant = raw_records[raw_key]
		if not selected.has(chunk_id) or not (record is Dictionary):
			return {"ok": false, "error": "foreign_chunk_record"}
		var expected_mineral: String = ""
		if _veins.has(stable_id) and is_instance_valid(_veins[stable_id]):
			expected_mineral = str(_veins[stable_id].get("mineral_id"))
		if not _validate_record(stable_id, record, expected_mineral, now):
			return {"ok": false, "error": "invalid_vein_record"}
		restored_records[stable_id] = record.duplicate(true)

	var merged_records: Dictionary = _saved_records.duplicate(true)
	for raw_key in merged_records.keys():
		if selected.has(_chunk_id_from_stable_id(str(raw_key))):
			merged_records.erase(raw_key)
	for stable_id in restored_records.keys():
		merged_records[stable_id] = restored_records[stable_id].duplicate(true)

	# Refresh unrelated live nodes at restore time instead of replaying their older
	# snapshot values. Unloaded unrelated records remain from the current Registry.
	for stable_id in get_registered_ids():
		if selected.has(_chunk_id_from_stable_id(stable_id)):
			if not restored_records.has(stable_id):
				return {"ok": false, "error": "snapshot_missing_loaded_vein"}
			continue
		var live_record: Dictionary = _veins[stable_id].call("to_save_dict")
		if not _validate_record(stable_id, live_record, str(_veins[stable_id].get("mineral_id")), now):
			return {"ok": false, "error": "invalid_unrelated_live_vein"}
		merged_records[stable_id] = live_record.duplicate(true)

	var prepared_all: Dictionary = _prepare_restore({"schema_version": 1, "veins": merged_records}, now)
	if not bool(prepared_all.get("ok", false)):
		return {"ok": false, "error": "merged_registry_invalid"}
	return {
		"ok": true,
		"records": prepared_all["records"],
		"now": int(prepared_all["now"]),
		"selected": selected
	}

func _normalize_chunk_ids(raw_chunk_ids: Array) -> Dictionary:
	if raw_chunk_ids.is_empty():
		return {"ok": false, "error": "empty_chunk_set"}
	var ids: Array[String] = []
	var seen: Dictionary = {}
	for raw_chunk_id in raw_chunk_ids:
		if not (raw_chunk_id is String):
			return {"ok": false, "error": "invalid_chunk_id_type"}
		var chunk_id: String = raw_chunk_id
		if chunk_id.is_empty() or chunk_id.length() > 128 or chunk_id != chunk_id.strip_edges() or chunk_id.contains("//") or chunk_id.contains("\n") or chunk_id.contains("\r") or seen.has(chunk_id):
			return {"ok": false, "error": "invalid_or_duplicate_chunk_id"}
		seen[chunk_id] = true
		ids.append(chunk_id)
	ids.sort()
	return {"ok": true, "ids": ids}

func _chunk_id_from_stable_id(stable_id: String) -> String:
	var marker: String = "/vein/"
	var marker_index: int = stable_id.find(marker)
	if marker_index <= 0 or marker_index + marker.length() >= stable_id.length():
		return ""
	return stable_id.substr(0, marker_index)

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
		_saved_records[key] = _veins[key].call("to_save_dict")
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
	if not _pending_atomic_registration_recovery.is_empty():
		return false
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
	if not _pending_atomic_registration_recovery.is_empty():
		return false
	var prepared := _prepare_restore(data, now_unix)
	if not bool(prepared.get("ok", false)):
		return false
	var next_records: Dictionary = prepared["records"]
	var now: int = int(prepared["now"])
	for key in get_registered_ids():
		if next_records.has(key):
			var record: Dictionary = next_records[key]
			if not bool(_veins[key].call("load_save_dict", record, now, false)):
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

extends RefCounted
class_name SurfaceWorldSaveStore

## Versioned, crash-conscious file storage for the production SurfaceWorld.
## The caller owns game-state validation and restore; this class owns envelope and file replacement.
const FORMAT_ID: String = "2126.surface_world"
const FORMAT_VERSION: int = 1
const MAX_SAVE_BYTES: int = 16 * 1024 * 1024

static func build_envelope(payload: Dictionary, saved_at_unix: int) -> Dictionary:
	return {
		"format_id": FORMAT_ID,
		"format_version": FORMAT_VERSION,
		"saved_at_unix": saved_at_unix,
		"payload": payload.duplicate(true)
	}

static func encode_envelope(envelope: Dictionary) -> String:
	return JSON.stringify(envelope, "\t")

static func decode_envelope(content: String) -> Dictionary:
	if content.is_empty() or content.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return {"ok": false, "reason": "empty_or_oversized_file"}
	var parser := JSON.new()
	var parse_error: int = parser.parse(content)
	if parse_error != OK:
		return {"ok": false, "reason": "invalid_json", "message": parser.get_error_message()}
	var raw_envelope: Variant = parser.data
	if not (raw_envelope is Dictionary):
		return {"ok": false, "reason": "invalid_envelope_type"}
	var format_id: Variant = raw_envelope.get("format_id", null)
	var format_version: Variant = raw_envelope.get("format_version", null)
	var saved_at: Variant = raw_envelope.get("saved_at_unix", null)
	var payload: Variant = raw_envelope.get("payload", null)
	if not (format_id is String) or str(format_id) != FORMAT_ID:
		return {"ok": false, "reason": "unsupported_format_id"}
	if not (format_version is int) or int(format_version) != FORMAT_VERSION:
		return {"ok": false, "reason": "unsupported_format_version"}
	if not (saved_at is int) or int(saved_at) <= 0:
		return {"ok": false, "reason": "invalid_saved_at"}
	if not (payload is Dictionary):
		return {"ok": false, "reason": "invalid_payload_type"}
	return {
		"ok": true,
		"saved_at_unix": int(saved_at),
		"payload": payload.duplicate(true),
		"envelope": raw_envelope.duplicate(true)
	}

static func read_valid_file(path: String, payload_validator: Callable) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"ok": false, "reason": "file_missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "file_open_failed", "error": FileAccess.get_open_error()}
	var byte_count: int = file.get_length()
	if byte_count <= 0 or byte_count > MAX_SAVE_BYTES:
		file.close()
		return {"ok": false, "reason": "invalid_file_size", "bytes": byte_count}
	var raw_text: String = file.get_as_text()
	file.close()
	var decoded: Dictionary = decode_envelope(raw_text)
	if not bool(decoded.get("ok", false)):
		decoded["path"] = path
		return decoded
	if not payload_validator.is_valid():
		return {"ok": false, "reason": "payload_validator_unavailable", "path": path}
	var payload: Dictionary = decoded["payload"]
	var validation_result: Variant = payload_validator.call(payload)
	if not (validation_result is bool) or not bool(validation_result):
		return {"ok": false, "reason": "payload_validation_failed", "path": path}
	return {
		"ok": true,
		"path": path,
		"raw_text": raw_text,
		"saved_at_unix": int(decoded["saved_at_unix"]),
		"payload": payload.duplicate(true),
		"envelope": decoded["envelope"].duplicate(true)
	}

static func write_atomic(path: String, envelope_text: String, payload_validator: Callable, rename_operation: Callable = Callable()) -> Dictionary:
	if path.is_empty() or envelope_text.is_empty() or not payload_validator.is_valid():
		return {"ok": false, "phase": "preflight", "reason": "invalid_write_arguments"}
	var interrupted: Dictionary = recover_interrupted_write(path, payload_validator, rename_operation)
	if not bool(interrupted.get("ok", false)):
		return {"ok": false, "phase": "interrupted_write_recovery", "reason": str(interrupted.get("reason", "recovery_failed")), "recovery_required": true}
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var parent_path: String = absolute_path.get_base_dir()
	var make_directory_error: int = DirAccess.make_dir_recursive_absolute(parent_path)
	if make_directory_error != OK and not DirAccess.dir_exists_absolute(parent_path):
		return {"ok": false, "phase": "directory", "reason": "save_directory_unavailable", "error": make_directory_error}
	if DirAccess.dir_exists_absolute(absolute_path):
		return {"ok": false, "phase": "preflight", "reason": "save_path_is_directory"}
	var temp_path: String = path + ".tmp"
	if not _remove_file_if_present(temp_path):
		return {"ok": false, "phase": "temp_cleanup", "reason": "stale_temp_could_not_be_removed"}
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return {"ok": false, "phase": "temp_write", "reason": "temp_open_failed", "error": FileAccess.get_open_error()}
	temp_file.store_string(envelope_text)
	temp_file.flush()
	var write_error: int = temp_file.get_error()
	temp_file.close()
	if write_error != OK:
		_remove_file_if_present(temp_path)
		return {"ok": false, "phase": "temp_write", "reason": "temp_flush_failed", "error": write_error}
	var verified_temp: Dictionary = read_valid_file(temp_path, payload_validator)
	if not bool(verified_temp.get("ok", false)):
		_remove_file_if_present(temp_path)
		return {"ok": false, "phase": "temp_verify", "reason": str(verified_temp.get("reason", "temp_validation_failed"))}

	var backup_path: String = path + ".bak"
	var backup_temp_path: String = backup_path + ".tmp"
	var previous_path: String = path + ".previous"
	var primary_exists: bool = FileAccess.file_exists(path)
	var primary_valid: Dictionary = {"ok": false, "reason": "primary_missing"}
	if primary_exists:
		primary_valid = read_valid_file(path, payload_validator)
		if bool(primary_valid.get("ok", false)):
			if not _remove_file_if_present(backup_temp_path):
				_remove_file_if_present(temp_path)
				return {"ok": false, "phase": "backup_prepare", "reason": "stale_backup_temp_could_not_be_removed"}
			var copy_error: int = DirAccess.copy_absolute(absolute_path, ProjectSettings.globalize_path(backup_temp_path))
			if copy_error != OK:
				_remove_file_if_present(temp_path)
				return {"ok": false, "phase": "backup_copy", "reason": "primary_backup_copy_failed", "error": copy_error}
			var verified_backup: Dictionary = read_valid_file(backup_temp_path, payload_validator)
			if not bool(verified_backup.get("ok", false)) or str(verified_backup.get("raw_text", "")) != str(primary_valid.get("raw_text", "")):
				_remove_file_if_present(backup_temp_path)
				_remove_file_if_present(temp_path)
				return {"ok": false, "phase": "backup_verify", "reason": "primary_backup_verification_failed"}
			if not _remove_file_if_present(backup_path):
				_remove_file_if_present(backup_temp_path)
				_remove_file_if_present(temp_path)
				return {"ok": false, "phase": "backup_replace", "reason": "old_backup_could_not_be_replaced"}
			var backup_rename_error: int = _rename_path(backup_temp_path, backup_path, rename_operation)
			if backup_rename_error != OK:
				_remove_file_if_present(backup_temp_path)
				_remove_file_if_present(temp_path)
				return {"ok": false, "phase": "backup_replace", "reason": "verified_backup_promotion_failed", "error": backup_rename_error}
	if primary_exists:
		if not _remove_file_if_present(previous_path):
			_remove_file_if_present(temp_path)
			return {"ok": false, "phase": "previous_cleanup", "reason": "stale_previous_file_could_not_be_removed"}
		var move_primary_error: int = _rename_path(path, previous_path, rename_operation)
		if move_primary_error != OK:
			_remove_file_if_present(temp_path)
			return {"ok": false, "phase": "primary_stage", "reason": "primary_could_not_be_staged", "error": move_primary_error}
	var promote_error: int = _rename_path(temp_path, path, rename_operation)
	if promote_error != OK:
		var rollback_error: int = OK
		if FileAccess.file_exists(previous_path):
			rollback_error = _rename_path(previous_path, path, rename_operation)
		_remove_file_if_present(temp_path)
		return {
			"ok": false,
			"phase": "primary_promote",
			"reason": "new_primary_promotion_failed",
			"error": promote_error,
			"recovery_required": rollback_error != OK,
			"rollback_error": rollback_error,
			"previous_path": previous_path,
			"backup_path": backup_path
		}
	var archive_path: String = ""
	var cleanup_warning: String = ""
	if FileAccess.file_exists(previous_path):
		if bool(primary_valid.get("ok", false)):
			if not _remove_file_if_present(previous_path):
				cleanup_warning = "old_primary_cleanup_failed"
		else:
			archive_path = _unique_corrupt_archive_path(path)
			var archive_error: int = _rename_path(previous_path, archive_path, rename_operation)
			if archive_error != OK:
				archive_path = previous_path
				cleanup_warning = "corrupt_primary_archive_rename_failed"
	return {
		"ok": true,
		"phase": "complete",
		"backup_path": backup_path if bool(primary_valid.get("ok", false)) else "",
		"archive_path": archive_path,
		"warning": cleanup_warning
	}

static func promote_backup(path: String, payload_validator: Callable, rename_operation: Callable = Callable()) -> Dictionary:
	var backup_path: String = path + ".bak"
	var backup_result: Dictionary = read_valid_file(backup_path, payload_validator)
	if not bool(backup_result.get("ok", false)):
		return {"ok": false, "phase": "backup_validation", "reason": str(backup_result.get("reason", "backup_invalid"))}
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute_path):
		return {"ok": false, "phase": "primary_preflight", "reason": "primary_path_is_directory"}
	var temp_path: String = path + ".restore.tmp"
	if not _remove_file_if_present(temp_path):
		return {"ok": false, "phase": "restore_temp", "reason": "stale_restore_temp_could_not_be_removed"}
	var copy_error: int = DirAccess.copy_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(temp_path))
	if copy_error != OK:
		return {"ok": false, "phase": "restore_temp", "reason": "backup_copy_failed", "error": copy_error}
	var verified_temp: Dictionary = read_valid_file(temp_path, payload_validator)
	if not bool(verified_temp.get("ok", false)) or str(verified_temp.get("raw_text", "")) != str(backup_result.get("raw_text", "")):
		_remove_file_if_present(temp_path)
		return {"ok": false, "phase": "restore_verify", "reason": "backup_copy_verification_failed"}
	var archive_path: String = ""
	if FileAccess.file_exists(path):
		archive_path = _unique_corrupt_archive_path(path)
		var archive_error: int = _rename_path(path, archive_path, rename_operation)
		if archive_error != OK:
			_remove_file_if_present(temp_path)
			return {"ok": false, "phase": "corrupt_archive", "reason": "corrupt_primary_could_not_be_preserved", "error": archive_error}
	var promote_error: int = _rename_path(temp_path, path, rename_operation)
	if promote_error != OK:
		var rollback_error: int = OK
		if not archive_path.is_empty():
			rollback_error = _rename_path(archive_path, path, rename_operation)
		_remove_file_if_present(temp_path)
		return {
			"ok": false,
			"phase": "backup_promote",
			"reason": "validated_backup_promotion_failed",
			"error": promote_error,
			"recovery_required": rollback_error != OK,
			"rollback_error": rollback_error,
			"archive_path": archive_path
		}
	return {"ok": true, "phase": "backup_promoted", "archive_path": archive_path, "backup_path": backup_path}

static func recover_interrupted_write(path: String, payload_validator: Callable, rename_operation: Callable = Callable()) -> Dictionary:
	var previous_path: String = path + ".previous"
	if not FileAccess.file_exists(previous_path):
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(previous_path)):
			return {"ok": false, "reason": "previous_path_is_directory"}
		return {"ok": true, "phase": "no_interrupted_write"}
	var primary_result: Dictionary = read_valid_file(path, payload_validator)
	if bool(primary_result.get("ok", false)):
		if not _remove_file_if_present(previous_path):
			return {"ok": false, "reason": "stale_previous_cleanup_failed"}
		return {"ok": true, "phase": "primary_already_valid"}
	var previous_result: Dictionary = read_valid_file(previous_path, payload_validator)
	if not bool(previous_result.get("ok", false)):
		return {"ok": false, "reason": "neither_primary_nor_previous_is_valid"}
	var archive_path: String = ""
	if FileAccess.file_exists(path):
		archive_path = _unique_corrupt_archive_path(path)
		var archive_error: int = _rename_path(path, archive_path, rename_operation)
		if archive_error != OK:
			return {"ok": false, "reason": "invalid_primary_could_not_be_archived", "error": archive_error}
	var restore_error: int = _rename_path(previous_path, path, rename_operation)
	if restore_error != OK:
		if not archive_path.is_empty():
			_rename_path(archive_path, path, rename_operation)
		return {"ok": false, "reason": "previous_primary_restore_failed", "error": restore_error}
	var verified_primary: Dictionary = read_valid_file(path, payload_validator)
	if not bool(verified_primary.get("ok", false)):
		return {"ok": false, "reason": "restored_previous_primary_failed_verification", "recovery_required": true}
	return {"ok": true, "phase": "previous_primary_restored", "archive_path": archive_path}

static func _rename_path(source_path: String, destination_path: String, rename_operation: Callable) -> int:
	var source_absolute: String = ProjectSettings.globalize_path(source_path)
	var destination_absolute: String = ProjectSettings.globalize_path(destination_path)
	if rename_operation.is_valid():
		return int(rename_operation.call(source_absolute, destination_absolute))
	return DirAccess.rename_absolute(source_absolute, destination_absolute)

static func _remove_file_if_present(path: String) -> bool:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute_path):
		return false
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(absolute_path) == OK

static func _unique_corrupt_archive_path(path: String) -> String:
	var base_path: String = path + ".corrupt." + str(Time.get_unix_time_from_system())
	var candidate: String = base_path
	var suffix: int = 1
	while FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate)):
		candidate = base_path + "." + str(suffix)
		suffix += 1
	return candidate

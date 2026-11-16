extends RefCounted
class_name WorldEnvelopeFileStore

## Durable JSON persistence for the production SurfaceWorld combined save envelope.
## The last known-good primary is retained as .bak until the next successful save.

var _last_report: Dictionary = {}


func write_atomically(destination_path: String, payload: Dictionary) -> bool:
	_set_report(false, "validation", "Save has not been written.", {})
	if not _is_safe_user_path(destination_path):
		return _fail("validation", "Save path must be a non-empty user:// path.", {})
	if payload.is_empty() or not _is_integer_value(payload.get("schema_version", null)):
		return _fail("validation", "World envelope is empty or has no integer schema version.", {})

	var encoded: String = JSON.stringify(payload, "", true, true)
	var encoded_parser := JSON.new()
	if encoded.is_empty() or encoded_parser.parse(encoded) != OK:
		return _fail("encode", "World envelope could not be encoded as JSON.", {})
	if not (encoded_parser.data is Dictionary):
		return _fail("encode_verify", "Encoded world envelope did not parse back to a Dictionary.", {})
	var round_trip_text: String = JSON.stringify(encoded_parser.data, "", true, true)
	if round_trip_text != encoded:
		return _fail("encode_verify", "Canonical JSON re-encoding differs from the supplied world envelope.", {})

	var temporary_path: String = destination_path + ".tmp"
	var backup_path: String = destination_path + ".bak"
	var destination_absolute: String = ProjectSettings.globalize_path(destination_path)
	var temporary_absolute: String = ProjectSettings.globalize_path(temporary_path)
	var backup_absolute: String = ProjectSettings.globalize_path(backup_path)
	var parent_absolute: String = destination_absolute.get_base_dir()
	if (
		_has_symlink_ancestor(destination_absolute)
		or _has_symlink_ancestor(temporary_absolute)
		or _has_symlink_ancestor(backup_absolute)
	):
		return _fail("path_symlink", "Save paths must not traverse symbolic links or reparse points.", {"path": destination_path})
	if not DirAccess.dir_exists_absolute(parent_absolute):
		if _has_file_ancestor(parent_absolute):
			return _fail("directory_create", "A file occupies a required parent-directory path; existing save files were not touched.", {"blocked_parent": parent_absolute})
		var directory_error: Error = DirAccess.make_dir_recursive_absolute(parent_absolute)
		if directory_error != OK and not DirAccess.dir_exists_absolute(parent_absolute):
			return _fail("directory_create", "The save parent directory could not be created; existing save files were not touched.", {"error": directory_error})

	if DirAccess.dir_exists_absolute(temporary_absolute):
		return _fail("temporary_obstruction", "A directory occupies the temporary save path; the current save was not touched.", {})
	if DirAccess.dir_exists_absolute(backup_absolute):
		return _fail("backup_obstruction", "A directory occupies the backup path; the current save was not touched.", {})
	if DirAccess.dir_exists_absolute(destination_absolute):
		return _fail("destination_obstruction", "A directory occupies the destination save path.", {})
	if FileAccess.file_exists(temporary_path) and DirAccess.remove_absolute(temporary_absolute) != OK:
		return _fail("temporary_cleanup", "A stale temporary save could not be removed.", {})

	var temporary_file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if temporary_file == null:
		return _fail("temporary_open", "Could not open the temporary save file.", {})
	temporary_file.store_string(encoded)
	temporary_file.flush()
	var write_error: Error = temporary_file.get_error()
	temporary_file.close()
	if write_error != OK:
		if FileAccess.file_exists(temporary_path):
			DirAccess.remove_absolute(temporary_absolute)
		return _fail("temporary_write", "Writing the temporary save failed.", {"error": write_error})

	var temporary_payload: Dictionary = _read_dictionary(temporary_path)
	var temporary_encoded: String = JSON.stringify(temporary_payload, "", true, true) if not temporary_payload.is_empty() else ""
	if temporary_encoded != encoded:
		if FileAccess.file_exists(temporary_path):
			DirAccess.remove_absolute(temporary_absolute)
		return _fail("temporary_verify", "The temporary save failed exact JSON readback.", {})

	var moved_existing_save: bool = false
	if FileAccess.file_exists(destination_path):
		# Replace only the previous backup. The current primary remains untouched
		# until the fully written and verified temporary file is ready.
		if FileAccess.file_exists(backup_path) and DirAccess.remove_absolute(backup_absolute) != OK:
			DirAccess.remove_absolute(temporary_absolute)
			return _fail("backup_rotate", "The previous backup could not be rotated; the primary save remains untouched.", {})
		if DirAccess.rename_absolute(destination_absolute, backup_absolute) != OK:
			DirAccess.remove_absolute(temporary_absolute)
			return _fail("primary_to_backup", "The current primary could not be moved to the backup path.", {})
		moved_existing_save = true

	if DirAccess.rename_absolute(temporary_absolute, destination_absolute) != OK:
		var primary_restored: bool = true
		if moved_existing_save:
			primary_restored = DirAccess.rename_absolute(backup_absolute, destination_absolute) == OK
		if FileAccess.file_exists(temporary_path):
			DirAccess.remove_absolute(temporary_absolute)
		return _fail("temporary_to_primary", "The new primary could not be installed.", {
			"previous_primary_restored": primary_restored,
			"backup_preserved": FileAccess.file_exists(backup_path)
		})

	var final_payload: Dictionary = _read_dictionary(destination_path)
	var final_encoded: String = JSON.stringify(final_payload, "", true, true) if not final_payload.is_empty() else ""
	if final_encoded != encoded:
		DirAccess.remove_absolute(destination_absolute)
		var primary_restored_after_verify: bool = true
		if moved_existing_save:
			primary_restored_after_verify = DirAccess.rename_absolute(backup_absolute, destination_absolute) == OK
		return _fail("primary_verify", "The installed primary failed exact readback.", {
			"previous_primary_restored": primary_restored_after_verify,
			"backup_preserved": FileAccess.file_exists(backup_path)
		})

	_set_report(true, "complete", "", {
		"path": destination_path,
		"backup_path": backup_path,
		"backup_contains_previous_primary": moved_existing_save,
		"backup_preserved": FileAccess.file_exists(backup_path)
	})
	return true


func load_with_backup(
	save_path: String,
	restore_callable: Callable,
	restore_report_callable: Callable,
	now_unix: int = -1
) -> bool:
	_set_report(false, "read", "No world envelope has been restored.", {})
	if not _is_safe_user_path(save_path):
		return _fail("validation", "Load path must be a non-empty user:// path.", {})
	if not restore_callable.is_valid() or not restore_report_callable.is_valid():
		return _fail("restore_contract", "Restore and restore-report callbacks are required.", {})

	var primary_absolute: String = ProjectSettings.globalize_path(save_path)
	var backup_absolute: String = ProjectSettings.globalize_path(save_path + ".bak")
	if _has_symlink_ancestor(primary_absolute) or _has_symlink_ancestor(backup_absolute):
		return _fail("path_symlink", "Load paths must not traverse symbolic links or reparse points.", {"path": save_path})

	var primary_exists: bool = FileAccess.file_exists(save_path)
	var primary_payload: Dictionary = _read_dictionary(save_path)
	if not primary_payload.is_empty():
		var primary_attempt: Dictionary = _attempt_restore(primary_payload, restore_callable, restore_report_callable, now_unix)
		if bool(primary_attempt.get("ok", false)):
			_set_report(true, "primary_restored", "", {
				"source": save_path,
				"backup_path": save_path + ".bak",
				"restore_report": primary_attempt.get("restore_report", {})
			})
			return true
		if not bool(primary_attempt.get("safe_to_fallback", false)):
			return _fail("primary_restore_unsafe", "Primary restore failed without a verified rollback; backup application was blocked.", {
				"restore_report": primary_attempt.get("restore_report", {})
			})

	var backup_path: String = save_path + ".bak"
	var backup_payload: Dictionary = _read_dictionary(backup_path)
	if backup_payload.is_empty():
		return _fail(
			"backup_unavailable",
			"Primary save is missing or invalid and no valid backup dictionary is available.",
			{"primary_exists": primary_exists, "backup_exists": FileAccess.file_exists(backup_path)}
		)

	var backup_attempt: Dictionary = _attempt_restore(backup_payload, restore_callable, restore_report_callable, now_unix)
	if not bool(backup_attempt.get("ok", false)):
		return _fail("backup_restore_failed", "The backup could not be restored; the live world was not declared recovered.", {
			"restore_report": backup_attempt.get("restore_report", {}),
			"safe_to_fallback": backup_attempt.get("safe_to_fallback", false)
		})

	var diagnostic_path: String = ""
	var primary_preserved: bool = not primary_exists
	if primary_exists:
		diagnostic_path = _next_diagnostic_path(save_path)
		if not diagnostic_path.is_empty():
			primary_preserved = DirAccess.rename_absolute(
				ProjectSettings.globalize_path(save_path),
				ProjectSettings.globalize_path(diagnostic_path)
			) == OK
		if not primary_preserved:
			diagnostic_path = ""

	# The world has already been restored from the validated backup. Repair the
	# primary only when the invalid original was safely preserved (or was missing).
	var primary_repaired: bool = false
	if primary_preserved:
		primary_repaired = write_atomically(save_path, backup_payload)

	_set_report(true, "backup_restored", "", {
		"source": backup_path,
		"primary_repaired": primary_repaired,
		"primary_preserved": primary_preserved,
		"diagnostic_path": diagnostic_path,
		"backup_retained": FileAccess.file_exists(backup_path),
		"restore_report": backup_attempt.get("restore_report", {})
	})
	return true


func get_last_report() -> Dictionary:
	return _last_report.duplicate(true)


func _attempt_restore(
	payload: Dictionary,
	restore_callable: Callable,
	restore_report_callable: Callable,
	now_unix: int
) -> Dictionary:
	var restored: bool = bool(restore_callable.call(payload, now_unix))
	var report_value: Variant = restore_report_callable.call()
	var report: Dictionary = report_value.duplicate(true) if report_value is Dictionary else {}
	if restored:
		return {"ok": true, "safe_to_fallback": false, "restore_report": report}

	var phase: String = str(report.get("phase", "unknown"))
	var rollback_complete: bool = bool(report.get("rollback_complete", false))
	var safe_to_fallback: bool = rollback_complete and not ["precondition", "snapshot"].has(phase)
	return {
		"ok": false,
		"safe_to_fallback": safe_to_fallback,
		"restore_report": report
	}


func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	# Malformed user save files are expected recovery inputs. JSON.parse avoids
	# the engine ERROR log emitted by JSON.parse_string for malformed text.
	if parse_error != OK or not (parser.data is Dictionary):
		return {}
	return parser.data.duplicate(true)


func _next_diagnostic_path(save_path: String) -> String:
	var first: String = save_path + ".corrupt"
	if (
		not FileAccess.file_exists(first)
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(first))
		and not _has_symlink_ancestor(ProjectSettings.globalize_path(first))
	):
		return first
	for index in range(1, 1000):
		var candidate: String = "%s.corrupt.%d" % [save_path, index]
		if (
			not FileAccess.file_exists(candidate)
			and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate))
			and not _has_symlink_ancestor(ProjectSettings.globalize_path(candidate))
		):
			return candidate
	return ""


func _is_integer_value(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return is_finite(number) and floorf(number) == number


func _has_file_ancestor(path: String) -> bool:
	var candidate: String = path
	while not candidate.is_empty():
		if DirAccess.dir_exists_absolute(candidate):
			return false
		if FileAccess.file_exists(candidate):
			return true
		var parent: String = candidate.get_base_dir()
		if parent == candidate:
			break
		candidate = parent
	return false


func _has_symlink_ancestor(path: String) -> bool:
	var user_root: String = ProjectSettings.globalize_path("user://").simplify_path()
	var candidate: String = path.simplify_path()
	while candidate != user_root:
		var parent: String = candidate.get_base_dir()
		if parent == candidate:
			return true
		if DirAccess.dir_exists_absolute(parent):
			var parent_access := DirAccess.open(parent)
			if parent_access != null and parent_access.is_link(candidate.get_file()):
				return true
		candidate = parent
	return false


func _is_safe_user_path(path: String) -> bool:
	return not path.strip_edges().is_empty() and path.begins_with("user://") and not path.contains("..")


func _set_report(success: bool, phase: String, message: String, details: Dictionary) -> void:
	_last_report = {
		"success": success,
		"phase": phase,
		"message": message,
		"details": details.duplicate(true)
	}


func _fail(phase: String, message: String, details: Dictionary) -> bool:
	_set_report(false, phase, message, details)
	return false

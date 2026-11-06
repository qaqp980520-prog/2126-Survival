extends PanelContainer

const MAX_VISIBLE_ROWS: int = 6
const MAX_HISTORY: int = 32
const REFRESH_INTERVAL: float = 0.25
const DEFAULT_EXPORT_PATH: String = "user://streaming_diagnostics_snapshot.json"

var _director: Node
var _corner_provider: Node
var _refresh_elapsed: float = 0.0
var _summary_label: Label
var _corner_label: Label
var _history_label: Label
var _export_status_label: Label
var _export_button: Button

func _ready() -> void:
	name = "StreamingDiagnosticsPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(440, 360)
	_build_ui()
	visible = false
	refresh_now()

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.045, 0.065, 0.94)
	style.border_color = Color(0.18, 0.58, 0.72, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var title := Label.new()
	title.text = "KROLL // STREAM DIAGNOSTICS"
	title.add_theme_color_override("font_color", Color(0.48, 0.9, 1.0))
	title.add_theme_font_size_override("font_size", 15)
	column.add_child(title)
	_summary_label = Label.new()
	_summary_label.name = "Summary"
	_summary_label.add_theme_color_override("font_color", Color(0.65, 0.92, 0.77))
	_summary_label.add_theme_font_size_override("font_size", 12)
	column.add_child(_summary_label)
	_corner_label = Label.new()
	_corner_label.name = "TerrainCorners"
	_corner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_corner_label.add_theme_color_override("font_color", Color(1.0, 0.73, 0.42))
	_corner_label.add_theme_font_size_override("font_size", 11)
	column.add_child(_corner_label)
	_history_label = Label.new()
	_history_label.name = "History"
	_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history_label.add_theme_color_override("font_color", Color(0.78, 0.87, 0.94))
	_history_label.add_theme_font_size_override("font_size", 11)
	_history_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_history_label)
	_export_button = Button.new()
	_export_button.name = "ExportSnapshot"
	_export_button.text = "EXPORT SNAPSHOT"
	_export_button.custom_minimum_size = Vector2(150.0, 32.0)
	_export_button.pressed.connect(export_snapshot_to_default_path)
	column.add_child(_export_button)
	_export_status_label = Label.new()
	_export_status_label.name = "ExportStatus"
	_export_status_label.add_theme_color_override("font_color", Color(0.55, 0.86, 0.74))
	_export_status_label.add_theme_font_size_override("font_size", 10)
	column.add_child(_export_status_label)
	var hint := Label.new()
	hint.text = "F3 CLOSE · NEWEST SIX REQUESTS · HISTORY CAP 32"
	hint.add_theme_color_override("font_color", Color(0.47, 0.62, 0.72))
	hint.add_theme_font_size_override("font_size", 10)
	column.add_child(hint)

func bind_director(candidate: Node) -> void:
	_director = candidate
	refresh_now()

func bind_corner_provider(candidate: Node) -> void:
	_corner_provider = candidate
	refresh_now()

func set_open(value: bool) -> void:
	visible = value
	_refresh_elapsed = 0.0
	if visible:
		refresh_now()

func toggle_open() -> bool:
	set_open(not visible)
	return visible

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_elapsed += delta
	if _refresh_elapsed >= REFRESH_INTERVAL:
		_refresh_elapsed = 0.0
		refresh_now()

func refresh_now() -> void:
	if _summary_label == null or _history_label == null:
		return
	if _director == null or not is_instance_valid(_director) or _director.is_queued_for_deletion():
		_summary_label.text = "STREAM DIAGNOSTICS · UNAVAILABLE"
		_history_label.text = "Bind a live MineralGridStreamingDirector to inspect requests."
		_refresh_corner_reports()
		return
	if not _director.has_method("get_active_async_request_id") or not _director.has_method("get_recent_async_request_diagnostics"):
		_summary_label.text = "STREAM DIAGNOSTICS · INVALID DIRECTOR"
		_history_label.text = "The bound node does not expose the diagnostics API."
		return
	var active_id: int = int(_director.call("get_active_async_request_id"))
	var recent: Array = _director.call("get_recent_async_request_diagnostics")
	_summary_label.text = "%s · HISTORY %d / %d" % [
		("ACTIVE #%d" % active_id) if active_id >= 0 else "IDLE",
		recent.size(), MAX_HISTORY
	]
	_refresh_corner_reports()
	if recent.is_empty():
		_history_label.text = "No asynchronous streaming requests recorded."
		return
	var lines: Array[String] = []
	var first_index: int = maxi(0, recent.size() - MAX_VISIBLE_ROWS)
	for index in range(first_index, recent.size()):
		var record: Dictionary = recent[index]
		var request_id: int = int(record.get("request_id", -1))
		var phase: String = str(record.get("phase", "unknown"))
		var staged: int = int(record.get("staged_count", 0))
		var desired: int = int(record.get("desired_count", 0))
		var loaded: int = int(record.get("newly_loaded_count", 0))
		var unloaded: int = int(record.get("unloaded_stale_count", 0))
		var duration_usec: int = int(record.get("duration_usec", -1))
		if duration_usec < 0:
			var started_usec: int = int(record.get("started_usec", -1))
			if started_usec >= 0:
				duration_usec = maxi(0, Time.get_ticks_usec() - started_usec)
		var duration_text: String = "pending" if duration_usec < 0 else "%.1fms" % (float(duration_usec) / 1000.0)
		var rollback_text: String = "rollback=pending"
		if bool(record.get("terminal", false)):
			if bool(record.get("success", false)):
				rollback_text = "rollback=n/a"
			else:
				rollback_text = "rollback=ok" if bool(record.get("rollback_complete", false)) else "rollback=FAILED"
		var reason: String = str(record.get("cancellation_reason", ""))
		if reason.length() > 22:
			reason = reason.substr(0, 22) + "…"
		var line: String = "#%d %s · stage %d/%d · +%d/-%d · %s · %s" % [
			request_id, phase, staged, desired, loaded, unloaded, duration_text, rollback_text
		]
		if not reason.is_empty():
			line += " · " + reason
		lines.append(line)
	_history_label.text = "\n".join(lines)

func _refresh_corner_reports() -> void:
	if _corner_label == null:
		return
	if _corner_provider == null or not is_instance_valid(_corner_provider) or _corner_provider.is_queued_for_deletion():
		_corner_label.text = "TERRAIN CORNERS · PROVIDER UNAVAILABLE"
		return
	if not _corner_provider.has_method("get_blocked_terrain_corner_reports"):
		_corner_label.text = "TERRAIN CORNERS · INVALID PROVIDER"
		return
	var reports: Array = _corner_provider.call("get_blocked_terrain_corner_reports")
	if reports.is_empty():
		_corner_label.text = "TERRAIN CORNERS · NONE BLOCKED"
		return
	var lines: Array[String] = []
	for index in range(mini(reports.size(), 3)):
		var report: Dictionary = reports[index] if reports[index] is Dictionary else {}
		var edge_keys: Array = report.get("edge_keys", [])
		var edge_text: String = ", ".join(PackedStringArray(edge_keys))
		lines.append("%s · %s · %s · %s" % [
			str(report.get("stable_id", "unknown")),
			str(report.get("corner", "unknown")),
			str(report.get("policy", "unknown")),
			edge_text
		])
	_corner_label.text = "BLOCKED CORNERS %d\n%s" % [reports.size(), "\n".join(lines)]


func _json_safe(value: Variant) -> Variant:
	if value is Vector2:
		var point: Vector2 = value
		return {"x": point.x, "y": point.y}
	if value is Vector2i:
		var point_i: Vector2i = value
		return {"x": point_i.x, "y": point_i.y}
	if value is Vector3:
		var point_3d: Vector3 = value
		return {"x": point_3d.x, "y": point_3d.y, "z": point_3d.z}
	if value is Vector3i:
		var point_3i: Vector3i = value
		return {"x": point_3i.x, "y": point_3i.y, "z": point_3i.z}
	if value is Color:
		var color_value: Color = value
		return {"r": color_value.r, "g": color_value.g, "b": color_value.b, "a": color_value.a}
	if value is Array:
		var safe_array: Array = []
		for item in value:
			safe_array.append(_json_safe(item))
		return safe_array
	if value is Dictionary:
		var safe_dictionary: Dictionary = {}
		for key in value:
			safe_dictionary[str(key)] = _json_safe(value[key])
		return safe_dictionary
	if value == null or value is bool or value is int or value is float or value is String:
		return value
	return str(value)

func build_export_snapshot() -> Dictionary:
	var active_id: int = -1
	var history: Array[Dictionary] = []
	if _director != null and is_instance_valid(_director) and not _director.is_queued_for_deletion():
		if _director.has_method("get_active_async_request_id") and _director.has_method("get_recent_async_request_diagnostics"):
			active_id = int(_director.call("get_active_async_request_id"))
			var raw_history: Array = _director.call("get_recent_async_request_diagnostics")
			var first_index: int = maxi(0, raw_history.size() - MAX_HISTORY)
			for index in range(first_index, raw_history.size()):
				if raw_history[index] is Dictionary:
					var safe_record: Dictionary = _json_safe(raw_history[index])
					history.append(safe_record)
	var corners: Array[Dictionary] = []
	if _corner_provider != null and is_instance_valid(_corner_provider) and not _corner_provider.is_queued_for_deletion():
		if _corner_provider.has_method("get_blocked_terrain_corner_reports"):
			var raw_corners: Array = _corner_provider.call("get_blocked_terrain_corner_reports")
			for report_value in raw_corners:
				if report_value is Dictionary:
					var safe_corner: Dictionary = _json_safe(report_value)
					corners.append(safe_corner)
	return {
		"schema_version": 1,
		"generated_unix": int(Time.get_unix_time_from_system()),
		"active_request_id": active_id,
		"history": history,
		"blocked_corners": corners
	}

func export_snapshot_json() -> String:
	return JSON.stringify(build_export_snapshot(), "\t")

func is_safe_export_path(path: String) -> bool:
	if not path.begins_with("user://") or path.contains("\\"):
		return false
	var relative_path: String = path.substr("user://".length())
	if relative_path.is_empty() or relative_path.begins_with("/") or relative_path.ends_with("/") or relative_path.contains("//"):
		return false
	for segment in relative_path.split("/"):
		if segment == "." or segment == "..":
			return false
	return true

func save_snapshot_to_file(path: String = DEFAULT_EXPORT_PATH) -> bool:
	if not is_safe_export_path(path):
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(export_snapshot_json())
	var write_error: Error = file.get_error()
	file.close()
	return write_error == OK

func export_snapshot_to_default_path() -> void:
	if save_snapshot_to_file():
		if _export_status_label != null:
			_export_status_label.text = "SAVED · " + DEFAULT_EXPORT_PATH
	elif _export_status_label != null:
		_export_status_label.text = "EXPORT FAILED · CHECK USER DATA STORAGE"

func get_export_button() -> Button:
	return _export_button

func get_export_button_count() -> int:
	return 1 if is_instance_valid(_export_button) else 0

func get_rendered_text() -> String:
	if _summary_label == null or _corner_label == null or _history_label == null:
		return ""
	return _summary_label.text + "\n" + _corner_label.text + "\n" + _history_label.text

func get_visible_row_count() -> int:
	if _history_label == null or _history_label.text.is_empty():
		return 0
	return _history_label.text.split("\n").size()

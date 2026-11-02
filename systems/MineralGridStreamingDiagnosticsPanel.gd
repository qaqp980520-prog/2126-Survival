extends PanelContainer

const MAX_VISIBLE_ROWS: int = 6
const MAX_HISTORY: int = 32
const REFRESH_INTERVAL: float = 0.25

var _director: Node
var _refresh_elapsed: float = 0.0
var _summary_label: Label
var _history_label: Label

func _ready() -> void:
	name = "StreamingDiagnosticsPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(410, 250)
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
	_history_label = Label.new()
	_history_label.name = "History"
	_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history_label.add_theme_color_override("font_color", Color(0.78, 0.87, 0.94))
	_history_label.add_theme_font_size_override("font_size", 11)
	_history_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_history_label)
	var hint := Label.new()
	hint.text = "F3 CLOSE · NEWEST SIX REQUESTS · HISTORY CAP 32"
	hint.add_theme_color_override("font_color", Color(0.47, 0.62, 0.72))
	hint.add_theme_font_size_override("font_size", 10)
	column.add_child(hint)

func bind_director(candidate: Node) -> void:
	_director = candidate
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
		var rollback_text: String = "rollback=ok" if bool(record.get("rollback_complete", false)) else "rollback=FAILED"
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

func get_rendered_text() -> String:
	if _summary_label == null or _history_label == null:
		return ""
	return _summary_label.text + "\n" + _history_label.text

func get_visible_row_count() -> int:
	if _history_label == null or _history_label.text.is_empty():
		return 0
	return _history_label.text.split("\n").size()

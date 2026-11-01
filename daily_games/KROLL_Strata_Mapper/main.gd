extends Control

const ROOT_RULES_PATH: String = "res://daily_games/KROLL_Strata_Mapper/rules.gd"
const LOCAL_RULES_PATH: String = "res://rules.gd"

var _rules: RefCounted
var _state: Dictionary = {}
var _site_label: Label
var _status_label: Label
var _progress_label: Label
var _selection_label: Label
var _message_label: Label
var _core_headers: Array = []
var _sample_buttons: Array = []
var _next_button: Button
var _verify_button: Button

func _ready() -> void:
	var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else LOCAL_RULES_PATH
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("KROLL Strata Mapper could not load its rules module.")
		return
	_rules = rules_script.new() as RefCounted
	_state = _rules.call("make_state", 0)
	_build_ui()
	_refresh_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#09141c")
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "KROLL // STRATA MAPPER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color("#74e6f5"))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "RECONSTRUCT THE GEOLOGICAL COLUMN — OLDEST BEDS BELOW, YOUNGEST BEDS ABOVE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("#b5c9d0"))
	column.add_child(subtitle)

	_site_label = Label.new()
	_site_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_site_label.add_theme_font_size_override("font_size", 21)
	_site_label.add_theme_color_override("font_color", Color("#f2d39a"))
	column.add_child(_site_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 17)
	column.add_child(_status_label)

	var core_row := HBoxContainer.new()
	core_row.alignment = BoxContainer.ALIGNMENT_CENTER
	core_row.add_theme_constant_override("separation", 14)
	core_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(core_row)

	for core_index in range(3):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(300.0, 350.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		core_row.add_child(card)
		var card_column := VBoxContainer.new()
		card_column.add_theme_constant_override("separation", 8)
		card.add_child(card_column)
		var header := Label.new()
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 17)
		header.add_theme_color_override("font_color", Color("#8be4ef"))
		card_column.add_child(header)
		_core_headers.append(header)
		var top_label := Label.new()
		top_label.text = "TOP / YOUNGEST"
		top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_label.add_theme_font_size_override("font_size", 10)
		top_label.add_theme_color_override("font_color", Color("#9eb2bc"))
		card_column.add_child(top_label)
		var buttons: Array = []
		buttons.resize(4)
		for ui_row in range(4):
			var sample_index: int = 3 - ui_row
			var sample_button := Button.new()
			sample_button.custom_minimum_size = Vector2(0.0, 52.0)
			sample_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sample_button.pressed.connect(select_sample.bind(core_index, sample_index))
			card_column.add_child(sample_button)
			buttons[sample_index] = sample_button
		_sample_buttons.append(buttons)
		var bottom_label := Label.new()
		bottom_label.text = "BASE / OLDEST"
		bottom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bottom_label.add_theme_font_size_override("font_size", 10)
		bottom_label.add_theme_color_override("font_color", Color("#9eb2bc"))
		card_column.add_child(bottom_label)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 15)
	_progress_label.add_theme_color_override("font_color", Color("#c0d8df"))
	column.add_child(_progress_label)

	_selection_label = Label.new()
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_label.add_theme_color_override("font_color", Color("#f2d39a"))
	column.add_child(_selection_label)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	column.add_child(controls)

	controls.add_child(_make_button("CORE ◀", 105.0, _change_core.bind(-1)))
	controls.add_child(_make_button("CORE ▶", 105.0, _change_core.bind(1)))
	controls.add_child(_make_button("MOVE ↑", 105.0, move_selected.bind(1)))
	controls.add_child(_make_button("MOVE ↓", 105.0, move_selected.bind(-1)))
	_verify_button = _make_button("VERIFY", 105.0, verify_solution)
	controls.add_child(_verify_button)
	controls.add_child(_make_button("RESET", 95.0, reset_level))
	_next_button = _make_button("NEXT SITE", 120.0, advance_level)
	controls.add_child(_next_button)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", Color("#9eb2bc"))
	column.add_child(_message_label)

	var instructions := Label.new()
	instructions.text = "CLICK A SAMPLE TO SELECT  •  A / D OR ← / → SELECT CORE  •  W / S OR ↑ / ↓ SELECT SAMPLE  •  Q / E MOVE SAMPLE  •  SPACE VERIFY  •  R RESET  •  N NEXT SITE"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.add_theme_font_size_override("font_size", 11)
	instructions.add_theme_color_override("font_color", Color("#7f9aa6"))
	column.add_child(instructions)

func _make_button(label_text: String, min_width: float, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(min_width, 46.0)
	button.pressed.connect(callback)
	return button

func select_sample(core_index: int, sample_index: int) -> bool:
	if _rules == null:
		return false
	var result: Dictionary = _rules.call("select_sample", _state, core_index, sample_index)
	if not bool(result.get("ok", false)):
		return false
	_state = result.get("state", _state)
	_message_label.text = "Sample selected. Reorder each core from oldest at the base to youngest at the top."
	_refresh_ui()
	return true

func move_selected(direction: int) -> bool:
	if _rules == null:
		return false
	var result: Dictionary = _rules.call("move_selected", _state, direction)
	if not bool(result.get("ok", false)):
		_message_label.text = "That sample cannot move beyond the core boundary."
		return false
	_state = result.get("state", _state)
	match str(_state.get("status", "")):
		"won":
			_message_label.text = "STRATIGRAPHY CORRELATED — all three marker beds align."
		"failed":
			_message_label.text = "Move budget exhausted. Reset this site and try a cleaner sequence."
		_:
			_message_label.text = "Layer moved. Check the marker bed and the relative age order."
	_refresh_ui()
	return true

func _change_core(direction: int) -> void:
	var next_core: int = clampi(int(_state.get("selected_core", 0)) + direction, 0, 2)
	var result: Dictionary = _rules.call("select_core", _state, next_core)
	if bool(result.get("ok", false)):
		_state = result.get("state", _state)
		_refresh_ui()

func _change_sample(direction: int) -> void:
	var core_index: int = int(_state.get("selected_core", 0))
	var sample_index: int = clampi(int(_state.get("selected_sample", 0)) + direction, 0, 3)
	select_sample(core_index, sample_index)

func verify_solution() -> bool:
	if _rules == null:
		return false
	var report: Dictionary = _rules.call("verify_state", _state)
	if bool(report.get("solved", false)):
		_state["status"] = "won"
		_message_label.text = "STRATIGRAPHY CORRELATED — all three marker beds align."
	else:
		var marker_text: String = "aligned" if bool(report.get("marker_aligned", false)) else "misaligned"
		_message_label.text = "Current order: %d/%d correct positions. Marker beds are %s." % [
			int(report.get("correct_slots", 0)),
			int(report.get("total_slots", 0)),
			marker_text
		]
	_refresh_ui()
	return bool(report.get("solved", false))

func reset_level() -> void:
	_state = _rules.call("make_state", int(_state.get("site_index", 0)))
	_message_label.text = "Core samples reset. Each move swaps one layer with its neighbor."
	_refresh_ui()

func advance_level() -> bool:
	var next_state: Dictionary = _rules.call("advance_state", _state)
	if next_state.is_empty():
		return false
	_state = next_state
	if str(_state.get("status", "")) == "complete":
		_message_label.text = "ALL THREE SITES CORRELATED — SURVEY COMPLETE."
	else:
		_message_label.text = "New survey site loaded. Correlate the three core columns."
	_refresh_ui()
	return true

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func get_current_site() -> Dictionary:
	return _rules.call("get_site_data", int(_state.get("site_index", 0)))

func _refresh_ui() -> void:
	if _rules == null or _state.is_empty():
		return
	var site: Dictionary = _rules.call("get_site_data", int(_state.get("site_index", 0)))
	_site_label.text = "SITE %d / %d — %s" % [
		int(_state.get("site_index", 0)) + 1,
		int(_rules.call("get_site_count")),
		str(site.get("name", "UNKNOWN"))
	]
	var progress: Dictionary = _rules.call("get_progress", _state)
	_progress_label.text = "CORRECT SLOTS %d / %d     MOVES %d / %d     MARKER BED: %s" % [
		int(progress.get("correct_slots", 0)),
		int(progress.get("total_slots", 0)),
		int(_state.get("moves_used", 0)),
		int(_state.get("moves_used", 0)) + int(_state.get("moves_left", 0)),
		"ALIGNED" if bool(progress.get("marker_aligned", false)) else "NOT ALIGNED"
	]
	var cores: Array = _state.get("cores", [])
	for core_index in range(mini(cores.size(), _sample_buttons.size())):
		var core: Dictionary = cores[core_index]
		var samples: Array = core.get("samples", [])
		var target: Array = core.get("target", [])
		var correct: int = 0
		for sample_index in range(mini(samples.size(), target.size())):
			if samples[sample_index] == target[sample_index]:
				correct += 1
		_core_headers[core_index].text = "%s  •  %d / %d" % [str(core.get("name", "CORE")), correct, target.size()]
		for sample_index in range(mini(samples.size(), 4)):
			var sample_button: Button = _sample_buttons[core_index][sample_index] as Button
			var layer_id: String = str(samples[sample_index])
			sample_button.text = "%02d   %s" % [sample_index + 1, str(_rules.call("get_layer_label", layer_id))]
			sample_button.disabled = str(_state.get("status", "")) != "playing"
			var style := StyleBoxFlat.new()
			style.bg_color = Color(str(_rules.call("get_layer_color", layer_id)))
			style.border_width_left = 3 if core_index == int(_state.get("selected_core", 0)) and sample_index == int(_state.get("selected_sample", 0)) else 1
			style.border_width_right = style.border_width_left
			style.border_width_top = style.border_width_left
			style.border_width_bottom = style.border_width_left
			style.border_color = Color("#76efff") if style.border_width_left == 3 else Color("#263b49")
			style.corner_radius_top_left = 5
			style.corner_radius_top_right = 5
			style.corner_radius_bottom_left = 5
			style.corner_radius_bottom_right = 5
			sample_button.add_theme_stylebox_override("normal", style)
			sample_button.add_theme_color_override("font_color", Color("#f4fbff"))
			sample_button.add_theme_font_size_override("font_size", 13)
	var status: String = str(_state.get("status", "playing"))
	match status:
		"won":
			_status_label.text = "CORE CORRELATION COMPLETE"
			_status_label.add_theme_color_override("font_color", Color("#72e6a6"))
		"failed":
			_status_label.text = "MOVE BUDGET EXHAUSTED"
			_status_label.add_theme_color_override("font_color", Color("#ff9a85"))
		"complete":
			_status_label.text = "SURVEY CAMPAIGN COMPLETE"
			_status_label.add_theme_color_override("font_color", Color("#72e6a6"))
		_:
			_status_label.text = "18 MOVES — ALIGN THE VOLCANIC ASH MARKER IN ALL THREE CORES"
			_status_label.add_theme_color_override("font_color", Color("#e6eef1"))
	var selected_core: int = int(_state.get("selected_core", 0))
	var selected_sample: int = int(_state.get("selected_sample", 0))
	var selected_id: String = str(cores[selected_core].get("samples", [])[selected_sample]) if selected_core < cores.size() else ""
	_selection_label.text = "SELECTED: %s / %s" % [str(cores[selected_core].get("name", "CORE")) if selected_core < cores.size() else "CORE", str(_rules.call("get_layer_label", selected_id))]
	_verify_button.disabled = status != "playing" and status != "won"
	_next_button.disabled = status != "won"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_A, KEY_LEFT:
			_change_core(-1)
		KEY_D, KEY_RIGHT:
			_change_core(1)
		KEY_W, KEY_UP:
			_change_sample(1)
		KEY_S, KEY_DOWN:
			_change_sample(-1)
		KEY_Q:
			move_selected(1)
		KEY_E:
			move_selected(-1)
		KEY_SPACE:
			verify_solution()
		KEY_R:
			reset_level()
		KEY_N:
			advance_level()

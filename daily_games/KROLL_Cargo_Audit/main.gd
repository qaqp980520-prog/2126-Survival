extends Control

const Rules = preload("res://rules.gd")
const CONTAINER_LABELS: Array[String] = ["A", "B", "C", "D"]

var case_index: int = 0
var selected_container: int = 0
var selected_field: String = "mass"
var state: Dictionary = {}
var touch_buttons: Dictionary = {}
var case_label: Label
var briefing_label: Label
var manifest_label: Label
var scan_log_label: Label
var status_label: Label
var container_buttons: Array[Button] = []
var field_buttons: Dictionary = {}
var scan_history: Array[String] = []

func _ready() -> void:
	state = Rules.create_state()
	_build_ui()
	_refresh_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#07131f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "KROLL CARGO AUDIT // MANIFEST INTEGRITY"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#79e5ff"))
	root.add_child(title)

	case_label = Label.new()
	case_label.add_theme_font_size_override("font_size", 18)
	case_label.add_theme_color_override("font_color", Color("#f2c879"))
	root.add_child(case_label)

	briefing_label = Label.new()
	briefing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing_label.custom_minimum_size = Vector2(0.0, 54.0)
	briefing_label.add_theme_color_override("font_color", Color("#d5e4ef"))
	root.add_child(briefing_label)

	var manifest_title := Label.new()
	manifest_title.text = "DECLARED MANIFEST // SELECT A CONTAINER"
	manifest_title.add_theme_font_size_override("font_size", 15)
	manifest_title.add_theme_color_override("font_color", Color("#79e5ff"))
	root.add_child(manifest_title)

	manifest_label = Label.new()
	manifest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	manifest_label.custom_minimum_size = Vector2(0.0, 128.0)
	manifest_label.add_theme_font_size_override("font_size", 16)
	manifest_label.add_theme_color_override("font_color", Color("#e9f2f8"))
	root.add_child(manifest_label)

	var container_row := HBoxContainer.new()
	container_row.add_theme_constant_override("separation", 8)
	root.add_child(container_row)
	for index in range(4):
		var button := Button.new()
		button.text = "CONTAINER %s" % CONTAINER_LABELS[index]
		button.custom_minimum_size = Vector2(0.0, 48.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_container.bind(index))
		container_row.add_child(button)
		container_buttons.append(button)
		touch_buttons["container_%d" % index] = button

	var field_title := Label.new()
	field_title.text = "INSPECTION TOOL // ONE FIELD IS ALREADY CERTIFIED"
	field_title.add_theme_color_override("font_color", Color("#79e5ff"))
	root.add_child(field_title)

	var field_row := HBoxContainer.new()
	field_row.add_theme_constant_override("separation", 8)
	root.add_child(field_row)
	for field in Rules.FIELDS:
		var button := Button.new()
		button.text = field.to_upper()
		button.custom_minimum_size = Vector2(0.0, 44.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_field.bind(field))
		field_row.add_child(button)
		field_buttons[field] = button
		touch_buttons["field_" + field] = button

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	root.add_child(action_row)
	_add_action_button(action_row, "scan", "RUN SCAN", _scan_selected)
	_add_action_button(action_row, "submit", "SUBMIT SUSPECT", _submit_suspect)
	_add_action_button(action_row, "reset", "RESET CASE", _reset_case)
	_add_action_button(action_row, "next", "NEXT CASE", _next_case)

	scan_log_label = Label.new()
	scan_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scan_log_label.custom_minimum_size = Vector2(0.0, 126.0)
	scan_log_label.add_theme_color_override("font_color", Color("#a7d9bd"))
	root.add_child(scan_log_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0.0, 54.0)
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.add_theme_color_override("font_color", Color("#f2c879"))
	root.add_child(status_label)

	var help := Label.new()
	help.text = "1–4 select container · M mass · S seal · C count · SPACE scan · ENTER submit · R reset · N next"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color("#8ca4b8"))
	root.add_child(help)

func _add_action_button(parent: HBoxContainer, key: String, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	touch_buttons[key] = button

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			_select_container(int(key_event.keycode) - int(KEY_1))
		KEY_M:
			_select_field("mass")
		KEY_S:
			_select_field("seal")
		KEY_C:
			_select_field("count")
		KEY_SPACE:
			_scan_selected()
		KEY_ENTER, KEY_KP_ENTER:
			_submit_suspect()
		KEY_R:
			_reset_case()
		KEY_N:
			_next_case()

func _select_container(index: int) -> void:
	if index < 0 or index >= 4:
		return
	selected_container = index
	_refresh_ui()

func _select_field(field: String) -> void:
	if not Rules.FIELDS.has(field):
		return
	selected_field = field
	_refresh_ui()

func _scan_selected() -> Dictionary:
	var result: Dictionary = Rules.scan(case_index, state, selected_container, selected_field)
	if bool(result.get("ok", false)):
		var record: Dictionary = result.get("record", {})
		var marker: String = "MISMATCH" if bool(record.get("mismatch", false)) else "MATCH"
		scan_history.append("%s / %s | manifest %s -> sensor %s | %s" % [
			CONTAINER_LABELS[selected_container],
			selected_field.to_upper(),
			Rules.format_value(selected_field, record.get("manifest_value")),
			Rules.format_value(selected_field, record.get("actual_value")),
			marker
		])
		state["feedback"] = "Scan recorded. Find the single discrepancy."
	else:
		state["feedback"] = "SCAN BLOCKED // " + str(result.get("reason", "unknown")).replace("_", " ").to_upper()
	_refresh_ui()
	return result

func _submit_suspect() -> Dictionary:
	var result: Dictionary = Rules.accuse(case_index, state, selected_container, selected_field)
	_refresh_ui()
	return result

func _reset_case() -> void:
	state = Rules.create_state()
	selected_container = 0
	selected_field = "mass"
	scan_history.clear()
	_refresh_ui()

func _next_case() -> void:
	if str(state.get("status", "")) == "investigating":
		return
	case_index = posmod(case_index + 1, Rules.get_case_count())
	_reset_case()

func _refresh_ui() -> void:
	var case_data: Dictionary = Rules.get_case(case_index)
	case_label.text = "%02d / %02d   %s" % [case_index + 1, Rules.get_case_count(), str(case_data.get("name", "UNKNOWN CASE"))]
	briefing_label.text = str(case_data.get("brief", ""))
	var containers: Array = case_data.get("containers", [])
	var lines: Array[String] = ["ID     MASS       SEAL       ITEMS"]
	for index in range(containers.size()):
		var container: Dictionary = containers[index]
		lines.append("%s    %.1f kg    %s    %d" % [
			CONTAINER_LABELS[index],
			float(container.get("manifest_mass", 0.0)),
			str(container.get("manifest_seal", "")),
			int(container.get("manifest_count", 0))
		])
	manifest_label.text = "\n".join(lines)
	var certified_field: String = str(case_data.get("certified_field", ""))
	for index in range(container_buttons.size()):
		container_buttons[index].text = ("▶ " if selected_container == index else "") + "CONTAINER %s" % CONTAINER_LABELS[index]
		container_buttons[index].disabled = str(state.get("status", "")) != "investigating"
	for field in Rules.FIELDS:
		var button: Button = field_buttons[field]
		button.text = field.to_upper() + ("  // CERTIFIED" if field == certified_field else "")
		button.disabled = field == certified_field or str(state.get("status", "")) != "investigating"
	var scan_button: Button = touch_buttons["scan"] as Button
	scan_button.disabled = str(state.get("status", "")) != "investigating" or int(state.get("scans_left", 0)) <= 0
	(touch_buttons["submit"] as Button).disabled = str(state.get("status", "")) != "investigating"
	(touch_buttons["reset"] as Button).disabled = false
	(touch_buttons["next"] as Button).disabled = str(state.get("status", "")) == "investigating"
	scan_log_label.text = "SCANS %d/%d · ATTEMPTS %d/%d\n%s" % [
		int(state.get("scans_used", 0)),
		Rules.MAX_SCANS,
		int(state.get("attempts_left", 0)),
		Rules.MAX_ATTEMPTS,
		"\n".join(scan_history) if not scan_history.is_empty() else "No scans recorded."
	]
	status_label.text = "%s  //  SCORE %d\n%s" % [
		str(state.get("status", "investigating")).to_upper(),
		int(state.get("score", 0)),
		str(state.get("feedback", ""))
	]

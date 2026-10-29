extends Control

const Rules = preload("res://rules.gd")
var state: Dictionary = {}
var _current_seed: int = 1
var incoming_label: Label
var siding_label: Label
var output_label: Label
var target_label: Label
var status_label: Label
var moves_label: Label
var action_buttons: Dictionary = {}

func _ready() -> void:
	_build_ui()
	restart_game()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color("#07111f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "PageMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var page := VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var title := Label.new()
	title.text = "KROLL // RAIL YARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#7de7ff"))
	page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Shunt five cars into A–E order. Siding capacity: 3. Move limit: 12."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#b8c8d9"))
	page.add_child(subtitle)

	target_label = _make_label("TargetOrder", "TARGET  A  →  B  →  C  →  D  →  E", 20, Color("#ffd28b"))
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(target_label)

	var tracks := HBoxContainer.new()
	tracks.name = "Tracks"
	tracks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tracks.add_theme_constant_override("separation", 12)
	page.add_child(tracks)
	incoming_label = _track_panel(tracks, "INCOMING", "IncomingTrack")
	siding_label = _track_panel(tracks, "SIDING STACK (LIFO)", "SidingTrack")
	output_label = _track_panel(tracks, "OUTPUT", "OutputTrack")

	moves_label = _make_label("MovesLabel", "MOVES 0 / 12", 18, Color("#8eeaff"))
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(moves_label)

	var action_row := HBoxContainer.new()
	action_row.name = "ActionButtons"
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	page.add_child(action_row)
	_add_button(action_row, "Direct → Output", "DirectButton", "direct")
	_add_button(action_row, "Push → Siding", "PushButton", "push")
	_add_button(action_row, "Pop Siding → Output", "PopButton", "pop")

	var utility_row := HBoxContainer.new()
	utility_row.alignment = BoxContainer.ALIGNMENT_CENTER
	utility_row.add_theme_constant_override("separation", 10)
	page.add_child(utility_row)
	var restart_button := Button.new()
	restart_button.name = "RestartButton"
	restart_button.text = "RESTART  [R]"
	restart_button.pressed.connect(restart_game)
	utility_row.add_child(restart_button)
	var next_button := Button.new()
	next_button.name = "NextLayoutButton"
	next_button.text = "NEXT LAYOUT  [N]"
	next_button.pressed.connect(next_layout)
	utility_row.add_child(next_button)
	action_buttons["restart"] = restart_button
	action_buttons["next"] = next_button

	status_label = _make_label("StatusLabel", "", 16, Color("#d6e4f0"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(status_label)

func _track_panel(parent: HBoxContainer, heading: String, node_name: String) -> Label:
	var panel := PanelContainer.new()
	panel.name = node_name + "Panel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style())
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#7de7ff"))
	column.add_child(title)
	var label := _make_label(node_name, "—", 22, Color("#f1f6fc"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	return label

func _add_button(parent: HBoxContainer, text_value: String, node_name: String, action_name: String) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(190, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_perform_action.bind(action_name))
	parent.add_child(button)
	action_buttons[action_name] = button

func _make_label(node_name: String, text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0c1c2d")
	style.border_color = Color("#28566e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_perform_action("direct")
		KEY_2:
			_perform_action("push")
		KEY_3:
			_perform_action("pop")
		KEY_R:
			restart_game()
		KEY_N:
			next_layout()

func _perform_action(action_name: String) -> void:
	if str(state.get("status", "")) != "playing":
		return
	var result: Dictionary = Rules.apply_action(state, action_name)
	if not bool(result.get("ok", false)):
		status_label.text = "Move rejected: %s" % str(result.get("reason", "unknown"))
		return
	state = result.get("state", state)
	_refresh_ui()

func restart_game() -> void:
	state = Rules.new_game(_current_seed)
	_refresh_ui()

func next_layout() -> void:
	var index: int = Rules.SEEDS.find(_current_seed)
	_current_seed = Rules.SEEDS[(index + 1) % Rules.SEEDS.size()]
	restart_game()

func _refresh_ui() -> void:
	if incoming_label == null:
		return
	incoming_label.text = _format_cars(state.get("incoming", []), true)
	siding_label.text = _format_cars(state.get("siding", []), false)
	output_label.text = _format_cars(state.get("output", []), false)
	moves_label.text = "MOVES %d / %d    •    SEED %d" % [int(state.get("moves", 0)), int(state.get("max_moves", Rules.MAX_MOVES)), int(state.get("seed", 1))]
	status_label.text = str(state.get("message", ""))
	var active: bool = str(state.get("status", "")) == "playing"
	for key in ["direct", "push", "pop"]:
		action_buttons[key].disabled = not active
	action_buttons["restart"].disabled = false
	action_buttons["next"].disabled = false

func _format_cars(cars: Array, show_next: bool) -> String:
	if cars.is_empty():
		return "EMPTY"
	var parts: Array[String] = []
	for index in range(cars.size()):
		var marker: String = "▶ " if show_next and index == 0 else ""
		parts.append(marker + str(cars[index]))
	return "   ".join(parts)

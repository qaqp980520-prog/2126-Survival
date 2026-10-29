extends Control

const Rules = preload("res://rules.gd")

var state: Dictionary = {}
var _current_seed: int = 13
var frequency_labels: Array[Label] = []
var output_labels: Array[Label] = []
var target_labels: Array[Label] = []
var status_label: Label
var move_label: Label

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
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var page := VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var title := Label.new()
	title.text = "KROLL // FREQUENCY TUNER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#79e7ff"))
	title.add_theme_font_size_override("font_size", 28)
	page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Three dials. Three coupled signals. One exact lock."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#b5c9d9"))
	page.add_child(subtitle)

	var target_panel := PanelContainer.new()
	target_panel.add_theme_stylebox_override("panel", _panel_style(Color("#10263a"), Color("#2f829a")))
	page.add_child(target_panel)
	var target_box := VBoxContainer.new()
	target_box.add_theme_constant_override("separation", 6)
	target_panel.add_child(target_box)
	var target_title := Label.new()
	target_title.text = "TARGET OUTPUTS"
	target_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_title.add_theme_color_override("font_color", Color("#ffcc75"))
	target_box.add_child(target_title)
	var targets_row := HBoxContainer.new()
	targets_row.alignment = BoxContainer.ALIGNMENT_CENTER
	targets_row.add_theme_constant_override("separation", 28)
	target_box.add_child(targets_row)
	for i in range(3):
		var label := Label.new()
		label.name = "TargetOutput%d" % (i + 1)
		label.text = "OUT %d : 00" % (i + 1)
		label.custom_minimum_size = Vector2(150, 42)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color("#ffd28b"))
		targets_row.add_child(label)
		target_labels.append(label)

	var dials_row := HBoxContainer.new()
	dials_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dials_row.add_theme_constant_override("separation", 14)
	page.add_child(dials_row)
	var dial_names: Array[String] = ["A", "B", "C"]
	for i in range(3):
		var card := PanelContainer.new()
		card.name = "DialCard%d" % (i + 1)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _panel_style(Color("#0c1c2d"), Color("#22556e")))
		dials_row.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		card.add_child(column)
		var dial_title := Label.new()
		dial_title.text = "DIAL %s" % dial_names[i]
		dial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dial_title.add_theme_color_override("font_color", Color("#8eeaff"))
		column.add_child(dial_title)
		var value := Label.new()
		value.name = "DialValue%d" % (i + 1)
		value.text = "0"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 42)
		value.add_theme_color_override("font_color", Color("#ffffff"))
		column.add_child(value)
		frequency_labels.append(value)
		var buttons := HBoxContainer.new()
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons.add_theme_constant_override("separation", 8)
		column.add_child(buttons)
		var minus := _make_button("−", "Dial%dMinus" % (i + 1), Callable(self, "_tune").bind(i, -1))
		var plus := _make_button("+", "Dial%dPlus" % (i + 1), Callable(self, "_tune").bind(i, 1))
		buttons.add_child(minus)
		buttons.add_child(plus)

	var outputs_panel := PanelContainer.new()
	outputs_panel.add_theme_stylebox_override("panel", _panel_style(Color("#10263a"), Color("#2f829a")))
	page.add_child(outputs_panel)
	var outputs_row := HBoxContainer.new()
	outputs_row.alignment = BoxContainer.ALIGNMENT_CENTER
	outputs_row.add_theme_constant_override("separation", 28)
	outputs_panel.add_child(outputs_row)
	for i in range(3):
		var label := Label.new()
		label.name = "CurrentOutput%d" % (i + 1)
		label.text = "OUT %d : 00" % (i + 1)
		label.custom_minimum_size = Vector2(150, 38)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", Color("#80f0c0"))
		outputs_row.add_child(label)
		output_labels.append(label)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Initializing..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#c5d6e5"))
	status_label.add_theme_font_size_override("font_size", 16)
	page.add_child(status_label)

	move_label = Label.new()
	move_label.name = "MoveLabel"
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_label.add_theme_color_override("font_color", Color("#ffcc75"))
	page.add_child(move_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	page.add_child(footer)
	footer.add_child(_make_button("RESTART  [R]", "RestartButton", Callable(self, "restart_game")))
	footer.add_child(_make_button("NEXT SIGNAL  [N]", "NextButton", Callable(self, "next_layout")))

	var controls := Label.new()
	controls.text = "Keyboard: Q/W = A dial −/+   A/S = B dial −/+   Z/X = C dial −/+"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_color_override("font_color", Color("#7f9db4"))
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(controls)

func _panel_style(fill: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _make_button(caption: String, stable_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = stable_name
	button.text = caption
	button.custom_minimum_size = Vector2(118, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color("#e9f8ff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_stylebox_override("normal", _panel_style(Color("#17344a"), Color("#3a829b")))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#20516a"), Color("#79e7ff")))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#0b2435"), Color("#79e7ff")))
	button.pressed.connect(callback)
	return button

func _tune(dial: int, delta: int) -> void:
	var result: Dictionary = Rules.tune(state, dial, delta)
	if bool(result.get("ok", false)):
		state = result["state"]
	_refresh_ui()

func restart_game() -> void:
	state = Rules.new_game(_current_seed)
	_refresh_ui()

func next_layout() -> void:
	_current_seed = Rules.next_seed(_current_seed)
	restart_game()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_Q:
			_tune(0, -1)
		KEY_W:
			_tune(0, 1)
		KEY_A:
			_tune(1, -1)
		KEY_S:
			_tune(1, 1)
		KEY_Z:
			_tune(2, -1)
		KEY_X:
			_tune(2, 1)
		KEY_R:
			restart_game()
		KEY_N:
			next_layout()

func _refresh_ui() -> void:
	if state.is_empty():
		return
	var frequencies: Array = state.get("frequencies", [])
	var targets: Array = state.get("target_outputs", [])
	var outputs: Array[int] = Rules.output_values(frequencies)
	for i in range(3):
		if i < frequency_labels.size():
			frequency_labels[i].text = "%d" % int(frequencies[i])
		if i < output_labels.size() and i < outputs.size():
			output_labels[i].text = "OUT %d : %02d" % [i + 1, outputs[i]]
		if i < target_labels.size() and i < targets.size():
			target_labels[i].text = "OUT %d : %02d" % [i + 1, int(targets[i])]
	status_label.text = str(state.get("message", ""))
	match str(state.get("status", "playing")):
		"won":
			status_label.add_theme_color_override("font_color", Color("#80f0c0"))
		"failed":
			status_label.add_theme_color_override("font_color", Color("#ff8f86"))
		_:
			status_label.add_theme_color_override("font_color", Color("#c5d6e5"))
	move_label.text = "SEED %d     MOVES %02d / %02d     STATUS %s" % [
		int(state.get("seed", 0)),
		int(state.get("moves", 0)),
		int(state.get("move_limit", Rules.MOVE_LIMIT)),
		str(state.get("status", "playing")).to_upper()
	]

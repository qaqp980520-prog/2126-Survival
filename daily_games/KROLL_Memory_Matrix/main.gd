extends Control

const Rules = preload("res://rules.gd")
const DEFAULT_SEED: int = 20261028

var state: Dictionary = {}
var tile_buttons: Array[Button] = []
var status_label: Label
var sequence_label: Label
var feedback_label: Label
var _sequence_token: int = 0

func _ready() -> void:
	_build_ui()
	_new_game()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.025, 0.045, 0.085)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "KROLL // MEMORY MATRIX"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	layout.add_child(title)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	layout.add_child(status_label)

	sequence_label = Label.new()
	sequence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sequence_label.add_theme_font_size_override("font_size", 16)
	layout.add_child(sequence_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	layout.add_child(grid)

	for index in range(Rules.TILE_COUNT):
		var button := Button.new()
		button.name = "SignalTile%d" % (index + 1)
		button.text = "%d" % (index + 1)
		button.custom_minimum_size = Vector2(116, 78)
		button.add_theme_font_size_override("font_size", 24)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_tile_pressed.bind(index))
		grid.add_child(button)
		tile_buttons.append(button)

	feedback_label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(feedback_label)

	var restart := Button.new()
	restart.text = "RESTART  [R]"
	restart.custom_minimum_size = Vector2(180, 42)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(_new_game)
	layout.add_child(restart)

func _new_game() -> void:
	_sequence_token += 1
	state = Rules.create_game(DEFAULT_SEED)
	_refresh_ui()
	call_deferred("_show_sequence")

func _show_sequence() -> void:
	if str(state.get("status", "")) != "showing":
		return
	_sequence_token += 1
	var token := _sequence_token
	sequence_label.text = "MEMORIZE THE SIGNALS"
	_refresh_ui()
	var sequence: Array = state.get("sequence", [])
	for raw_tile in sequence:
		if token != _sequence_token:
			return
		var tile_index := int(raw_tile)
		_set_tile_highlight(tile_index, true)
		await get_tree().create_timer(0.32).timeout
		if token != _sequence_token:
			return
		_set_tile_highlight(tile_index, false)
		await get_tree().create_timer(0.12).timeout
	if token != _sequence_token:
		return
	Rules.begin_input(state)
	sequence_label.text = "YOUR TURN // REPEAT THE SEQUENCE"
	_refresh_ui()

func _on_tile_pressed(tile_index: int) -> void:
	if not Rules.press_tile(state, tile_index):
		return
	_refresh_ui()
	if str(state.get("status", "")) == "showing":
		call_deferred("_show_sequence")

func _set_tile_highlight(tile_index: int, active: bool) -> void:
	if tile_index < 0 or tile_index >= tile_buttons.size():
		return
	tile_buttons[tile_index].modulate = Color(0.25, 1.0, 1.0) if active else Color.WHITE

func _refresh_ui() -> void:
	if status_label == null:
		return
	var status := str(state.get("status", "showing"))
	status_label.text = "ROUND %d / %d     MISTAKES %d / %d" % [
		int(state.get("round", 1)), Rules.MAX_ROUNDS,
		int(state.get("mistakes", 0)), Rules.MAX_MISTAKES
	]
	if status == "won":
		sequence_label.text = "ALL SIGNALS RESTORED"
	elif status == "lost":
		sequence_label.text = "SIGNAL INTEGRITY LOST"
	elif status == "input":
		sequence_label.text = "YOUR TURN // REPEAT THE SEQUENCE"
	else:
		sequence_label.text = "MEMORIZE THE SIGNALS"
	feedback_label.text = str(state.get("message", ""))
	for button in tile_buttons:
		button.disabled = status != "input"

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var tile_index := -1
	match key_event.keycode:
		KEY_1: tile_index = 0
		KEY_2: tile_index = 1
		KEY_3: tile_index = 2
		KEY_4: tile_index = 3
		KEY_5: tile_index = 4
		KEY_6: tile_index = 5
		KEY_7: tile_index = 6
		KEY_8: tile_index = 7
		KEY_9: tile_index = 8
		KEY_R:
			_new_game()
			get_viewport().set_input_as_handled()
			return
	if tile_index >= 0:
		_on_tile_pressed(tile_index)
		get_viewport().set_input_as_handled()

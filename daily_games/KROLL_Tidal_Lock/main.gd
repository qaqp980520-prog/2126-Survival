extends Control

const Rules = preload("res://rules.gd")
var state: Dictionary = {}
var seed_cursor: int = 0
var status_label: Label
var details_label: Label
var feedback_message: String = ""
var chamber_labels: Array[Label] = []
var action_buttons: Dictionary = {}

func _ready() -> void:
	state = Rules.new_game(Rules.SEEDS[seed_cursor])
	_build_ui()
	_render()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_A, KEY_LEFT:
			_act(Rules.move_boat(state, -1))
		KEY_D, KEY_RIGHT:
			_act(Rules.move_boat(state, 1))
		KEY_SPACE:
			_act(Rules.toggle_gate(state))
		KEY_W, KEY_UP:
			_act(Rules.pump(state, 1))
		KEY_S, KEY_DOWN:
			_act(Rules.pump(state, -1))
		KEY_R:
			restart_game()
		KEY_N:
			next_layout()

func _build_ui() -> void:
	var root_box := VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 16)
	root_box.add_theme_constant_override("margin_left", 24)
	root_box.add_theme_constant_override("margin_right", 24)
	root_box.add_theme_constant_override("margin_top", 20)
	root_box.add_theme_constant_override("margin_bottom", 20)
	add_child(root_box)

	var title := Label.new()
	title.text = "KROLL // TIDAL LOCK"
	title.add_theme_font_size_override("font_size", 30)
	root_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Balance adjacent water levels, open each gate, and guide the vessel through four chambers."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(subtitle)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	root_box.add_child(status_label)
	details_label = Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(details_label)

	var chamber_row := HBoxContainer.new()
	chamber_row.add_theme_constant_override("separation", 10)
	root_box.add_child(chamber_row)
	for index in range(Rules.CHAMBER_COUNT):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.custom_minimum_size = Vector2(120, 150)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 17)
		panel.add_child(label)
		chamber_row.add_child(panel)
		chamber_labels.append(label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root_box.add_child(actions)
	_add_button(actions, "MOVE LEFT (A)", "left", func(): _act(Rules.move_boat(state, -1)))
	_add_button(actions, "MOVE RIGHT (D)", "right", func(): _act(Rules.move_boat(state, 1)))
	_add_button(actions, "TOGGLE GATE (SPACE)", "gate", func(): _act(Rules.toggle_gate(state)))
	var pumps := HBoxContainer.new()
	pumps.add_theme_constant_override("separation", 8)
	root_box.add_child(pumps)
	_add_button(pumps, "PUMP + (W)", "pump_up", func(): _act(Rules.pump(state, 1)))
	_add_button(pumps, "PUMP - (S)", "pump_down", func(): _act(Rules.pump(state, -1)))
	_add_button(pumps, "RESTART (R)", "restart", restart_game)
	_add_button(pumps, "NEXT LAYOUT (N)", "next", next_layout)

	var footer := Label.new()
	footer.text = "Rules: one level of pressure difference maximum; 10 actions; 3 pump units."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(footer)

func _add_button(parent: Container, text_value: String, key: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(callback)
	parent.add_child(button)
	action_buttons[key] = button

func _act(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		state = result.get("state", state)
		feedback_message = str(state.get("message", ""))
	else:
		feedback_message = "ACTION BLOCKED: " + str(result.get("reason", "unknown"))
	_render()

func restart_game() -> void:
	state = Rules.new_game(int(state.get("seed", 7)))
	feedback_message = str(state.get("message", ""))
	_render()

func next_layout() -> void:
	seed_cursor = (seed_cursor + 1) % Rules.SEEDS.size()
	state = Rules.new_game(Rules.SEEDS[seed_cursor])
	feedback_message = str(state.get("message", ""))
	_render()

func _render() -> void:
	if state.is_empty() or status_label == null:
		return
	status_label.text = "STATUS: %s    TURN: %d/%d    PUMP ENERGY: %d" % [
		str(state.get("status", "unknown")).to_upper(),
		int(state.get("turns", 0)), Rules.MAX_TURNS, int(state.get("pump_energy", 0))
	]
	details_label.text = feedback_message if not feedback_message.is_empty() else str(state.get("message", ""))
	var levels: Array = state.get("levels", [])
	var gates: Array = state.get("gates", [])
	var position: int = int(state.get("position", 0))
	for index in range(chamber_labels.size()):
		var marker: String = "  < VESSEL >" if index == position else ""
		var gate_text: String = ""
		if index < gates.size():
			gate_text = "\nGATE %d: %s" % [index + 1, "OPEN" if bool(gates[index]) else "CLOSED"]
		chamber_labels[index].text = "CHAMBER %d%s\n\nWATER LEVEL\n%d%s" % [index + 1, marker, int(levels[index]), gate_text]
	for key in action_buttons.keys():
		action_buttons[key].disabled = str(state.get("status", "")) != "playing"

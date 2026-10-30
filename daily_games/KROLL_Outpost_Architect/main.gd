extends Control

const Rules = preload("res://rules.gd")

var state: Dictionary = {}
var layout_index: int = 0
var selected_card: int = -1
var focused_cell: int = 0
var board_grid: GridContainer
var board_buttons: Array[Button] = []
var hand_buttons: Array[Button] = []
var status_label: Label
var layout_label: Label
var restart_button: Button
var next_button: Button
var _message: String = ""

func _ready() -> void:
	_build_ui()
	_start_layout(0)
	set_process_unhandled_key_input(true)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var title := Label.new()
	title.text = "KROLL // OUTPOST ARCHITECT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	content.add_child(title)

	layout_label = Label.new()
	layout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout_label.add_theme_font_size_override("font_size", 17)
	content.add_child(layout_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	content.add_child(status_label)

	var board_center := CenterContainer.new()
	board_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(board_center)

	board_grid = GridContainer.new()
	board_grid.columns = Rules.BOARD_WIDTH
	board_grid.add_theme_constant_override("h_separation", 5)
	board_grid.add_theme_constant_override("v_separation", 5)
	board_center.add_child(board_grid)
	for cell_index in range(Rules.BOARD_CELLS):
		var cell_button := Button.new()
		cell_button.custom_minimum_size = Vector2(64, 58)
		cell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell_button.focus_mode = Control.FOCUS_ALL
		cell_button.pressed.connect(_on_board_pressed.bind(cell_index))
		board_grid.add_child(cell_button)
		board_buttons.append(cell_button)

	var hand_title := Label.new()
	hand_title.text = "MODULE HAND // choose a module, then choose a cell"
	hand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hand_title)

	var hand_row := HBoxContainer.new()
	hand_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_row.add_theme_constant_override("separation", 8)
	content.add_child(hand_row)
	for card_index in range(Rules.HAND_SIZE):
		var card_button := Button.new()
		card_button.custom_minimum_size = Vector2(120, 58)
		card_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_button.pressed.connect(_on_hand_pressed.bind(card_index))
		hand_row.add_child(card_button)
		hand_buttons.append(card_button)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	content.add_child(controls)

	restart_button = Button.new()
	restart_button.text = "RESTART (R)"
	restart_button.pressed.connect(_restart)
	controls.add_child(restart_button)

	next_button = Button.new()
	next_button.text = "NEXT OUTPOST (N)"
	next_button.pressed.connect(_next_layout)
	controls.add_child(next_button)

	var help := Label.new()
	help.text = "Keyboard: 1-3 select module · arrows move focus · Enter place · R restart · N next outpost"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 13)
	content.add_child(help)

func _start_layout(next_layout: int) -> void:
	layout_index = posmod(next_layout, Rules.layout_count())
	state = Rules.new_game(layout_index)
	selected_card = -1
	focused_cell = 0
	_message = "Place 8 modules. Keep within the energy budget and connect the four essential systems."
	_refresh_ui()

func _restart() -> void:
	_start_layout(layout_index)

func _next_layout() -> void:
	_start_layout(layout_index + 1)

func _on_hand_pressed(card_index: int) -> void:
	if str(state.get("result", "")) != "playing":
		return
	var hand: Array = state.get("hand", [])
	if card_index < 0 or card_index >= hand.size():
		return
	selected_card = card_index
	_message = "Selected %s. Choose an empty cell." % _module_name(str(hand[card_index]))
	_refresh_ui()

func _on_board_pressed(cell_index: int) -> void:
	if str(state.get("result", "")) != "playing":
		return
	focused_cell = cell_index
	if selected_card < 0:
		_message = "Choose a module from the hand first."
		_refresh_ui()
		return
	var hand: Array = state.get("hand", [])
	var module_id: String = str(hand[selected_card]) if selected_card < hand.size() else ""
	var result: Dictionary = Rules.place_module(state, selected_card, cell_index)
	if not bool(result.get("ok", false)):
		_message = _reason_text(str(result.get("reason", "invalid")))
		_refresh_ui()
		return
	selected_card = -1
	var game_result: String = str(state.get("result", "playing"))
	if game_result == "won":
		_message = "OUTPOST ONLINE // target reached with all essential systems connected."
	elif game_result == "lost":
		_message = "OUTPOST INCOMPLETE // score or essential-system requirement not met. Restart and redesign."
	else:
		_message = "Placed %s." % _module_name(module_id)
	_refresh_ui()

func _refresh_ui() -> void:
	if state.is_empty():
		return
	layout_label.text = "%s // LAYOUT %d OF %d" % [Rules.layout_name(layout_index), layout_index + 1, Rules.layout_count()]
	var turns_used: int = Rules.PLACEMENT_LIMIT - int(state.get("turns_left", 0))
	status_label.text = "ENERGY %d / %d     SCORE %d / %d     PLACEMENTS %d / %d\n%s" % [
		int(state.get("energy", 0)),
		Rules.STARTING_ENERGY,
		int(state.get("score", 0)),
		int(state.get("target_score", 0)),
		turns_used,
		Rules.PLACEMENT_LIMIT,
		_message
	]
	var board: Dictionary = state.get("board", {})
	var result: String = str(state.get("result", "playing"))
	for cell_index in range(board_buttons.size()):
		var module_id: String = str(board.get(cell_index, ""))
		var cell_text: String = "·" if module_id.is_empty() else _module_short_name(module_id)
		if cell_index == focused_cell:
			cell_text = "[" + cell_text + "]"
		board_buttons[cell_index].text = cell_text
		board_buttons[cell_index].disabled = result != "playing" or not module_id.is_empty()
		board_buttons[cell_index].modulate = Color(0.55, 0.9, 1.0) if not module_id.is_empty() else Color(1.0, 1.0, 1.0)
	var hand: Array = state.get("hand", [])
	for card_index in range(hand_buttons.size()):
		if card_index >= hand.size():
			hand_buttons[card_index].text = "EMPTY"
			hand_buttons[card_index].disabled = true
			continue
		var card_id: String = str(hand[card_index])
		var prefix: String = "▶ " if selected_card == card_index else ""
		hand_buttons[card_index].text = "%s%s\n%d ENERGY" % [prefix, _module_name(card_id), Rules.module_cost(card_id)]
		hand_buttons[card_index].disabled = result != "playing"
		hand_buttons[card_index].modulate = Color(0.7, 1.0, 0.75) if selected_card == card_index else Color(1.0, 1.0, 1.0)
	restart_button.disabled = false
	next_button.disabled = false

func _module_name(module_id: String) -> String:
	match module_id:
		"power":
			return "Power"
		"water":
			return "Water"
		"greenhouse":
			return "Greenhouse"
		"habitat":
			return "Habitat"
		"workshop":
			return "Workshop"
		"relay":
			return "Relay"
	return "Unknown"

func _module_short_name(module_id: String) -> String:
	match module_id:
		"power":
			return "PWR"
		"water":
			return "H2O"
		"greenhouse":
			return "GRN"
		"habitat":
			return "HAB"
		"workshop":
			return "WRK"
		"relay":
			return "RLY"
	return "?"

func _reason_text(reason: String) -> String:
	match reason:
		"occupied":
			return "That cell is already occupied."
		"insufficient_energy":
			return "Not enough energy for that module."
		"invalid_cell":
			return "That cell is outside the grid."
		"invalid_card":
			return "Choose a card that is still in your hand."
		"finished":
			return "This outpost is finished. Restart or choose another layout."
	return "The placement was rejected."

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_on_hand_pressed(0)
		KEY_2:
			_on_hand_pressed(1)
		KEY_3:
			_on_hand_pressed(2)
		KEY_LEFT:
			_move_focus(-1, 0)
		KEY_RIGHT:
			_move_focus(1, 0)
		KEY_UP:
			_move_focus(0, -1)
		KEY_DOWN:
			_move_focus(0, 1)
		KEY_ENTER:
			_on_board_pressed(focused_cell)
		KEY_SPACE:
			_on_board_pressed(focused_cell)
		KEY_R:
			_restart()
		KEY_N:
			_next_layout()

func _move_focus(dx: int, dy: int) -> void:
	var x: int = focused_cell % Rules.BOARD_WIDTH
	var y: int = int(focused_cell / Rules.BOARD_WIDTH)
	x = clampi(x + dx, 0, Rules.BOARD_WIDTH - 1)
	y = clampi(y + dy, 0, Rules.BOARD_WIDTH - 1)
	focused_cell = y * Rules.BOARD_WIDTH + x
	board_buttons[focused_cell].grab_focus()
	_refresh_ui()

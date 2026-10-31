extends Control

const RulesScript = preload("res://rules.gd")

var _state: Dictionary = {}
var _cell_buttons: Dictionary = {}
var _selected_cell: Vector2i = Vector2i(0, 2)
var _selected_direction: int = RulesScript.DIRECTION_RIGHT
var _status_label: Label
var _budget_label: Label
var _campaign_complete: bool = false

func _ready() -> void:
	_state = RulesScript.create_state(0)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#08131d")
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
	title.text = "KROLL CONVEYOR ARCHITECT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#65e6ff"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ROUTE CARGO THROUGH THE FACTORY GRID"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	column.add_child(subtitle)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_status_label)
	_budget_label = Label.new()
	_budget_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_budget_label.add_theme_color_override("font_color", Color("#b6d3df"))
	column.add_child(_budget_label)
	var board := GridContainer.new()
	board.name = "FactoryGrid"
	board.columns = RulesScript.GRID_WIDTH
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board.add_theme_constant_override("h_separation", 6)
	board.add_theme_constant_override("v_separation", 6)
	column.add_child(board)
	for y in range(RulesScript.GRID_HEIGHT):
		for x in range(RulesScript.GRID_WIDTH):
			var cell := Vector2i(x, y)
			var button := Button.new()
			button.custom_minimum_size = Vector2(112.0, 68.0)
			button.add_theme_font_size_override("font_size", 17)
			button.pressed.connect(_on_cell_pressed.bind(cell))
			board.add_child(button)
			_cell_buttons[RulesScript.cell_key(cell)] = button
	var direction_row := HBoxContainer.new()
	direction_row.alignment = BoxContainer.ALIGNMENT_CENTER
	direction_row.add_theme_constant_override("separation", 6)
	column.add_child(direction_row)
	for direction in range(RulesScript.DIRECTION_GLYPHS.size()):
		var direction_button := Button.new()
		direction_button.text = RulesScript.DIRECTION_GLYPHS[direction]
		direction_button.custom_minimum_size = Vector2(58.0, 48.0)
		direction_button.pressed.connect(_set_selected_direction.bind(direction))
		direction_row.add_child(direction_button)
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	column.add_child(action_row)
	var step_button := Button.new()
	step_button.text = "ADVANCE CARGO"
	step_button.custom_minimum_size = Vector2(180.0, 48.0)
	step_button.pressed.connect(advance_cargo)
	action_row.add_child(step_button)
	var reset_button := Button.new()
	reset_button.text = "RESET"
	reset_button.custom_minimum_size = Vector2(100.0, 48.0)
	reset_button.pressed.connect(reset_level)
	action_row.add_child(reset_button)
	var next_button := Button.new()
	next_button.text = "NEXT"
	next_button.custom_minimum_size = Vector2(100.0, 48.0)
	next_button.pressed.connect(advance_level)
	action_row.add_child(next_button)
	var help := Label.new()
	help.text = "Tap a cell to place/rotate a conveyor. Arrow keys set its direction; Space advances cargo; R resets; N advances after delivery. Touch buttons are available above."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color("#91aab8"))
	column.add_child(help)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_UP, KEY_W:
			_set_selected_direction(RulesScript.DIRECTION_UP)
		KEY_RIGHT, KEY_D:
			_set_selected_direction(RulesScript.DIRECTION_RIGHT)
		KEY_DOWN, KEY_S:
			_set_selected_direction(RulesScript.DIRECTION_DOWN)
		KEY_LEFT, KEY_A:
			_set_selected_direction(RulesScript.DIRECTION_LEFT)
		KEY_SPACE:
			advance_cargo()
		KEY_R:
			reset_level()
		KEY_N:
			advance_level()

func _on_cell_pressed(cell: Vector2i) -> void:
	_selected_cell = cell
	var existing: int = RulesScript.get_conveyor_direction(_state, cell)
	var direction: int = _selected_direction if existing < 0 else (existing + 1) % RulesScript.DIRECTION_GLYPHS.size()
	var result: Dictionary = apply_conveyor(cell, direction)
	if not bool(result.get("ok", false)):
		_state["message"] = "Cannot place conveyor: %s." % str(result.get("reason", "unknown"))
	_refresh()

func _set_selected_direction(direction: int) -> void:
	_selected_direction = direction
	var result: Dictionary = apply_conveyor(_selected_cell, direction)
	if not bool(result.get("ok", false)):
		_state["message"] = "Direction not applied: %s." % str(result.get("reason", "unknown"))
	_refresh()

func apply_conveyor(cell: Vector2i, direction: int) -> Dictionary:
	var result: Dictionary = RulesScript.place_conveyor(_state, cell, direction)
	_refresh()
	return result

func advance_cargo() -> Dictionary:
	var result: Dictionary = RulesScript.advance(_state)
	_refresh()
	return result

func reset_level() -> void:
	_state = RulesScript.create_state(int(_state.get("level_index", 0)))
	_campaign_complete = false
	_refresh()

func advance_level() -> bool:
	if str(_state.get("status", "")) != "delivered":
		_state["message"] = "Deliver the cargo before advancing."
		_refresh()
		return false
	var next_index: int = int(_state.get("level_index", 0)) + 1
	if next_index >= RulesScript.get_level_count():
		_campaign_complete = true
		_state["message"] = "CAMPAIGN COMPLETE: all KROLL work orders delivered."
		_refresh()
		return true
	_state = RulesScript.create_state(next_index)
	_campaign_complete = false
	_selected_cell = _state.get("start", Vector2i.ZERO)
	_refresh()
	return true

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func get_current_level() -> String:
	return str(_state.get("level_id", ""))

func _refresh() -> void:
	if _state.is_empty():
		return
	var walls: Array = _state.get("walls", [])
	var conveyors: Dictionary = _state.get("conveyors", {})
	var position: Vector2i = _state.get("position", Vector2i.ZERO)
	var start: Vector2i = _state.get("start", Vector2i.ZERO)
	var goal: Vector2i = _state.get("goal", Vector2i.ZERO)
	for y in range(RulesScript.GRID_HEIGHT):
		for x in range(RulesScript.GRID_WIDTH):
			var cell := Vector2i(x, y)
			var key: String = RulesScript.cell_key(cell)
			var button: Button = _cell_buttons.get(key) as Button
			if button == null:
				continue
			var label_text := ""
			if walls.has(cell):
				label_text = "BLOCK"
			elif cell == goal:
				label_text = "DOCK"
			elif cell == position:
				label_text = "CARGO"
			elif cell == start:
				label_text = "IN"
			else:
				label_text = "·"
			if conveyors.has(key):
				label_text += "\n" + RulesScript.DIRECTION_GLYPHS[int(conveyors[key])]
			button.text = label_text
			button.disabled = walls.has(cell) or cell == goal
			button.modulate = Color("#1c4558") if cell == _selected_cell else Color.WHITE
			if cell == position:
				button.modulate = Color("#f2b45e")
			elif cell == goal:
				button.modulate = Color("#59d59a")
			elif walls.has(cell):
				button.modulate = Color("#293640")
	if _status_label != null:
		var level_title: String = str(_state.get("title", ""))
		var message: String = str(_state.get("message", ""))
		_status_label.text = "%s — %s\n%s" % [level_title, "CAMPAIGN COMPLETE" if _campaign_complete else str(_state.get("status", "")).to_upper(), message]
	if _budget_label != null:
		_budget_label.text = "Conveyors: %d / %d    Steps: %d / %d" % [
			int(_state.get("placements_used", 0)),
			int(_state.get("placement_budget", 0)),
			int(_state.get("steps", 0)),
			int(_state.get("max_steps", 0))
		]

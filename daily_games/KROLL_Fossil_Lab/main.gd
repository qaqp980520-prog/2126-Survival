extends Node2D

const Rules = preload("res://rules.gd")
const BACKGROUND := Color(0.012, 0.022, 0.04)
const BOARD_ORIGIN := Vector2(320.0, 150.0)
const CELL_SIZE: float = 60.0
const PIECE_COLORS: Array[Color] = [
	Color(0.22, 0.84, 0.95),
	Color(0.98, 0.62, 0.25),
	Color(0.42, 0.86, 0.52),
	Color(0.78, 0.54, 0.96)
]

var scenario_index: int = 0
var scenario: Dictionary = {}
var state: Dictionary = {}
var hud: Label
var status_label: Label
var buttons: Dictionary = {}

func _ready() -> void:
	_build_ui()
	_load_scenario(0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Label.new()
	hud.name = "FossilStatus"
	hud.position = Vector2(18.0, 14.0)
	hud.size = Vector2(920.0, 74.0)
	hud.add_theme_color_override("font_color", Color(0.72, 0.93, 1.0))
	hud.add_theme_font_size_override("font_size", 18)
	layer.add_child(hud)
	status_label = Label.new()
	status_label.name = "FossilMessage"
	status_label.position = Vector2(18.0, 92.0)
	status_label.size = Vector2(920.0, 30.0)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.34))
	layer.add_child(status_label)
	var panel := PanelContainer.new()
	panel.name = "TouchControls"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -450.0
	panel.offset_right = 450.0
	panel.offset_top = -82.0
	panel.offset_bottom = -8.0
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	for index in range(Rules.PIECE_COUNT):
		_add_button(row, "piece_%d" % index, "P%d" % (index + 1), Callable(self, "_select_piece").bind(index), Vector2(58.0, 52.0))
	_add_button(row, "rotate_left", "ROT -", Callable(self, "_rotate_selected").bind(-1), Vector2(78.0, 52.0))
	_add_button(row, "rotate_right", "ROT +", Callable(self, "_rotate_selected").bind(1), Vector2(78.0, 52.0))
	_add_button(row, "place", "PLACE", Callable(self, "_place_selected"), Vector2(78.0, 52.0))
	_add_button(row, "undo", "UNDO", Callable(self, "_undo_selected"), Vector2(72.0, 52.0))
	_add_button(row, "reset", "RESET", Callable(self, "_restart"), Vector2(72.0, 52.0))
	_add_button(row, "next", "NEXT", Callable(self, "_next_scenario"), Vector2(72.0, 52.0))

func _add_button(parent: HBoxContainer, key: String, label_text: String, callback: Callable, minimum_size: Vector2) -> void:
	var button := Button.new()
	button.name = "Action_" + key
	button.text = label_text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 12)
	parent.add_child(button)
	buttons[key] = button
	button.pressed.connect(callback)

func _load_scenario(index: int) -> void:
	scenario_index = posmod(index, Rules.get_scenario_count())
	scenario = Rules.get_scenario(scenario_index)
	state = Rules.create_state(scenario_index)
	status_label.text = "Place every bone fragment inside the amber fossil outline. No overlap."
	_refresh()

func _select_piece(index: int) -> void:
	state = Rules.select_piece(state, index)
	_refresh()

func _rotate_selected(direction: int) -> void:
	state = Rules.rotate_selected(state, direction)
	_refresh()

func _move_cursor(delta: Vector2i) -> void:
	state = Rules.move_cursor(state, delta)
	_refresh()

func _place_selected() -> void:
	var previous_moves: int = int(state.get("moves", 0))
	state = Rules.place_selected(state, scenario)
	if str(state.get("status", "")) == "won":
		status_label.text = "FOSSIL RESTORED — all fragments aligned."
	elif int(state.get("moves", 0)) > previous_moves:
		status_label.text = "Fragment secured. Continue the reconstruction."
	else:
		status_label.text = "That fragment does not fit the highlighted fossil area."
	_refresh()

func _undo_selected() -> void:
	state = Rules.remove_selected(state)
	status_label.text = "Selected fragment returned to the tray."
	_refresh()

func _restart() -> void:
	_load_scenario(scenario_index)

func _next_scenario() -> void:
	_load_scenario(scenario_index + 1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_1: _select_piece(0)
				KEY_2: _select_piece(1)
				KEY_3: _select_piece(2)
				KEY_4: _select_piece(3)
				KEY_A: _move_cursor(Vector2i(-1, 0))
				KEY_D: _move_cursor(Vector2i(1, 0))
				KEY_W: _move_cursor(Vector2i(0, -1))
				KEY_S: _move_cursor(Vector2i(0, 1))
				KEY_Q: _rotate_selected(-1)
				KEY_E: _rotate_selected(1)
				KEY_SPACE: _place_selected()
				KEY_BACKSPACE: _undo_selected()
				KEY_R: _restart()
				KEY_N: _next_scenario()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_position: Vector2 = get_global_mouse_position()
			var cell := Vector2i(
				floori((mouse_position.x - BOARD_ORIGIN.x) / CELL_SIZE),
				floori((mouse_position.y - BOARD_ORIGIN.y) / CELL_SIZE)
			)
			if cell.x >= 0 and cell.y >= 0 and cell.x < Rules.BOARD_SIZE and cell.y < Rules.BOARD_SIZE:
				state = Rules.set_cursor(state, cell)
				_place_selected()

func _refresh() -> void:
	if hud == null or status_label == null:
		return
	var placements: Dictionary = state.get("placements", {})
	var selected: int = int(state.get("selected_piece", 0))
	var rotations: Array = state.get("rotations", [0, 0, 0, 0])
	var rotation: int = int(rotations[selected])
	hud.text = "KROLL FOSSIL LAB // %s\nFRAGMENTS %d/%d   SELECTED %s   ROTATION %d°   PLACEMENTS %d" % [
		str(scenario.get("name", "UNKNOWN")), placements.size(), Rules.PIECE_COUNT,
		Rules.get_piece_name(selected), rotation * 90, int(state.get("moves", 0))
	]
	if str(state.get("status", "")) == "won":
		status_label.text = "FOSSIL RESTORED — all fragments aligned."
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960.0, 640.0)), BACKGROUND)
	for y in range(Rules.BOARD_SIZE):
		for x in range(Rules.BOARD_SIZE):
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			draw_rect(rect, Color(0.045, 0.075, 0.105), true)
			draw_rect(rect, Color(0.18, 0.29, 0.36), false, 1.5)
	for cell in Rules.get_target_cells(scenario):
		draw_rect(_cell_rect(cell).grow(-5.0), Color(0.96, 0.62, 0.23, 0.22), true)
		draw_rect(_cell_rect(cell).grow(-5.0), Color(1.0, 0.73, 0.36, 0.68), false, 1.5)
	var placements: Dictionary = state.get("placements", {})
	for key in placements.keys():
		var piece_index: int = int(key)
		var placement: Dictionary = placements[key]
		for cell in Rules.get_piece_cells(piece_index, int(placement.get("rotation", 0)), placement.get("anchor", Vector2i.ZERO)):
			var rect := _cell_rect(cell).grow(-4.0)
			draw_rect(rect, PIECE_COLORS[piece_index], true)
			draw_rect(rect, Color(0.88, 0.97, 1.0), false, 2.0)
	var selected: int = int(state.get("selected_piece", 0))
	var rotations: Array = state.get("rotations", [0, 0, 0, 0])
	var cursor: Vector2i = state.get("cursor", Vector2i.ZERO)
	if not placements.has(selected):
		var preview_cells: Array[Vector2i] = Rules.get_piece_cells(selected, int(rotations[selected]), cursor)
		var can_fit: bool = Rules.can_place(state, scenario, selected, cursor, int(rotations[selected]))
		var preview_color := Color(0.26, 0.94, 0.66, 0.38) if can_fit else Color(1.0, 0.25, 0.24, 0.32)
		for cell in preview_cells:
			if cell.x >= 0 and cell.y >= 0 and cell.x < Rules.BOARD_SIZE and cell.y < Rules.BOARD_SIZE:
				draw_rect(_cell_rect(cell).grow(-7.0), preview_color, true)
	var cursor_rect := _cell_rect(cursor).grow(-2.0)
	draw_rect(cursor_rect, Color(0.4, 0.94, 1.0), false, 3.0)

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(BOARD_ORIGIN + Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)

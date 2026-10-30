extends Node2D

const Rules = preload("res://rules.gd")
const BOARD_ORIGIN: Vector2 = Vector2(48.0, 70.0)
const CELL_SIZE: float = 68.0

var level_index: int = 0
var state: Dictionary = {}
var status_label: Label
var help_label: Label

func _ready() -> void:
	_load_level(0)
	_build_ui()
	_refresh_ui()

func _draw() -> void:
	if state.is_empty():
		return
	var walls: Array = state.get("walls", [])
	var player_position: Vector2i = Vector2i(state["player"])
	var crate_position: Vector2i = Vector2i(state["crate"])
	var goal_position: Vector2i = Vector2i(state["goal"])
	for y in range(Rules.BOARD_SIZE):
		for x in range(Rules.BOARD_SIZE):
			var cell := Vector2i(x, y)
			var rect := Rect2(BOARD_ORIGIN + Vector2(float(x), float(y)) * CELL_SIZE, Vector2(CELL_SIZE - 4.0, CELL_SIZE - 4.0))
			draw_rect(rect, Color("#172b3e"), true)
			if walls.has(cell):
				draw_rect(rect, Color("#435367"), true)
			if cell == goal_position:
				draw_rect(rect, Color("#1d765d"), true)
			if cell == crate_position:
				draw_rect(rect.grow(-12.0), Color("#e6a34b"), true)
			if cell == player_position:
				draw_circle(rect.get_center(), 19.0, Color("#42d7f2"))

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var panel := PanelContainer.new()
	panel.name = "ControlPanel"
	panel.position = Vector2(560.0, 48.0)
	panel.custom_minimum_size = Vector2(340.0, 550.0)
	hud.add_child(panel)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 6)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "KROLL // MAGNETIC MAZE"
	title.add_theme_font_size_override("font_size", 20)
	layout.add_child(title)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.custom_minimum_size = Vector2(300.0, 96.0)
	status_label.add_theme_font_size_override("font_size", 16)
	layout.add_child(status_label)

	help_label = Label.new()
	help_label.text = "WASD / arrows: move and face\nSPACE: magnetic pulse\nTAB: toggle PUSH / PULL\nR: restart   N: next layout"
	help_label.custom_minimum_size = Vector2(300.0, 72.0)
	layout.add_child(help_label)

	var dpad := GridContainer.new()
	dpad.name = "DPad"
	dpad.columns = 3
	layout.add_child(dpad)
	_add_spacer(dpad)
	_add_button(dpad, "MoveUp", "UP", Callable(self, "_move_up"), Vector2(88.0, 38.0))
	_add_spacer(dpad)
	_add_button(dpad, "MoveLeft", "LEFT", Callable(self, "_move_left"), Vector2(88.0, 38.0))
	_add_button(dpad, "MoveDown", "DOWN", Callable(self, "_move_down"), Vector2(88.0, 38.0))
	_add_button(dpad, "MoveRight", "RIGHT", Callable(self, "_move_right"), Vector2(88.0, 38.0))

	_add_button(layout, "Pulse", "MAGNETIC PULSE", Callable(self, "_pulse"))
	_add_button(layout, "ToggleMode", "TOGGLE PUSH / PULL", Callable(self, "_toggle_mode"))
	_add_button(layout, "Restart", "RESTART", Callable(self, "_restart"))
	_add_button(layout, "NextLevel", "NEXT LAYOUT", Callable(self, "_next_level"))

func _add_spacer(parent: Control) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(88.0, 38.0)
	parent.add_child(spacer)

func _add_button(parent: Control, node_name: String, caption: String, callback: Callable, minimum_size: Vector2 = Vector2(300.0, 38.0)) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.custom_minimum_size = minimum_size
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_W, KEY_UP:
			_move(Vector2i.UP)
		KEY_A, KEY_LEFT:
			_move(Vector2i.LEFT)
		KEY_S, KEY_DOWN:
			_move(Vector2i.DOWN)
		KEY_D, KEY_RIGHT:
			_move(Vector2i.RIGHT)
		KEY_SPACE:
			_pulse()
		KEY_TAB:
			_toggle_mode()
		KEY_R:
			_restart()
		KEY_N:
			_next_level()

func _load_level(index: int) -> void:
	level_index = posmod(index, Rules.LEVEL_COUNT)
	state = Rules.create_state(level_index)
	queue_redraw()
	_refresh_ui()

func _move(direction: Vector2i) -> void:
	var result: Dictionary = Rules.move_player(state, direction)
	state = result.get("state", state)
	_refresh_ui()

func _pulse() -> void:
	var result: Dictionary = Rules.pulse(state)
	state = result.get("state", state)
	_refresh_ui()

func _toggle_mode() -> void:
	var result: Dictionary = Rules.toggle_mode(state)
	state = result.get("state", state)
	_refresh_ui()

func _move_up() -> void:
	_move(Vector2i.UP)

func _move_left() -> void:
	_move(Vector2i.LEFT)

func _move_down() -> void:
	_move(Vector2i.DOWN)

func _move_right() -> void:
	_move(Vector2i.RIGHT)

func _restart() -> void:
	_load_level(level_index)

func _next_level() -> void:
	_load_level(level_index + 1)

func _refresh_ui() -> void:
	if status_label == null:
		queue_redraw()
		return
	var status: String = Rules.get_status(state).to_upper()
	status_label.text = "%s\nMODE: %s\nCHARGES: %d\nACTIONS: %d / %d\nSTATUS: %s" % [
		Rules.get_level_name(level_index),
		str(state.get("mode", "push")).to_upper(),
		int(state.get("charges", 0)),
		int(state.get("moves", 0)),
		int(state.get("move_limit", Rules.MOVE_LIMIT)),
		status
	]
	queue_redraw()

func get_debug_state() -> Dictionary:
	return state.duplicate(true)

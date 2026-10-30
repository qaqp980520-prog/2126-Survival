extends Node2D

const Rules = preload("res://rules.gd")
const BOARD_ORIGIN: Vector2 = Vector2(32.0, 74.0)
const CELL_SIZE: float = 68.0
const DRONE_COLORS: Array[Color] = [
	Color("#42d7f2"),
	Color("#f2a84b"),
	Color("#8bd66f")
]

var level_index: int = 0
var selected_drone: int = 0
var state: Dictionary = {}
var status_label: Label
var command_label: Label
var drone_buttons: Array[Button] = []

func _ready() -> void:
	_load_level(0)
	_build_ui()
	_refresh_ui()


func _draw() -> void:
	if state.is_empty():
		return
	var walls: Array = state.get("walls", [])
	var drones: Array = state.get("drones", [])
	for y in range(Rules.BOARD_SIZE):
		for x in range(Rules.BOARD_SIZE):
			var cell := Vector2i(x, y)
			var rect := Rect2(BOARD_ORIGIN + Vector2(float(x), float(y)) * CELL_SIZE, Vector2(CELL_SIZE - 4.0, CELL_SIZE - 4.0))
			draw_rect(rect, Color("#172b3e"), true)
			if walls.has(cell):
				draw_rect(rect, Color("#526274"), true)
			for index_drone in range(drones.size()):
				var drone: Dictionary = drones[index_drone]
				if Vector2i(drone.get("goal", Vector2i(-1, -1))) == cell:
					draw_rect(rect.grow(-9.0), Color("#1e6a55"), false, 3.0)
	for index_drone in range(drones.size()):
		var drone: Dictionary = drones[index_drone]
		var position: Vector2i = Vector2i(drone.get("position", Vector2i.ZERO))
		var rect := Rect2(BOARD_ORIGIN + Vector2(float(position.x), float(position.y)) * CELL_SIZE, Vector2(CELL_SIZE - 4.0, CELL_SIZE - 4.0))
		draw_circle(rect.get_center(), 20.0, DRONE_COLORS[index_drone])
		draw_string(ThemeDB.fallback_font, rect.get_center() + Vector2(-7.0, 7.0), str(drone.get("id", "?")), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#10202c"))


func _build_ui() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var panel := PanelContainer.new()
	panel.name = "ControlPanel"
	panel.position = Vector2(474.0, 42.0)
	panel.custom_minimum_size = Vector2(490.0, 530.0)
	hud.add_child(panel)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "KROLL // DRONE RELAY"
	title.add_theme_font_size_override("font_size", 22)
	layout.add_child(title)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.custom_minimum_size = Vector2(450.0, 96.0)
	status_label.add_theme_font_size_override("font_size", 16)
	layout.add_child(status_label)

	var help := Label.new()
	help.text = "Select a drone, assign its next move, then commit all three together.\nWASD/arrows: command selected drone · 1/2/3: select · SPACE: step"
	help.custom_minimum_size = Vector2(450.0, 58.0)
	layout.add_child(help)

	var selection_row := HBoxContainer.new()
	selection_row.name = "DroneSelection"
	layout.add_child(selection_row)
	for index_drone in range(Rules.DRONE_COUNT):
		var drone_button := _add_button(selection_row, ["DroneA", "DroneB", "DroneC"][index_drone], "DRONE " + ["A", "B", "C"][index_drone], Callable(self, "_select_drone").bind(index_drone), Vector2(145.0, 42.0))
		drone_buttons.append(drone_button)

	var command_pad := GridContainer.new()
	command_pad.name = "CommandPad"
	command_pad.columns = 3
	layout.add_child(command_pad)
	_add_spacer(command_pad)
	_add_button(command_pad, "CommandUp", "UP", Callable(self, "_command_up"), Vector2(132.0, 40.0))
	_add_spacer(command_pad)
	_add_button(command_pad, "CommandLeft", "LEFT", Callable(self, "_command_left"), Vector2(132.0, 40.0))
	_add_button(command_pad, "CommandHold", "HOLD", Callable(self, "_command_hold"), Vector2(132.0, 40.0))
	_add_button(command_pad, "CommandRight", "RIGHT", Callable(self, "_command_right"), Vector2(132.0, 40.0))
	_add_spacer(command_pad)
	_add_button(command_pad, "CommandDown", "DOWN", Callable(self, "_command_down"), Vector2(132.0, 40.0))

	command_label = Label.new()
	command_label.name = "CommandLabel"
	command_label.custom_minimum_size = Vector2(450.0, 34.0)
	layout.add_child(command_label)

	_add_button(layout, "StepAll", "COMMIT SIMULTANEOUS TICK", Callable(self, "_commit_tick"), Vector2(450.0, 46.0))
	_add_button(layout, "Restart", "RESTART LAYOUT", Callable(self, "_restart"), Vector2(450.0, 38.0))
	_add_button(layout, "NextLevel", "NEXT LAYOUT", Callable(self, "_next_level"), Vector2(450.0, 38.0))


func _add_spacer(parent: Control) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(132.0, 40.0)
	parent.add_child(spacer)


func _add_button(parent: Control, node_name: String, caption: String, callback: Callable, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.custom_minimum_size = minimum_size
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func _load_level(index: int) -> void:
	level_index = posmod(index, Rules.LEVEL_COUNT)
	selected_drone = 0
	state = Rules.create_state(level_index)
	if is_node_ready():
		_refresh_ui()


func _select_drone(index_drone: int) -> void:
	selected_drone = clampi(index_drone, 0, Rules.DRONE_COUNT - 1)
	_refresh_ui()


func _set_selected_command(direction: Vector2i) -> void:
	var result: Dictionary = Rules.set_command(state, selected_drone, direction)
	state = result.get("state", state)
	command_label.text = str(result.get("reason", ""))
	_refresh_ui()


func _commit_tick() -> void:
	var result: Dictionary = Rules.step(state)
	state = result.get("state", state)
	command_label.text = str(result.get("reason", ""))
	_refresh_ui()


func _command_up() -> void:
	_set_selected_command(Vector2i.UP)


func _command_left() -> void:
	_set_selected_command(Vector2i.LEFT)


func _command_hold() -> void:
	_set_selected_command(Vector2i.ZERO)


func _command_right() -> void:
	_set_selected_command(Vector2i.RIGHT)


func _command_down() -> void:
	_set_selected_command(Vector2i.DOWN)


func _restart() -> void:
	_load_level(level_index)


func _next_level() -> void:
	_load_level(level_index + 1)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			_select_drone(0)
		KEY_2:
			_select_drone(1)
		KEY_3:
			_select_drone(2)
		KEY_W, KEY_UP:
			_command_up()
		KEY_A, KEY_LEFT:
			_command_left()
		KEY_S, KEY_DOWN:
			_command_down()
		KEY_D, KEY_RIGHT:
			_command_right()
		KEY_H:
			_command_hold()
		KEY_SPACE:
			_commit_tick()
		KEY_R:
			_restart()
		KEY_N:
			_next_level()


func _refresh_ui() -> void:
	if state.is_empty():
		return
	var drones: Array = state.get("drones", [])
	var commands: Array = state.get("commands", [])
	for index_drone in range(mini(drone_buttons.size(), drones.size())):
		var drone: Dictionary = drones[index_drone]
		var command: Vector2i = Vector2i(commands[index_drone]) if index_drone < commands.size() else Vector2i.ZERO
		var reached: bool = Vector2i(drone.get("position", Vector2i.ZERO)) == Vector2i(drone.get("goal", Vector2i(-1, -1)))
		drone_buttons[index_drone].text = "DRONE %s%s\n%s" % [str(drone.get("id", "?")), " ✓" if reached else "", Rules.command_name(command)]
		drone_buttons[index_drone].modulate = Color("#d8f7ff") if index_drone == selected_drone else Color("#ffffff")
	if status_label != null:
		var battery_text: Array[String] = []
		for drone in drones:
			battery_text.append("%s:%d" % [str(drone.get("id", "?")), int(drone.get("battery", 0))])
		status_label.text = "%s\nTICK: %d / %d   BATTERY: %s\nCOLLISION BLOCKS: %d   STATUS: %s" % [
			Rules.get_level_name(level_index),
			int(state.get("ticks", 0)),
			int(state.get("max_ticks", Rules.MAX_TICKS)),
			"  ".join(battery_text),
			int(state.get("collisions", 0)),
			Rules.get_status(state).to_upper()
		]
	if command_label != null:
		command_label.text = "SELECTED DRONE: %s" % ["A", "B", "C"][selected_drone]
	queue_redraw()


func get_debug_state() -> Dictionary:
	return state.duplicate(true)


func get_selected_drone() -> int:
	return selected_drone

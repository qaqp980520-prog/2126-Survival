extends Control

const Rules = preload("res://daily_games/KROLL_Echo_Mapper/rules.gd")
const GRID_SIZE: int = 9

var state: Dictionary = {}
var buttons: Dictionary = {}
var status_label: Label
var message_label: Label
var hint_label: Label

func _ready() -> void:
	state = Rules.new_game(0)
	_build_ui()
	_render()

func _build_ui() -> void:
	status_label = Label.new()
	status_label.name = "MissionStatus"
	status_label.position = Vector2(24.0, 16.0)
	status_label.size = Vector2(912.0, 34.0)
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color("#72e5ff"))
	add_child(status_label)

	message_label = Label.new()
	message_label.name = "MissionMessage"
	message_label.position = Vector2(24.0, 52.0)
	message_label.size = Vector2(912.0, 34.0)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 15)
	message_label.add_theme_color_override("font_color", Color("#e2edf4"))
	add_child(message_label)

	hint_label = Label.new()
	hint_label.name = "ControlHint"
	hint_label.position = Vector2(24.0, 88.0)
	hint_label.size = Vector2(912.0, 26.0)
	hint_label.text = "WASD / ARROWS move · SPACE ping sonar · R restart · N next after extraction"
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color("#8ea9b8"))
	add_child(hint_label)

	var controls := GridContainer.new()
	controls.name = "TouchControls"
	controls.columns = 4
	controls.position = Vector2(38.0, 574.0)
	controls.size = Vector2(884.0, 116.0)
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 8)
	add_child(controls)

	_add_button(controls, "up", "UP", Callable(self, "_act").bind("up"))
	_add_button(controls, "left", "LEFT", Callable(self, "_act").bind("left"))
	_add_button(controls, "down", "DOWN", Callable(self, "_act").bind("down"))
	_add_button(controls, "right", "RIGHT", Callable(self, "_act").bind("right"))
	_add_button(controls, "ping", "PING SONAR", Callable(self, "_act").bind("ping"))
	_add_button(controls, "restart", "RESTART", Callable(self, "restart_game"))
	_add_button(controls, "next", "NEXT MISSION", Callable(self, "next_level"))

func _add_button(parent: GridContainer, key: String, label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = key.capitalize() + "Button"
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	buttons[key] = button

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_W, KEY_UP:
			_act("up")
		KEY_A, KEY_LEFT:
			_act("left")
		KEY_S, KEY_DOWN:
			_act("down")
		KEY_D, KEY_RIGHT:
			_act("right")
		KEY_SPACE:
			_act("ping")
		KEY_R:
			restart_game()
		KEY_N:
			next_level()

func _act(action: String) -> void:
	var result: Dictionary = Rules.apply_action(state, action)
	if bool(result.get("ok", false)):
		state = result.get("state", state)
	else:
		var next_state: Dictionary = state.duplicate(true)
		next_state["message"] = "Action unavailable: %s." % str(result.get("reason", "unknown"))
		state = next_state
	_render()

func restart_game() -> void:
	state = Rules.new_game(int(state.get("level_index", 0)))
	_render()

func next_level() -> void:
	if str(state.get("status", "")) != "won":
		return
	var next_index: int = (int(state.get("level_index", 0)) + 1) % Rules.get_level_count()
	state = Rules.new_game(next_index)
	_render()

func get_current_state() -> Dictionary:
	return state.duplicate(true)

func _render() -> void:
	if state.is_empty() or status_label == null:
		return
	var level_index: int = int(state.get("level_index", 0))
	var collected: Array = state.get("collected", [])
	var beacons: Array = state.get("beacons", [])
	status_label.text = "ECHO MAPPER  //  %d/%d  %s  //  TURN %d/%d  //  SONAR %d  //  SIGNAL %d/%d" % [
		level_index + 1,
		Rules.get_level_count(),
		Rules.get_level_title(level_index).to_upper(),
		int(state.get("turns", 0)),
		Rules.MAX_TURNS,
		int(state.get("sonar_charges", 0)),
		collected.size(),
		beacons.size()
	]
	message_label.text = str(state.get("message", ""))
	buttons["ping"].disabled = int(state.get("sonar_charges", 0)) <= 0
	buttons["next"].disabled = str(state.get("status", "")) != "won"
	queue_redraw()

func _draw() -> void:
	if DisplayServer.get_name() == "headless" or size.x < 360.0 or size.y < 360.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#07111c"), true)
	if state.is_empty():
		return
	var cell_size: float = minf(46.0, minf((size.x - 100.0) / float(GRID_SIZE), (size.y - 220.0) / float(GRID_SIZE)))
	var board_size: float = cell_size * float(GRID_SIZE)
	var origin := Vector2((size.x - board_size) * 0.5, 126.0)
	var player: Vector2i = state.get("player", Vector2i.ZERO)
	var exit_cell: Vector2i = state.get("exit", Vector2i.ZERO)
	var beacons: Array = state.get("beacons", [])
	var collected: Array = state.get("collected", [])
	var font: Font = ThemeDB.fallback_font

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			var cell_origin := origin + Vector2(float(x), float(y)) * cell_size
			var rect := Rect2(cell_origin + Vector2(2.0, 2.0), Vector2(cell_size - 4.0, cell_size - 4.0))
			var visible: bool = Rules.is_cell_visible(state, cell)
			var fill := Color("#0c1b29")
			if visible:
				fill = Color("#263b4b") if Rules.is_wall(state, cell) else Color("#173448")
			draw_rect(rect, fill, true)
			draw_rect(rect, Color("#29485b"), false, 1.0)

			if not visible:
				draw_string(font, rect.get_center() + Vector2(-5.0, 6.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#486273"))
				continue

			if Rules.is_wall(state, cell):
				draw_line(rect.position + Vector2(7.0, 7.0), rect.end - Vector2(7.0, 7.0), Color("#40596a"), 2.0)
				continue

			if beacons.has(cell) and not collected.has(cell):
				draw_circle(rect.get_center(), cell_size * 0.23, Color("#f1b85d"))
				draw_circle(rect.get_center(), cell_size * 0.12, Color("#fff0bd"))
			elif cell == exit_cell:
				var exit_color := Color("#53d79a") if collected.size() == beacons.size() else Color("#b58c55")
				draw_rect(rect.grow(-9.0), exit_color, false, 3.0)
			elif cell == player:
				draw_circle(rect.get_center(), cell_size * 0.25, Color("#55dfff"))
				draw_circle(rect.get_center(), cell_size * 0.11, Color("#effcff"))
			elif collected.has(cell):
				draw_circle(rect.get_center(), cell_size * 0.12, Color("#68d5b0"))

	draw_string(font, Vector2(24.0, 552.0), "UNKNOWN CELLS ARE HIDDEN  ·  PING REVEALS WALLS AND SIGNALS FOR A SHORT TIME", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8ea9b8"))

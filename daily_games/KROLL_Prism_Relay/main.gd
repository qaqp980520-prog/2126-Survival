extends Control

const Rules = preload("res://rules.gd")
const BACKGROUND := Color("#07131d")
const CELL_NORMAL := Color("#122a38")
const CELL_BEAM := Color("#145e6a")
const CELL_WON := Color("#236b4c")
const CELL_WALL := Color("#26333a")
const ACCENT := Color("#77e8df")
const TEXT_COLOR := Color("#dcebf0")

var puzzle_index: int = 0
var game_state: Dictionary = {}
var _grid: GridContainer
var _status_label: Label
var _turn_label: Label
var _cell_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_start_puzzle(0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R:
			_start_puzzle(puzzle_index)
		KEY_N:
			_start_puzzle(puzzle_index + 1)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 22.0
	layout.offset_top = 18.0
	layout.offset_right = -22.0
	layout.offset_bottom = -18.0
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	var title := Label.new()
	title.text = "KROLL // PRISM RELAY"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", ACCENT)
	layout.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ROTATE MIRRORS. ROUTE THE BEAM. POWER THE RECEIVER."
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("#9bb9c6"))
	layout.add_child(subtitle)
	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", TEXT_COLOR)
	layout.add_child(_status_label)
	_turn_label = Label.new()
	_turn_label.name = "TurnCounter"
	_turn_label.add_theme_font_size_override("font_size", 14)
	_turn_label.add_theme_color_override("font_color", Color("#f3c46d"))
	layout.add_child(_turn_label)
	_grid = GridContainer.new()
	_grid.name = "MirrorGrid"
	_grid.columns = Rules.WIDTH
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	layout.add_child(_grid)
	for y in range(Rules.HEIGHT):
		for x in range(Rules.WIDTH):
			var button := Button.new()
			button.name = "Cell_" + str(x) + "_" + str(y)
			button.custom_minimum_size = Vector2(54.0, 54.0)
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override("font_size", 22)
			button.pressed.connect(_on_cell_pressed.bind(x, y))
			_grid.add_child(button)
			_cell_buttons[_key(x, y)] = button
	var help := Label.new()
	help.text = "Click / tap a mirror to rotate it. R = reset   N = next relay"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color("#9bb9c6"))
	layout.add_child(help)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)
	_add_action_button(actions, "RESET RELAY", _reset_current)
	_add_action_button(actions, "NEXT RELAY", _next_relay)

func _add_action_button(parent: HBoxContainer, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(140.0, 42.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)

func _start_puzzle(index: int) -> void:
	puzzle_index = posmod(index, 3)
	game_state = Rules.create_puzzle(puzzle_index)
	_render_board()

func _reset_current() -> void:
	_start_puzzle(puzzle_index)

func _next_relay() -> void:
	_start_puzzle(puzzle_index + 1)

func _on_cell_pressed(x: int, y: int) -> void:
	var result: Dictionary = Rules.apply_rotation(game_state, _key(x, y))
	if not bool(result.get("ok", false)):
		return
	game_state = result["state"]
	_render_board()

func _render_board() -> void:
	if _grid == null:
		return
	var trace: Dictionary = Rules.trace_beam(game_state)
	var path: Array = trace.get("path", [])
	var path_lookup: Dictionary = {}
	for cell in path:
		path_lookup[_key(cell.x, cell.y)] = true
	var mirrors: Dictionary = game_state.get("mirrors", {})
	var walls: Dictionary = game_state.get("walls", {})
	var source: Vector2i = game_state.get("source", Vector2i.ZERO)
	var target: Vector2i = game_state.get("target", Vector2i(-1, -1))
	var terminal := str(game_state.get("status", "playing")) != "playing"
	for y in range(Rules.HEIGHT):
		for x in range(Rules.WIDTH):
			var key := _key(x, y)
			var button: Button = _cell_buttons[key]
			var position := Vector2i(x, y)
			var background_color := CELL_NORMAL
			var text := "·"
			var text_color := Color("#b8d0d8")
			if path_lookup.has(key):
				background_color = CELL_WON if bool(trace.get("hit_target", false)) else CELL_BEAM
			if walls.has(key):
				text = "■"
				background_color = CELL_WALL
				text_color = Color("#536772")
			if mirrors.has(key):
				text = "/" if int(mirrors[key]) == Rules.MIRROR_SLASH else "\\"
				text_color = Color("#ffffff")
			if position == source:
				text = "▶"
				background_color = Color("#22516b")
				text_color = ACCENT
			elif position == target:
				text = "◎"
				background_color = CELL_WON if bool(trace.get("hit_target", false)) else Color("#4c3920")
				text_color = Color("#ffe39b")
			button.text = text
			button.disabled = terminal or not mirrors.has(key)
			button.add_theme_color_override("font_color", text_color)
			var style := StyleBoxFlat.new()
			style.bg_color = background_color
			style.border_color = ACCENT if mirrors.has(key) else Color("#314b58")
			style.set_border_width_all(1)
			style.set_corner_radius_all(5)
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
			button.add_theme_stylebox_override("pressed", style)
	_status_label.text = "RELAY %d  |  %s  |  %s" % [
		puzzle_index + 1,
		str(game_state.get("status", "playing")).to_upper(),
		str(game_state.get("message", ""))
	]
	_turn_label.text = "POWER BUDGET: %d / %d     MIRROR ROTATIONS: %d" % [
		int(game_state.get("turns_left", 0)), Rules.MAX_TURNS, int(game_state.get("moves", 0))
	]

func _key(x: int, y: int) -> String:
	return str(x) + "," + str(y)

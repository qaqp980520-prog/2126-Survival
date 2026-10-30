extends Control

const Rules = preload("res://rules.gd")

var game_state: Dictionary = {}
var layout_index: int = 0
var _board_grid: GridContainer
var _layout_label: Label
var _moves_label: Label
var _status_label: Label


func _ready() -> void:
	_build_ui()
	_start_layout(0)


func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 24.0
	layout.offset_top = 20.0
	layout.offset_right = -24.0
	layout.offset_bottom = -20.0
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "KROLL // PIPE RELAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	layout.add_child(title)

	_layout_label = Label.new()
	_layout_label.name = "LayoutLabel"
	_layout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout_label.add_theme_font_size_override("font_size", 18)
	layout.add_child(_layout_label)

	var instructions := Label.new()
	instructions.text = "Rotate each pipe clockwise. Connect SOURCE to TARGET and power every pipe."
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(instructions)

	_moves_label = Label.new()
	_moves_label.name = "MovesLabel"
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moves_label.add_theme_font_size_override("font_size", 18)
	layout.add_child(_moves_label)

	_board_grid = GridContainer.new()
	_board_grid.name = "BoardGrid"
	_board_grid.columns = Rules.BOARD_SIZE
	_board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_board_grid.add_theme_constant_override("h_separation", 8)
	_board_grid.add_theme_constant_override("v_separation", 8)
	layout.add_child(_board_grid)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status_label)

	var controls := HBoxContainer.new()
	controls.name = "Controls"
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 12)
	layout.add_child(controls)

	var run_button := Button.new()
	run_button.name = "RunButton"
	run_button.text = "TEST NETWORK"
	run_button.custom_minimum_size = Vector2(160, 48)
	run_button.pressed.connect(_on_run_pressed)
	controls.add_child(run_button)

	var restart_button := Button.new()
	restart_button.name = "RestartButton"
	restart_button.text = "RESTART"
	restart_button.custom_minimum_size = Vector2(120, 48)
	restart_button.pressed.connect(_on_restart_pressed)
	controls.add_child(restart_button)

	var next_button := Button.new()
	next_button.name = "NextButton"
	next_button.text = "NEXT LAYOUT"
	next_button.custom_minimum_size = Vector2(140, 48)
	next_button.pressed.connect(_on_next_pressed)
	controls.add_child(next_button)

	var footer := Label.new()
	footer.text = "Click a pipe to rotate · R restart · N next layout · SPACE test"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color(0.55, 0.78, 0.88))
	layout.add_child(footer)


func _start_layout(index: int) -> void:
	layout_index = posmod(index, Rules.LAYOUTS.size())
	game_state = Rules.create_layout(layout_index)
	_build_board()
	_refresh_labels("Rotate the pipes to restore the relay.")


func _build_board() -> void:
	for child in _board_grid.get_children():
		_board_grid.remove_child(child)
		child.queue_free()

	var tile_lookup: Dictionary = {}
	var tiles: Array = game_state.get("tiles", [])
	for tile_index in range(tiles.size()):
		var tile: Dictionary = tiles[tile_index]
		tile_lookup[tile["cell"]] = tile_index

	var source: Vector2i = game_state["source"]
	var target: Vector2i = game_state["target"]
	for y in range(Rules.BOARD_SIZE):
		for x in range(Rules.BOARD_SIZE):
			var cell := Vector2i(x, y)
			if cell == source:
				var source_label := Label.new()
				source_label.text = "SOURCE\n→"
				source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				source_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				source_label.custom_minimum_size = Vector2(132, 84)
				source_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.9))
				_board_grid.add_child(source_label)
			elif cell == target:
				var target_label := Label.new()
				target_label.text = "TARGET\n◎"
				target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				target_label.custom_minimum_size = Vector2(132, 84)
				target_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3))
				_board_grid.add_child(target_label)
			elif tile_lookup.has(cell):
				var tile_index: int = int(tile_lookup[cell])
				var tile_button := Button.new()
				tile_button.name = "PipeTile_%02d" % tile_index
				tile_button.text = Rules.tile_text(tiles[tile_index])
				tile_button.custom_minimum_size = Vector2(132, 84)
				tile_button.pressed.connect(_on_tile_pressed.bind(tile_index))
				_board_grid.add_child(tile_button)
			else:
				var empty_label := Label.new()
				empty_label.text = "·"
				empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				empty_label.custom_minimum_size = Vector2(132, 84)
				empty_label.add_theme_color_override("font_color", Color(0.28, 0.38, 0.46))
				_board_grid.add_child(empty_label)


func _refresh_labels(message: String = "") -> void:
	_layout_label.text = "LAYOUT %d/3  //  %s" % [layout_index + 1, str(game_state.get("name", ""))]
	_moves_label.text = "MOVES: %d / %d" % [int(game_state.get("moves", 0)), int(game_state.get("max_moves", Rules.MAX_MOVES))]
	if bool(game_state.get("solved", false)):
		_status_label.text = "POWER RESTORED // ALL PIPES CONNECTED"
	elif not message.is_empty():
		_status_label.text = message
	else:
		_status_label.text = "NETWORK OFFLINE"


func _on_tile_pressed(tile_index: int) -> void:
	if not Rules.rotate_tile(game_state, tile_index):
		_refresh_labels("No moves remain, or the network is already locked.")
		return
	_build_board()
	if bool(game_state.get("solved", false)):
		_refresh_labels("Power restored. All pipe segments are online.")
	elif int(game_state.get("moves", 0)) >= int(game_state.get("max_moves", Rules.MAX_MOVES)):
		_refresh_labels("Move budget exhausted. Restart to try again.")
	else:
		_refresh_labels("Pipe rotated. Keep following the signal.")


func _on_run_pressed() -> void:
	var result: Dictionary = Rules.evaluate(game_state)
	if bool(result.get("connected", false)):
		game_state["solved"] = true
		_refresh_labels("Power restored. All pipe segments are online.")
	else:
		_refresh_labels("Network blocked: %s." % str(result.get("reason", "unknown")))


func _on_restart_pressed() -> void:
	_start_layout(layout_index)


func _on_next_pressed() -> void:
	_start_layout(layout_index + 1)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_R:
			_on_restart_pressed()
		KEY_N:
			_on_next_pressed()
		KEY_SPACE:
			_on_run_pressed()

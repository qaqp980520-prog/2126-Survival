extends Control

const Rules = preload("res://scripts/rules.gd")

var rng := RandomNumberGenerator.new()
var sequence: Array[int] = []
var round_number: int = 1
var lives: int = Rules.INITIAL_LIVES
var score: int = 0
var state: String = "ready"
var input_index: int = 0
var show_index: int = 0
var show_timer: float = 0.0
var show_step_seconds: float = 0.48
var highlighted_cell: int = -1
var feedback_text: String = "Preparing cipher..."

func _ready() -> void:
	set_process(true)
	start_game()

func start_game() -> void:
	rng.randomize()
	round_number = 1
	lives = Rules.INITIAL_LIVES
	score = 0
	_start_round()

func _start_round() -> void:
	sequence = Rules.make_sequence(rng, Rules.next_round_length(round_number))
	input_index = 0
	show_index = 0
	show_timer = 0.0
	highlighted_cell = -1
	state = "showing"
	feedback_text = "Memorize the sequence"
	queue_redraw()

func _process(delta: float) -> void:
	if state != "showing":
		return
	show_timer += delta
	while show_timer >= show_step_seconds and state == "showing":
		show_timer -= show_step_seconds
		if show_index < sequence.size():
			highlighted_cell = sequence[show_index]
			show_index += 1
		else:
			highlighted_cell = -1
			state = "input"
			input_index = 0
			feedback_text = "Repeat the sequence"
			break
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_R and (state == "won" or state == "failed"):
			start_game()
			return
		var cell := _key_to_cell(key_event.keycode)
		if cell >= 0:
			submit_cell(cell)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var cell := _cell_at(mouse_event.position)
			if cell >= 0:
				submit_cell(cell)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			var cell := _cell_at(touch_event.position)
			if cell >= 0:
				submit_cell(cell)

func submit_cell(cell: int) -> bool:
	if state != "input" or cell < 0 or cell >= Rules.CELL_COUNT:
		return false
	if not Rules.is_correct_input(sequence, input_index, cell):
		lives -= 1
		input_index = 0
		highlighted_cell = -1
		if lives <= 0:
			state = "failed"
			feedback_text = "Cipher rejected — press R to retry"
		else:
			state = "showing"
			show_index = 0
			show_timer = 0.0
			feedback_text = "Incorrect — watch again"
		queue_redraw()
		return false

	score += 100
	input_index += 1
	if Rules.is_round_complete(sequence, input_index):
		if not Rules.can_advance_round(round_number):
			state = "won"
			highlighted_cell = -1
			feedback_text = "Cipher accepted — press R to replay"
		else:
			round_number += 1
			_start_round()
	else:
		feedback_text = "Correct"
		queue_redraw()
	return true

## Deterministic test hook; never bound to player input.
func debug_force_input_phase() -> void:
	state = "input"
	input_index = 0
	show_index = sequence.size()
	show_timer = 0.0
	highlighted_cell = -1
	queue_redraw()

func _key_to_cell(keycode: int) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
		KEY_5: return 4
		KEY_6: return 5
		KEY_7: return 6
		KEY_8: return 7
		KEY_9: return 8
		_: return -1

func _cell_at(position: Vector2) -> int:
	for cell in range(Rules.CELL_COUNT):
		if _cell_rect(cell).has_point(position):
			return cell
	return -1

func _board_metrics() -> Dictionary:
	var viewport_size := get_viewport_rect().size
	var available_width: float = maxf(180.0, viewport_size.x - 32.0)
	var available_height: float = maxf(180.0, viewport_size.y - 200.0)
	var cell_size: float = minf(160.0, minf((available_width - 20.0) / 3.0, (available_height - 20.0) / 3.0))
	cell_size = maxf(58.0, cell_size)
	var gap: float = 10.0
	var board_size: float = cell_size * 3.0 + gap * 2.0
	var origin := Vector2((viewport_size.x - board_size) / 2.0, maxf(130.0, (viewport_size.y - board_size) / 2.0 + 45.0))
	if origin.y + board_size > viewport_size.y - 8.0:
		origin.y = viewport_size.y - board_size - 8.0
	return {"origin": origin, "cell_size": cell_size, "gap": gap}

func _cell_rect(cell: int) -> Rect2:
	var metrics := _board_metrics()
	var origin: Vector2 = metrics["origin"]
	var cell_size: float = metrics["cell_size"]
	var gap: float = metrics["gap"]
	var column: int = cell % Rules.GRID_SIZE
	var row: int = floori(float(cell) / float(Rules.GRID_SIZE))
	return Rect2(origin + Vector2(column * (cell_size + gap), row * (cell_size + gap)), Vector2(cell_size, cell_size))

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.015, 0.028, 0.055), true)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(24.0, 38.0), "KROLL // CIPHER RECALL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 27, Color(0.43, 0.94, 1.0))
	draw_string(font, Vector2(24.0, 70.0), "ROUND %d/%d   SCORE %d   CORES %d" % [round_number, Rules.TOTAL_ROUNDS, score, lives], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.78, 0.88, 0.96))
	draw_string(font, Vector2(24.0, 102.0), feedback_text, HORIZONTAL_ALIGNMENT_LEFT, viewport_size.x - 48.0, 17, Color(0.95, 0.83, 0.45))
	for cell in range(Rules.CELL_COUNT):
		var rect := _cell_rect(cell)
		var tile_color := Color(0.10, 0.23, 0.34)
		if cell == highlighted_cell:
			tile_color = Color(0.20, 0.92, 0.83)
		draw_rect(rect, tile_color, true)
		draw_rect(rect, Color(0.30, 0.78, 0.88), false, 2.0)
		var number_color := Color(0.95, 0.98, 1.0) if cell != highlighted_cell else Color(0.02, 0.07, 0.10)
		draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.61), str(cell + 1), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 28, number_color)
	if state == "showing":
		draw_string(font, Vector2(24.0, viewport_size.y - 18.0), "WATCH THE LIGHTS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.43, 0.94, 1.0))
	elif state == "input":
		draw_string(font, Vector2(24.0, viewport_size.y - 18.0), "REPEAT: 1-9 OR TAP A TILE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.43, 0.94, 1.0))
	elif state == "won":
		draw_string(font, Vector2(24.0, viewport_size.y - 18.0), "ALL CIPHERS DECODED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.30, 1.0, 0.65))
	elif state == "failed":
		draw_string(font, Vector2(24.0, viewport_size.y - 18.0), "ACCESS DENIED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1.0, 0.35, 0.35))

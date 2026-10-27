extends Node2D

const Rules = preload("res://rules.gd")
const SYMBOL_COLORS: Array[Color] = [
	Color("#ff647c"), Color("#ffb454"), Color("#f5e96b"),
	Color("#63e6a6"), Color("#5bd7ff"), Color("#b99aff")
]
const SYMBOL_CENTERS: Array[float] = [250.0, 340.0, 430.0, 520.0, 610.0, 700.0]

var state: Dictionary = {}
var draft: Array[int] = []
var notice := "Tune the four-symbol signal. No symbol repeats."
var _seed_value := 1

func _ready() -> void:
	_restart_game()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1024, 720)), Color("#06101d"))
	draw_rect(Rect2(24, 20, 976, 680), Color("#0b1b2c"))
	draw_string(ThemeDB.fallback_font, Vector2(58, 64), "KROLL / FREQUENCY LOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#76f4ff"))
	draw_string(ThemeDB.fallback_font, Vector2(60, 94), "Break the four-symbol code. Exact = right slot; Misplaced = right symbol.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#a9bfd1"))
	draw_rect(Rect2(54, 112, 916, 58), Color("#10283a"))
	var status_text := "SIGNAL: ENCRYPTED"
	if str(state.get("status", "playing")) == "won":
		status_text = "SIGNAL DECODED  /  SUCCESS"
	elif str(state.get("status", "playing")) == "lost":
		status_text = "LOCKOUT  /  CODE REVEALED"
	draw_string(ThemeDB.fallback_font, Vector2(74, 148), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#8ef5d0") if str(state.get("status", "")) == "won" else Color("#76f4ff"))
	if str(state.get("status", "playing")) != "playing":
		var secret: Array = state.get("secret", [])
		draw_string(ThemeDB.fallback_font, Vector2(690, 148), "CODE: " + _code_text(secret), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffcf78"))

	draw_rect(Rect2(54, 184, 916, 76), Color("#102033"))
	draw_string(ThemeDB.fallback_font, Vector2(72, 210), "SYMBOL BANK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8ba8bd"))
	for index in range(SYMBOL_CENTERS.size()):
		var center := Vector2(SYMBOL_CENTERS[index], 224.0)
		draw_circle(center, 23.0, SYMBOL_COLORS[index])
		draw_string(ThemeDB.fallback_font, center + Vector2(-6, 7), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#081321"))

	draw_rect(Rect2(54, 270, 916, 76), Color("#10283a"))
	draw_string(ThemeDB.fallback_font, Vector2(72, 295), "YOUR GUESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8ba8bd"))
	for index in range(Rules.CODE_LENGTH):
		var center := Vector2(282.0 + float(index) * 92.0, 317.0)
		if index < draft.size():
			draw_circle(center, 20.0, _symbol_color(draft[index]))
			draw_string(ThemeDB.fallback_font, center + Vector2(-6, 7), str(draft[index]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#081321"))
		else:
			draw_circle(center, 20.0, Color("#14283a"))
			draw_arc(center, 20.0, 0.0, TAU, 32, Color("#426176"), 2.0)
	draw_rect(Rect2(700, 284, 112, 42), Color("#1b766f") if str(state.get("status", "")) == "playing" else Color("#263746"))
	draw_string(ThemeDB.fallback_font, Vector2(718, 310), "SUBMIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_rect(Rect2(826, 284, 112, 42), Color("#25394b"))
	draw_string(ThemeDB.fallback_font, Vector2(847, 310), "CLEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#d6e5ef"))

	draw_rect(Rect2(54, 356, 916, 286), Color("#0e2132"))
	draw_string(ThemeDB.fallback_font, Vector2(72, 381), "ATTEMPTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8ba8bd"))
	draw_string(ThemeDB.fallback_font, Vector2(810, 381), str(state.get("attempts_left", Rules.MAX_ATTEMPTS)) + " LEFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#76f4ff"))
	var guesses: Array = state.get("guesses", [])
	var feedback: Array = state.get("feedback", [])
	for row in range(Rules.MAX_ATTEMPTS):
		var y := 410.0 + float(row) * 27.0
		draw_string(ThemeDB.fallback_font, Vector2(76, y + 5.0), "%02d" % (row + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#66859b"))
		if row < guesses.size():
			var guess: Array = guesses[row]
			for slot in range(guess.size()):
				var center := Vector2(145.0 + float(slot) * 39.0, y)
				draw_circle(center, 9.0, _symbol_color(int(guess[slot])))
			var score: Dictionary = feedback[row]
			draw_string(ThemeDB.fallback_font, Vector2(340, y + 5.0), "EXACT %d   MISPLACED %d" % [int(score.get("exact", 0)), int(score.get("misplaced", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#a6e8d2"))
		else:
			draw_string(ThemeDB.fallback_font, Vector2(145, y + 5.0), "—  —  —  —", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#3f5b70"))
	draw_string(ThemeDB.fallback_font, Vector2(60, 672), notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#c3d5e2"))
	draw_string(ThemeDB.fallback_font, Vector2(810, 672), "R  RESTART", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#76f4ff"))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _handle_symbol(1)
			KEY_2: _handle_symbol(2)
			KEY_3: _handle_symbol(3)
			KEY_4: _handle_symbol(4)
			KEY_5: _handle_symbol(5)
			KEY_6: _handle_symbol(6)
			KEY_BACKSPACE: _clear_draft()
			KEY_ENTER, KEY_KP_ENTER: _submit_guess()
			KEY_R: _restart_game()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)
	if event is InputEventScreenTouch and event.pressed:
		_handle_click(event.position)

func _handle_click(position: Vector2) -> void:
	if position.y >= 195.0 and position.y <= 252.0:
		for index in range(SYMBOL_CENTERS.size()):
			if absf(position.x - SYMBOL_CENTERS[index]) <= 27.0:
				_handle_symbol(index + 1)
				return
	if position.y >= 278.0 and position.y <= 334.0:
		if position.x >= 695.0 and position.x <= 818.0:
			_submit_guess()
		elif position.x >= 820.0 and position.x <= 945.0:
			_clear_draft()
	if position.x >= 800.0 and position.y >= 648.0 and position.y <= 695.0:
		_restart_game()

func _handle_symbol(symbol: int) -> void:
	if str(state.get("status", "playing")) != "playing":
		notice = "Round finished. Press R to start a new code."
	elif draft.size() >= Rules.CODE_LENGTH:
		notice = "Four symbols selected. Submit or clear the guess."
	elif draft.has(symbol):
		notice = "No repeats: choose a different symbol."
	elif symbol < 1 or symbol > Rules.SYMBOL_COUNT:
		notice = "Symbol outside the bank."
	else:
		draft.append(symbol)
		notice = "Selected %d of %d symbols." % [draft.size(), Rules.CODE_LENGTH]
	queue_redraw()

func _submit_guess() -> void:
	var result: Dictionary = Rules.submit_guess(state, draft)
	if not bool(result.get("accepted", false)):
		notice = "Choose four different symbols before submitting."
	else:
		var score: Dictionary = result["feedback"]
		notice = "Exact %d / Misplaced %d." % [int(score["exact"]), int(score["misplaced"])]
		draft.clear()
		if str(state.get("status", "")) == "won":
			notice = "Decoded! Press R for another signal."
		elif str(state.get("status", "")) == "lost":
			notice = "Lockout. The code is revealed above; press R."
	queue_redraw()

func _clear_draft() -> void:
	draft.clear()
	notice = "Draft cleared."
	queue_redraw()

func _restart_game() -> void:
	_seed_value = int(Time.get_ticks_msec()) + int(Time.get_unix_time_from_system())
	state = Rules.create_state(Rules.generate_secret(_seed_value))
	draft.clear()
	notice = "Tune the four-symbol signal. No symbol repeats."
	queue_redraw()

func _symbol_color(symbol: int) -> Color:
	if symbol < 1 or symbol > SYMBOL_COLORS.size():
		return Color("#334b5f")
	return SYMBOL_COLORS[symbol - 1]

func _code_text(code: Array) -> String:
	var parts: PackedStringArray = []
	for value in code:
		parts.append(str(value))
	return " ".join(parts)

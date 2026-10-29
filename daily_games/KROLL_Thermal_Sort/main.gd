extends Control

const Rules = preload("res://rules.gd")

var state: Dictionary = {}
var seed_cursor: int = 0
var status_label: Label
var temperature_label: Label
var progress_label: Label
var feedback_label: Label
var action_buttons: Dictionary = {}

func _ready() -> void:
	state = Rules.new_game(Rules.SEEDS[seed_cursor])
	_build_ui()
	_render()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_A, KEY_LEFT:
			_route("cold")
		KEY_S, KEY_DOWN:
			_route("stable")
		KEY_D, KEY_RIGHT:
			_route("hot")
		KEY_R:
			restart_game()
		KEY_N:
			next_layout()

func _build_ui() -> void:
	var root_box := VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 14)
	root_box.add_theme_constant_override("margin_left", 24)
	root_box.add_theme_constant_override("margin_right", 24)
	root_box.add_theme_constant_override("margin_top", 22)
	root_box.add_theme_constant_override("margin_bottom", 22)
	add_child(root_box)

	var title := Label.new()
	title.text = "KROLL // THERMAL SORT"
	title.add_theme_font_size_override("font_size", 30)
	root_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Sort temperature canisters into COLD, STABLE, or HOT. Two errors are allowed; the third ends the shift."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(subtitle)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 20)
	root_box.add_child(status_label)

	temperature_label = Label.new()
	temperature_label.custom_minimum_size = Vector2(0, 130)
	temperature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	temperature_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	temperature_label.add_theme_font_size_override("font_size", 36)
	root_box.add_child(temperature_label)

	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(progress_label)

	var bins := HBoxContainer.new()
	bins.add_theme_constant_override("separation", 10)
	root_box.add_child(bins)
	_add_button(bins, "COLD <= -10 C (A)", "cold", func(): _route("cold"))
	_add_button(bins, "STABLE -9..9 C (S)", "stable", func(): _route("stable"))
	_add_button(bins, "HOT >= 10 C (D)", "hot", func(): _route("hot"))

	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(0, 56)
	root_box.add_child(feedback_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	root_box.add_child(controls)
	_add_button(controls, "RESTART (R)", "restart", restart_game)
	_add_button(controls, "NEXT SEED (N)", "next", next_layout)

	var footer := Label.new()
	footer.text = "Each canister is processed once. Routing rules use Celsius thresholds shown above."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(footer)

func _add_button(parent: Container, text_value: String, key: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = {"cold": "ColdButton", "stable": "StableButton", "hot": "HotButton", "restart": "RestartButton", "next": "NextButton"}.get(key, key)
	button.text = text_value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	action_buttons[key] = button

func _route(bin_name: String) -> void:
	_act(Rules.route(state, bin_name))

func _act(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		state = result.get("state", state)
	else:
		feedback_label.text = "ACTION BLOCKED: " + str(result.get("reason", "unknown"))
	_render()

func restart_game() -> void:
	state = Rules.new_game(int(state.get("seed", Rules.SEEDS[seed_cursor])))
	_render()

func next_layout() -> void:
	seed_cursor = (seed_cursor + 1) % Rules.SEEDS.size()
	state = Rules.new_game(Rules.SEEDS[seed_cursor])
	_render()

func _render() -> void:
	if state.is_empty() or status_label == null:
		return
	var temperatures: Array = state.get("temperatures", [])
	var index: int = int(state.get("index", 0))
	status_label.text = "STATUS: %s    SHIFT: %d/%d    ERRORS: %d/%d" % [
		str(state.get("status", "unknown")).to_upper(),
		mini(index, temperatures.size()), temperatures.size(),
		int(state.get("mistakes", 0)), Rules.MAX_MISTAKES
	]
	if index < temperatures.size():
		temperature_label.text = "%d C" % int(temperatures[index])
	else:
		temperature_label.text = "SHIFT CLOSED"
	progress_label.text = "CORRECT ROUTES: %d" % int(state.get("correct", 0))
	feedback_label.text = str(state.get("message", ""))
	for key in ["cold", "stable", "hot"]:
		action_buttons[key].disabled = str(state.get("status", "")) != "playing"
	action_buttons["restart"].disabled = false
	action_buttons["next"].disabled = false

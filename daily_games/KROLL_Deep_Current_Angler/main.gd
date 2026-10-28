extends Control

const Rules = preload("res://rules.gd")

var state: Dictionary = {}
var status_label: Label
var stats_label: Label
var tension_bar: ProgressBar
var action_buttons: Dictionary = {}
var seed_value: int = 33

func _ready() -> void:
    _build_ui()
    state = Rules.new_game(seed_value)
    _render()

func _build_ui() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := ColorRect.new()
    background.color = Color("#071b2a")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 28)
    margin.add_theme_constant_override("margin_right", 28)
    margin.add_theme_constant_override("margin_top", 24)
    margin.add_theme_constant_override("margin_bottom", 24)
    add_child(margin)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 14)
    margin.add_child(layout)

    var title := Label.new()
    title.text = "KROLL // DEEP CURRENT ANGLER"
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color("#79e6df"))
    layout.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Catch three fish. Keep line tension below the snap limit. Every action advances the tide."
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(subtitle)

    status_label = Label.new()
    status_label.custom_minimum_size = Vector2(0, 64)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size", 20)
    layout.add_child(status_label)

    stats_label = Label.new()
    stats_label.add_theme_font_size_override("font_size", 17)
    layout.add_child(stats_label)

    var tension_title := Label.new()
    tension_title.text = "LINE TENSION"
    layout.add_child(tension_title)
    tension_bar = ProgressBar.new()
    tension_bar.min_value = 0
    tension_bar.max_value = Rules.MAX_TENSION
    tension_bar.custom_minimum_size = Vector2(0, 26)
    tension_bar.show_percentage = true
    layout.add_child(tension_bar)

    var action_row := HBoxContainer.new()
    action_row.add_theme_constant_override("separation", 10)
    layout.add_child(action_row)
    _add_action_button(action_row, "CAST", "cast")
    _add_action_button(action_row, "WAIT", "wait")
    _add_action_button(action_row, "HOOK", "hook")
    _add_action_button(action_row, "REEL", "reel")
    _add_action_button(action_row, "EASE", "ease")

    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 10)
    layout.add_child(footer)
    var restart_button := Button.new()
    restart_button.text = "RESET (Backspace)"
    restart_button.custom_minimum_size = Vector2(200, 42)
    restart_button.pressed.connect(restart_game)
    footer.add_child(restart_button)
    var next_button := Button.new()
    next_button.text = "NEXT TIDE (N)"
    next_button.custom_minimum_size = Vector2(180, 42)
    next_button.pressed.connect(next_tide)
    footer.add_child(next_button)

    var hint := Label.new()
    hint.text = "Keyboard: C cast · W wait · H hook · R reel · E ease · Backspace reset · N next tide"
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(hint)

func _add_action_button(parent: HBoxContainer, label_text: String, action: String) -> void:
    var button := Button.new()
    button.text = label_text
    button.custom_minimum_size = Vector2(140, 54)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.pressed.connect(_perform_action.bind(action))
    parent.add_child(button)
    action_buttons[action] = button

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_C:
            _perform_action("cast")
        KEY_W:
            _perform_action("wait")
        KEY_H:
            _perform_action("hook")
        KEY_R:
            _perform_action("reel")
        KEY_E:
            _perform_action("ease")
        KEY_BACKSPACE:
            restart_game()
        KEY_N:
            next_tide()

func _perform_action(action: String) -> bool:
    var result: Dictionary = Rules.perform_action(state, action)
    if not bool(result.get("ok", false)):
        return false
    state = result["state"]
    _render()
    return true

func restart_game() -> void:
    state = Rules.new_game(seed_value)
    _render()

func next_tide() -> void:
    seed_value += 1
    state = Rules.new_game(seed_value)
    _render()

func _render() -> void:
    if status_label == null:
        return
    status_label.text = str(state.get("message", ""))
    stats_label.text = "Catches: %d / %d     Casts: %d     Turns: %d / %d     Mode: %s" % [
        int(state.get("catches", 0)), Rules.TARGET_CATCHES, int(state.get("casts", 0)),
        int(state.get("turns", 0)), Rules.MAX_TURNS, str(state.get("mode", "idle")).to_upper()
    ]
    tension_bar.value = float(state.get("tension", 0.0))
    var mode: String = str(state.get("mode", "idle"))
    var status: String = str(state.get("status", "playing"))
    action_buttons["cast"].disabled = status != "playing" or mode != "idle"
    action_buttons["wait"].disabled = status != "playing" or not (mode == "waiting" or mode == "bite")
    action_buttons["hook"].disabled = status != "playing" or mode != "bite"
    action_buttons["reel"].disabled = status != "playing" or mode != "fight"
    action_buttons["ease"].disabled = status != "playing" or mode != "fight"


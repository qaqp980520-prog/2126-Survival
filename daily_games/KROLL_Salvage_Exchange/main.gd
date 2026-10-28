extends Control

const Rules = preload("res://rules.gd")

var state: Dictionary = {}
var seed_value: int = 3
var selected_item: String = "copper"
var status_label: Label
var stats_label: Label
var market_rows: Dictionary = {}
var action_buttons: Array[Button] = []

func _ready() -> void:
    state = Rules.new_game(seed_value)
    _build_ui()
    _render()

func _build_ui() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := ColorRect.new()
    background.color = Color("#071520")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_right", 24)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    add_child(margin)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 10)
    margin.add_child(layout)

    var title := Label.new()
    title.text = "KROLL // SALVAGE EXCHANGE"
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color("#79e6df"))
    layout.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Trade four salvage commodities. Fees are 5%. Cargo capacity: 10 units. Reach net worth 150 before closing day 8."
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(subtitle)

    status_label = Label.new()
    status_label.custom_minimum_size = Vector2(0, 48)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size", 17)
    layout.add_child(status_label)

    stats_label = Label.new()
    stats_label.add_theme_font_size_override("font_size", 17)
    layout.add_child(stats_label)

    var table_header := HBoxContainer.new()
    table_header.add_theme_constant_override("separation", 8)
    layout.add_child(table_header)
    _add_header(table_header, "COMMODITY", 150)
    _add_header(table_header, "PRICE", 85)
    _add_header(table_header, "CARGO", 75)
    _add_header(table_header, "TRADE", 1)

    for item in Rules.ITEMS:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        row.custom_minimum_size = Vector2(0, 54)
        layout.add_child(row)
        var item_label := Label.new()
        item_label.custom_minimum_size = Vector2(150, 0)
        item_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(item_label)
        var price_label := Label.new()
        price_label.custom_minimum_size = Vector2(85, 0)
        price_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(price_label)
        var cargo_label := Label.new()
        cargo_label.custom_minimum_size = Vector2(75, 0)
        cargo_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(cargo_label)
        var buttons := HBoxContainer.new()
        buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        buttons.add_theme_constant_override("separation", 6)
        row.add_child(buttons)
        _add_trade_button(buttons, "Buy 1", "buy", item, 1)
        _add_trade_button(buttons, "Sell 1", "sell", item, 1)
        _add_trade_button(buttons, "Buy 5", "buy", item, 5)
        _add_trade_button(buttons, "Sell 5", "sell", item, 5)
        market_rows[item] = {"item": item_label, "price": price_label, "cargo": cargo_label}

    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 10)
    layout.add_child(footer)
    var advance := Button.new()
    advance.text = "CLOSE DAY / NEXT DAY (Enter)"
    advance.custom_minimum_size = Vector2(270, 48)
    advance.pressed.connect(dispatch_action.bind("advance", "", 0))
    footer.add_child(advance)
    action_buttons.append(advance)
    var reset := Button.new()
    reset.text = "RESET (R)"
    reset.custom_minimum_size = Vector2(150, 48)
    reset.pressed.connect(restart_game)
    footer.add_child(reset)
    var next_seed := Button.new()
    next_seed.text = "NEXT MARKET (N)"
    next_seed.custom_minimum_size = Vector2(190, 48)
    next_seed.pressed.connect(next_market)
    footer.add_child(next_seed)

    var help := Label.new()
    help.text = "Keyboard: 1–4 select commodity · B buy 1 · S sell 1 · Enter close day · R reset · N next market"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(help)

func _add_header(parent: HBoxContainer, text_value: String, width: int) -> void:
    var label := Label.new()
    label.text = text_value
    label.custom_minimum_size = Vector2(width, 0)
    label.add_theme_color_override("font_color", Color("#f3bd62"))
    parent.add_child(label)

func _add_trade_button(parent: HBoxContainer, label_text: String, side: String, item: String, quantity: int) -> void:
    var button := Button.new()
    button.text = label_text
    button.custom_minimum_size = Vector2(84, 40)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.pressed.connect(dispatch_action.bind(side, item, quantity))
    parent.add_child(button)
    action_buttons.append(button)

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_1:
            selected_item = Rules.ITEMS[0]
        KEY_2:
            selected_item = Rules.ITEMS[1]
        KEY_3:
            selected_item = Rules.ITEMS[2]
        KEY_4:
            selected_item = Rules.ITEMS[3]
        KEY_B:
            dispatch_action("buy", selected_item, 1)
        KEY_S:
            dispatch_action("sell", selected_item, 1)
        KEY_ENTER, KEY_KP_ENTER:
            dispatch_action("advance", "", 0)
        KEY_R:
            restart_game()
        KEY_N:
            next_market()
    _render()

func dispatch_action(action: String, item: String = "", quantity: int = 0) -> bool:
    var result: Dictionary
    if action == "advance":
        result = Rules.advance_day(state)
    else:
        result = Rules.trade(state, action, item, quantity)
    if not bool(result.get("ok", false)):
        status_label.text = "Rejected: %s. No state was changed." % str(result.get("reason", "unknown"))
        return false
    state = result["state"]
    _render()
    return true

func restart_game() -> void:
    state = Rules.new_game(seed_value)
    _render()

func next_market() -> void:
    seed_value += 1
    restart_game()

func _render() -> void:
    if status_label == null:
        return
    status_label.text = str(state.get("message", ""))
    var cargo_units := 0
    for item in Rules.ITEMS:
        cargo_units += int(state["cargo"].get(item, 0))
    var worth := Rules.net_worth(state)
    stats_label.text = "DAY %d / %d    CREDITS %d    NET WORTH %d    PROFIT %+d    CARGO %d / %d    SELECTED %s" % [
        int(state["day"]), Rules.MAX_DAYS, int(state["credits"]), worth,
        worth - int(state["starting_credits"]), cargo_units, int(state["capacity"]), selected_item.to_upper()
    ]
    for item in Rules.ITEMS:
        var row: Dictionary = market_rows[item]
        row["item"].text = ("> " if item == selected_item else "  ") + str(Rules.LABELS[item])
        row["price"].text = "%d cr" % int(state["prices"][item])
        row["cargo"].text = str(int(state["cargo"][item]))
    var terminal := str(state["status"]) != "playing"
    for button in action_buttons:
        button.disabled = terminal

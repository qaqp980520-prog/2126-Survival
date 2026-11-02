extends Control

const STANDALONE_RULES_PATH := "res://rules.gd"
const ROOT_RULES_PATH := "res://daily_games/KROLL_Solar_Sail_Navigator/rules.gd"

class FlightCanvas extends Control:
    var game: Control
    func _draw() -> void:
        draw_rect(Rect2(Vector2.ZERO,size),Color("#071722"))
        if not is_instance_valid(game):
            return
        for i in range(36):
            var x: float = float((i * 73 + 19) % 997) / 997.0 * size.x
            var y: float = float((i * 137 + 41) % 991) / 991.0 * size.y
            draw_circle(Vector2(x,y),1.0 + float(i % 3) * 0.45,Color(0.55,0.78,0.9,0.65))
        var sun := Vector2(size.x * 0.06,size.y * 0.5)
        draw_circle(sun,24.0,Color("#f5d98c"))
        draw_circle(sun,34.0,Color(0.96,0.78,0.38,0.16))
        var state: Dictionary = game.call("get_current_state")
        var target: Vector2 = state.get("target",Vector2(70.0,50.0))
        var target_point := Vector2(target.x / 100.0 * size.x,target.y / 100.0 * size.y)
        draw_circle(target_point,16.0,Color(0.2,0.95,0.8,0.12))
        draw_arc(target_point,18.0,0.0,TAU,48,Color("#78f0d0"),2.0)
        for hazard_value in state.get("hazards",[]):
            var hazard: Dictionary = hazard_value
            var hp: Vector2 = hazard["position"]
            var point := Vector2(hp.x / 100.0 * size.x,hp.y / 100.0 * size.y)
            var radius: float = float(hazard["radius"]) / 100.0 * minf(size.x,size.y)
            draw_circle(point,radius,Color(0.78,0.34,0.27,0.18))
            draw_arc(point,radius,0.0,TAU,32,Color("#d98567"),1.5)
        var trail: Array = game.call("get_trail")
        for i in range(1,trail.size()):
            var a: Vector2 = trail[i - 1]
            var b: Vector2 = trail[i]
            draw_line(Vector2(a.x / 100.0 * size.x,a.y / 100.0 * size.y),Vector2(b.x / 100.0 * size.x,b.y / 100.0 * size.y),Color("#6ccfe4"),2.0)
        var position: Vector2 = state.get("position",Vector2(10.0,50.0))
        var ship := Vector2(position.x / 100.0 * size.x,position.y / 100.0 * size.y)
        var angle: float = deg_to_rad(float(state.get("trim",0)) * 10.0)
        var forward := Vector2(cos(angle),-sin(angle))
        var side := Vector2(-forward.y,forward.x)
        draw_colored_polygon(PackedVector2Array([ship + forward * 13.0,ship - forward * 9.0 + side * 7.0,ship - forward * 9.0 - side * 7.0]),Color("#d8f4f5"))
        draw_line(ship - forward * 4.0,ship - forward * 4.0 + side * (14.0 + float(state.get("deployment",0)) * 5.0),Color("#f5c76e"),3.0)
        draw_circle(ship,3.0,Color.WHITE)

var _rules: RefCounted
var _mission_index := 0
var _state: Dictionary = {}
var _trim := 0
var _deployment := 3
var _score := 0
var _mission_awarded := false
var _campaign_complete := false
var _trail: Array[Vector2] = []
var _status := "TRIM THE SAIL AND ADVANCE ONE FLIGHT TURN."
var _canvas: FlightCanvas
var _mission_label: Label
var _flight_label: Label
var _score_label: Label
var _status_label: Label
var _buttons: Array[Button] = []

func _ready() -> void:
    var path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else STANDALONE_RULES_PATH
    var script: Script = load(path) as Script
    if script == null:
        push_error("Solar Sail Navigator could not load rules: %s" % path)
        return
    _rules = script.new() as RefCounted
    _load_mission()
    _build_ui()
    _refresh_ui()

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_Q: adjust_trim(-1)
        KEY_E: adjust_trim(1)
        KEY_W: adjust_deployment(1)
        KEY_S: adjust_deployment(-1)
        KEY_SPACE,KEY_ENTER,KEY_KP_ENTER: advance_turn()
        KEY_R: reset_mission()
        KEY_N: advance_mission()
        _: return
    get_viewport().set_input_as_handled()

func _build_ui() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("#06131d")
    add_child(background)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left",24)
    margin.add_theme_constant_override("margin_right",24)
    margin.add_theme_constant_override("margin_top",16)
    margin.add_theme_constant_override("margin_bottom",16)
    add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation",8)
    margin.add_child(column)
    var title := Label.new()
    title.text = "KROLL // SOLAR SAIL NAVIGATOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",27)
    title.add_theme_color_override("font_color",Color("#a9e8f2"))
    column.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "LIGHT PRESSURE · SAIL TRIM · INERTIAL COASTING"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color",Color("#9ebbc6"))
    column.add_child(subtitle)
    var header := HBoxContainer.new()
    header.alignment = BoxContainer.ALIGNMENT_CENTER
    header.add_theme_constant_override("separation",24)
    column.add_child(header)
    _mission_label = Label.new()
    header.add_child(_mission_label)
    _score_label = Label.new()
    header.add_child(_score_label)
    _canvas = FlightCanvas.new()
    _canvas.name = "SolarSailFlightMap"
    _canvas.game = self
    _canvas.custom_minimum_size = Vector2(0.0,330.0)
    _canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(_canvas)
    _flight_label = Label.new()
    _flight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _flight_label.add_theme_color_override("font_color",Color("#c5e2e9"))
    column.add_child(_flight_label)
    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.add_theme_color_override("font_color",Color("#f0d59b"))
    column.add_child(_status_label)
    var trim_row := HBoxContainer.new()
    trim_row.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_child(trim_row)
    trim_row.add_child(_button("TRIM − 10°",Callable(self,"adjust_trim").bind(-1)))
    trim_row.add_child(_button("TRIM + 10°",Callable(self,"adjust_trim").bind(1)))
    trim_row.add_child(_button("SAIL −",Callable(self,"adjust_deployment").bind(-1)))
    trim_row.add_child(_button("SAIL +",Callable(self,"adjust_deployment").bind(1)))
    var action_row := HBoxContainer.new()
    action_row.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_child(action_row)
    action_row.add_child(_button("ADVANCE TURN [SPACE]",Callable(self,"advance_turn")))
    action_row.add_child(_button("RESET / RESTART [R]",Callable(self,"reset_mission")))
    action_row.add_child(_button("NEXT RELAY [N]",Callable(self,"advance_mission")))
    var hint := Label.new()
    hint.text = "Q/E trim · W/S sail deployment · Space advance · R reset · N next relay"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size",11)
    column.add_child(hint)

func _button(text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(145.0,42.0)
    button.pressed.connect(callback)
    _buttons.append(button)
    return button

func _load_mission() -> void:
    if _rules == null:
        return
    _state = _rules.call("initial_state")
    _trail.clear()
    var start: Vector2 = _state["position"]
    _trail.append(start)
    _trim = 0
    _deployment = 3
    _mission_awarded = false

func set_sail(trim: int, deployment: int) -> bool:
    if _mission_awarded or _campaign_complete or trim < -3 or trim > 3 or deployment < 0 or deployment > 3:
        return false
    _trim = trim
    _deployment = deployment
    _refresh_ui()
    return true

func adjust_trim(amount: int) -> bool:
    if _mission_awarded or _campaign_complete or amount == 0:
        return false
    var next_value := clampi(_trim + amount,-3,3)
    if next_value == _trim:
        return false
    _trim = next_value
    _refresh_ui()
    return true

func adjust_deployment(amount: int) -> bool:
    if _mission_awarded or _campaign_complete or amount == 0:
        return false
    var next_value := clampi(_deployment + amount,0,3)
    if next_value == _deployment:
        return false
    _deployment = next_value
    _refresh_ui()
    return true

func advance_turn() -> bool:
    if _rules == null or _mission_awarded or _campaign_complete:
        return false
    var result: Dictionary = _rules.call("step",_mission_index,_state,_trim,_deployment)
    if not bool(result.get("accepted",false)):
        return false
    _state = result["state"]
    var next_position: Vector2 = _state["position"]
    _trail.append(next_position)
    match str(_state.get("status","flight")):
        "success":
            _mission_awarded = true
            _score += 100
            if _mission_index == int(_rules.call("get_mission_count")) - 1:
                _campaign_complete = true
                _status = "CAMPAIGN COMPLETE · ALL THREE RELAYS CAPTURED."
            else:
                _status = "RELAY CAPTURED · 100 POINTS · ADVANCE WHEN READY."
        "collision": _status = "DEBRIS IMPACT · RESET AND CHANGE YOUR SAIL TRIM."
        "timeout": _status = "TURN LIMIT REACHED · RESET AND TRY A DIFFERENT FLIGHT PLAN."
        "out_of_bounds": _status = "FLIGHT PATH LOST · RESET THE RELAY."
        _: _status = "FLIGHT TURN %d · DISTANCE %.1f" % [int(_state.get("turn",0)),float(result.get("distance_to_target",0.0))]
    _refresh_ui()
    return true

func reset_mission() -> bool:
    if _campaign_complete:
        reset_campaign()
        return true
    if _mission_awarded:
        return false
    _load_mission()
    _status = "RELAY RESET · RE-TRIM THE SAIL."
    _refresh_ui()
    return true

func advance_mission() -> bool:
    if not _mission_awarded or _campaign_complete:
        return false
    _mission_index += 1
    _load_mission()
    _status = "NEXT RELAY · READ THE TARGET AND DEBRIS FIELD."
    _refresh_ui()
    return true

func reset_campaign() -> void:
    _mission_index = 0
    _score = 0
    _campaign_complete = false
    _load_mission()
    _status = "NEW EXPEDITION · SOLAR WAKE READY."
    _refresh_ui()

func get_current_state() -> Dictionary:
    if _rules == null:
        return {}
    var mission: Dictionary = _rules.call("get_mission",_mission_index)
    var result: Dictionary = _state.duplicate(true)
    result["mission_index"] = _mission_index
    result["mission_count"] = int(_rules.call("get_mission_count"))
    result["mission_id"] = str(mission.get("id",""))
    result["mission_name"] = str(mission.get("name",""))
    result["brief"] = str(mission.get("brief",""))
    result["target"] = mission.get("target",Vector2.ZERO)
    result["max_turns"] = int(mission.get("max_turns",0))
    result["hazards"] = mission.get("hazards",[]).duplicate(true)
    result["trim"] = _trim
    result["deployment"] = _deployment
    result["score"] = _score
    result["mission_awarded"] = _mission_awarded
    result["campaign_complete"] = _campaign_complete
    return result

func get_trail() -> Array:
    return _trail.duplicate()

func get_title_text() -> String:
    return "KROLL // SOLAR SAIL NAVIGATOR"

func get_mission_count() -> int:
    return int(_rules.call("get_mission_count")) if _rules != null else 0

func get_control_button_count() -> int:
    return _buttons.size()

func _refresh_ui() -> void:
    if _rules == null or _mission_label == null:
        return
    var state: Dictionary = get_current_state()
    var position: Vector2 = state.get("position",Vector2.ZERO)
    var velocity: Vector2 = state.get("velocity",Vector2.ZERO)
    _mission_label.text = "%s · %d/%d" % [str(state.get("mission_name","")),_mission_index + 1,int(state.get("mission_count",0))]
    _score_label.text = "SCORE %d" % _score
    _flight_label.text = "TURN %d/%d · POS %.1f, %.1f · SPEED %.2f · TRIM %d0° · SAIL %d/3" % [int(state.get("turn",0)),int(state.get("max_turns",0)),position.x,position.y,velocity.length(),_trim,_deployment]
    _status_label.text = str(state.get("brief","")) + "\n" + _status
    if is_instance_valid(_canvas):
        _canvas.queue_redraw()

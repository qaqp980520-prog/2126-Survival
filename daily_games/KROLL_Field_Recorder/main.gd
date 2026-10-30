extends Node2D

const Rules = preload("res://rules.gd")
const BACKGROUND := Color(0.025,0.055,0.045)
const CYAN := Color(0.28,0.9,1.0)
const AMBER := Color(1.0,0.72,0.28)
const SPECIES_COLORS: Dictionary = {
	"MOSSBACK":Color(0.46,0.78,0.38),"GLASSWING":Color(0.42,0.82,1.0),"TIDEHOPPER":Color(0.95,0.65,0.35),
	"SHARDHORN":Color(0.75,0.72,1.0),"LANTERN MITE":Color(1.0,0.86,0.42),"DUNE SKIPPER":Color(0.86,0.65,0.42),
	"CORAL GRAZER":Color(0.96,0.52,0.55),"PRISM JELLY":Color(0.55,0.82,1.0),"SALT RUNNER":Color(0.85,0.88,0.68)
}
var scenario_index: int = 0
var scenario: Dictionary = {}
var state: Dictionary = {}
var hud: Label
var message_label: Label
var touch_buttons: Dictionary = {}
var _held_actions: Dictionary = {"left":false,"right":false,"up":false,"down":false}
var _queued_focus_delta: float = 0.0

func _ready() -> void:
	_build_ui()
	_load_scenario(0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FieldHUD"
	add_child(layer)
	hud = Label.new()
	hud.name = "FieldStatus"
	hud.position = Vector2(18.0,12.0)
	hud.size = Vector2(920.0,62.0)
	hud.add_theme_color_override("font_color",Color(0.78,0.95,0.82))
	hud.add_theme_font_size_override("font_size",17)
	layer.add_child(hud)
	message_label = Label.new()
	message_label.name = "FieldMessage"
	message_label.position = Vector2(18.0,78.0)
	message_label.size = Vector2(920.0,34.0)
	message_label.add_theme_color_override("font_color",AMBER)
	layer.add_child(message_label)
	var panel := PanelContainer.new()
	panel.name = "TouchControls"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -206.0
	panel.offset_right = 206.0
	panel.offset_top = -142.0
	panel.offset_bottom = -8.0
	layer.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",4)
	grid.add_theme_constant_override("v_separation",4)
	panel.add_child(grid)
	_add_held_button(grid,"up","UP","up")
	_add_held_button(grid,"left","LEFT","left")
	_add_held_button(grid,"down","DOWN","down")
	_add_held_button(grid,"right","RIGHT","right")
	_add_command_button(grid,"focus_down","FOCUS -",_adjust_focus.bind(-1.0))
	_add_command_button(grid,"focus_up","FOCUS +",_adjust_focus.bind(1.0))
	_add_command_button(grid,"capture","CAPTURE",_capture_photo)
	_add_command_button(grid,"reset","RESET",_restart)
	_add_command_button(grid,"next","NEXT",_next_scenario)
	_refresh_hud()

func _add_held_button(parent: GridContainer,key: String,label_text: String,action: String) -> void:
	var button := Button.new()
	button.name = "Touch_"+key
	button.text = label_text
	button.custom_minimum_size = Vector2(92.0,36.0)
	parent.add_child(button)
	touch_buttons[key] = button
	button.button_down.connect(_set_held_action.bind(action,true))
	button.button_up.connect(_set_held_action.bind(action,false))

func _add_command_button(parent: GridContainer,key: String,label_text: String,callback: Callable) -> void:
	var button := Button.new()
	button.name = "Action_"+key
	button.text = label_text
	button.custom_minimum_size = Vector2(92.0,36.0)
	parent.add_child(button)
	touch_buttons[key] = button
	button.pressed.connect(callback)

func _set_held_action(action: String,value: bool) -> void:
	if _held_actions.has(action):
		_held_actions[action] = value

func _adjust_focus(delta_steps: float) -> void:
	_queued_focus_delta += delta_steps

func _process(delta: float) -> void:
	if state.is_empty() or scenario.is_empty(): return
	var input_state: Dictionary = _held_actions.duplicate(true)
	input_state["focus_delta"] = _queued_focus_delta
	state = Rules.step(state,input_state,delta,scenario)
	_queued_focus_delta = 0.0
	_refresh_hud()
	queue_redraw()

func _load_scenario(index: int) -> void:
	scenario_index = posmod(index,Rules.get_scenario_count())
	scenario = Rules.get_scenario(scenario_index)
	state = Rules.create_state(scenario_index)
	_held_actions = {"left":false,"right":false,"up":false,"down":false}
	_queued_focus_delta = 0.0
	if message_label != null:
		message_label.text = "Photograph all three species, then return to the field base."
	_refresh_hud()
	queue_redraw()

func _restart() -> void:
	_load_scenario(scenario_index)

func _next_scenario() -> void:
	_load_scenario(scenario_index+1)

func _capture_photo() -> Dictionary:
	var capture: Dictionary = Rules.capture_photo(state,scenario)
	state = capture["state"]
	var result: Dictionary = capture["result"]
	if bool(result.get("ok",false)):
		message_label.text = "Captured %s — quality %.0f%% · %d targets left" % [str(result.get("species","UNKNOWN")),float(result.get("quality",0.0)),int(result.get("remaining",0))]
	elif str(result.get("reason","")) == "camera_unsteady":
		message_label.text = "Hold still for %.2f seconds before shooting." % maxf(0.0,Rules.STILLNESS_REQUIRED-float(state.get("stillness",0.0)))
	elif str(result.get("reason","")) == "wrong_focus":
		message_label.text = "Focus mismatch. Adjust with Q / E or the FOCUS buttons."
	elif str(result.get("reason","")) == "wrong_facing":
		message_label.text = "Target is in range but outside the camera view."
	elif str(result.get("reason","")) in ["battery_low","battery_empty"]:
		message_label.text = "Camera battery too low."
	elif str(result.get("reason","")) == "return_to_base":
		message_label.text = "All species recorded. Return to the field base."
	else:
		message_label.text = "No unrecorded species in range. Move closer and align the camera."
	_refresh_hud()
	queue_redraw()
	return result

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey): return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo:
		match key_event.keycode:
			KEY_A,KEY_LEFT: _set_held_action("left",true)
			KEY_D,KEY_RIGHT: _set_held_action("right",true)
			KEY_W,KEY_UP: _set_held_action("up",true)
			KEY_S,KEY_DOWN: _set_held_action("down",true)
			KEY_Q: _adjust_focus(-1.0)
			KEY_E: _adjust_focus(1.0)
			KEY_SPACE: _capture_photo()
			KEY_R: _restart()
			KEY_N: _next_scenario()
	else:
		match key_event.keycode:
			KEY_A,KEY_LEFT: _set_held_action("left",false)
			KEY_D,KEY_RIGHT: _set_held_action("right",false)
			KEY_W,KEY_UP: _set_held_action("up",false)
			KEY_S,KEY_DOWN: _set_held_action("down",false)

func _refresh_hud() -> void:
	if hud == null or state.is_empty(): return
	var captured: Array = state.get("captured",[])
	var creatures: Array = state.get("creatures",[])
	hud.text = "KROLL FIELD RECORDER // %s\nSPECIES %d/%d   BATTERY %.0f%%   FOCUS %.2f   STABILITY %.1f s   TIME %.0f s" % [
		str(scenario.get("name","UNKNOWN")),captured.size(),creatures.size(),float(state.get("battery",0.0)),
		float(state.get("focus",1.0)),float(state.get("stillness",0.0)),float(state.get("elapsed",0.0))
	]
	var status: String = str(state.get("status","running"))
	if status == "won": message_label.text = "FIELD LOG COMPLETE — all specimens recorded and safely returned."
	elif status == "failed": message_label.text = "SURVEY FAILED — press R to retry or N for another field site."

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(960.0,640.0)),BACKGROUND)
	draw_rect(Rect2(Vector2(28.0,108.0),Vector2(904.0,454.0)),Color(0.06,0.12,0.085),false,3.0)
	for index in range(18):
		var point := Vector2(50.0+float((index*149)%860),126.0+float((index*83)%420))
		draw_circle(point,2.0+float(index%3),Color(0.24,0.4,0.23,0.55))
	if state.is_empty() or scenario.is_empty(): return
	var base_position: Vector2 = scenario["base_position"]
	draw_circle(base_position,34.0,Color(0.14,0.38,0.25))
	draw_arc(base_position,34.0,0.0,TAU,48,Color(0.4,0.9,0.58),3.0)
	draw_circle(base_position,9.0,Color(0.55,1.0,0.68))
	var captured: Array = state.get("captured",[])
	var creatures: Array = state.get("creatures",[])
	for creature in creatures:
		var species: String = str(creature.get("species",""))
		var creature_position: Vector2 = creature.get("position",Vector2.ZERO)
		var creature_color: Color = SPECIES_COLORS.get(species,AMBER)
		draw_circle(creature_position,17.0,creature_color if not captured.has(species) else Color(0.45,0.55,0.5,0.45))
		draw_arc(creature_position,23.0,0.0,TAU,32,creature_color,2.0)
	var player_position: Vector2 = state.get("player_position",Vector2.ZERO)
	var facing: Vector2 = state.get("facing",Vector2.RIGHT).normalized()
	draw_arc(player_position,Rules.MAX_RANGE,0.0,TAU,72,Color(0.22,0.72,0.78,0.18),1.0)
	draw_line(player_position,player_position+facing*52.0,CYAN,4.0)
	var side := Vector2(-facing.y,facing.x)
	var points := PackedVector2Array([player_position+facing*20.0,player_position-facing*12.0+side*11.0,player_position-facing*12.0-side*11.0])
	draw_colored_polygon(points,CYAN)

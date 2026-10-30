extends RefCounted

const MOVE_SPEED: float = 150.0
const MAX_BATTERY: float = 100.0
const SHOT_BASE_COST: float = 2.0
const SUCCESS_EXTRA_COST: float = 6.0
const MIN_RANGE: float = 60.0
const MAX_RANGE: float = 230.0
const MIN_FACING_DOT: float = 0.82
const FOCUS_TOLERANCE: float = 0.22
const STILLNESS_REQUIRED: float = 0.35
const RETURN_RADIUS: float = 54.0
const MAX_TIME: float = 180.0

const SCENARIOS: Array[Dictionary] = [
	{"id":"moss_fen","name":"MOSS FEN","base_position":Vector2(100.0,320.0),"creatures":[
		{"species":"MOSSBACK","base_position":Vector2(340.0,180.0),"patrol_axis":Vector2(1.0,0.0),"amplitude":16.0,"frequency":0.55,"phase":0.2,"focus":1.0},
		{"species":"GLASSWING","base_position":Vector2(690.0,230.0),"patrol_axis":Vector2(0.0,1.0),"amplitude":22.0,"frequency":0.7,"phase":1.1,"focus":2.0},
		{"species":"TIDEHOPPER","base_position":Vector2(650.0,470.0),"patrol_axis":Vector2(1.0,0.0),"amplitude":18.0,"frequency":0.85,"phase":2.0,"focus":3.0}
	]},
	{"id":"crystal_gully","name":"CRYSTAL GULLY","base_position":Vector2(120.0,520.0),"creatures":[
		{"species":"SHARDHORN","base_position":Vector2(260.0,210.0),"patrol_axis":Vector2(0.0,1.0),"amplitude":20.0,"frequency":0.6,"phase":0.8,"focus":1.25},
		{"species":"LANTERN MITE","base_position":Vector2(620.0,170.0),"patrol_axis":Vector2(1.0,0.0),"amplitude":24.0,"frequency":0.75,"phase":1.6,"focus":2.25},
		{"species":"DUNE SKIPPER","base_position":Vector2(760.0,430.0),"patrol_axis":Vector2(0.0,1.0),"amplitude":18.0,"frequency":0.9,"phase":2.4,"focus":3.25}
	]},
	{"id":"salt_reef","name":"SALT REEF","base_position":Vector2(850.0,520.0),"creatures":[
		{"species":"CORAL GRAZER","base_position":Vector2(650.0,410.0),"patrol_axis":Vector2(1.0,0.0),"amplitude":18.0,"frequency":0.65,"phase":0.4,"focus":1.5},
		{"species":"PRISM JELLY","base_position":Vector2(350.0,250.0),"patrol_axis":Vector2(0.0,1.0),"amplitude":26.0,"frequency":0.8,"phase":1.4,"focus":2.5},
		{"species":"SALT RUNNER","base_position":Vector2(160.0,150.0),"patrol_axis":Vector2(1.0,0.0),"amplitude":14.0,"frequency":0.95,"phase":2.2,"focus":3.5}
	]}
]

static func get_scenario_count() -> int:
	return SCENARIOS.size()

static func get_scenario(index: int) -> Dictionary:
	return SCENARIOS[posmod(index, SCENARIOS.size())].duplicate(true)

static func create_state(scenario_index: int = 0) -> Dictionary:
	var scenario: Dictionary = get_scenario(scenario_index)
	var creatures: Array = scenario["creatures"].duplicate(true)
	for index in range(creatures.size()):
		var creature: Dictionary = creatures[index]
		creature["position"] = creature["base_position"]
		creatures[index] = creature
	return {"elapsed":0.0,"player_position":scenario["base_position"],"facing":Vector2.RIGHT,"focus":1.0,"stillness":0.0,"battery":MAX_BATTERY,"captured":[],"creatures":creatures,"status":"running"}

static func step(state: Dictionary, input_state: Dictionary, delta_seconds: float, scenario: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status","failed")) != "running" or not is_finite(delta_seconds) or delta_seconds <= 0.0:
		return next
	var movement := Vector2.ZERO
	if bool(input_state.get("left",false)): movement.x -= 1.0
	if bool(input_state.get("right",false)): movement.x += 1.0
	if bool(input_state.get("up",false)): movement.y -= 1.0
	if bool(input_state.get("down",false)): movement.y += 1.0
	var player_position: Vector2 = next.get("player_position",Vector2.ZERO)
	if movement.length_squared() > 1.0: movement = movement.normalized()
	if movement.length_squared() > 0.0:
		player_position += movement * MOVE_SPEED * delta_seconds
		player_position.x = clampf(player_position.x,36.0,924.0)
		player_position.y = clampf(player_position.y,112.0,566.0)
		next["facing"] = movement.normalized()
		next["stillness"] = 0.0
	else:
		next["stillness"] = float(next.get("stillness",0.0)) + delta_seconds
	next["player_position"] = player_position
	next["focus"] = clampf(float(next.get("focus",1.0)) + float(input_state.get("focus_delta",0.0))*0.25,0.5,4.0)
	var elapsed: float = float(next.get("elapsed",0.0)) + delta_seconds
	next["elapsed"] = elapsed
	var creatures: Array = next.get("creatures",[])
	for index in range(creatures.size()):
		var creature: Dictionary = creatures[index]
		var base_position: Vector2 = creature.get("base_position",Vector2.ZERO)
		var axis: Vector2 = creature.get("patrol_axis",Vector2.RIGHT)
		creature["position"] = base_position + axis * sin(elapsed * float(creature.get("frequency",0.0)) + float(creature.get("phase",0.0))) * float(creature.get("amplitude",0.0))
		creatures[index] = creature
	next["creatures"] = creatures
	if elapsed >= MAX_TIME or float(next.get("battery",0.0)) <= 0.0:
		next["status"] = "failed"
	elif (next.get("captured",[]) as Array).size() >= creatures.size() and player_position.distance_to(scenario["base_position"]) <= RETURN_RADIUS:
		next["status"] = "won"
	return next

static func capture_photo(state: Dictionary, scenario: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status","failed")) != "running":
		return {"state":next,"result":{"ok":false,"reason":"not_running"}}
	var captured: Array = next.get("captured",[])
	var creatures: Array = next.get("creatures",[])
	if captured.size() >= creatures.size():
		return {"state":next,"result":{"ok":false,"reason":"return_to_base"}}
	if float(next.get("battery",0.0)) < SHOT_BASE_COST:
		return {"state":next,"result":{"ok":false,"reason":"battery_empty"}}
	next["battery"] = float(next["battery"]) - SHOT_BASE_COST
	if float(next.get("stillness",0.0)) < STILLNESS_REQUIRED:
		return {"state":next,"result":{"ok":false,"reason":"camera_unsteady"}}
	var player_position: Vector2 = next.get("player_position",Vector2.ZERO)
	var facing: Vector2 = next.get("facing",Vector2.RIGHT).normalized()
	var focus: float = float(next.get("focus",1.0))
	var in_range := false
	var facing_match := false
	var focus_match := false
	var target_index := -1
	for index in range(creatures.size()):
		var creature: Dictionary = creatures[index]
		if captured.has(str(creature.get("species",""))): continue
		var creature_position: Vector2 = creature.get("position",Vector2.ZERO)
		var distance: float = player_position.distance_to(creature_position)
		if distance < MIN_RANGE or distance > MAX_RANGE: continue
		in_range = true
		if facing.dot((creature_position-player_position).normalized()) < MIN_FACING_DOT: continue
		facing_match = true
		if absf(focus-float(creature.get("focus",1.0))) > FOCUS_TOLERANCE: continue
		focus_match = true
		target_index = index
		break
	if target_index < 0:
		var reason := "no_target"
		if in_range and not facing_match: reason = "wrong_facing"
		elif facing_match and not focus_match: reason = "wrong_focus"
		return {"state":next,"result":{"ok":false,"reason":reason,"battery_spent":SHOT_BASE_COST}}
	if float(next["battery"]) < SUCCESS_EXTRA_COST:
		return {"state":next,"result":{"ok":false,"reason":"battery_low","battery_spent":SHOT_BASE_COST}}
	var target: Dictionary = creatures[target_index]
	next["battery"] = float(next["battery"]) - SUCCESS_EXTRA_COST
	captured.append(str(target["species"]))
	next["captured"] = captured
	var distance_to_target: float = player_position.distance_to(target["position"])
	var focus_error: float = absf(focus-float(target["focus"]))
	var quality: float = clampf(100.0-absf(distance_to_target-140.0)*0.18-focus_error*40.0,0.0,100.0)
	var result := {"ok":true,"reason":"captured","species":str(target["species"]),"quality":quality,"battery_spent":SHOT_BASE_COST+SUCCESS_EXTRA_COST,"remaining":creatures.size()-captured.size()}
	if captured.size() >= creatures.size() and player_position.distance_to(scenario["base_position"]) <= RETURN_RADIUS:
		next["status"] = "won"
	return {"state":next,"result":result}

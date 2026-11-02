extends RefCounted
class_name KROLLChronoVaultRules

const GRID_SIZE: int = 7
const ACTIONS: Array[String] = ["up","down","left","right","wait"]
const OFFSETS: Dictionary = {"up":Vector2i(0,-1),"down":Vector2i(0,1),"left":Vector2i(-1,0),"right":Vector2i(1,0),"wait":Vector2i.ZERO}
const LEVELS: Array[Dictionary] = [
	{"id":"first_loop","title":"FIRST LOOP","start":Vector2i(1,1),"echo_plate":Vector2i(5,1),"player_plate":Vector2i(5,5),"exit":Vector2i(1,5),"walls":[Vector2i(3,2),Vector2i(3,3),Vector2i(3,4),Vector2i(2,4),Vector2i(4,2)]},
	{"id":"split_corridor","title":"SPLIT CORRIDOR","start":Vector2i(1,1),"echo_plate":Vector2i(5,1),"player_plate":Vector2i(5,5),"exit":Vector2i(1,5),"walls":[Vector2i(2,1),Vector2i(2,2),Vector2i(2,3),Vector2i(4,3),Vector2i(4,4),Vector2i(4,5)]},
	{"id":"fractured_timeline","title":"FRACTURED TIMELINE","start":Vector2i(1,1),"echo_plate":Vector2i(5,1),"player_plate":Vector2i(5,5),"exit":Vector2i(1,5),"walls":[Vector2i(2,1),Vector2i(3,1),Vector2i(4,1),Vector2i(2,3),Vector2i(4,3),Vector2i(2,5),Vector2i(3,5),Vector2i(4,5)]}
]
func get_level_count() -> int:
	return LEVELS.size()
func get_level_definition(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return LEVELS[index].duplicate(true)
func create_state(index: int, campaign_score: int = 0, completed: Array = []) -> Dictionary:
	var level: Dictionary = get_level_definition(index)
	if level.is_empty() or campaign_score < 0:
		return {}
	var done: Array[int] = []
	for value in completed:
		if value is int and int(value) >= 0 and int(value) < LEVELS.size() and not done.has(int(value)):
			done.append(int(value))
	var start: Vector2i = level["start"]
	return {"level_index":index,"level_id":str(level["id"]),"status":"playing","campaign_score":campaign_score,"score":0,"completed_levels":done,"player_pos":start,"echo_pos":start,"echo_script":[],"recording":[],"turn_index":0,"turn_count":0,"echo_active":false,"exit_unlocked":false}
func step_action(state: Dictionary, action: String) -> Dictionary:
	if str(state.get("status","")) != "playing":
		return {"ok":false,"reason":"level_not_playing"}
	if not ACTIONS.has(action):
		return {"ok":false,"reason":"invalid_action"}
	var level: Dictionary = get_level_definition(int(state.get("level_index",-1)))
	if level.is_empty():
		return {"ok":false,"reason":"invalid_level"}
	var next: Dictionary = state.duplicate(true)
	var walls: Array = level.get("walls",[])
	var echo_moved := false
	var script: Array = next.get("echo_script",[])
	var turn: int = int(next.get("turn_index",0))
	if bool(next.get("echo_active",false)) and turn < script.size():
		var echo_result: Dictionary = _apply(next["echo_pos"],str(script[turn]),walls)
		next["echo_pos"] = echo_result["position"]
		echo_moved = bool(echo_result["moved"])
	var player_result: Dictionary = _apply(next["player_pos"],action,walls)
	next["player_pos"] = player_result["position"]
	if not bool(next.get("echo_active",false)):
		var recording: Array = next.get("recording",[])
		recording.append(action)
		next["recording"] = recording
	next["turn_index"] = turn + 1
	next["turn_count"] = int(next.get("turn_count",0)) + 1
	var unlocked: bool = bool(next.get("exit_unlocked",false))
	if next["echo_pos"] == level["echo_plate"] and next["player_pos"] == level["player_plate"]:
		unlocked = true
	next["exit_unlocked"] = unlocked
	if unlocked and next["player_pos"] == level["exit"]:
		next["status"] = "passed"
		next["score"] = 100
	return {"ok":true,"state":next,"player_moved":bool(player_result["moved"]),"echo_moved":echo_moved}
func commit_echo(state: Dictionary) -> Dictionary:
	if str(state.get("status","")) != "playing":
		return {"ok":false,"reason":"level_not_playing"}
	if bool(state.get("echo_active",false)):
		return {"ok":false,"reason":"echo_already_active"}
	var level: Dictionary = get_level_definition(int(state.get("level_index",-1)))
	var recording: Array = state.get("recording",[])
	if level.is_empty() or recording.is_empty() or state.get("player_pos",Vector2i.ZERO) != level.get("echo_plate",Vector2i(-1,-1)):
		return {"ok":false,"reason":"echo_plate_not_reached"}
	var next: Dictionary = create_state(int(state["level_index"]),int(state.get("campaign_score",0)),state.get("completed_levels",[]))
	next["echo_script"] = recording.duplicate(true)
	next["echo_active"] = true
	return {"ok":true,"state":next,"recorded_turns":recording.size()}
func restart_level(state: Dictionary) -> Dictionary:
	var status: String = str(state.get("status",""))
	if status == "passed" or status == "campaign_complete":
		return {"ok":false,"reason":"completed_level_locked"}
	var next: Dictionary = create_state(int(state.get("level_index",-1)),int(state.get("campaign_score",0)),state.get("completed_levels",[]))
	if next.is_empty():
		return {"ok":false,"reason":"invalid_level"}
	next["echo_script"] = state.get("echo_script",[]).duplicate(true)
	next["echo_active"] = bool(state.get("echo_active",false))
	return {"ok":true,"state":next}
func advance_level(state: Dictionary) -> Dictionary:
	if str(state.get("status","")) != "passed":
		return {"ok":false,"reason":"level_not_passed"}
	var index: int = int(state.get("level_index",-1))
	if index < 0 or index >= LEVELS.size():
		return {"ok":false,"reason":"invalid_level"}
	var completed: Array = state.get("completed_levels",[]).duplicate()
	if not completed.has(index):
		completed.append(index)
	var total: int = int(state.get("campaign_score",0)) + int(state.get("score",0))
	if index + 1 >= LEVELS.size():
		return {"ok":true,"state":{"level_index":index,"level_id":"campaign","status":"campaign_complete","campaign_score":total,"total_score":total,"score":int(state.get("score",0)),"completed_levels":completed,"player_pos":Vector2i.ZERO,"echo_pos":Vector2i.ZERO,"echo_script":[],"recording":[],"turn_index":0,"turn_count":0,"echo_active":false,"exit_unlocked":true}}
	return {"ok":true,"state":create_state(index + 1,total,completed)}
func restart_campaign() -> Dictionary:
	return create_state(0)
func get_title_text() -> String:
	return "KROLL // CHRONO VAULT"
static func _apply(position: Vector2i, action: String, walls: Array) -> Dictionary:
	if not OFFSETS.has(action):
		return {"position":position,"moved":false}
	var offset: Vector2i = OFFSETS[action]
	if offset == Vector2i.ZERO:
		return {"position":position,"moved":false}
	var target: Vector2i = position + offset
	if target.x <= 0 or target.y <= 0 or target.x >= GRID_SIZE - 1 or target.y >= GRID_SIZE - 1 or walls.has(target):
		return {"position":position,"moved":false}
	return {"position":target,"moved":true}

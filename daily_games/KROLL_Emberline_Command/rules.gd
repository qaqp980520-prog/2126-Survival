extends RefCounted
class_name EmberlineCommandRules

const GRID_SIZE: int = 8
const CELL_COUNT: int = 64
const ACTIONS_PER_TURN: int = 2
const MISSIONS: Array[Dictionary] = [
    {"id":"ridge_watch","title":"RIDGE WATCH","briefing":"Two ignition points are moving toward the relay ridge. Use a water drop and a short firebreak to keep the three watch relays online.","board":["########","#..T...#","#..R...#","#FFTT..#","#..R...#","#...T.R#","#......#","########"],"wind_cycle":["east","east","north","east","south"],"max_turns":6,"max_burned":10},
    {"id":"canyon_shift","title":"CANYON SHIFT","briefing":"A northbound gust is pushing the canyon fire between dry timber stands. Wet the active front, then cut its next crosswind route.","board":["########","#T..T..#","#R.....#","#..FF..#","#..T..R#","#T..T..#","#R.....#","########"],"wind_cycle":["north","north","east","north","west"],"max_turns":7,"max_burned":12},
    {"id":"basin_relay","title":"BASIN RELAY","briefing":"A rotating west wind threatens a three-station sensor chain. Preserve the relay network while fuel pockets burn down.","board":["########","#..T...#","#R.T.R.#","#..FF..#","#TT.T..#","#R.....#","#...T..#","########"],"wind_cycle":["west","north","west","south","west","east"],"max_turns":7,"max_burned":14}
]

func create_state(mission_index: int = 0, campaign_score: int = 0) -> Dictionary:
    if mission_index < 0 or mission_index >= MISSIONS.size() or campaign_score < 0:
        return {}
    var rows: Array = MISSIONS[mission_index]["board"]
    var cells: Array[Dictionary] = []
    for y in range(GRID_SIZE):
        var row: String = str(rows[y])
        if row.length() != GRID_SIZE:
            return {}
        for x in range(GRID_SIZE):
            var cell: Dictionary = _make_cell(row.substr(x, 1))
            if cell.is_empty():
                return {}
            cells.append(cell)
    return {"mission_index":mission_index,"cells":cells,"turn":0,"actions_left":ACTIONS_PER_TURN,"actions_used":0,"firebreaks_remaining":6,"water_drops":3,"burned_count":0,"mission_score":0,"campaign_score":campaign_score,"relay_breached":false,"status":"playing","last_action":""}

func get_mission_count() -> int:
    return MISSIONS.size()

func get_cell_count() -> int:
    return CELL_COUNT

func get_cell_index(x: int, y: int) -> int:
    if x < 0 or x >= GRID_SIZE or y < 0 or y >= GRID_SIZE:
        return -1
    return y * GRID_SIZE + x

func get_mission_definition(mission_index: int) -> Dictionary:
    if mission_index < 0 or mission_index >= MISSIONS.size():
        return {}
    var definition: Dictionary = MISSIONS[mission_index].duplicate(true)
    definition.erase("board")
    definition.erase("wind_cycle")
    return definition

func get_wind_direction(state: Dictionary) -> String:
    var mission_index: int = int(state.get("mission_index",-1))
    if mission_index < 0 or mission_index >= MISSIONS.size():
        return "calm"
    var pattern: Array = MISSIONS[mission_index]["wind_cycle"]
    var turn: int = maxi(0,int(state.get("turn",0)))
    return str(pattern[turn % pattern.size()])

func get_active_fire_count(state: Dictionary) -> int:
    var count: int = 0
    for cell in state.get("cells",[]):
        if cell is Dictionary and bool(cell.get("burning",false)):
            count += 1
    return count

func get_relay_count(state: Dictionary) -> int:
    var count: int = 0
    for cell in state.get("cells",[]):
        if cell is Dictionary and bool(cell.get("relay",false)):
            count += 1
    return count

func get_cell_state(state: Dictionary, cell_index: int) -> Dictionary:
    var cells: Array = state.get("cells",[])
    if cell_index < 0 or cell_index >= cells.size() or not (cells[cell_index] is Dictionary):
        return {}
    return cells[cell_index].duplicate(true)

func get_neighbors(cell_index: int) -> Array[int]:
    var result: Array[int] = []
    if cell_index < 0 or cell_index >= CELL_COUNT:
        return result
    var x: int = cell_index % GRID_SIZE
    var y: int = int(cell_index / GRID_SIZE)
    if x > 0: result.append(get_cell_index(x-1,y))
    if x < GRID_SIZE-1: result.append(get_cell_index(x+1,y))
    if y > 0: result.append(get_cell_index(x,y-1))
    if y < GRID_SIZE-1: result.append(get_cell_index(x,y+1))
    return result

func apply_action(state: Dictionary, action: String, cell_index: int) -> Dictionary:
    var mission_index: int = int(state.get("mission_index",-1))
    if mission_index < 0 or mission_index >= MISSIONS.size():
        return {"ok":false,"reason":"invalid_mission"}
    if str(state.get("status","")) != "playing":
        return {"ok":false,"reason":"mission_not_active"}
    if cell_index < 0 or cell_index >= CELL_COUNT:
        return {"ok":false,"reason":"invalid_cell"}
    if int(state.get("actions_left",0)) <= 0:
        return {"ok":false,"reason":"actions_exhausted"}
    if not ["firebreak","water"].has(action):
        return {"ok":false,"reason":"invalid_action"}
    var next_state: Dictionary = state.duplicate(true)
    var cells: Array = next_state.get("cells",[])
    if cells.size() != CELL_COUNT:
        return {"ok":false,"reason":"invalid_grid"}
    var target: Dictionary = cells[cell_index]
    if action == "firebreak":
        if int(next_state.get("firebreaks_remaining",0)) <= 0:
            return {"ok":false,"reason":"firebreaks_exhausted"}
        if bool(target.get("burning",false)) or bool(target.get("firebreak",false)) or bool(target.get("relay",false)):
            return {"ok":false,"reason":"invalid_firebreak_target"}
        if not ["grass","forest"].has(str(target.get("terrain",""))) or int(target.get("fuel",0)) <= 0:
            return {"ok":false,"reason":"not_flammable"}
        if int(target.get("wet",0)) > 0 or not _is_adjacent_to_fire(cells,cell_index):
            return {"ok":false,"reason":"not_frontline"}
        target["firebreak"] = true
        target["fuel"] = 0
        cells[cell_index] = target
        next_state["firebreaks_remaining"] = int(next_state["firebreaks_remaining"])-1
    else:
        if int(next_state.get("water_drops",0)) <= 0:
            return {"ok":false,"reason":"water_exhausted"}
        if not bool(target.get("burning",false)):
            return {"ok":false,"reason":"water_requires_active_fire"}
        target["burning"] = false
        target["wet"] = 2
        cells[cell_index] = target
        for neighbor_index in get_neighbors(cell_index):
            var neighbor: Dictionary = cells[neighbor_index]
            if not bool(neighbor.get("burning",false)) and ["grass","forest"].has(str(neighbor.get("terrain",""))):
                neighbor["wet"] = maxi(int(neighbor.get("wet",0)),2)
                cells[neighbor_index] = neighbor
        next_state["water_drops"] = int(next_state.get("water_drops",0))-1
    next_state["cells"] = cells
    next_state["actions_left"] = int(next_state.get("actions_left",0))-1
    next_state["actions_used"] = int(next_state.get("actions_used",0))+1
    next_state["last_action"] = action
    return {"ok":true,"state":next_state,"action":action,"cell_index":cell_index}

func end_turn(state: Dictionary) -> Dictionary:
    var mission_index: int = int(state.get("mission_index",-1))
    if mission_index < 0 or mission_index >= MISSIONS.size():
        return {"ok":false,"reason":"invalid_mission"}
    if str(state.get("status","")) != "playing":
        return {"ok":false,"reason":"mission_not_active"}
    var cells: Array = state.get("cells",[]).duplicate(true)
    if cells.size() != CELL_COUNT:
        return {"ok":false,"reason":"invalid_grid"}
    var next_state: Dictionary = state.duplicate(true)
    var wind: Vector2i = _wind_vector(get_wind_direction(state))
    var side_wind: Vector2i = Vector2i(-wind.y,wind.x)
    if int(state.get("turn",0)) % 2 == 1:
        side_wind = -side_wind
    var new_ignitions: Dictionary = {}
    var breach_state: Dictionary = {"breached":bool(next_state.get("relay_breached",false))}
    var burned_count: int = int(next_state.get("burned_count",0))
    for cell_index in range(cells.size()):
        var cell: Dictionary = cells[cell_index]
        if not bool(cell.get("burning",false)):
            continue
        if int(cell.get("wet",0)) <= 0:
            _attempt_ignition(cells,_offset_index(cell_index,wind),new_ignitions,breach_state)
            if int(cell.get("fuel",0)) >= 2:
                _attempt_ignition(cells,_offset_index(cell_index,side_wind),new_ignitions,breach_state)
        cell["fuel"] = maxi(0,int(cell.get("fuel",0))-1)
        if int(cell["fuel"]) <= 0:
            cell["burning"] = false
            if not bool(cell.get("burned",false)):
                burned_count += 1
            cell["burned"] = true
        cells[cell_index] = cell
    for ignition_index_value in new_ignitions.keys():
        var ignition_index: int = int(ignition_index_value)
        var ignition_cell: Dictionary = cells[ignition_index]
        if bool(ignition_cell.get("relay",false)):
            ignition_cell["relay_hp"] = 0
            breach_state["breached"] = true
        elif not bool(ignition_cell.get("firebreak",false)) and int(ignition_cell.get("wet",0)) <= 0:
            ignition_cell["burning"] = true
        cells[ignition_index] = ignition_cell
    for cell_index in range(cells.size()):
        var cell: Dictionary = cells[cell_index]
        if int(cell.get("wet",0)) > 0:
            cell["wet"] = int(cell["wet"])-1
        cells[cell_index] = cell
    var next_turn: int = int(state.get("turn",0))+1
    next_state["cells"] = cells
    next_state["turn"] = next_turn
    next_state["burned_count"] = burned_count
    next_state["relay_breached"] = bool(breach_state.get("breached",false))
    if bool(next_state["relay_breached"]) or burned_count > int(MISSIONS[mission_index]["max_burned"]):
        next_state["status"] = "failed"
    elif get_active_fire_count(next_state) == 0:
        next_state["status"] = "passed"
        var score: int = maxi(25,100-next_turn*7-int(next_state.get("actions_used",0))*2-burned_count*2)
        next_state["mission_score"] = score
        next_state["campaign_score"] = int(next_state.get("campaign_score",0))+score
    elif next_turn >= int(MISSIONS[mission_index]["max_turns"]):
        next_state["status"] = "failed"
    else:
        next_state["actions_left"] = ACTIONS_PER_TURN
    return {"ok":true,"state":next_state,"wind":get_wind_direction(state)}

func advance_mission(state: Dictionary) -> Dictionary:
    if str(state.get("status","")) != "passed":
        return {"ok":false,"reason":"mission_not_passed"}
    var current_index: int = int(state.get("mission_index",-1))
    if current_index < 0 or current_index >= MISSIONS.size():
        return {"ok":false,"reason":"invalid_mission"}
    var campaign_score: int = int(state.get("campaign_score",0))
    if current_index+1 >= MISSIONS.size():
        var completed: Dictionary = state.duplicate(true)
        completed["status"] = "campaign_complete"
        return {"ok":true,"state":completed}
    return {"ok":true,"state":create_state(current_index+1,campaign_score)}

func restart_campaign() -> Dictionary:
    return {"ok":true,"state":create_state(0,0)}

func _make_cell(symbol: String) -> Dictionary:
    match symbol:
        "#": return {"terrain":"rock","fuel":0,"burning":false,"wet":0,"firebreak":false,"burned":false,"relay":false,"relay_hp":0}
        "~": return {"terrain":"water","fuel":0,"burning":false,"wet":0,"firebreak":false,"burned":false,"relay":false,"relay_hp":0}
        "T": return {"terrain":"forest","fuel":3,"burning":false,"wet":0,"firebreak":false,"burned":false,"relay":false,"relay_hp":0}
        "R": return {"terrain":"relay","fuel":0,"burning":false,"wet":0,"firebreak":false,"burned":false,"relay":true,"relay_hp":1}
        "F": return {"terrain":"grass","fuel":3,"burning":true,"wet":0,"firebreak":false,"burned":false,"relay":false,"relay_hp":0}
        ".": return {"terrain":"grass","fuel":2,"burning":false,"wet":0,"firebreak":false,"burned":false,"relay":false,"relay_hp":0}
        _: return {}

func _is_adjacent_to_fire(cells: Array, cell_index: int) -> bool:
    for neighbor_index in get_neighbors(cell_index):
        if bool(cells[neighbor_index].get("burning",false)):
            return true
    return false

func _offset_index(cell_index: int, offset: Vector2i) -> int:
    return get_cell_index(cell_index % GRID_SIZE + offset.x,int(cell_index / GRID_SIZE) + offset.y)

func _wind_vector(direction: String) -> Vector2i:
    match direction:
        "east": return Vector2i.RIGHT
        "south": return Vector2i.DOWN
        "west": return Vector2i.LEFT
        "north": return Vector2i.UP
        _: return Vector2i.ZERO

func _attempt_ignition(cells: Array, target_index: int, new_ignitions: Dictionary, breach_state: Dictionary) -> void:
    if target_index < 0 or target_index >= cells.size():
        return
    var target: Dictionary = cells[target_index]
    if bool(target.get("relay",false)):
        target["relay_hp"] = 0
        breach_state["breached"] = true
        cells[target_index] = target
        return
    if bool(target.get("burning",false)) or bool(target.get("firebreak",false)) or bool(target.get("burned",false)):
        return
    if int(target.get("wet",0)) > 0 or int(target.get("fuel",0)) <= 0:
        return
    if not ["grass","forest"].has(str(target.get("terrain",""))):
        return
    new_ignitions[target_index] = true

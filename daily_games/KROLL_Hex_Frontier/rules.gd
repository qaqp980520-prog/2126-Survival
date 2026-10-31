extends RefCounted

const GRID_RADIUS: int = 2
const WIN_TERRITORY: int = 10
const MAX_ENERGY: int = 9
const CLAIM_COST: int = 1
const UPGRADE_COST: int = 2
const BASE_PLAYER: Vector2i = Vector2i(-2, 0)
const BASE_AI: Vector2i = Vector2i(2, 0)
const DIRECTIONS: Array[Vector2i] = [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1)
]
const SCENARIO_NAMES: Array[String] = ["Dockside", "Ridge", "Floodplain"]

func get_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for q in range(-GRID_RADIUS, GRID_RADIUS + 1):
        for r in range(-GRID_RADIUS, GRID_RADIUS + 1):
            if abs(q + r) <= GRID_RADIUS:
                cells.append(Vector2i(q, r))
    return cells

func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for direction in DIRECTIONS:
        var neighbor: Vector2i = coord + direction
        if is_valid_coord(neighbor):
            result.append(neighbor)
    return result

func is_valid_coord(coord: Vector2i) -> bool:
    return maxi(maxi(abs(coord.x), abs(coord.y)), abs(coord.x + coord.y)) <= GRID_RADIUS

func get_scenario_name(scenario: int) -> String:
    return SCENARIO_NAMES[posmod(scenario, SCENARIO_NAMES.size())]

func new_game(scenario: int = 0) -> Dictionary:
    var selected_scenario: int = posmod(scenario, SCENARIO_NAMES.size())
    var tiles: Dictionary = {}
    for coord in get_cells():
        var yield_value: int = _tile_yield(coord, selected_scenario)
        tiles[_key(coord)] = {
            "q": coord.x,
            "r": coord.y,
            "owner": 0,
            "yield": yield_value,
            "upgrades": 0,
            "base": false
        }
    var player_base: Dictionary = tiles[_key(BASE_PLAYER)]
    player_base["owner"] = 1
    player_base["yield"] = 1
    player_base["base"] = true
    tiles[_key(BASE_PLAYER)] = player_base
    var ai_base: Dictionary = tiles[_key(BASE_AI)]
    ai_base["owner"] = 2
    ai_base["yield"] = 1
    ai_base["base"] = true
    tiles[_key(BASE_AI)] = ai_base
    return {
        "scenario": selected_scenario,
        "turn": 1,
        "current_player": 1,
        "action_used": false,
        "energy": {"1": 4, "2": 4},
        "tiles": tiles,
        "winner": 0,
        "last_action": "Claim a neutral hex connected to your base."
    }

func get_tile(state: Dictionary, coord: Vector2i) -> Dictionary:
    var tiles: Dictionary = state.get("tiles", {})
    var value: Variant = tiles.get(_key(coord), {})
    return value.duplicate(true) if value is Dictionary else {}

func get_energy(state: Dictionary, owner: int) -> int:
    var energy: Dictionary = state.get("energy", {})
    return int(energy.get(str(owner), 0))

func territory_count(state: Dictionary, owner: int) -> int:
    var count: int = 0
    var tiles: Dictionary = state.get("tiles", {})
    for value in tiles.values():
        if value is Dictionary and int(value.get("owner", 0)) == owner:
            count += 1
    return count

func get_legal_claims(state: Dictionary, owner: int) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    if int(state.get("winner", 0)) != 0 or int(state.get("current_player", 0)) != owner or bool(state.get("action_used", false)):
        return result
    if get_energy(state, owner) < CLAIM_COST:
        return result
    for coord in get_cells():
        var tile: Dictionary = get_tile(state, coord)
        if int(tile.get("owner", -1)) == 0 and _touches_owner(state, coord, owner):
            result.append(coord)
    return result

func get_legal_upgrades(state: Dictionary, owner: int) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    if int(state.get("winner", 0)) != 0 or int(state.get("current_player", 0)) != owner or bool(state.get("action_used", false)):
        return result
    if get_energy(state, owner) < UPGRADE_COST:
        return result
    for coord in get_cells():
        var tile: Dictionary = get_tile(state, coord)
        if int(tile.get("owner", 0)) == owner and int(tile.get("yield", 0)) < 3:
            result.append(coord)
    return result

func apply_claim(state: Dictionary, coord: Vector2i) -> Dictionary:
    var owner: int = int(state.get("current_player", 0))
    if int(state.get("winner", 0)) != 0:
        return _failure("game_over", state)
    if owner != 1 and owner != 2:
        return _failure("invalid_turn", state)
    if bool(state.get("action_used", false)):
        return _failure("action_already_used", state)
    if get_energy(state, owner) < CLAIM_COST:
        return _failure("insufficient_energy", state)
    var tile: Dictionary = get_tile(state, coord)
    if tile.is_empty() or int(tile.get("owner", -1)) != 0:
        return _failure("occupied_or_invalid", state)
    if not _touches_owner(state, coord, owner):
        return _failure("not_connected", state)
    var next: Dictionary = state.duplicate(true)
    _claim_in_place(next, owner, coord)
    return {"ok": true, "reason": "claimed", "state": next}

func apply_upgrade(state: Dictionary, coord: Vector2i) -> Dictionary:
    var owner: int = int(state.get("current_player", 0))
    if int(state.get("winner", 0)) != 0:
        return _failure("game_over", state)
    if owner != 1 and owner != 2:
        return _failure("invalid_turn", state)
    if bool(state.get("action_used", false)):
        return _failure("action_already_used", state)
    if get_energy(state, owner) < UPGRADE_COST:
        return _failure("insufficient_energy", state)
    var tile: Dictionary = get_tile(state, coord)
    if tile.is_empty() or int(tile.get("owner", 0)) != owner:
        return _failure("not_owned", state)
    if int(tile.get("yield", 0)) >= 3:
        return _failure("max_yield", state)
    var next: Dictionary = state.duplicate(true)
    var tiles: Dictionary = next["tiles"]
    var upgraded: Dictionary = tiles[_key(coord)]
    upgraded["yield"] = int(upgraded.get("yield", 0)) + 1
    upgraded["upgrades"] = int(upgraded.get("upgrades", 0)) + 1
    tiles[_key(coord)] = upgraded
    next["tiles"] = tiles
    _spend_energy(next, owner, UPGRADE_COST)
    next["action_used"] = true
    next["last_action"] = "Player %d upgraded a tile at %s." % [owner, _coord_label(coord)]
    return {"ok": true, "reason": "upgraded", "state": next}

func advance_round(state: Dictionary) -> Dictionary:
    if int(state.get("winner", 0)) != 0:
        return _failure("game_over", state)
    if int(state.get("current_player", 0)) != 1:
        return _failure("not_player_turn", state)
    var next: Dictionary = state.duplicate(true)
    next["current_player"] = 2
    next["action_used"] = false
    _apply_income(next, 2)
    var ai_action: String = "AI passed."
    var ai_claims: Array[Vector2i] = get_legal_claims(next, 2)
    if not ai_claims.is_empty():
        var best_coord: Vector2i = ai_claims[0]
        var best_score: int = -999
        for coord in ai_claims:
            var tile: Dictionary = get_tile(next, coord)
            var score: int = int(tile.get("yield", 0)) * 100 + _owned_neighbor_count(next, coord, 2) * 10
            if score > best_score:
                best_score = score
                best_coord = coord
        _claim_in_place(next, 2, best_coord)
        ai_action = "AI claimed %s." % _coord_label(best_coord)
    else:
        var ai_upgrades: Array[Vector2i] = get_legal_upgrades(next, 2)
        if not ai_upgrades.is_empty():
            var upgrade_coord: Vector2i = ai_upgrades[0]
            var upgrade_result: Dictionary = apply_upgrade(next, upgrade_coord)
            if bool(upgrade_result.get("ok", false)):
                next = upgrade_result["state"]
                ai_action = "AI upgraded %s." % _coord_label(upgrade_coord)
    if int(next.get("winner", 0)) == 0:
        next["current_player"] = 1
        next["action_used"] = false
        next["turn"] = int(next.get("turn", 1)) + 1
        _apply_income(next, 1)
    else:
        next["current_player"] = 0
    next["last_action"] = ai_action
    return {"ok": true, "reason": "round_advanced", "state": next, "ai_action": ai_action}

func _claim_in_place(state: Dictionary, owner: int, coord: Vector2i) -> void:
    var tiles: Dictionary = state["tiles"]
    var tile: Dictionary = tiles[_key(coord)]
    tile["owner"] = owner
    tile["upgrades"] = 0
    tiles[_key(coord)] = tile
    state["tiles"] = tiles
    _spend_energy(state, owner, CLAIM_COST)
    state["action_used"] = true
    state["last_action"] = "Player %d claimed %s." % [owner, _coord_label(coord)]
    if territory_count(state, owner) >= WIN_TERRITORY:
        state["winner"] = owner

func _spend_energy(state: Dictionary, owner: int, amount: int) -> void:
    var energy: Dictionary = state.get("energy", {}).duplicate(true)
    energy[str(owner)] = maxi(0, int(energy.get(str(owner), 0)) - amount)
    state["energy"] = energy

func _apply_income(state: Dictionary, owner: int) -> void:
    var income: int = 0
    var tiles: Dictionary = state.get("tiles", {})
    for value in tiles.values():
        if value is Dictionary and int(value.get("owner", 0)) == owner:
            income += int(value.get("yield", 0))
    income = maxi(1, income)
    var energy: Dictionary = state.get("energy", {}).duplicate(true)
    energy[str(owner)] = mini(MAX_ENERGY, int(energy.get(str(owner), 0)) + income)
    state["energy"] = energy

func _touches_owner(state: Dictionary, coord: Vector2i, owner: int) -> bool:
    for neighbor in get_neighbors(coord):
        if int(get_tile(state, neighbor).get("owner", 0)) == owner:
            return true
    return false

func _owned_neighbor_count(state: Dictionary, coord: Vector2i, owner: int) -> int:
    var count: int = 0
    for neighbor in get_neighbors(coord):
        if int(get_tile(state, neighbor).get("owner", 0)) == owner:
            count += 1
    return count

func _tile_yield(coord: Vector2i, scenario: int) -> int:
    var value: int = posmod(coord.x * 7 + coord.y * 11 + scenario * 5 + 31, 4)
    if coord == Vector2i.ZERO:
        value = 3
    return value

func _key(coord: Vector2i) -> String:
    return "%d,%d" % [coord.x, coord.y]

func _coord_label(coord: Vector2i) -> String:
    return "(%d,%d)" % [coord.x, coord.y]

func _failure(reason: String, state: Dictionary) -> Dictionary:
    return {"ok": false, "reason": reason, "state": state.duplicate(true)}

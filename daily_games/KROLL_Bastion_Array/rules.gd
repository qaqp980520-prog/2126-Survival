extends RefCounted
class_name KrollBastionArrayRules

const LANE_COUNT: int = 3
const COLUMN_COUNT: int = 5
const STARTING_CORE_HP: int = 20
const STARTING_CREDITS: int = 100
const TOWER_COST: int = 40
const TOWER_RANGE: float = 1.75
const TOWER_DAMAGE: int = 3
const TOWER_COOLDOWN: float = 0.78
const ENEMY_HP: int = 6
const ENEMY_SPEED: float = 0.62
const ENEMY_LEAK_X: float = 4.25
const ENEMY_LEAK_DAMAGE: int = 4
const KILL_REWARD: int = 15
const WAVE_CLEAR_REWARD: int = 25
const WAVE_SCORE_REWARD: int = 100
const WAVE_QUOTAS := [4, 5, 6]

static func create_state() -> Dictionary:
	return {
		"core_hp": STARTING_CORE_HP,
		"credits": STARTING_CREDITS,
		"wave_index": 0,
		"completed_waves": 0,
		"spawned": 0,
		"kills": 0,
		"leaks": 0,
		"score": 0,
		"towers": [],
		"enemies": [],
		"game_over": false,
		"won": false
	}

static func wave_count() -> int:
	return WAVE_QUOTAS.size()

static func wave_quota(index: int) -> int:
	if index < 0 or index >= WAVE_QUOTAS.size():
		return 0
	return int(WAVE_QUOTAS[index])

static func build_tower(state: Dictionary, lane: int, column: int) -> bool:
	if bool(state.get("game_over", false)) or bool(state.get("won", false)):
		return false
	if lane < 0 or lane >= LANE_COUNT or column < 1 or column >= COLUMN_COUNT - 1:
		return false
	var towers: Array = state.get("towers", [])
	for existing in towers:
		if not (existing is Dictionary):
			continue
		if int(existing.get("lane", -1)) == lane and int(existing.get("column", -1)) == column:
			return false
	var credits: int = int(state.get("credits", 0))
	if credits < TOWER_COST:
		return false
	towers.append({
		"lane": lane,
		"column": column,
		"level": 1,
		"cooldown": 0.0
	})
	state["towers"] = towers
	state["credits"] = credits - TOWER_COST
	return true

static func add_enemy(state: Dictionary, lane: int, serial: int) -> bool:
	if bool(state.get("game_over", false)) or bool(state.get("won", false)):
		return false
	if lane < 0 or lane >= LANE_COUNT:
		return false
	var enemies: Array = state.get("enemies", [])
	enemies.append({
		"id": serial,
		"lane": lane,
		"x": 0.0,
		"hp": ENEMY_HP
	})
	state["enemies"] = enemies
	state["spawned"] = int(state.get("spawned", 0)) + 1
	return true

static func fire_tower(state: Dictionary, tower_index: int) -> bool:
	var towers: Array = state.get("towers", [])
	if tower_index < 0 or tower_index >= towers.size():
		return false
	var tower_value: Variant = towers[tower_index]
	if not (tower_value is Dictionary):
		return false
	var tower: Dictionary = tower_value
	var enemies: Array = state.get("enemies", [])
	var target_index: int = -1
	var target_x: float = -1000000.0
	for enemy_index in range(enemies.size()):
		var enemy_value: Variant = enemies[enemy_index]
		if not (enemy_value is Dictionary):
			continue
		var enemy: Dictionary = enemy_value
		if int(enemy.get("lane", -1)) != int(tower.get("lane", -2)):
			continue
		var enemy_x: float = float(enemy.get("x", -1000.0))
		if absf(enemy_x - float(tower.get("column", -1000))) > TOWER_RANGE:
			continue
		if enemy_x > target_x:
			target_x = enemy_x
			target_index = enemy_index
	if target_index < 0:
		return false
	var target: Dictionary = enemies[target_index]
	target["hp"] = int(target.get("hp", 0)) - TOWER_DAMAGE
	if int(target["hp"]) <= 0:
		enemies.remove_at(target_index)
		state["kills"] = int(state.get("kills", 0)) + 1
		state["credits"] = int(state.get("credits", 0)) + KILL_REWARD
	else:
		enemies[target_index] = target
	state["enemies"] = enemies
	return true

static func advance_enemies(state: Dictionary, delta: float) -> int:
	if not is_finite(delta) or delta <= 0.0:
		return 0
	var enemies: Array = state.get("enemies", [])
	var leaked: int = 0
	for index in range(enemies.size() - 1, -1, -1):
		var enemy_value: Variant = enemies[index]
		if not (enemy_value is Dictionary):
			enemies.remove_at(index)
			continue
		var enemy: Dictionary = enemy_value
		var next_x: float = float(enemy.get("x", 0.0)) + ENEMY_SPEED * delta
		if next_x >= ENEMY_LEAK_X:
			enemies.remove_at(index)
			leaked += 1
		else:
			enemy["x"] = next_x
			enemies[index] = enemy
	state["enemies"] = enemies
	if leaked > 0:
		state["leaks"] = int(state.get("leaks", 0)) + leaked
		var remaining_hp: int = maxi(0, int(state.get("core_hp", STARTING_CORE_HP)) - leaked * ENEMY_LEAK_DAMAGE)
		state["core_hp"] = remaining_hp
		if remaining_hp <= 0:
			state["game_over"] = true
	return leaked

static func finish_wave(state: Dictionary) -> bool:
	if bool(state.get("game_over", false)) or bool(state.get("won", false)):
		return false
	var wave_index: int = int(state.get("wave_index", 0))
	if wave_index < 0 or wave_index >= WAVE_QUOTAS.size():
		return false
	state["wave_index"] = wave_index + 1
	state["completed_waves"] = int(state.get("completed_waves", 0)) + 1
	state["credits"] = int(state.get("credits", 0)) + WAVE_CLEAR_REWARD
	state["score"] = int(state.get("score", 0)) + WAVE_SCORE_REWARD
	if int(state["wave_index"]) >= WAVE_QUOTAS.size():
		state["won"] = true
	return true

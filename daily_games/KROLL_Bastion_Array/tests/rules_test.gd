extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	_test_build_rules_and_credit_cost()
	_test_tower_targets_only_its_lane()
	_test_enemy_leak_and_core_failure()
	_test_wave_rewards_are_one_time()
	print("KROLL Bastion Array rules tests passed.")
	quit(0)

func _test_build_rules_and_credit_cost() -> void:
	var state: Dictionary = Rules.create_state()
	assert(Rules.build_tower(state, 0, 1))
	assert(int(state["credits"]) == 60)
	assert(not Rules.build_tower(state, 0, 1), "a cell cannot contain two towers")
	assert(not Rules.build_tower(state, -1, 2))
	assert(not Rules.build_tower(state, 3, 2))
	assert(not Rules.build_tower(state, 1, 0), "entry column is reserved")
	assert(not Rules.build_tower(state, 1, 4), "core column is reserved")
	assert(Rules.build_tower(state, 1, 3))
	assert(int(state["credits"]) == 20)
	assert(not Rules.build_tower(state, 2, 2), "insufficient credits must reject a build")
	assert(state["towers"].size() == 2)

func _test_tower_targets_only_its_lane() -> void:
	var state: Dictionary = Rules.create_state()
	assert(Rules.build_tower(state, 0, 2))
	assert(Rules.add_enemy(state, 1, 1))
	assert(Rules.add_enemy(state, 0, 2))
	var enemies: Array = state["enemies"]
	var target: Dictionary = enemies[1]
	target["x"] = 1.5
	enemies[1] = target
	state["enemies"] = enemies
	assert(Rules.fire_tower(state, 0), "tower should attack an enemy in its own lane")
	assert(Rules.fire_tower(state, 0), "second shot should finish the target")
	assert(int(state["kills"]) == 1)
	assert(int(state["credits"]) == 75, "kill reward is granted once")
	assert(state["enemies"].size() == 1, "enemy in another lane remains untouched")
	assert(not Rules.fire_tower(state, 0), "tower cannot target an enemy outside its lane")

func _test_enemy_leak_and_core_failure() -> void:
	var state: Dictionary = Rules.create_state()
	assert(Rules.add_enemy(state, 2, 1))
	var enemies: Array = state["enemies"]
	var first: Dictionary = enemies[0]
	first["x"] = 4.2
	enemies[0] = first
	state["enemies"] = enemies
	assert(Rules.advance_enemies(state, 0.1) == 1)
	assert(int(state["core_hp"]) == 16)
	for serial in range(2, 6):
		assert(Rules.add_enemy(state, 2, serial))
	enemies = state["enemies"]
	for index in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		enemy["x"] = 4.2
		enemies[index] = enemy
	state["enemies"] = enemies
	assert(Rules.advance_enemies(state, 0.1) == 4)
	assert(int(state["core_hp"]) == 0)
	assert(bool(state["game_over"]))

func _test_wave_rewards_are_one_time() -> void:
	var state: Dictionary = Rules.create_state()
	assert(not Rules.finish_wave(state), "wave cannot clear before its quota is spawned")
	state["spawned"] = Rules.wave_quota(0)
	state["enemies"] = [{"lane": 0, "x": 1.0, "hp": 1}]
	assert(not Rules.finish_wave(state), "wave cannot clear while enemies remain")
	state["enemies"] = []
	assert(Rules.finish_wave(state))
	assert(int(state["wave_index"]) == 1)
	assert(int(state["completed_waves"]) == 1)
	assert(int(state["score"]) == 100)
	assert(int(state["credits"]) == 125)
	state["spawned"] = Rules.wave_quota(1)
	assert(Rules.finish_wave(state))
	state["spawned"] = Rules.wave_quota(2)
	assert(Rules.finish_wave(state))
	assert(bool(state["won"]))
	assert(int(state["completed_waves"]) == 3)
	assert(int(state["score"]) == 300)
	assert(int(state["credits"]) == 175)
	assert(not Rules.finish_wave(state), "completed campaign cannot award a fourth wave")

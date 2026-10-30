extends RefCounted

## Deterministic three-lane runner model. Input actions are edge-triggered.
const RUN_SPEED: float = 14.0
const JUMP_DURATION: float = 0.62
const SLIDE_DURATION: float = 0.48
const LANE_COUNT: int = 3

const SCENARIOS: Array[Dictionary] = [
	{
		"id": "training",
		"name": "TRAINING TUNNEL",
		"end_distance": 48.0,
		"required_cells": 2,
		"obstacles": [
			{"at": 9.0, "lane": 1, "kind": "barrier"},
			{"at": 18.0, "lane": 0, "kind": "gate"},
			{"at": 29.0, "lane": 2, "kind": "drone"},
			{"at": 38.0, "lane": 1, "kind": "barrier"}
		],
		"pickups": [
			{"at": 14.0, "lane": 2},
			{"at": 33.0, "lane": 0}
		]
	},
	{
		"id": "cargo",
		"name": "CARGO SPINE",
		"end_distance": 52.0,
		"required_cells": 2,
		"obstacles": [
			{"at": 8.0, "lane": 1, "kind": "gate"},
			{"at": 19.0, "lane": 2, "kind": "barrier"},
			{"at": 31.0, "lane": 0, "kind": "drone"},
			{"at": 42.0, "lane": 1, "kind": "gate"}
		],
		"pickups": [
			{"at": 14.0, "lane": 0},
			{"at": 36.0, "lane": 2}
		]
	},
	{
		"id": "reactor",
		"name": "REACTOR ACCESS",
		"end_distance": 56.0,
		"required_cells": 2,
		"obstacles": [
			{"at": 10.0, "lane": 1, "kind": "drone"},
			{"at": 22.0, "lane": 0, "kind": "barrier"},
			{"at": 34.0, "lane": 2, "kind": "gate"},
			{"at": 45.0, "lane": 1, "kind": "barrier"}
		],
		"pickups": [
			{"at": 16.0, "lane": 2},
			{"at": 39.0, "lane": 0}
		]
	}
]

static func get_scenario_count() -> int:
	return SCENARIOS.size()

static func get_scenario(index: int) -> Dictionary:
	return SCENARIOS[posmod(index, SCENARIOS.size())].duplicate(true)

static func create_state(scenario_index: int = 0) -> Dictionary:
	var scenario: Dictionary = get_scenario(scenario_index)
	var obstacles: Array = scenario["obstacles"].duplicate(true)
	var pickups: Array = scenario["pickups"].duplicate(true)
	for obstacle in obstacles:
		obstacle["resolved"] = false
	for pickup in pickups:
		pickup["resolved"] = false
	return {
		"distance": 0.0,
		"elapsed": 0.0,
		"lane": 1,
		"jump_timer": 0.0,
		"slide_timer": 0.0,
		"health": 2,
		"cells": 0,
		"status": "running",
		"obstacles": obstacles,
		"pickups": pickups
	}

static func step(state: Dictionary, input_state: Dictionary, delta_seconds: float, scenario: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "failed")) != "running":
		return next
	if not is_finite(delta_seconds) or delta_seconds <= 0.0:
		return next
	var lane: int = int(next.get("lane", 1))
	if bool(input_state.get("left", false)) and not bool(input_state.get("right", false)):
		lane = maxi(0, lane - 1)
	elif bool(input_state.get("right", false)) and not bool(input_state.get("left", false)):
		lane = mini(LANE_COUNT - 1, lane + 1)
	next["lane"] = lane
	var jump_timer: float = maxf(0.0, float(next.get("jump_timer", 0.0)) - delta_seconds)
	var slide_timer: float = maxf(0.0, float(next.get("slide_timer", 0.0)) - delta_seconds)
	if bool(input_state.get("jump", false)):
		jump_timer = JUMP_DURATION
	if bool(input_state.get("slide", false)):
		slide_timer = SLIDE_DURATION
	next["jump_timer"] = jump_timer
	next["slide_timer"] = slide_timer
	var previous_distance: float = float(next.get("distance", 0.0))
	var distance: float = previous_distance + RUN_SPEED * delta_seconds
	next["distance"] = distance
	next["elapsed"] = float(next.get("elapsed", 0.0)) + delta_seconds
	var health: int = int(next.get("health", 0))
	var obstacles: Array = next.get("obstacles", [])
	for index in range(obstacles.size()):
		var obstacle: Dictionary = obstacles[index]
		if bool(obstacle.get("resolved", false)):
			continue
		var obstacle_distance: float = float(obstacle.get("at", -1.0))
		if obstacle_distance <= previous_distance or obstacle_distance > distance:
			continue
		var kind: String = str(obstacle.get("kind", "drone"))
		var safe: bool = false
		if int(obstacle.get("lane", -1)) != lane:
			safe = true
		elif kind == "barrier":
			safe = jump_timer > 0.0
		elif kind == "gate":
			safe = slide_timer > 0.0
		if not safe:
			health -= 1
		obstacle["resolved"] = true
		obstacles[index] = obstacle
	next["obstacles"] = obstacles
	var cells: int = int(next.get("cells", 0))
	var pickups: Array = next.get("pickups", [])
	for index in range(pickups.size()):
		var pickup: Dictionary = pickups[index]
		if bool(pickup.get("resolved", false)):
			continue
		var pickup_distance: float = float(pickup.get("at", -1.0))
		if pickup_distance <= previous_distance or pickup_distance > distance:
			continue
		if int(pickup.get("lane", -1)) == lane:
			cells += 1
		pickup["resolved"] = true
		pickups[index] = pickup
	next["pickups"] = pickups
	next["cells"] = cells
	next["health"] = health
	if health <= 0:
		next["status"] = "failed"
	elif distance >= float(scenario.get("end_distance", INF)):
		next["status"] = "won" if cells >= int(scenario.get("required_cells", 0)) else "failed"
	return next

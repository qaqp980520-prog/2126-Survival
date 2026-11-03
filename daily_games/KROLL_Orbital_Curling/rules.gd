extends RefCounted

const RINK_MIN := Vector2(40.0, 105.0)
const RINK_MAX := Vector2(960.0, 585.0)
const LAUNCH_POINT := Vector2(140.0, 345.0)
const TARGETS := [
	Vector2(820.0, 185.0),
	Vector2(820.0, 505.0),
	Vector2(820.0, 345.0)
]
const STONE_RADIUS := 16.0
const MIN_POWER := 60.0
const MAX_POWER := 360.0
const FRICTION := 0.991
const WALL_RESTITUTION := 0.58
const STEP_SECONDS := 1.0 / 60.0
const REST_SPEED := 3.0
const MAX_STEPS := 900
const SHOTS_PER_ROUND := 3
const CAMPAIGN_GOAL := 45

func get_rink_min() -> Vector2:
	return RINK_MIN

func get_rink_max() -> Vector2:
	return RINK_MAX

func get_stone_radius() -> float:
	return STONE_RADIUS

func get_min_power() -> float:
	return MIN_POWER

func get_max_power() -> float:
	return MAX_POWER

func get_shots_per_round() -> int:
	return SHOTS_PER_ROUND

func new_campaign() -> Dictionary:
	return {
		"round_index": 0,
		"shots_left": SHOTS_PER_ROUND,
		"stones": [],
		"round_scores": [],
		"round_score": 0,
		"total_score": 0,
		"target": TARGETS[0],
		"status": "playing",
		"message": "Drag from the launch stone opposite your desired direction, then release."
	}

func get_round_count() -> int:
	return TARGETS.size()

func get_target(round_index: int) -> Vector2:
	return TARGETS[clampi(round_index, 0, TARGETS.size() - 1)]

func get_launch_point() -> Vector2:
	return LAUNCH_POINT

func throw_stone(state: Dictionary, aim: Vector2, power: float) -> Dictionary:
	if state.is_empty() or str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "round_not_playing"}
	if int(state.get("shots_left", 0)) <= 0:
		return {"ok": false, "reason": "no_shots_left"}
	if not is_finite(aim.x) or not is_finite(aim.y) or aim.length_squared() < 0.0001:
		return {"ok": false, "reason": "invalid_aim"}
	if not is_finite(power) or power < MIN_POWER or power > MAX_POWER:
		return {"ok": false, "reason": "invalid_power"}

	var next: Dictionary = state.duplicate(true)
	var positions: Array[Vector2] = []
	var velocities: Array[Vector2] = []
	for stone_value in next.get("stones", []):
		var stone: Dictionary = stone_value
		var stone_position: Vector2 = stone.get("position", LAUNCH_POINT)
		positions.append(stone_position)
		velocities.append(Vector2.ZERO)
	positions.append(LAUNCH_POINT)
	velocities.append(aim.normalized() * power)
	_simulate(positions, velocities)

	var settled_stones: Array[Dictionary] = []
	for position in positions:
		settled_stones.append({"position": position})
	next["stones"] = settled_stones
	next["shots_left"] = int(next["shots_left"]) - 1
	var round_score := 0
	if int(next["shots_left"]) == 0:
		round_score = _score_round(next)
		var scores: Array = next.get("round_scores", []).duplicate()
		scores.append(round_score)
		next["round_scores"] = scores
		next["round_score"] = round_score
		next["total_score"] = int(next.get("total_score", 0)) + round_score
		if int(next["round_index"]) >= TARGETS.size() - 1:
			var campaign_cleared := int(next["total_score"]) >= CAMPAIGN_GOAL
			next["status"] = "won" if campaign_cleared else "complete"
			if campaign_cleared:
				next["message"] = "CAMPAIGN CLEARED — %d / 90 points." % int(next["total_score"])
			else:
				next["message"] = "CAMPAIGN COMPLETE — %d / 90 points. Goal: 45." % int(next["total_score"])
		else:
			next["status"] = "round_complete"
			next["message"] = "Round scored %d points. Advance when ready." % round_score
	else:
		next["message"] = "Stone settled. %d throws remain." % int(next["shots_left"])
	return {
		"ok": true,
		"reason": "thrown",
		"state": next,
		"round_score": round_score,
		"stone_count": settled_stones.size()
	}

func advance_round(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "round_complete":
		return {"ok": false, "reason": "round_not_complete"}
	var next_index: int = int(state.get("round_index", 0)) + 1
	if next_index >= TARGETS.size():
		return {"ok": false, "reason": "campaign_complete"}
	var next := state.duplicate(true)
	next["round_index"] = next_index
	next["shots_left"] = SHOTS_PER_ROUND
	next["stones"] = []
	next["round_score"] = 0
	next["target"] = TARGETS[next_index]
	next["status"] = "playing"
	next["message"] = "New target locked. Three throws available."
	return {"ok": true, "state": next}

func restart_campaign() -> Dictionary:
	return new_campaign()

func _simulate(positions: Array[Vector2], velocities: Array[Vector2]) -> void:
	var diameter := STONE_RADIUS * 2.0
	for _step in range(MAX_STEPS):
		var moving := false
		for index in range(positions.size()):
			var velocity: Vector2 = velocities[index]
			if velocity.length() < REST_SPEED:
				velocities[index] = Vector2.ZERO
				continue
			velocity *= FRICTION
			var position: Vector2 = positions[index] + velocity * STEP_SECONDS
			var min_x := RINK_MIN.x + STONE_RADIUS
			var max_x := RINK_MAX.x - STONE_RADIUS
			var min_y := RINK_MIN.y + STONE_RADIUS
			var max_y := RINK_MAX.y - STONE_RADIUS
			if position.x < min_x:
				position.x = min_x
				velocity.x = absf(velocity.x) * WALL_RESTITUTION
			elif position.x > max_x:
				position.x = max_x
				velocity.x = -absf(velocity.x) * WALL_RESTITUTION
			if position.y < min_y:
				position.y = min_y
				velocity.y = absf(velocity.y) * WALL_RESTITUTION
			elif position.y > max_y:
				position.y = max_y
				velocity.y = -absf(velocity.y) * WALL_RESTITUTION
			positions[index] = position
			velocities[index] = velocity
			if velocity.length() >= REST_SPEED:
				moving = true

		for first in range(positions.size()):
			for second in range(first + 1, positions.size()):
				var delta: Vector2 = positions[first] - positions[second]
				var distance := delta.length()
				if distance >= diameter:
					continue
				var normal := Vector2.RIGHT if distance < 0.001 else delta / distance
				var overlap := diameter - distance
				positions[first] += normal * overlap * 0.5
				positions[second] -= normal * overlap * 0.5
				var closing_speed := (velocities[first] - velocities[second]).dot(normal)
				if closing_speed < 0.0:
					var impulse := normal * closing_speed
					velocities[first] -= impulse
					velocities[second] += impulse
				moving = true
		if not moving:
			break

func _score_round(state: Dictionary) -> int:
	var stones: Array = state.get("stones", [])
	if stones.is_empty():
		return 0
	var target: Vector2 = state.get("target", TARGETS[0])
	var nearest := INF
	for stone_value in stones:
		var stone: Dictionary = stone_value
		var position: Vector2 = stone.get("position", LAUNCH_POINT)
		nearest = minf(nearest, position.distance_to(target))
	if nearest <= 32.0:
		return 30
	if nearest <= 64.0:
		return 20
	if nearest <= 110.0:
		return 10
	return 0

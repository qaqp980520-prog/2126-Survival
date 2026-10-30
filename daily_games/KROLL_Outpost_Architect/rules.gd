extends RefCounted
class_name OutpostArchitectRules

const BOARD_WIDTH: int = 5
const BOARD_CELLS: int = 25
const HAND_SIZE: int = 3
const PLACEMENT_LIMIT: int = 8
const STARTING_ENERGY: int = 18

const MODULE_COSTS: Dictionary = {
	"power": 0,
	"water": 2,
	"greenhouse": 2,
	"habitat": 3,
	"workshop": 3,
	"relay": 2
}

const MODULE_BASE_SCORES: Dictionary = {
	"power": 1,
	"water": 2,
	"greenhouse": 3,
	"habitat": 2,
	"workshop": 4,
	"relay": 2
}

const LAYOUT_NAMES: Array[String] = [
	"Dockside Habitat",
	"Ridge Research",
	"Floodplain Colony"
]

const TARGET_SCORES: Array[int] = [27, 25, 25]

const DECKS: Array = [
	["power", "water", "greenhouse", "habitat", "workshop", "relay", "power", "water", "greenhouse", "habitat", "relay", "workshop"],
	["water", "power", "habitat", "greenhouse", "relay", "workshop", "water", "power", "habitat", "greenhouse", "workshop", "relay"],
	["power", "greenhouse", "water", "habitat", "relay", "workshop", "water", "power", "greenhouse", "habitat", "relay", "workshop"]
]

static func layout_count() -> int:
	return DECKS.size()

static func layout_name(layout_index: int) -> String:
	var index: int = posmod(layout_index, DECKS.size())
	return LAYOUT_NAMES[index]

static func target_score(layout_index: int) -> int:
	var index: int = posmod(layout_index, TARGET_SCORES.size())
	return TARGET_SCORES[index]

static func module_cost(module_id: String) -> int:
	return int(MODULE_COSTS.get(module_id, -1))

static func new_game(layout_index: int = 0) -> Dictionary:
	var index: int = posmod(layout_index, DECKS.size())
	var deck: Array = DECKS[index].duplicate()
	var hand: Array = []
	for card_index in range(mini(HAND_SIZE, deck.size())):
		hand.append(deck[card_index])
	return {
		"layout_index": index,
		"deck": deck,
		"deck_index": hand.size(),
		"hand": hand,
		"board": {},
		"energy": STARTING_ENERGY,
		"turns_left": PLACEMENT_LIMIT,
		"score": 0,
		"target_score": TARGET_SCORES[index],
		"result": "playing"
	}

## A successful placement consumes energy and one turn. Invalid actions are side-effect free.
static func place_module(state: Dictionary, hand_index: int, cell_index: int) -> Dictionary:
	if str(state.get("result", "")) != "playing":
		return {"ok": false, "reason": "finished"}
	if cell_index < 0 or cell_index >= BOARD_CELLS:
		return {"ok": false, "reason": "invalid_cell"}
	var hand_value: Variant = state.get("hand", null)
	var board_value: Variant = state.get("board", null)
	var deck_value: Variant = state.get("deck", null)
	if not (hand_value is Array) or not (board_value is Dictionary) or not (deck_value is Array):
		return {"ok": false, "reason": "invalid_state"}
	if hand_index < 0 or hand_index >= hand_value.size():
		return {"ok": false, "reason": "invalid_card"}
	if board_value.has(cell_index):
		return {"ok": false, "reason": "occupied"}
	var module_id: String = str(hand_value[hand_index])
	var cost: int = module_cost(module_id)
	if cost < 0:
		return {"ok": false, "reason": "unknown_module"}
	var energy: int = int(state.get("energy", -1))
	if energy < cost:
		return {"ok": false, "reason": "insufficient_energy"}
	var turns_left: int = int(state.get("turns_left", 0))
	if turns_left <= 0:
		return {"ok": false, "reason": "finished"}

	var next_board: Dictionary = board_value.duplicate(true)
	next_board[cell_index] = module_id
	var next_hand: Array = hand_value.duplicate()
	next_hand.remove_at(hand_index)
	var next_deck_index: int = int(state.get("deck_index", 0))
	if next_deck_index < deck_value.size():
		next_hand.append(deck_value[next_deck_index])
		next_deck_index += 1
	var next_turns: int = turns_left - 1
	var next_score: int = calculate_score(next_board)

	state["board"] = next_board
	state["hand"] = next_hand
	state["deck_index"] = next_deck_index
	state["energy"] = energy - cost
	state["turns_left"] = next_turns
	state["score"] = next_score
	if next_turns == 0:
		if next_score >= int(state.get("target_score", 0)) and _has_required_modules(next_board):
			state["result"] = "won"
		else:
			state["result"] = "lost"
	return {
		"ok": true,
		"reason": "placed",
		"module_id": module_id,
		"score": next_score,
		"turns_left": next_turns,
		"result": str(state.get("result", "playing"))
	}

## Scores base module value plus orthogonal support links.
static func calculate_score(board: Dictionary) -> int:
	var score: int = 0
	for raw_cell in board.keys():
		if not (raw_cell is int):
			continue
		var cell_index: int = int(raw_cell)
		var module_id: String = str(board[raw_cell])
		if not MODULE_BASE_SCORES.has(module_id):
			continue
		score += int(MODULE_BASE_SCORES[module_id])
		for neighbor in _neighbors(cell_index):
			var adjacent_id: String = str(board.get(neighbor, ""))
			if adjacent_id.is_empty():
				continue
			match module_id:
				"power":
					if adjacent_id != "power":
						score += 1
				"water":
					if adjacent_id == "greenhouse":
						score += 2
				"greenhouse":
					if adjacent_id == "habitat":
						score += 1
				"habitat":
					if adjacent_id == "power":
						score += 1
				"workshop":
					if adjacent_id == "relay":
						score += 1
	return score

static func _has_required_modules(board: Dictionary) -> bool:
	var counts: Dictionary = {}
	for module_value in board.values():
		var module_id: String = str(module_value)
		counts[module_id] = int(counts.get(module_id, 0)) + 1
	for required_id in ["power", "water", "greenhouse", "habitat"]:
		if int(counts.get(required_id, 0)) < 1:
			return false
	return true

static func _neighbors(cell_index: int) -> Array[int]:
	var x: int = cell_index % BOARD_WIDTH
	var y: int = int(cell_index / BOARD_WIDTH)
	var result: Array[int] = []
	if x > 0:
		result.append(cell_index - 1)
	if x < BOARD_WIDTH - 1:
		result.append(cell_index + 1)
	if y > 0:
		result.append(cell_index - BOARD_WIDTH)
	if y < BOARD_WIDTH - 1:
		result.append(cell_index + BOARD_WIDTH)
	return result

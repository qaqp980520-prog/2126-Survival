extends RefCounted
class_name ReactorDeckRules

const MAX_HP: int = 36
const ENERGY_PER_TURN: int = 3
const HAND_SIZE: int = 5
const ENCOUNTER_REWARD: int = 100

const CARD_DEFINITIONS: Dictionary = {
	"arc_bolt": {"name": "ARC BOLT", "cost": 1, "damage": 6, "block": 0, "heal": 0, "self_damage": 0, "draw": 0, "description": "Deal 6 damage."},
	"brace": {"name": "BRACE", "cost": 1, "damage": 0, "block": 7, "heal": 0, "self_damage": 0, "draw": 0, "description": "Gain 7 block."},
	"pulse": {"name": "PULSE", "cost": 1, "damage": 4, "block": 4, "heal": 0, "self_damage": 0, "draw": 0, "description": "Deal 4 damage and gain 4 block."},
	"repair": {"name": "REPAIR", "cost": 2, "damage": 0, "block": 0, "heal": 5, "self_damage": 0, "draw": 0, "description": "Restore up to 5 core HP."},
	"overload": {"name": "OVERLOAD", "cost": 2, "damage": 12, "block": 0, "heal": 0, "self_damage": 2, "draw": 0, "description": "Deal 12 damage and take 2 recoil."},
	"coolant": {"name": "COOLANT", "cost": 0, "damage": 0, "block": 3, "heal": 0, "self_damage": 0, "draw": 1, "description": "Gain 3 block and draw 1 card."}
}

const STARTER_DECK: Array[String] = [
	"arc_bolt", "arc_bolt", "arc_bolt", "arc_bolt",
	"brace", "brace", "brace",
	"pulse", "pulse", "pulse",
	"repair", "repair",
	"overload", "overload",
	"coolant"
]

const ENCOUNTERS: Array[Dictionary] = [
	{"id": "coolant_leak", "name": "COOLANT LEAK", "hp": 26, "attack": 5, "growth": 0},
	{"id": "surge_drone", "name": "SURGE DRONE", "hp": 34, "attack": 7, "growth": 1},
	{"id": "core_sentinel", "name": "CORE SENTINEL", "hp": 42, "attack": 8, "growth": 1}
]

func get_energy_per_turn() -> int:
	return ENERGY_PER_TURN

func get_encounter_count() -> int:
	return ENCOUNTERS.size()

func get_card_definition(card_id: String) -> Dictionary:
	var definition: Variant = CARD_DEFINITIONS.get(card_id, {})
	if definition is Dictionary:
		return definition.duplicate(true)
	return {}

func get_encounter_definition(index: int) -> Dictionary:
	if index < 0 or index >= ENCOUNTERS.size():
		return {}
	return ENCOUNTERS[index].duplicate(true)

func create_state(seed_value: int = 2026) -> Dictionary:
	var draw_pile: Array = STARTER_DECK.duplicate()
	_shuffle(draw_pile, seed_value)
	var first_encounter: Dictionary = get_encounter_definition(0)
	var state: Dictionary = {
		"status": "playing",
		"hp": MAX_HP,
		"max_hp": MAX_HP,
		"block": 0,
		"energy": ENERGY_PER_TURN,
		"turn": 1,
		"encounter_index": 0,
		"enemy_id": str(first_encounter.get("id", "")),
		"enemy_name": str(first_encounter.get("name", "")),
		"enemy_hp": int(first_encounter.get("hp", 0)),
		"enemy_max_hp": int(first_encounter.get("hp", 0)),
		"base_attack": int(first_encounter.get("attack", 0)),
		"attack_growth": int(first_encounter.get("growth", 0)),
		"enemy_attack": int(first_encounter.get("attack", 0)),
		"score": 0,
		"awarded": [false, false, false],
		"seed": seed_value,
		"shuffle_count": 0,
		"draw_pile": draw_pile,
		"discard_pile": [],
		"hand": []
	}
	draw_cards(state, HAND_SIZE)
	return state

func can_play_card(state: Dictionary, hand_index: int) -> bool:
	if str(state.get("status", "")) != "playing":
		return false
	var hand: Array = state.get("hand", [])
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var definition: Dictionary = get_card_definition(str(hand[hand_index]))
	return not definition.is_empty() and int(state.get("energy", 0)) >= int(definition.get("cost", 0))

func play_card(state: Dictionary, hand_index: int) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "error": "not_playing"}
	var hand: Array = state.get("hand", []).duplicate()
	if hand_index < 0 or hand_index >= hand.size():
		return {"ok": false, "error": "invalid_hand_index"}
	var card_id: String = str(hand[hand_index])
	var definition: Dictionary = get_card_definition(card_id)
	if definition.is_empty():
		return {"ok": false, "error": "unknown_card"}
	var cost: int = int(definition.get("cost", 0))
	if int(state.get("energy", 0)) < cost:
		return {"ok": false, "error": "insufficient_energy"}

	hand.remove_at(hand_index)
	state["hand"] = hand
	state["energy"] = int(state.get("energy", 0)) - cost
	var damage: int = int(definition.get("damage", 0))
	var block_gained: int = int(definition.get("block", 0))
	var heal: int = int(definition.get("heal", 0))
	var recoil: int = int(definition.get("self_damage", 0))
	state["enemy_hp"] = maxi(0, int(state.get("enemy_hp", 0)) - damage)
	state["block"] = maxi(0, int(state.get("block", 0)) + block_gained)
	state["hp"] = maxi(0, mini(int(state.get("max_hp", MAX_HP)), int(state.get("hp", 0)) + heal) - recoil)
	var discard_pile: Array = state.get("discard_pile", []).duplicate()
	discard_pile.append(card_id)
	state["discard_pile"] = discard_pile

	if int(state.get("hp", 0)) <= 0:
		state["status"] = "defeat"
	elif int(state.get("enemy_hp", 0)) <= 0:
		_award_encounter(state)
	elif int(definition.get("draw", 0)) > 0:
		draw_cards(state, int(definition.get("draw", 0)))

	return {
		"ok": true,
		"card_id": card_id,
		"damage": damage,
		"block_gained": block_gained,
		"heal": heal,
		"recoil": recoil,
		"status": str(state.get("status", ""))
	}

func end_turn(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "error": "not_playing"}
	var incoming: int = maxi(0, int(state.get("enemy_attack", 0)))
	var available_block: int = maxi(0, int(state.get("block", 0)))
	var blocked: int = mini(incoming, available_block)
	var damage_taken: int = incoming - blocked
	state["hp"] = maxi(0, int(state.get("hp", 0)) - damage_taken)
	state["block"] = 0
	_discard_hand(state)
	if int(state.get("hp", 0)) <= 0:
		state["status"] = "defeat"
		return {"ok": true, "damage_taken": damage_taken, "blocked": blocked, "status": "defeat"}

	var next_turn: int = int(state.get("turn", 1)) + 1
	state["turn"] = next_turn
	state["energy"] = ENERGY_PER_TURN
	state["enemy_attack"] = int(state.get("base_attack", 0)) + int(state.get("attack_growth", 0)) * (next_turn - 1)
	var drawn: int = draw_cards(state, HAND_SIZE)
	return {"ok": true, "damage_taken": damage_taken, "blocked": blocked, "drawn": drawn, "status": "playing"}

func advance_encounter(state: Dictionary) -> bool:
	if str(state.get("status", "")) != "encounter_won":
		return false
	var next_index: int = int(state.get("encounter_index", 0)) + 1
	if next_index < 0 or next_index >= ENCOUNTERS.size():
		return false
	var encounter: Dictionary = get_encounter_definition(next_index)
	state["encounter_index"] = next_index
	state["enemy_id"] = str(encounter.get("id", ""))
	state["enemy_name"] = str(encounter.get("name", ""))
	state["enemy_hp"] = int(encounter.get("hp", 0))
	state["enemy_max_hp"] = int(encounter.get("hp", 0))
	state["base_attack"] = int(encounter.get("attack", 0))
	state["attack_growth"] = int(encounter.get("growth", 0))
	state["enemy_attack"] = int(encounter.get("attack", 0))
	state["turn"] = 1
	state["energy"] = ENERGY_PER_TURN
	state["block"] = 0
	state["status"] = "playing"
	_discard_hand(state)
	draw_cards(state, HAND_SIZE)
	return true

func restart_campaign(seed_value: int = 2026) -> Dictionary:
	return create_state(seed_value)

func draw_cards(state: Dictionary, amount: int) -> int:
	if amount <= 0:
		return 0
	var draw_pile: Array = state.get("draw_pile", []).duplicate()
	var discard_pile: Array = state.get("discard_pile", []).duplicate()
	var hand: Array = state.get("hand", []).duplicate()
	var drawn: int = 0
	while drawn < amount:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			var shuffle_count: int = int(state.get("shuffle_count", 0)) + 1
			state["shuffle_count"] = shuffle_count
			_shuffle(draw_pile, int(state.get("seed", 1)) + shuffle_count * 7919)
		hand.append(str(draw_pile.pop_front()))
		drawn += 1
	state["draw_pile"] = draw_pile
	state["discard_pile"] = discard_pile
	state["hand"] = hand
	return drawn

func _discard_hand(state: Dictionary) -> void:
	var hand: Array = state.get("hand", []).duplicate()
	var discard_pile: Array = state.get("discard_pile", []).duplicate()
	discard_pile.append_array(hand)
	hand.clear()
	state["hand"] = hand
	state["discard_pile"] = discard_pile

func _award_encounter(state: Dictionary) -> void:
	var index: int = int(state.get("encounter_index", -1))
	var awarded: Array = state.get("awarded", []).duplicate()
	if index >= 0 and index < awarded.size() and not bool(awarded[index]):
		awarded[index] = true
		state["score"] = int(state.get("score", 0)) + ENCOUNTER_REWARD
	state["awarded"] = awarded
	state["status"] = "victory" if index == ENCOUNTERS.size() - 1 else "encounter_won"

func _shuffle(items: Array, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(items.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: Variant = items[index]
		items[index] = items[swap_index]
		items[swap_index] = temporary

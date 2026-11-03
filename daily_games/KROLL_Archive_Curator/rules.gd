extends RefCounted

const SLOT_COUNT: int = 4
const CARD_COUNT: int = 6
const THEME_BONUS: int = 3
const ADJACENCY_BONUS: int = 2
const MIN_THEME_ITEMS: int = 2
const ADJACENT_PAIRS: Array = [[0, 1], [0, 2], [1, 3], [2, 3]]

const GALLERIES: Array = [
	{
		"name": "Engineering Wing",
		"theme": "engineering",
		"target": 27,
		"cards": [
			{"name": "Reactor Blueprint", "tags": ["engineering", "energy"], "base": 4},
			{"name": "Survey Drone", "tags": ["engineering", "navigation"], "base": 3},
			{"name": "Crystal Core", "tags": ["energy", "geology"], "base": 4},
			{"name": "Circuit Atlas", "tags": ["engineering", "energy"], "base": 3},
			{"name": "Fossil Lens", "tags": ["biology", "geology"], "base": 5},
			{"name": "Star Map", "tags": ["navigation", "space"], "base": 4}
		]
	},
	{
		"name": "Life Sciences Wing",
		"theme": "biology",
		"target": 27,
		"cards": [
			{"name": "Cell Atlas", "tags": ["biology", "chemistry"], "base": 4},
			{"name": "Wetland Model", "tags": ["biology", "ecology"], "base": 3},
			{"name": "Mineral Sample", "tags": ["geology", "chemistry"], "base": 4},
			{"name": "Seed Vault", "tags": ["biology", "ecology"], "base": 3},
			{"name": "Orbit Photo", "tags": ["space", "navigation"], "base": 5},
			{"name": "Energy Prism", "tags": ["energy", "physics"], "base": 4}
		]
	},
	{
		"name": "Exploration Wing",
		"theme": "exploration",
		"target": 27,
		"cards": [
			{"name": "Deep-Space Chart", "tags": ["space", "navigation"], "base": 4},
			{"name": "Survey Beacon", "tags": ["exploration", "navigation"], "base": 3},
			{"name": "Canyon Fossil", "tags": ["geology", "biology"], "base": 4},
			{"name": "Rover Log", "tags": ["exploration", "geology"], "base": 3},
			{"name": "Reactor Map", "tags": ["engineering", "energy"], "base": 5},
			{"name": "Ocean Record", "tags": ["exploration", "biology"], "base": 4}
		]
	}
]

func get_gallery_count() -> int:
	return GALLERIES.size()

func get_gallery(index: int) -> Dictionary:
	if index < 0 or index >= GALLERIES.size():
		return {}
	return GALLERIES[index].duplicate(true)

func can_place(placements: Dictionary, card_index: int, slot_index: int) -> bool:
	if card_index < 0 or card_index >= CARD_COUNT or slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	if placements.size() >= SLOT_COUNT or placements.has(slot_index):
		return false
	for key_value in placements.keys():
		if typeof(key_value) != TYPE_INT:
			return false
		var existing_card: Variant = placements[key_value]
		if typeof(existing_card) != TYPE_INT or int(existing_card) < 0 or int(existing_card) >= CARD_COUNT:
			return false
		if int(existing_card) == card_index:
			return false
	return true

func place_card(placements: Dictionary, card_index: int, slot_index: int) -> Dictionary:
	var copied: Dictionary = placements.duplicate(true)
	if not can_place(copied, card_index, slot_index):
		return {"ok": false, "error": "invalid_or_duplicate_placement", "placements": copied}
	copied[slot_index] = card_index
	return {"ok": true, "placements": copied}

func calculate_score(gallery_index: int, placements: Dictionary) -> Dictionary:
	if gallery_index < 0 or gallery_index >= GALLERIES.size():
		return {"ok": false, "error": "invalid_gallery"}
	if placements.size() > SLOT_COUNT:
		return {"ok": false, "error": "too_many_placements"}

	var gallery: Dictionary = GALLERIES[gallery_index]
	var cards: Array = gallery["cards"]
	var theme: String = str(gallery["theme"])
	var used_cards: Dictionary = {}
	var base_score: int = 0
	var theme_count: int = 0

	for slot_value in placements.keys():
		if typeof(slot_value) != TYPE_INT:
			return {"ok": false, "error": "invalid_slot"}
		var slot_index: int = int(slot_value)
		var card_value: Variant = placements[slot_value]
		if slot_index < 0 or slot_index >= SLOT_COUNT or typeof(card_value) != TYPE_INT:
			return {"ok": false, "error": "invalid_placement"}
		var card_index: int = int(card_value)
		if card_index < 0 or card_index >= cards.size() or used_cards.has(card_index):
			return {"ok": false, "error": "duplicate_or_invalid_card"}
		used_cards[card_index] = true
		var card: Dictionary = cards[card_index]
		var tags: Array = card.get("tags", [])
		base_score += int(card.get("base", 0))
		if tags.has(theme):
			theme_count += 1

	var adjacency_count: int = 0
	for pair_value in ADJACENT_PAIRS:
		var pair: Array = pair_value
		var first_slot: int = int(pair[0])
		var second_slot: int = int(pair[1])
		if not placements.has(first_slot) or not placements.has(second_slot):
			continue
		var first_card: Dictionary = cards[int(placements[first_slot])]
		var second_card: Dictionary = cards[int(placements[second_slot])]
		if _shares_tag(first_card.get("tags", []), second_card.get("tags", [])):
			adjacency_count += 1

	var theme_bonus: int = theme_count * THEME_BONUS
	var adjacency_bonus: int = adjacency_count * ADJACENCY_BONUS
	var total_score: int = base_score + theme_bonus + adjacency_bonus
	var target: int = int(gallery["target"])
	var passed: bool = placements.size() == SLOT_COUNT and theme_count >= MIN_THEME_ITEMS and total_score >= target
	return {
		"ok": true,
		"base_score": base_score,
		"theme_count": theme_count,
		"theme_bonus": theme_bonus,
		"adjacency_count": adjacency_count,
		"adjacency_bonus": adjacency_bonus,
		"total_score": total_score,
		"target": target,
		"passed": passed
	}

func _shares_tag(first_tags: Array, second_tags: Array) -> bool:
	for tag_value in first_tags:
		if second_tags.has(tag_value):
			return true
	return false

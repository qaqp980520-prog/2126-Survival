extends "res://tests/helpers/LegacyInventoryCountFixture.gd"

func get_item_count(item_id: String) -> Variant:
	return counts.get(item_id, 0)

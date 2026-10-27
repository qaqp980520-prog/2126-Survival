extends SceneTree

const Inventory = preload("res://systems/SurvivalInventory.gd")
const MineralCatalog = preload("res://systems/MineralCatalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for mineral_id in MineralCatalog.get_ids():
		var mineral: Dictionary = MineralCatalog.get_mineral(str(mineral_id))
		_expect(Inventory.ITEM_WEIGHTS.has(mineral_id), "inventory registers mineral ID " + str(mineral_id))
		if Inventory.ITEM_WEIGHTS.has(mineral_id):
			_expect(is_equal_approx(float(Inventory.ITEM_WEIGHTS[mineral_id]), float(mineral.get("weight_kg", -1.0))), "inventory weight matches mineral catalog for " + str(mineral_id))
	for item_id in Inventory.ITEM_WEIGHTS.keys():
		var weight := float(Inventory.ITEM_WEIGHTS[item_id])
		_expect(is_finite(weight) and weight >= 0.0, "registered item weight is finite and non-negative for " + str(item_id))

	var inventory = Inventory.new({"rock": 2})
	var known_weight := inventory.total_weight_kg()
	inventory.counts["unregistered_external_item"] = 2
	_expect(inventory.total_weight_kg() >= known_weight + Inventory.UNKNOWN_ITEM_WEIGHT_KG * 2.0, "externally injected unknown counts use a non-zero safety weight")
	var before: Dictionary = inventory.to_save_dict()
	_expect(not inventory.load_save_dict(before), "save validation rejects externally injected unknown IDs")
	_expect(inventory.to_save_dict() == before, "rejected unknown-ID save does not mutate the inventory")
	print("Inventory mineral catalog compatibility tests passed." if failures.is_empty() else "Inventory mineral catalog compatibility tests failed.")
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

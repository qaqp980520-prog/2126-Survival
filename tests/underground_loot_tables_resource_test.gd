extends SceneTree

const Factory = preload("res://systems/UndergroundMineFactory.gd")
const MineralCatalog = preload("res://systems/MineralCatalog.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(FileAccess.file_exists("res://systems/data/underground_loot_tables.json"), "regional loot-table JSON resource exists")
	var tables: Dictionary = Factory.load_cache_tables(true)
	_expect(tables.size() == 4, "resource loader returns exactly four regional tables")
	var all_items: Dictionary = {}
	for table_id in ["west", "east", "north", "south"]:
		var entries: Variant = tables.get(table_id, null)
		_expect(entries is Array and not entries.is_empty(), "regional table is present: " + table_id)
		if not (entries is Array):
			continue
		var seen: Dictionary = {}
		for entry in entries:
			if not (entry is Dictionary):
				_expect(false, "table entry is a dictionary")
				continue
			var item_id: String = str(entry.get("item_id", ""))
			var weight_value: Variant = entry.get("weight", null)
			_expect(MineralCatalog.has_mineral(item_id), "table item exists in MineralCatalog: " + item_id)
			_expect(weight_value is int and int(weight_value) > 0, "table weight is a positive integer")
			_expect(not seen.has(item_id), "table does not repeat an item ID")
			seen[item_id] = true
			all_items[item_id] = true
	_expect(all_items.size() == 7, "regional resource covers all seven catalog minerals")

	_expect_golden(Vector2i.ZERO, 0, ["MineCache_Gold", "MineCache_Coal"], ["gold_ore", "coal_ore"], ["service", "service"])
	_expect_golden(Vector2i(-1, 1), 0, ["MineCache_coal_ore"], ["coal_ore"], ["west"])
	_expect_golden(Vector2i(0, -1), 2, ["MineCache_aluminium_ore"], ["aluminium_ore"], ["north"])
	_expect_golden(Vector2i(2, 1), 3, ["MineCache_silver_ore"], ["silver_ore"], ["east"])
	_expect_golden(Vector2i(-3, -1), 8, ["MineCache_iron_ore"], ["iron_ore"], ["west"])
	_expect_golden(Vector2i.ZERO, 1, ["MineCache_aluminium_ore"], ["aluminium_ore"], ["north"])
	_expect_golden(Vector2i.ZERO, 2, [], [], [])
	_expect_golden(Vector2i(1, 0), 1, [], [], [])

	for layer_index in range(9):
		for y in range(-6, 7):
			for x in range(-6, 7):
				var coord := Vector2i(x, y)
				var first: Array[Dictionary] = Factory.get_cache_spawn_data(coord, layer_index)
				var second: Array[Dictionary] = Factory.get_cache_spawn_data(coord, layer_index)
				_expect(first == second, "cache output is deterministic at layer %d room %d,%d" % [layer_index, x, y])
				for cache in first:
					_expect(MineralCatalog.has_mineral(str(cache.get("item_id", ""))), "generated cache uses a catalog item")
	if failures.is_empty():
		print("Underground loot-table resource tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect_golden(coord: Vector2i, layer_index: int, names: Array[String], items: Array[String], tables: Array[String]) -> void:
	var entries: Array[Dictionary] = Factory.get_cache_spawn_data(coord, layer_index)
	_expect(entries.size() == names.size(), "legacy cache count is preserved at %s layer %d" % [coord, layer_index])
	for index in range(mini(entries.size(), names.size())):
		_expect(str(entries[index].get("node_name", "")) == names[index], "legacy cache node identity is preserved")
		_expect(str(entries[index].get("item_id", "")) == items[index], "legacy cache mineral identity is preserved")
		_expect(str(entries[index].get("table_id", "")) == tables[index], "legacy cache region table is preserved")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

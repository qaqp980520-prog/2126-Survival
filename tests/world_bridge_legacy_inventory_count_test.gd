extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const LegacyFixture = preload("res://tests/helpers/LegacyInventoryCountFixture.gd")
const MethodFixture = preload("res://tests/helpers/MethodInventoryCountFixture.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_test_legacy_dictionary_fallback()
	_test_custom_count_method()
	if failures.is_empty():
		print("World bridge custom inventory count validation tests passed.")
		quit(0)
	else:
		push_error("World bridge count validation failures: " + str(failures))
		quit(1)

func _test_legacy_dictionary_fallback() -> void:
	var fixture = LegacyFixture.new()
	_verify_count_values(fixture, "legacy dictionary fallback")

func _test_custom_count_method() -> void:
	var fixture = MethodFixture.new()
	_verify_count_values(fixture, "custom count method")

func _verify_count_values(fixture: RefCounted, label: String) -> void:
	fixture.set("counts", {
		"meat": 4,
		"rock": 3.0,
		"berries": 3.5,
		"hide": -1,
		"bone": 1000000001,
		"food": "7",
		"herbs": true,
		"seeds": 0.0,
		"uranium_ore": INF,
		"crystal": NAN,
		"legacy_unknown": 2
	})
	var bridge = BridgeScript.new()
	_expect(bool(bridge.bind_inventory(fixture)), label + " satisfies the legacy inventory contract")
	_expect(bridge.get_item_count("meat") == 4, label + " reads positive integer counts")
	_expect(bridge.get_item_count("rock") == 3, label + " accepts whole-valued floats consistently")
	_expect(bridge.get_item_count("berries") == 0, label + " rejects fractional counts")
	_expect(bridge.get_item_count("hide") == 0, label + " rejects negative counts")
	_expect(bridge.get_item_count("bone") == 0, label + " rejects counts above the save limit")
	_expect(bridge.get_item_count("food") == 0, label + " rejects string counts")
	_expect(bridge.get_item_count("herbs") == 0, label + " rejects boolean counts")
	_expect(bridge.get_item_count("seeds") == 0, label + " keeps zero counts at zero")
	_expect(bridge.get_item_count("uranium_ore") == 0, label + " rejects positive infinity")
	_expect(bridge.get_item_count("crystal") == 0, label + " rejects NaN")
	_expect(bridge.get_item_count("legacy_unknown") == 2, label + " preserves legacy unknown-key reads")
	bridge.free()

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

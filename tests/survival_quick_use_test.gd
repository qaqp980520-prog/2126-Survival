extends SceneTree

const InventoryScript = preload("res://systems/SurvivalInventory.gd")
const StaminaScript = preload("res://systems/SurvivalStamina.gd")
const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const QuickUseScript = preload("res://systems/SurvivalQuickUse.gd")
var failures: Array[String] = []
var reentrant_result: Dictionary = {}
var reentrant_quick_use: RefCounted
var reentrant_bridge: Node
var reentrant_stamina: RefCounted

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var inventory: RefCounted = InventoryScript.new({"berries": 2, "herbs": 1, "meat": 1, "food": 1})
	var bridge: Node = BridgeScript.new()
	_expect(bool(bridge.call("bind_inventory", inventory)), "quick-use binds through the shared inventory bridge")
	var stamina: RefCounted = StaminaScript.new()
	var quick_use: RefCounted = QuickUseScript.new()
	_expect(quick_use.get("selected_slot") == 0, "quick-use starts on slot one")
	_expect(str(quick_use.call("get_slot_item", 0)) == "berries", "slot one defaults to berries")
	_expect(bool(quick_use.call("assign_slot", 2, "food")), "a valid consumable can be assigned to a slot")
	_expect(not bool(quick_use.call("assign_slot", 2, "iron_ore")), "non-consumable items cannot be assigned")
	_expect(bool(quick_use.call("select_slot", 0)), "valid slot selection succeeds")
	stamina.set("current_stamina", 40.0)
	bridge.connect("item_consumed", Callable(self, "_on_item_consumed"))
	reentrant_quick_use = quick_use
	reentrant_bridge = bridge
	reentrant_stamina = stamina
	var result: Dictionary = quick_use.call("consume_selected", bridge, stamina)
	_expect(bool(result.get("ok", false)), "selected ration is consumed")
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 48.0), "berries restore eight stamina")
	_expect(int(inventory.get("counts").get("berries", 0)) == 1, "one berry is removed from the authoritative inventory")
	_expect(int(result.get("remaining", -1)) == 1, "consume result reports remaining inventory count")
	_expect(reentrant_result.get("reason", "") == "interaction_in_progress", "inventory signal cannot re-enter the active quick-use transaction")

	stamina.set("current_stamina", 97.0)
	result = quick_use.call("consume_selected", bridge, stamina)
	_expect(bool(result.get("ok", false)) and is_equal_approx(float(result.get("restored", 0.0)), 3.0), "restoration clamps to remaining stamina capacity")
	_expect(int(inventory.get("counts").get("berries", 0)) == 0, "partial restoration still consumes exactly one ration")

	stamina.reset()
	var food_before: int = int(inventory.get("counts").get("food", 0))
	quick_use.call("select_slot", 2)
	result = quick_use.call("consume_selected", bridge, stamina)
	_expect(not bool(result.get("ok", false)) and str(result.get("reason", "")) == "stamina_full", "full stamina preserves the selected ration")
	_expect(int(inventory.get("counts").get("food", 0)) == food_before, "full stamina does not consume inventory")

	quick_use.call("select_slot", 1)
	stamina.set("current_stamina", 50.0)
	result = quick_use.call("consume_selected", bridge, stamina)
	_expect(bool(result.get("ok", false)) and is_equal_approx(float(result.get("restored", 0.0)), 12.0), "herbs restore twelve stamina")
	var empty_bridge: Node = BridgeScript.new()
	result = quick_use.call("consume_selected", empty_bridge, stamina)
	_expect(not bool(result.get("ok", false)) and str(result.get("reason", "")) == "empty", "empty slot inventory is rejected without stamina change")

	var saved: Dictionary = quick_use.call("to_save_dict")
	var restored: RefCounted = QuickUseScript.new()
	_expect(bool(restored.call("load_save_dict", saved)), "valid quick-use save restores")
	_expect(restored.get("selected_slot") == 1 and str(restored.call("get_slot_item", 2)) == "food", "selected slot and assignments round-trip")
	var invalid: Dictionary = saved.duplicate(true)
	invalid["selected_slot"] = 4
	_expect(not bool(restored.call("load_save_dict", invalid)), "out-of-range selected slot is rejected")
	_expect(restored.get("selected_slot") == 1, "invalid quick-use save is non-mutating")
	invalid = saved.duplicate(true)
	invalid["slots"][0] = "uranium_ore"
	_expect(not bool(restored.call("validate_save_dict", invalid)), "non-consumable hotbar item is rejected")
	# The bridge is a Node, not RefCounted; explicitly release both test instances.
	empty_bridge.free()
	bridge.free()
	if failures.is_empty():
		print("Survival quick-use model tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _on_item_consumed(_item_id: String, _amount: int) -> void:
	reentrant_result = reentrant_quick_use.call("consume_selected", reentrant_bridge, reentrant_stamina)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

extends SceneTree

const StaminaScript = preload("res://systems/SurvivalStamina.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stamina: RefCounted = StaminaScript.new()
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 100.0), "stamina starts full")
	stamina.call("tick", 1.0, true, 1.0)
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 98.0), "normal movement drains two stamina per second")
	stamina.call("tick", 1.0, true, 0.68)
	var overweight_value: float = float(stamina.get("current_stamina"))
	_expect(overweight_value < 96.1 and overweight_value > 95.0, "overweight movement increases stamina consumption using the movement penalty")
	stamina.call("tick", 1.0, true, 0.42)
	var super_heavy_value: float = float(stamina.get("current_stamina"))
	_expect(super_heavy_value < overweight_value - 4.0, "super-heavy movement consumes more stamina than ordinary overweight movement")
	stamina.call("tick", 1.0, false, 0.42)
	_expect(float(stamina.get("current_stamina")) > super_heavy_value, "stamina regenerates while stationary")
	stamina.call("tick", 100.0, false, 1.0)
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 100.0), "stamina regeneration clamps at the maximum")
	_expect(bool(stamina.call("can_jump")), "full stamina permits jumping")
	_expect(bool(stamina.call("spend_jump")), "jump consumes stamina")
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 90.0), "jump costs ten stamina")
	stamina.set("current_stamina", 10.0)
	_expect(bool(stamina.call("can_jump")), "exactly ten stamina still permits a jump")
	_expect(bool(stamina.call("spend_jump")), "jump succeeds at the exact stamina boundary")
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 0.0), "jump can consume the final ten stamina")
	stamina.set("current_stamina", 9.99)
	_expect(not bool(stamina.call("can_jump")), "stamina below the jump cost blocks jumping")
	_expect(not bool(stamina.call("spend_jump")), "blocked jump does not consume more stamina")

	stamina.reset()
	_expect(bool(stamina.call("can_sprint")), "full stamina permits sprinting")
	_expect(is_equal_approx(float(stamina.call("get_movement_speed_multiplier", true)), 1.35), "sprint raises the stamina movement multiplier to 1.35")
	stamina.call("tick", 1.0, true, 1.0, true)
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 95.5), "sprinting drains 2.25 times the normal movement rate")
	stamina.set("current_stamina", 5.0)
	_expect(bool(stamina.call("can_sprint")), "exactly five stamina permits sprinting")
	_expect(is_equal_approx(float(stamina.call("get_movement_speed_multiplier", true)), 1.35), "exact sprint threshold receives the sprint speed multiplier")
	stamina.call("tick", 1.0, true, 1.0, true)
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 0.5), "sprinting can drain below the threshold without going negative")
	stamina.set("current_stamina", 4.99)
	_expect(not bool(stamina.call("can_sprint")), "stamina below five blocks sprinting")
	_expect(is_equal_approx(float(stamina.call("get_movement_speed_multiplier", true)), 1.0), "blocked sprint request falls back to walking speed")
	stamina.call("tick", 1.0, true, 1.0, true)
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 2.99), "sprint drain is not applied below the sprint threshold")
	stamina.set("current_stamina", 0.0)
	_expect(is_equal_approx(float(stamina.call("get_movement_speed_multiplier", false)), 0.65), "zero stamina applies the 0.65 exhaustion movement penalty")
	_expect(not bool(stamina.call("can_sprint")), "exhaustion prevents sprinting")
	stamina.call("tick", 1.0, false, 1.0)
	_expect(is_equal_approx(float(stamina.get("current_stamina")), 6.0), "one idle second restores six stamina from exhaustion")
	_expect(bool(stamina.call("can_sprint")), "sprint becomes available after crossing the five-point threshold")
	var before_invalid_delta: float = float(stamina.get("current_stamina"))
	stamina.call("tick", -1.0, true, 1.0)
	stamina.call("tick", 0.0, false, 1.0)
	_expect(is_equal_approx(float(stamina.get("current_stamina")), before_invalid_delta), "non-positive delta does not mutate stamina")
	var saved: Dictionary = stamina.call("to_save_dict")
	var restored: RefCounted = StaminaScript.new()
	_expect(bool(restored.call("load_save_dict", saved)), "valid stamina save restores")
	_expect(is_equal_approx(float(restored.get("current_stamina")), 6.0), "stamina save round-trips the current value")
	var invalid: Dictionary = saved.duplicate(true)
	invalid["current"] = 100.01
	_expect(not bool(restored.call("load_save_dict", invalid)), "out-of-range stamina save is rejected")
	_expect(is_equal_approx(float(restored.get("current_stamina")), 6.0), "invalid stamina save is non-mutating")
	var unknown: Dictionary = saved.duplicate(true)
	unknown["extra"] = 1
	_expect(not bool(restored.call("validate_save_dict", unknown)), "unknown stamina save fields are rejected")
	if failures.is_empty():
		print("Survival stamina model tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

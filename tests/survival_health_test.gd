extends SceneTree

const HealthScript = preload("res://systems/SurvivalHealth.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var health: RefCounted = HealthScript.new()
	_expect(is_equal_approx(float(health.call("get_current_health")), 100.0), "new health model starts at full health")
	_expect(bool(health.call("is_alive")), "new health model is alive")
	var damaged: Dictionary = health.call("apply_damage", 12.0, "hound")
	_expect(bool(damaged.get("ok", false)) and is_equal_approx(float(damaged.get("applied", 0.0)), 12.0), "valid Hound damage is applied exactly once")
	_expect(is_equal_approx(float(health.call("get_current_health")), 88.0), "damage reduces current health")
	var before_invalid: Dictionary = health.call("get_snapshot")
	for invalid_amount in [-1.0, 0.0, NAN, INF]:
		var rejected: Dictionary = health.call("apply_damage", invalid_amount, "hound")
		_expect(not bool(rejected.get("ok", true)), "invalid damage amount is rejected")
		_expect(health.call("get_snapshot") == before_invalid, "invalid damage leaves the complete health snapshot unchanged")
	var empty_source: Dictionary = health.call("apply_damage", 1.0, "")
	_expect(not bool(empty_source.get("ok", true)) and health.call("get_snapshot") == before_invalid, "empty damage source is rejected transactionally")
	var healed: Dictionary = health.call("heal", 20.0)
	_expect(bool(healed.get("ok", false)) and is_equal_approx(float(healed.get("restored", 0.0)), 12.0), "healing is clamped to maximum health")
	_expect(is_equal_approx(float(health.call("get_current_health")), 100.0), "healing never exceeds maximum health")
	var saved: Dictionary = health.call("to_save_dict")
	var restored: RefCounted = HealthScript.new()
	_expect(bool(restored.call("load_save_dict", {"schema_version": 1, "current": 64.0})), "valid health save payload restores")
	_expect(is_equal_approx(float(restored.call("get_current_health")), 64.0), "restored health matches saved value")
	var before_invalid_save: Dictionary = restored.call("get_snapshot")
	for invalid_payload in [
		{"schema_version": 2, "current": 50.0},
		{"schema_version": 1, "current": 100.1},
		{"schema_version": 1, "current": -0.1},
		{"schema_version": 1, "current": NAN},
		{"schema_version": 1, "current": 50.0, "extra": true}
	]:
		_expect(not bool(restored.call("load_save_dict", invalid_payload)), "malformed health save payload is rejected")
		_expect(restored.call("get_snapshot") == before_invalid_save, "rejected health restore leaves current health unchanged")
	_expect(bool(health.call("validate_save_dict", saved)), "health model accepts its own serialized payload")
	var lethal: Dictionary = health.call("apply_damage", 200.0, "hound")
	_expect(bool(lethal.get("ok", false)) and bool(lethal.get("defeated", false)), "overkill clamps health to zero and marks the player defeated")
	_expect(is_equal_approx(float(health.call("get_current_health")), 0.0), "health never becomes negative")
	var defeated_damage: Dictionary = health.call("apply_damage", 1.0, "hound")
	_expect(not bool(defeated_damage.get("ok", true)), "defeated player cannot receive additional damage")
	var revived: Dictionary = health.call("heal", 5.0)
	_expect(bool(revived.get("ok", false)) and bool(revived.get("revived", false)), "valid healing can revive a defeated player")
	_expect(bool(health.call("is_alive")) and is_equal_approx(float(health.call("get_current_health")), 5.0), "revival restores a positive health value")
	if failures.is_empty():
		print("Survival health model tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FAIL: " + message)

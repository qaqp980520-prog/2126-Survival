extends SceneTree

const MiningNode = preload("res://systems/MineralMiningNode.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var node: Node3D = MiningNode.new()
	node.mineral_id = "iron_ore"
	node.max_units = 10
	node.remaining_units = 10
	node.regen_interval_seconds = 60
	node.last_regen_unix = int(Time.get_unix_time_from_system())
	root.add_child(node)
	await process_frame

	# Use controlled timestamps after _ready so no wall-clock timing makes the assertions flaky.
	node.max_units = 10
	node.remaining_units = 2
	node.regen_interval_seconds = 60
	node.last_regen_unix = 1000
	_expect(node.apply_elapsed_regeneration(1059) == 0, "partial interval does not regenerate early")
	_expect(node.apply_elapsed_regeneration(1060) == 1, "one complete interval restores one unit")
	_expect(node.remaining_units == 3 and node.last_regen_unix == 1060, "partial interval remainder is preserved")
	_expect(node.apply_elapsed_regeneration(1119) == 0, "second interval also respects its boundary")
	_expect(node.apply_elapsed_regeneration(1120) == 1, "second complete interval restores one unit")

	node.remaining_units = 4
	node.last_regen_unix = 1120
	_expect(node.apply_elapsed_regeneration(1100) == 0, "clock rollback never creates stock")
	_expect(node.remaining_units == 4 and node.last_regen_unix == 1120, "clock rollback preserves amount and timestamp")

	node.remaining_units = 10
	node.last_regen_unix = 1120
	_expect(node.apply_elapsed_regeneration(1300) == 0, "full vein does not add stock")
	_expect(node.last_regen_unix == 1300, "full vein resets the regeneration clock")
	node.remaining_units = 9
	_expect(node.apply_elapsed_regeneration(1359) == 0, "full-stock time is not banked for the next depletion")
	_expect(node.apply_elapsed_regeneration(1360) == 1, "regeneration resumes after a fresh full interval")

	node.remaining_units = 5
	node.max_units = 10
	node.regen_interval_seconds = 60
	node.last_regen_unix = 2000
	var before_invalid_load: Dictionary = node.to_save_dict()
	var invalid_record := {
		"schema_version": 2,
		"mineral_id": "iron_ore",
		"remaining_units": 11,
		"max_units": 10,
		"regen_interval_seconds": 60,
		"last_regen_unix": 2000
	}
	_expect(not node.load_save_dict(invalid_record, 2000, false), "out-of-capacity save record is rejected")
	_expect(node.to_save_dict() == before_invalid_load, "invalid save record cannot partially mutate live vein")

	var legacy_record := {
		"schema_version": 1,
		"mineral_id": "iron_ore",
		"remaining_units": 3
	}
	_expect(node.load_save_dict(legacy_record, 3000, false), "legacy schema-v1 save remains loadable")
	_expect(node.remaining_units == 3 and node.last_regen_unix == 3000, "legacy save receives a deterministic regeneration timestamp")

	node.remaining_units = 0
	node.last_regen_unix = 1
	node.restore_vein(1)
	var restored_at: int = node.last_regen_unix
	_expect(node.remaining_units == 1, "manual restore adds the requested stock")
	_expect(restored_at > 1000000000, "manual restore resets the regeneration timestamp to current wall clock")
	_expect(node.apply_elapsed_regeneration(restored_at + 59) == 0, "manual restore does not bank the old depleted interval")
	_expect(node.apply_elapsed_regeneration(restored_at + 60) == 1, "restored vein resumes regeneration after a fresh interval")

	node.queue_free()
	await process_frame
	if failures.is_empty():
		print("Mineral mining regeneration regression tests passed.")
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

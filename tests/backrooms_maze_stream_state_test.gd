extends SceneTree

const Layout = preload("res://systems/BackroomsMazeLayout.gd")
const StreamState = preload("res://systems/BackroomsMazeStreamState.gd")
const EntityDirector = preload("res://systems/BackroomsEntityDirector.gd")
const EntityRuntimeState = preload("res://systems/BackroomsEntityRuntimeState.gd")

func _initialize() -> void:
	_test_configuration_and_initial_window()
	_test_cell_key_parser_bounds()
	_test_load_first_shift_and_failed_stage()
	_test_unload_reload_determinism_and_stale_plans()
	_test_save_restore_and_layout_version_guard()
	_test_extreme_float_inputs_fail_atomically()
	print("Backrooms maze stream state tests passed.")
	quit(0)

func _test_configuration_and_initial_window() -> void:
	assert(Layout.ALGORITHM_VERSION == 1)
	assert(EntityDirector.is_spawn_algorithm_version_supported(EntityDirector.SPAWN_ALGORITHM_VERSION))
	assert(not EntityDirector.is_spawn_algorithm_version_supported(EntityDirector.SPAWN_ALGORITHM_VERSION + 1))
	assert(EntityDirector.get_cell_spawn_descriptors(
		"Level 1",
		Vector2i.ZERO,
		8.0,
		{},
		EntityDirector.SPAWN_ALGORITHM_VERSION + 1
	).is_empty())
	var state = StreamState.new()
	assert(not state.configure("Level 6", 20261113, 8.0, 1))
	assert(not state.configure("Level 1", 20261113, 8.0, 9))
	assert(not state.configure("Level 1", 20261113, NAN, 1))
	assert(not state.configure("Level 1", 20261113, 1025.0, 1))
	assert(state.get_loaded_cell_count() == 0)
	assert(state.configure("Level 1", 20261113, 8.0, 1))

	var invalid_position: Dictionary = state.plan_window_for_position(Vector3(NAN, 0.0, 0.0))
	assert(not bool(invalid_position.get("ok", false)))
	assert(state.get_loaded_cell_count() == 0)
	assert(not bool(state.plan_window_at_cell(Vector2i(1000001, 0)).get("ok", false)))
	assert(not bool(state.plan_window_at_cell(Vector2i(1000000, 0)).get("ok", false)))
	assert(bool(state.plan_window_at_cell(Vector2i(999999, 0)).get("ok", false)))
	assert(not bool(state.plan_window_for_position(Vector3(8000008.0, 0.0, 0.0)).get("ok", false)))

	var plan: Dictionary = state.plan_window_for_position(Vector3.ZERO)
	assert(bool(plan.get("ok", false)))
	assert(plan["center_cell"] == Vector2i.ZERO)
	assert(plan["desired_cell_keys"].size() == 9)
	assert(plan["load_cell_keys"].size() == 9)
	assert(plan["keep_cell_keys"].is_empty())
	assert(plan["unload_cell_keys"].is_empty())

	var descriptors: Array = plan["cell_descriptors"]
	assert(descriptors.size() == 9)
	var origin_descriptor: Dictionary = state.get_cell_descriptor(Vector2i.ZERO)
	assert(origin_descriptor.is_empty())
	var planned_origin: Dictionary = {}
	for descriptor in descriptors:
		if descriptor["cell"] == Vector2i.ZERO:
			planned_origin = descriptor
	assert(not planned_origin.is_empty())
	assert(planned_origin["layout_algorithm_version"] == Layout.ALGORITHM_VERSION)
	assert(planned_origin["open_edges"].size() == 4)
	assert(state.commit_window(plan, plan["load_cell_keys"]))
	assert(state.get_loaded_cell_count() == 9)
	assert(state.get_cell_descriptor(Vector2i.ZERO) == planned_origin)

func _test_load_first_shift_and_failed_stage() -> void:
	var state = StreamState.new()
	assert(state.configure("Level 2", 424242, 8.0, 1))
	var first: Dictionary = state.plan_window_at_cell(Vector2i.ZERO)
	assert(state.commit_window(first, first["load_cell_keys"]))
	var before_keys: Array[String] = state.get_loaded_cell_keys()
	var before_origin: Dictionary = state.get_cell_descriptor(Vector2i.ZERO)

	var shifted: Dictionary = state.plan_window_at_cell(Vector2i(1, 0))
	assert(shifted["load_cell_keys"].size() == 3)
	assert(shifted["keep_cell_keys"].size() == 6)
	assert(shifted["unload_cell_keys"].size() == 3)
	var incomplete: Array = shifted["load_cell_keys"].duplicate()
	incomplete.pop_back()
	assert(not state.commit_window(shifted, incomplete))
	assert(state.get_loaded_cell_keys() == before_keys)
	assert(state.get_cell_descriptor(Vector2i.ZERO) == before_origin)

	var duplicate_stage: Array = shifted["load_cell_keys"].duplicate()
	duplicate_stage.append(duplicate_stage[0])
	assert(not state.commit_window(shifted, duplicate_stage))
	assert(state.get_loaded_cell_keys() == before_keys)
	assert(state.commit_window(shifted, shifted["load_cell_keys"]))
	assert(state.get_loaded_cell_count() == 9)
	assert(state.is_cell_loaded(Vector2i(2, 0)))
	assert(not state.is_cell_loaded(Vector2i(-1, 0)))

func _test_unload_reload_determinism_and_stale_plans() -> void:
	var state = StreamState.new()
	assert(state.configure("Level 3", 777, 8.0, 1))
	var initial: Dictionary = state.plan_window_at_cell(Vector2i.ZERO)
	assert(state.commit_window(initial, initial["load_cell_keys"]))
	var original_origin: Dictionary = state.get_cell_descriptor(Vector2i.ZERO)

	var far_plan: Dictionary = state.plan_window_at_cell(Vector2i(2, 0))
	assert(state.commit_window(far_plan, far_plan["load_cell_keys"]))
	assert(not state.is_cell_loaded(Vector2i.ZERO))

	var return_plan: Dictionary = state.plan_window_at_cell(Vector2i.ZERO)
	assert(return_plan["load_cell_keys"].has("0,0"))
	assert(state.commit_window(return_plan, return_plan["load_cell_keys"]))
	assert(state.get_cell_descriptor(Vector2i.ZERO) == original_origin)

	var stale_plan: Dictionary = state.plan_window_at_cell(Vector2i(4, 0))
	var current_plan: Dictionary = state.plan_window_at_cell(Vector2i(3, 0))
	assert(state.commit_window(current_plan, current_plan["load_cell_keys"]))
	assert(not state.commit_window(stale_plan, stale_plan["load_cell_keys"]))
	assert(state.get_center_cell() == Vector2i(3, 0))

	var no_op: Dictionary = state.plan_window_at_cell(Vector2i(3, 0))
	assert(no_op["load_cell_keys"].is_empty())
	assert(no_op["keep_cell_keys"].size() == 9)
	assert(no_op["unload_cell_keys"].is_empty())
	assert(state.commit_window(no_op, []))
	var configuration_stale: Dictionary = state.plan_window_at_cell(Vector2i(4, 0))
	assert(state.configure("Level 4", 778, 8.0, 1))
	assert(not state.commit_window(configuration_stale, configuration_stale["load_cell_keys"]))
	assert(state.get_loaded_cell_count() == 0)

func _test_save_restore_and_layout_version_guard() -> void:
	var source = StreamState.new()
	assert(source.configure("Level 5", 987654, 8.0, 2))
	var plan: Dictionary = source.plan_window_at_cell(Vector2i(-3, 7))
	assert(state_commit(source, plan))
	var saved: Dictionary = source.to_save_dict()
	assert(saved["schema_version"] == StreamState.SAVE_SCHEMA_VERSION)
	assert(saved["layout_algorithm_version"] == Layout.ALGORITHM_VERSION)
	assert(saved["entity_spawn_algorithm_version"] == EntityDirector.SPAWN_ALGORITHM_VERSION)
	assert(saved["center_cell"] == [-3, 7])

	var restored = StreamState.new()
	assert(restored.load_save_dict(saved))
	assert(restored.get_loaded_cell_count() == 0)
	assert(restored.get_center_cell() == Vector2i(-3, 7))
	var rebuild: Dictionary = restored.plan_window_at_cell(restored.get_center_cell())
	assert(rebuild["load_cell_keys"].size() == 25)
	assert(restored.commit_window(rebuild, rebuild["load_cell_keys"]))
	assert(restored.to_save_dict() == saved)

	var legacy_payload: Dictionary = saved.duplicate(true)
	legacy_payload["schema_version"] = 1
	legacy_payload.erase("entity_spawn_algorithm_version")
	legacy_payload.erase("entity_runtime_state_version")
	legacy_payload.erase("entity_runtime_states")
	legacy_payload.erase("entity_ownership_ledger_version")
	legacy_payload.erase("entity_ownership_ledger")
	var legacy_restored = StreamState.new()
	assert(legacy_restored.load_save_dict(legacy_payload))
	assert(legacy_restored.get_center_cell() == Vector2i(-3, 7))
	assert(legacy_restored.to_save_dict()["schema_version"] == StreamState.SAVE_SCHEMA_VERSION)
	assert(legacy_restored.to_save_dict()["entity_spawn_algorithm_version"] == EntityDirector.SPAWN_ALGORITHM_VERSION)
	var legacy_v2_payload: Dictionary = saved.duplicate(true)
	legacy_v2_payload["schema_version"] = 2
	legacy_v2_payload.erase("entity_runtime_state_version")
	legacy_v2_payload.erase("entity_runtime_states")
	legacy_v2_payload.erase("entity_ownership_ledger_version")
	legacy_v2_payload.erase("entity_ownership_ledger")
	var legacy_v2_restored = StreamState.new()
	assert(legacy_v2_restored.load_save_dict(legacy_v2_payload))
	assert(legacy_v2_restored.to_save_dict()["schema_version"] == StreamState.SAVE_SCHEMA_VERSION)
	assert(legacy_v2_restored.get_entity_runtime_states().is_empty())

	var transaction_clone = source.clone_for_transaction()
	assert(transaction_clone.get_loaded_cell_keys() == source.get_loaded_cell_keys())
	var clone_target_cell: Vector2i = source.get_center_cell() + Vector2i(1, 0)
	var transaction_plan: Dictionary = transaction_clone.plan_window_at_cell(clone_target_cell)
	assert(transaction_plan["load_cell_keys"].size() == 5 and transaction_plan["unload_cell_keys"].size() == 5)

	var before_invalid_load: Dictionary = restored.to_save_dict()
	var unsupported: Dictionary = saved.duplicate(true)
	unsupported["layout_algorithm_version"] = Layout.ALGORITHM_VERSION + 1
	assert(not restored.load_save_dict(unsupported))
	assert(restored.last_load_error == "unsupported_layout_algorithm_version")
	assert(restored.to_save_dict() == before_invalid_load)
	assert(restored.get_loaded_cell_count() == 25)

	var unsupported_spawn: Dictionary = saved.duplicate(true)
	unsupported_spawn["entity_spawn_algorithm_version"] = EntityDirector.SPAWN_ALGORITHM_VERSION + 1
	assert(not restored.load_save_dict(unsupported_spawn))
	assert(restored.last_load_error == "unsupported_entity_spawn_algorithm_version")
	assert(restored.to_save_dict() == before_invalid_load)
	assert(restored.get_loaded_cell_count() == 25)

	var missing_spawn_version: Dictionary = saved.duplicate(true)
	missing_spawn_version.erase("entity_spawn_algorithm_version")
	assert(not restored.load_save_dict(missing_spawn_version))
	assert(restored.last_load_error == "unsupported_entity_spawn_algorithm_version")
	assert(restored.to_save_dict() == before_invalid_load)
	assert(restored.get_loaded_cell_count() == 25)

	var malformed: Dictionary = saved.duplicate(true)
	malformed["center_cell"] = [-3, 7.5]
	assert(not restored.load_save_dict(malformed))
	assert(restored.to_save_dict() == before_invalid_load)
	assert(restored.get_loaded_cell_count() == 25)

	var edge_overflow: Dictionary = saved.duplicate(true)
	edge_overflow["center_cell"] = [1000000, 0]
	assert(not restored.load_save_dict(edge_overflow))
	assert(restored.last_load_error == "center_window_out_of_range")
	assert(restored.to_save_dict() == before_invalid_load)
	assert(restored.get_loaded_cell_count() == 25)


func _test_extreme_float_inputs_fail_atomically() -> void:
	var source = StreamState.new()
	assert(source.configure("Level 5", 987654, 8.0, 2))
	var source_plan: Dictionary = source.plan_window_at_cell(Vector2i(-3, 7))
	assert(state_commit(source, source_plan))
	var saved: Dictionary = source.to_save_dict()

	var restored = StreamState.new()
	assert(restored.load_save_dict(saved))
	var rebuild: Dictionary = restored.plan_window_at_cell(restored.get_center_cell())
	assert(state_commit(restored, rebuild))
	var before: Dictionary = restored.to_save_dict()
	var before_count: int = restored.get_loaded_cell_count()
	assert(before_count == 25)

	var invalid_cases: Array[Dictionary] = []
	var payload := saved.duplicate(true)
	payload["schema_version"] = 1e300
	invalid_cases.append({"payload": payload, "reason": "invalid_schema_version"})
	payload = saved.duplicate(true)
	payload["layout_algorithm_version"] = -1e300
	invalid_cases.append({"payload": payload, "reason": "unsupported_layout_algorithm_version"})
	payload = saved.duplicate(true)
	payload["world_seed"] = 1e300
	invalid_cases.append({"payload": payload, "reason": "invalid_world_seed"})
	payload = saved.duplicate(true)
	payload["world_seed"] = -1e300
	invalid_cases.append({"payload": payload, "reason": "invalid_world_seed"})
	payload = saved.duplicate(true)
	payload["stream_radius"] = 1e300
	invalid_cases.append({"payload": payload, "reason": "invalid_stream_radius"})
	payload = saved.duplicate(true)
	payload["center_cell"] = [1e300, 7]
	invalid_cases.append({"payload": payload, "reason": "invalid_center_cell"})
	payload = saved.duplicate(true)
	payload["center_cell"] = [-1e300, 7]
	invalid_cases.append({"payload": payload, "reason": "invalid_center_cell"})
	payload = saved.duplicate(true)
	payload["center_cell"] = [-3, 1e300]
	invalid_cases.append({"payload": payload, "reason": "invalid_center_cell"})
	payload = saved.duplicate(true)
	payload["center_cell"] = [-3, -1e300]
	invalid_cases.append({"payload": payload, "reason": "invalid_center_cell"})

	for test_case in invalid_cases:
		var invalid_payload: Dictionary = test_case["payload"]
		assert(not restored.load_save_dict(invalid_payload), "Out-of-range finite float save fields must be rejected.")
		assert(restored.last_load_error == str(test_case["reason"]), "Out-of-range float rejection reports the field-specific reason.")
		assert(restored.to_save_dict() == before, "Rejected extreme-float load must leave the saved configuration unchanged.")
		assert(restored.get_loaded_cell_count() == before_count, "Rejected extreme-float load must preserve the committed cell window.")

func _test_cell_key_parser_bounds() -> void:
	assert(bool(EntityRuntimeState.parse_cell_key("0,0").get("ok", false)))
	assert(bool(EntityRuntimeState.parse_cell_key("1000000,-1000000").get("ok", false)))
	assert(not bool(EntityRuntimeState.parse_cell_key("1000001,0").get("ok", false)))
	assert(not bool(EntityRuntimeState.parse_cell_key("-1000001,0").get("ok", false)))
	assert(not bool(EntityRuntimeState.parse_cell_key("2147483648,0").get("ok", false)))
	assert(not bool(EntityRuntimeState.parse_cell_key("-2147483648,0").get("ok", false)))
	assert(not bool(EntityRuntimeState.parse_cell_key("-9223372036854775808,0").get("ok", false)))
	assert(not bool(EntityRuntimeState.parse_cell_key("01,0").get("ok", false)))
	assert(not bool(EntityRuntimeState.parse_cell_key("0,-0").get("ok", false)))

func state_commit(state: RefCounted, plan: Dictionary) -> bool:
	return state.commit_window(plan, plan["load_cell_keys"])

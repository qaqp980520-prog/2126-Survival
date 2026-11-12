extends SceneTree

const Session = preload("res://systems/BackroomsLocationSession.gd")
const PortalDirector = preload("res://systems/BackroomsPortalDirector.gd")

func _initialize() -> void:
	_test_transition_and_commit_return()
	_test_portal_director_handoff()
	_test_invalid_transition_is_atomic()
	_test_save_round_trip()
	_test_invalid_save_is_atomic()
	print("Backrooms location session tests passed.")
	quit()

func _test_transition_and_commit_return() -> void:
	var session = Session.new()
	var return_position := Vector3(18.5, 2.0, -41.25)
	var entry_position := Vector3(3.0, 0.0, -5.0)
	var before: Dictionary = session.to_save_dict()
	assert(session.can_begin_transition("Level 3", 77, return_position, 20261112, entry_position))
	assert(session.to_save_dict() == before, "Preflight must not mutate session state.")
	assert(session.begin_transition("Level 3", 77, return_position, 20261112, entry_position))
	assert(session.is_active())
	assert(session.get_current_level() == "Level 3")
	assert(session.entry_portal_id == 77)
	assert(session.surface_return_position == return_position)
	assert(session.backrooms_position == entry_position)
	assert(session.surface_world_seed == 20261112)
	assert(session.backrooms_seed >= 0 and session.backrooms_seed <= Session.MAX_WORLD_SEED)

	var next_position := Vector3(-24.0, 1.5, 63.25)
	assert(session.set_backrooms_position(next_position))
	assert(session.backrooms_position == next_position)
	var return_context: Dictionary = session.get_return_context()
	assert(return_context["surface_return_position"] == return_position)
	assert(return_context["surface_world_seed"] == 20261112)
	assert(return_context["entry_portal_id"] == 77)
	assert(session.is_active(), "Reading the return context must not commit the return.")

	var completed: Dictionary = session.complete_return()
	assert(bool(completed.get("ok", false)))
	assert(completed["surface_return_position"] == return_position)
	assert(completed["surface_world_seed"] == 20261112)
	assert(completed["entry_portal_id"] == 77)
	assert(not session.is_active())
	assert(session.to_save_dict() == Session.new().to_save_dict())
	assert(not bool(session.complete_return().get("ok", false)))

func _test_portal_director_handoff() -> void:
	var director = PortalDirector.new(42, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(spawned.get("event", "") == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var preview: Dictionary = director.preview_portal_entry(portal_id)
	assert(bool(preview.get("ok", false)))
	var session = Session.new()
	var surface_position := Vector3(12.0, 2.0, -8.0)
	assert(session.can_begin_from_portal_result(preview, surface_position, 314159))
	assert(not session.begin_from_portal_result(preview, surface_position, 314159), "A preview cannot commit the session.")
	assert(not session.is_active())
	var consumed: Dictionary = director.consume_portal(portal_id)
	assert(bool(consumed.get("ok", false)))
	assert(consumed["destination_level"] == preview["destination_level"])
	assert(session.begin_from_portal_result(consumed, surface_position, 314159))
	assert(session.entry_portal_id == portal_id)
	assert(session.get_current_level() == str(consumed["destination_level"]))
	assert(PortalDirector.TARGET_LEVELS.has(session.get_current_level()))
	assert(session.surface_return_position == surface_position)
	var second_session = Session.new()
	assert(second_session.begin_from_portal_result(consumed, surface_position, 314159))
	var invalid_result: Dictionary = consumed.duplicate(true)
	invalid_result["portal_id"] = float(portal_id)
	var rejected_session = Session.new()
	assert(not rejected_session.begin_from_portal_result(invalid_result, surface_position, 314159))
	assert(rejected_session.to_save_dict() == Session.new().to_save_dict())
	assert(second_session.backrooms_seed == session.backrooms_seed, "The same source seed and portal ID must produce the same Backrooms layout seed.")

func _test_invalid_transition_is_atomic() -> void:
	var session = Session.new()
	var baseline: Dictionary = session.to_save_dict()
	assert(not session.begin_transition("Level 99", 1, Vector3.ZERO, 1))
	assert(not session.begin_transition("Level 1", 0, Vector3.ZERO, 1))
	assert(not session.begin_transition("Level 1", PortalDirector.MAX_PORTAL_SERIAL + 1, Vector3.ZERO, 1))
	assert(not session.begin_transition("Level 1", 1, Vector3(NAN, 0.0, 0.0), 1))
	assert(not session.begin_transition("Level 1", 1, Vector3.ZERO, -1))
	assert(not session.begin_transition("Level 1", 1, Vector3.ZERO, Session.MAX_WORLD_SEED + 1))
	assert(session.to_save_dict() == baseline)

	assert(session.begin_transition("Level 1", 9, Vector3(1.0, 2.0, 3.0), 17))
	var active_baseline: Dictionary = session.to_save_dict()
	assert(not session.begin_transition("Level 2", 10, Vector3.ZERO, 18))
	assert(session.to_save_dict() == active_baseline, "A second portal must not overwrite an active visit.")
	assert(not session.set_backrooms_position(Vector3(INF, 0.0, 0.0)))
	assert(session.to_save_dict() == active_baseline)

func _test_save_round_trip() -> void:
	var original = Session.new()
	assert(original.begin_transition("Level 5", 1234, Vector3(200.25, 4.0, -91.5), 987654321, Vector3(-8.0, 0.0, 16.0)))
	assert(original.set_backrooms_position(Vector3(48.125, 1.25, -32.5)))
	var saved: Dictionary = original.to_save_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	assert(parsed is Dictionary)
	var restored = Session.new()
	assert(restored.load_save_dict(parsed))
	assert(restored.to_save_dict() == saved)
	assert(restored.get_return_context() == original.get_return_context())

	var inactive = Session.new()
	var inactive_saved: Dictionary = inactive.to_save_dict()
	var inactive_parsed: Variant = JSON.parse_string(JSON.stringify(inactive_saved))
	var inactive_restored = Session.new()
	assert(inactive_parsed is Dictionary and inactive_restored.load_save_dict(inactive_parsed))
	assert(inactive_restored.to_save_dict() == inactive_saved)

func _test_invalid_save_is_atomic() -> void:
	var session = Session.new()
	assert(session.begin_transition("Level 2", 51, Vector3(5.0, 2.0, 7.0), 2026, Vector3(1.0, 0.0, 1.0)))
	var baseline: Dictionary = session.to_save_dict()
	var invalid_payloads: Array[Dictionary] = []

	var bad: Dictionary = baseline.duplicate(true)
	bad["schema_version"] = 2
	invalid_payloads.append(bad)
	bad = baseline.duplicate(true)
	bad["level_id"] = "Level 99"
	invalid_payloads.append(bad)
	bad = baseline.duplicate(true)
	bad["entry_portal_id"] = 0
	invalid_payloads.append(bad)
	bad = baseline.duplicate(true)
	bad["entry_portal_id"] = 51.0
	invalid_payloads.append(bad)
	bad = baseline.duplicate(true)
	bad["surface_return_position"] = [1.0, 2.0]
	invalid_payloads.append(bad)
	bad = baseline.duplicate(true)
	bad["backrooms_position"] = [1.0, NAN, 3.0]
	invalid_payloads.append(bad)
	bad = baseline.duplicate(true)
	bad["surface_world_seed"] = -1
	invalid_payloads.append(bad)
	bad = baseline.duplicate(true)
	bad["surface_world_seed"] = Session.MAX_WORLD_SEED + 1
	invalid_payloads.append(bad)
	bad = baseline.duplicate(true)
	bad["backrooms_seed"] = "42"
	invalid_payloads.append(bad)
	bad = baseline.duplicate(true)
	bad["backrooms_seed"] = posmod(int(baseline["backrooms_seed"]) + 1, Session.MAX_WORLD_SEED + 1)
	invalid_payloads.append(bad)
	bad = baseline.duplicate(true)
	bad["active"] = false
	invalid_payloads.append(bad)
	bad = baseline.duplicate(true)
	bad["backrooms_position"] = [INF, 0.0, 0.0]
	invalid_payloads.append(bad)

	var inactive_bad: Dictionary = Session.new().to_save_dict()
	inactive_bad["level_id"] = "Level 1"
	invalid_payloads.append(inactive_bad)

	for candidate in invalid_payloads:
		assert(not session.load_save_dict(candidate))
		assert(session.to_save_dict() == baseline, "Rejected save must leave every live session field unchanged.")

extends SceneTree

const Descriptor = preload("res://systems/SurfaceTerrainTransitionDescriptor.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_cardinal_directions_and_order_independence()
	_test_equal_height_join()
	_test_reject_invalid_pairs()
	_test_descriptor_revalidation()
	if failures.is_empty():
		print("Surface terrain transition descriptor tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_cardinal_directions_and_order_independence() -> void:
	var cases: Array[Dictionary] = [
		{"position":Vector3(2.0,0.0,0.0),"side":"east","opposite":"west"},
		{"position":Vector3(-2.0,0.0,0.0),"side":"west","opposite":"east"},
		{"position":Vector3(0.0,0.0,-2.0),"side":"north","opposite":"south"},
		{"position":Vector3(0.0,0.0,2.0),"side":"south","opposite":"north"}
	]
	for index in range(cases.size()):
		var first: Dictionary = _snapshot("terrain/A", Vector3.ZERO, 2)
		var second: Dictionary = _snapshot("terrain/B", cases[index]["position"], 0)
		var forward: Dictionary = Descriptor.build(first, second)
		var reverse: Dictionary = Descriptor.build(second, first)
		_expect(bool(forward.get("ok", false)), "cardinal case %d builds a descriptor" % index)
		_expect(bool(reverse.get("ok", false)), "reversed cardinal case %d builds a descriptor" % index)
		if not bool(forward.get("ok", false)) or not bool(reverse.get("ok", false)):
			continue
		var descriptor: Dictionary = forward["descriptor"]
		_expect(descriptor == reverse["descriptor"], "cardinal case %d is independent of argument order" % index)
		_expect(str(descriptor["first_side"]) == str(cases[index]["side"]), "cardinal case %d records the canonical first side" % index)
		_expect(str(descriptor["second_side"]) == str(cases[index]["opposite"]), "cardinal case %d records the opposite side" % index)
		_expect(str(descriptor["owner_stable_id"]) == "terrain/A", "cardinal case %d selects the lexicographically stable owner" % index)
		_expect(str(descriptor["higher_stable_id"]) == "terrain/A" and str(descriptor["lower_stable_id"]) == "terrain/B", "cardinal case %d records the correct high and low patches" % index)
		_expect(str(descriptor["mode"]) == "unequal_height" and bool(descriptor["transition_required"]), "cardinal case %d requests exactly one future transition" % index)
		_expect(is_equal_approx(float(descriptor["height_delta"]), 0.5), "cardinal case %d calculates the exact 0.5 m rise" % index)
		_expect(str(descriptor["edge_key"]) == str(reverse["descriptor"]["edge_key"]), "cardinal case %d keeps one deterministic edge key" % index)
	_expect(_snapshot("terrain/A", Vector3.ZERO, 2) == _snapshot("terrain/A", Vector3.ZERO, 2), "snapshot helper is deterministic")

func _test_equal_height_join() -> void:
	var first: Dictionary = _snapshot("terrain/A", Vector3.ZERO, 1)
	var second: Dictionary = _snapshot("terrain/B", Vector3(2.0,0.0,0.0), 1)
	var result: Dictionary = Descriptor.build(first, second)
	_expect(bool(result.get("ok", false)), "equal-height pair builds")
	if bool(result.get("ok", false)):
		var descriptor: Dictionary = result["descriptor"]
		_expect(str(descriptor["mode"]) == "flush_join", "equal-height pair remains a flush join")
		_expect(not bool(descriptor["transition_required"]), "equal-height pair does not request a transition collider")
		_expect(str(descriptor["higher_stable_id"]).is_empty() and str(descriptor["lower_stable_id"]).is_empty(), "equal-height pair has no artificial high/low owner")
		_expect(is_zero_approx(float(descriptor["height_delta"])), "equal-height pair has zero rise")

func _test_reject_invalid_pairs() -> void:
	var base: Dictionary = _snapshot("terrain/A", Vector3.ZERO, 0)
	_expect(not bool(Descriptor.build(base, _snapshot("terrain/A", Vector3(2.0,0.0,0.0), 1)).get("ok", true)), "duplicate stable IDs are rejected")
	_expect(str(Descriptor.build(base, _snapshot("terrain/B", Vector3(2.0,0.0,0.0), 0, 3.0)).get("error", "")) == "mixed_patch_sizes", "mixed patch sizes are rejected")
	_expect(str(Descriptor.build(base, _snapshot("terrain/B", Vector3(2.0,0.0,1.0), 0)).get("error", "")) == "not_cardinal_neighbors", "diagonal offsets are rejected")
	_expect(str(Descriptor.build(base, _snapshot("terrain/B", Vector3(4.0,0.0,0.0), 0)).get("error", "")) == "not_cardinal_neighbors", "distant patches are rejected")
	_expect(str(Descriptor.build(base, _snapshot("terrain/B", Vector3(2.0,0.2,0.0), 0)).get("error", "")) == "not_cardinal_neighbors", "vertical offsets are rejected")
	_expect(str(Descriptor.build(base, _snapshot("terrain/B", Vector3(2.0,0.0,0.0), 3)).get("error", "")) == "second_invalid_height_level", "unsupported height levels are rejected")
	var missing: Dictionary = base.duplicate(true)
	missing.erase("revision")
	_expect(str(Descriptor.build(missing, _snapshot("terrain/B", Vector3(2.0,0.0,0.0), 0)).get("error", "")) == "first_missing_revision", "incomplete snapshots are rejected")
	var bad_id: Dictionary = _snapshot("", Vector3.ZERO, 0)
	_expect(str(Descriptor.build(bad_id, _snapshot("terrain/B", Vector3(2.0,0.0,0.0), 0)).get("error", "")) == "first_invalid_stable_id", "empty stable IDs are rejected")

func _test_descriptor_revalidation() -> void:
	var first: Dictionary = _snapshot("terrain/A", Vector3.ZERO, 2)
	var second: Dictionary = _snapshot("terrain/B", Vector3(0.0,0.0,-2.0), 0)
	var result: Dictionary = Descriptor.build(first, second)
	_expect(bool(result.get("ok", false)), "valid descriptor fixture builds")
	if not bool(result.get("ok", false)):
		return
	var descriptor: Dictionary = result["descriptor"]
	_expect(Descriptor.validate_descriptor(first, second, descriptor), "descriptor validates against its original snapshots")
	var changed: Dictionary = second.duplicate(true)
	changed["height_level"] = 1
	_expect(not Descriptor.validate_descriptor(first, changed, descriptor), "descriptor becomes stale when either patch height changes")
	_expect(first["height_level"] == 2 and second["height_level"] == 0, "building descriptors never mutates source snapshots")

func _snapshot(stable_id: String, position: Vector3, height_level: int, patch_size: float = 2.0) -> Dictionary:
	return {"stable_id":stable_id,"position":position,"patch_size":patch_size,"height_level":height_level,"revision":1}

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

extends SceneTree

const PolicyScript = preload("res://systems/SurfaceTerrainEdgePolicy.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var low := _state(0, "soil", 4)
	var equal := _state(0, "soil", 9)
	var equal_other_material := _state(0, "rock", 2)
	var high := _state(2, "metal", 6)
	var isolated: Dictionary = PolicyScript.classify_edge(low, {})
	_expect(bool(isolated.get("valid", false)) and str(isolated.get("mode", "")) == "ground_ramp", "isolated patch retains its base-ground ramp")
	_expect(bool(isolated.get("ramp_enabled", false)), "isolated patch ramp remains enabled")
	var flush: Dictionary = PolicyScript.classify_edge(low, equal)
	_expect(str(flush.get("mode", "")) == "flush_join", "equal-height neighbors form a flush join")
	_expect(not bool(flush.get("ramp_enabled", true)), "equal-height join suppresses overlapping ground ramps")
	_expect(is_equal_approx(float(flush.get("height_delta", -1.0)), 0.0), "flush join has zero height delta")
	_expect(not bool(flush.get("material_seam", true)), "matching materials have no material seam")
	var material_seam: Dictionary = PolicyScript.classify_edge(low, equal_other_material)
	_expect(str(material_seam.get("mode", "")) == "flush_join", "material changes do not alter edge elevation policy")
	_expect(bool(material_seam.get("material_seam", false)), "different materials are reported as a material seam")
	var neighbor_higher: Dictionary = PolicyScript.classify_edge(low, high)
	_expect(str(neighbor_higher.get("mode", "")) == "neighbor_higher", "higher neighboring patch is identified")
	_expect(str(neighbor_higher.get("higher_patch", "")) == "neighbor", "higher neighbor owns the raised side of the step")
	_expect(is_equal_approx(float(neighbor_higher.get("height_delta", 0.0)), 0.5), "two height levels produce the expected 0.5 m step")
	_expect(not bool(neighbor_higher.get("ramp_enabled", true)), "different-height edge suppresses conflicting ramps")
	var local_higher: Dictionary = PolicyScript.classify_edge(high, low)
	_expect(str(local_higher.get("mode", "")) == "local_higher", "higher local patch is identified")
	_expect(str(local_higher.get("higher_patch", "")) == "local", "local patch is identified as the high side")
	_expect(is_equal_approx(float(local_higher.get("height_delta", 0.0)), 0.5), "height delta is symmetric from either side")
	var invalid: Dictionary = PolicyScript.classify_edge(low, {"height_level": "2", "surface_type": "rock", "revision": 0})
	_expect(not bool(invalid.get("valid", true)) and str(invalid.get("reason", "")) == "invalid_neighbor_state", "invalid neighbor state is rejected")
	_expect(low == _state(0, "soil", 4), "policy never mutates the local saved state")
	_expect(high == _state(2, "metal", 6), "policy never mutates the neighbor saved state")
	if failures.is_empty():
		print("Surface terrain edge policy tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _state(height: int, material: String, revision: int) -> Dictionary:
	return {"height_level": height, "surface_type": material, "revision": revision}

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

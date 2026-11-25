extends SceneTree

const OverlayMapScript = preload("res://systems/SurfaceTerrainOverlayMap.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source: Dictionary = {
		"keep": 1,
		"replace": 2,
		"remove": 3,
		"false_value": false,
		"null_value": null
	}
	var root: RefCounted = OverlayMapScript.new(source)
	source["external_mutation"] = 99
	_expect(not bool(root.call("has_key", "external_mutation")), "root owns a shallow snapshot of the source Dictionary")
	_expect(int(root.call("size")) == 5, "root size is cached at construction")
	_expect(bool(root.call("has_key", "null_value")), "present null values remain distinguishable from absent keys")
	_expect(root.call("get_value", "false_value", true) == false, "false values are returned without falling back to the default")
	_expect(int(root.call("get_stats").get("base_keys_copied", -1)) == 5, "root records its one-time base-map copy")

	var first: RefCounted = root.call("fork")
	_expect(bool(root.call("is_sealed")), "fork seals the parent snapshot")
	_expect(not bool(root.call("set_value", "late_write", 1)), "sealed snapshots reject mutation")
	_expect(int(first.call("get_stats").get("base_keys_copied", -1)) == 0, "fork performs no base-key copy")
	_expect(int(first.call("get_stats").get("materialize_calls", -1)) == 0, "fork does not materialize the visible key set")

	_expect(bool(first.call("set_value", "replace", 20)), "overlay replaces an existing key")
	_expect(bool(first.call("erase_key", "remove")), "overlay tombstones an existing key")
	_expect(not bool(first.call("erase_key", "missing")), "overlay rejects erasing an absent key")
	_expect(bool(first.call("set_value", "new", 4)), "overlay adds a new key")
	_expect(int(first.call("size")) == 5, "replace, erase, and insert update the cached visible size")
	_expect(int(root.call("get_value", "replace")) == 2, "child replacement does not mutate its parent")
	_expect(bool(root.call("has_key", "remove")), "child tombstone does not mutate its parent")
	_expect(not bool(first.call("has_key", "remove")), "tombstone hides a parent key")

	_expect(bool(first.call("set_value", "remove", 30)), "setting a tombstoned key resurrects it")
	_expect(int(first.call("size")) == 6, "resurrection increments visible size exactly once")
	_expect(bool(first.call("set_value", "remove", 31)), "replacing a resurrected key succeeds")
	_expect(int(first.call("size")) == 6, "replacing a local write does not change visible size")

	var second: RefCounted = first.call("fork")
	_expect(bool(first.call("is_sealed")), "fork seals the intermediate snapshot")
	_expect(bool(second.call("erase_key", "new")), "grandchild tombstones a parent-local write")
	_expect(bool(second.call("set_value", "false_value", false)), "grandchild preserves false-valued overrides")
	_expect(bool(second.call("set_value", "new_null", null)), "grandchild supports null-valued insertions")
	_expect(int(second.call("size")) == 6, "grandchild cached size accounts for parent writes and tombstones")
	_expect(bool(first.call("has_key", "new")), "grandchild tombstone does not mutate its parent")
	_expect(not bool(second.call("has_key", "new")), "grandchild tombstone hides an intermediate write")
	_expect(bool(second.call("has_key", "new_null")), "null-valued insertions remain present")

	var keys: Array = second.call("keys")
	_expect(keys.size() == int(second.call("size")), "explicit key enumeration matches cached size")
	_expect(int(second.call("get_stats").get("materialize_calls", -1)) == 1, "keys() is an explicit materialization boundary")
	var materialized: Dictionary = second.call("materialize")
	_expect(materialized.size() == 6, "materialized Dictionary has the visible size")
	_expect(int(materialized.get("replace", -1)) == 20, "materialization applies the newest override")
	_expect(int(materialized.get("remove", -1)) == 31, "materialization applies a resurrected key")
	_expect(not materialized.has("new"), "materialization applies child tombstones")
	_expect(materialized.has("new_null") and materialized["new_null"] == null, "materialization preserves null-valued keys")
	_expect(materialized.get("false_value", true) == false, "materialization preserves false-valued keys")
	_expect(bool(root.call("has_key", "new")) == false, "original root remains independent of all descendants")

	var compacted: RefCounted = second.call("compact")
	_expect(int(compacted.call("get_depth")) == 0, "compact returns a new root snapshot")
	_expect(compacted.call("materialize") == materialized, "compaction preserves exact visible Dictionary contents")
	_expect(int(second.call("get_depth")) == 2, "compaction does not mutate the source overlay chain")

	var cursor: RefCounted = OverlayMapScript.new({"seed": 0})
	for index in range(24):
		var next: RefCounted = cursor.call("fork")
		_expect(bool(next.call("set_value", "key_%02d" % index, index)), "overlay chain accepts write %d" % index)
		cursor = next
		_expect(int(cursor.call("get_depth")) <= 8, "automatic compaction bounds lookup depth at write %d" % index)
	var chain_snapshot: Dictionary = cursor.call("materialize")
	_expect(chain_snapshot.size() == 25, "bounded overlay chain retains every inserted key")
	_expect(int(chain_snapshot.get("seed", -1)) == 0, "bounded overlay chain retains the root value")
	for index in range(24):
		_expect(int(chain_snapshot.get("key_%02d" % index, -1)) == index, "bounded overlay chain retains key %d" % index)

	if failures.is_empty():
		print("Surface terrain overlay map tests passed.")
		quit(0)
	else:
		push_error("Surface terrain overlay map tests failed: %d" % failures.size())
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

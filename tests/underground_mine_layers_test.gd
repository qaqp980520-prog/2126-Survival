extends SceneTree

const Director = preload("res://systems/UndergroundMineDirector.gd")
const Factory = preload("res://systems/UndergroundMineFactory.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := Director.new()
	_expect(director.get_layer_index(Vector3(1.5, 2.0, 7.5)) == 0, "surface-height positions resolve to layer zero")
	_expect(director.get_layer_index(Vector3(1.5, -8.25, 7.5)) == 0, "legacy underground floor resolves to layer zero")
	_expect(director.get_layer_index(Vector3(1.5, -28.25, 7.5)) == 1, "second mine floor resolves to layer one")
	_expect(director.get_layer_index(Vector3(1.5, -168.25, 7.5)) == 8, "maximum supported mine depth resolves to layer eight")
	_expect(director.get_layer_index(Vector3(1.5, -188.25, 7.5)) == -1, "positions below the supported depth are rejected")
	_expect(director.get_chunk_id(Vector2i.ZERO, 0) == "underground/mine_0_0", "layer zero preserves legacy stable chunk IDs")
	_expect(director.get_chunk_id(Vector2i.ZERO, 1) == "underground/layer_1/mine_0_0", "deeper layers use an explicit namespace")
	_expect(director.call("_parse_chunk_id", "underground/mine_-1_2").get("layer", -1) == 0, "legacy chunk IDs parse as layer zero")
	_expect(director.call("_parse_chunk_id", "underground/layer_2/mine_-1_2").get("layer", -1) == 2, "layered chunk IDs preserve their depth")
	_expect(not bool(director.call("_parse_chunk_id", "underground/layer_9/mine_0_0").get("valid", false)), "unsupported layer IDs are rejected")

	var root: Node3D = Factory.make_chunk(1000, Vector2i.ZERO, 1)
	_expect(root != null and root.name == "UndergroundMine_L1_0_0", "factory creates a depth-qualified layer-one root")
	if root != null:
		_expect(is_equal_approx(root.position.y, -20.0), "layer-one chunks are placed one vertical interval below layer zero")
		_expect(root.get_node_or_null("MineLiftAnchor") != null, "origin room exposes a vertical lift anchor on deeper levels")
		var first_caches: Array[Dictionary] = Factory.get_cache_spawn_data(Vector2i.ZERO, 1)
		var second_caches: Array[Dictionary] = Factory.get_cache_spawn_data(Vector2i.ZERO, 1)
		_expect(first_caches == second_caches, "deeper cache selection is deterministic across reloads")
		_expect(first_caches.size() <= 1, "deeper service shaft does not duplicate the layer-zero service cache pair")
		root.free()
	director.free()
	if failures.is_empty():
		print("Underground mine layer tests passed.")
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

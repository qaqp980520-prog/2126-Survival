extends SceneTree

const PlaygroundScene = preload("res://prototypes/SurfaceChunkStreamingPlayground.tscn")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var playground := PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	await physics_frame

	var bridge: Node = playground.get("inventory_bridge")
	var controller: Node = playground.get("chunk_controller")
	_expect(bridge != null, "surface prototype creates the shared inventory bridge")
	_expect(controller != null, "surface prototype creates the mineral chunk controller")
	if bridge == null or controller == null:
		playground.queue_free()
		await process_frame
		_finish()
		return

	var chunk: Node3D = controller.call("get_chunk_root", "surface/chunk_0_0")
	var ore: Node = chunk.get_node_or_null("Ore_0_0") if chunk != null else null
	_expect(ore != null, "initial surface chunk contains a mineral vein")
	if ore != null:
		var before_units := int(ore.get("remaining_units"))
		playground.player.global_position = (ore as Node3D).global_position + Vector3(0.0, 1.5, 0.0)
		playground.call("_mine_nearest_vein")
		var payload: Dictionary = bridge.call("serialize_inventory")
		var counts: Dictionary = payload.get("inventory", {})
		_expect(int(ore.get("remaining_units")) == before_units - 1, "mining consumes one unit from the nearest vein")
		_expect(int(counts.get("iron_ore", 0)) == 1, "mined ore enters the shared survival inventory")
		_expect(float(bridge.call("get_weight_kg")) > 0.0, "mining updates inventory carry weight")

	playground.queue_free()
	await process_frame
	_finish()

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

func _finish() -> void:
	if failures.is_empty():
		print("Surface mining integration test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

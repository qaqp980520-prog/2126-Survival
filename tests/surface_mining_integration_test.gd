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
	if bridge != null and controller != null:
		var chunk: Node3D = controller.call("get_chunk_root", "surface/chunk_0_0")
		var ore: Node3D = chunk.get_node_or_null("Ore_0_0") as Node3D if chunk != null else null
		_expect(ore != null, "streamed chunk retains its mineral vein data node")
		if ore != null:
			_expect(ore.global_position.y < -0.5, "mineral vein is placed below the surface ground slab")
			_expect(not playground.has_method("_mine_nearest_vein"), "surface prototype does not expose surface mining")
			_expect(is_zero_approx(float(bridge.call("get_weight_kg"))), "surface exploration cannot collect underground ore directly")

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
		print("Surface underground-vein placement test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

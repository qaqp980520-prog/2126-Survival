extends SceneTree

const MineralRegistry = preload("res://systems/MineralVeinRegistry.gd")
const CropRegistry = preload("res://systems/CropRegistry.gd")
const CropController = preload("res://systems/CropPlotController.gd")
const ChunkController = preload("res://systems/MineralChunkController.gd")
const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const CropPlotScene = preload("res://systems/CropPlotVisual.tscn")

var failures: Array[String] = []
var factory_calls := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var mineral_registry: Node = MineralRegistry.new()
	var crop_registry: Node = CropRegistry.new()
	var crop_controller: Node = CropController.new()
	var chunk_controller: Node3D = ChunkController.new()
	var director: Node = Director.new()
	root.add_child(mineral_registry)
	root.add_child(crop_registry)
	root.add_child(crop_controller)
	root.add_child(chunk_controller)
	root.add_child(director)
	await process_frame

	_expect(bool(crop_controller.call("bind_registry", crop_registry)), "crop controller binds the authoritative crop registry")
	_expect(bool(chunk_controller.call("bind_registry", mineral_registry)), "chunk controller binds the mineral registry")
	_expect(bool(chunk_controller.call("bind_crop_controller", crop_controller)), "chunk controller binds the crop adapter")
	director.set("chunk_size_x", 10.0)
	director.set("chunk_size_z", 10.0)
	director.set("load_radius", 0)
	_expect(bool(director.call("bind_controller", chunk_controller)), "director binds the production chunk controller")
	_expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_chunk"))), "director binds the crop-bearing test factory")

	var chunk_id := "surface/chunk_0_0"
	var now := int(Time.get_unix_time_from_system())
	_expect(bool(director.call("sync_to_world_position", Vector3.ZERO, now)), "initial crop-bearing chunk loads")
	var old_root: Node3D = chunk_controller.call("get_chunk_root", chunk_id)
	var old_plot: Node3D = _find_plot(chunk_controller)
	_expect(is_instance_valid(old_root) and is_instance_valid(old_plot), "initial chunk exposes a configured CropPlotVisual")
	if not is_instance_valid(old_root) or not is_instance_valid(old_plot):
		await _finish(1, director, chunk_controller, crop_controller, crop_registry, mineral_registry)
		return

	var stable_id := str(old_plot.get("stable_id"))
	_expect(stable_id.begins_with(chunk_id + "/crop/"), "plot receives a chunk-derived stable crop ID")
	var old_root_ref: WeakRef = weakref(old_root)
	var old_plot_ref: WeakRef = weakref(old_plot)
	_expect(bool(crop_controller.call("plant_crop", stable_id, "wheat", 80.0, now)), "plant a stable-ID crop before queueing the shared root")
	_expect(bool(crop_controller.call("advance_crop", stable_id, 120.0, now + 120)), "advance the crop to a non-default persisted stage")
	var before: Dictionary = crop_controller.call("get_crop", stable_id)
	_expect(int(before.get("growth_stage", -1)) == 1 and is_equal_approx(float(before.get("moisture", -1.0)), 50.0), "pre-unload crop state has stage one and fifty moisture")

	old_root.queue_free()
	_expect(chunk_controller.call("get_loaded_crop_plots").is_empty(), "queued root and crop plot are omitted from live crop enumeration")
	_expect(not bool(chunk_controller.call("is_chunk_loaded", chunk_id)), "queued crop-bearing root is not reported loaded")
	_expect(bool(director.call("sync_to_world_position", Vector3.ZERO, now + 180)), "same-coordinate sync recovers the queued crop-bearing root")

	var replacement_root: Node3D = chunk_controller.call("get_chunk_root", chunk_id)
	var replacement_plot: Node3D = _find_plot(chunk_controller)
	_expect(is_instance_valid(replacement_root) and replacement_root != old_root, "replacement root is a new Node3D instance")
	_expect(is_instance_valid(replacement_plot) and replacement_plot != old_plot, "replacement crop visual is a new node instance")
	if is_instance_valid(replacement_plot):
		_expect(str(replacement_plot.get("stable_id")) == stable_id, "replacement crop visual keeps the same stable ID")
		_expect(str(replacement_plot.get("status_text")).contains("1/4"), "replacement visual refreshes from the restored registry record")

	var after: Dictionary = crop_controller.call("get_crop", stable_id)
	_expect(int(after.get("growth_stage", -1)) == 1, "queued-root recovery preserves the crop growth stage")
	_expect(is_equal_approx(float(after.get("growth_progress", -1.0)), 0.5), "reload catches the crop up by the elapsed sixty seconds")
	_expect(is_equal_approx(float(after.get("moisture", -1.0)), 35.0), "offline catch-up drains the expected moisture")
	_expect(int(after.get("last_updated_unix", 0)) == now + 180, "crop catch-up records the reload timestamp")
	_expect(crop_controller.call("get_crop", stable_id) == after, "repeating the same timestamp is idempotent")

	await process_frame
	_expect(old_root_ref.get_ref() == null, "old queued root is released after the replacement commits")
	_expect(old_plot_ref.get_ref() == null, "old crop visual is released with its root")
	_expect(factory_calls == 2, "recovery creates exactly one replacement crop-bearing root")

	await _finish(0, director, chunk_controller, crop_controller, crop_registry, mineral_registry)

func _find_plot(controller: Node) -> Node3D:
	var plots: Array = controller.call("get_loaded_crop_plots")
	for plot_value in plots:
		var plot: Node3D = plot_value as Node3D
		if is_instance_valid(plot) and plot.name == "CropPlot_0":
			return plot
	return null

func _make_chunk(_coordinate: Vector2i) -> Node3D:
	factory_calls += 1
	var chunk := Node3D.new()
	chunk.name = "Chunk_0_0"
	var plot := CropPlotScene.instantiate() as Node3D
	plot.name = "CropPlot_0"
	plot.set("crop_id", "wheat")
	plot.set("plot_index", 1)
	chunk.add_child(plot)
	return chunk

func _finish(code: int, director: Node, chunk_controller: Node, crop_controller: Node, crop_registry: Node, mineral_registry: Node) -> void:
	for node in [director, chunk_controller, crop_controller, crop_registry, mineral_registry]:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame
	if code == 0 and failures.is_empty():
		print("Mineral grid queued-root crop recovery regression passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

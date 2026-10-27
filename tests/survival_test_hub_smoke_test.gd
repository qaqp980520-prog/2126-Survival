extends SceneTree

const HubScene = preload("res://prototypes/SurvivalTestHub.tscn")
const SURFACE_SCENE := "res://prototypes/SurfaceChunkStreamingPlayground.tscn"
const BACKROOMS_SCENE := "res://prototypes/BackroomsPortalPlayground.tscn"
const UNDERGROUND_SCENE := "res://prototypes/UndergroundMiningPlayground.tscn"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(ResourceLoader.exists(SURFACE_SCENE), "surface prototype scene exists")
	_expect(ResourceLoader.exists(BACKROOMS_SCENE), "Backrooms prototype scene exists")
	_expect(ResourceLoader.exists(UNDERGROUND_SCENE), "underground mining prototype scene exists")
	_expect(str(ProjectSettings.get_setting("application/run/main_scene", "")) == "res://prototypes/SurvivalTestHub.tscn", "project launches into the test hub")

	var hub := HubScene.instantiate()
	root.add_child(hub)
	await process_frame
	var buttons := hub.find_children("*", "Button", true, false)
	_expect(buttons.size() == 3, "hub exposes exactly three prototype launch buttons")
	var labels: Array[String] = []
	for candidate in buttons:
		labels.append((candidate as Button).text)
	_expect(labels.has("地表探索／區塊與礦物串流"), "hub labels the surface streaming prototype")
	_expect(labels.has("後室傳送門實驗場"), "hub labels the Backrooms portal prototype")
	_expect(labels.has("地下礦坑／採礦與共用背包"), "hub labels the underground mining prototype")
	_expect(hub.find_child("StatusLabel", true, false) != null, "hub creates visible explanatory labels")

	hub.queue_free()
	await process_frame
	if failures.is_empty():
		print("Survival test hub smoke test passed.")
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

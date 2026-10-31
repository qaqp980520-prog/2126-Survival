extends SceneTree

const HubScene = preload("res://prototypes/SurvivalTestHub.tscn")
const WORLD_SCENE := "res://world/SurfaceWorld.tscn"
const SURFACE_SCENE := "res://prototypes/SurfaceChunkStreamingPlayground.tscn"
const BACKROOMS_SCENE := "res://prototypes/BackroomsPortalPlayground.tscn"
const UNDERGROUND_SCENE := "res://prototypes/UndergroundMiningPlayground.tscn"
const PINBALL_SCENE := "res://daily_games/KROLL_Orbital_Pinball/main.tscn"
const TETHER_SCENE := "res://daily_games/KROLL_Tether_Recovery/main.tscn"
const SHADOW_SCENE := "res://daily_games/KROLL_Shadow_Courier/main.tscn"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(ResourceLoader.exists(WORLD_SCENE), "playable surface world scene exists")
	_expect(ResourceLoader.exists(SURFACE_SCENE), "surface streaming prototype scene exists")
	_expect(ResourceLoader.exists(BACKROOMS_SCENE), "Backrooms prototype scene exists")
	_expect(ResourceLoader.exists(UNDERGROUND_SCENE), "underground mining prototype scene exists")
	_expect(ResourceLoader.exists(PINBALL_SCENE), "Orbital Pinball game scene exists")
	_expect(ResourceLoader.exists(TETHER_SCENE), "Tether Recovery game scene exists")
	_expect(ResourceLoader.exists(SHADOW_SCENE), "Shadow Courier game scene exists")
	_expect(str(ProjectSettings.get_setting("application/run/main_scene", "")) == WORLD_SCENE, "project launches directly into the playable surface world")

	var hub := HubScene.instantiate()
	root.add_child(hub)
	await process_frame
	var buttons := hub.find_children("*", "Button", true, false)
	_expect(buttons.size() == 7, "hub exposes the world entry and six prototype launch buttons")
	var labels: Array[String] = []
	for candidate in buttons:
		labels.append((candidate as Button).text)
	_expect(labels.has("主世界／地表生存"), "hub provides a return path to the playable surface world")
	_expect(labels.has("地表探索／區塊與礦物串流"), "hub labels the surface streaming prototype")
	_expect(labels.has("後室傳送門實驗場"), "hub labels the Backrooms portal prototype")
	_expect(labels.has("地下礦坑／採礦與共用背包"), "hub labels the underground mining prototype")
	_expect(labels.has("KROLL Orbital Pinball"), "hub labels the Orbital Pinball game")
	_expect(labels.has("KROLL Tether Recovery"), "hub labels the Tether Recovery game")
	_expect(labels.has("KROLL Shadow Courier"), "hub labels the Shadow Courier game")
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

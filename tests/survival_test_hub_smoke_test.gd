extends SceneTree

const HubScene = preload("res://prototypes/SurvivalTestHub.tscn")
const WORLD_SCENE := "res://world/SurfaceWorld.tscn"
const SURFACE_SCENE := "res://prototypes/SurfaceChunkStreamingPlayground.tscn"
const BACKROOMS_SCENE := "res://prototypes/BackroomsPortalPlayground.tscn"
const UNDERGROUND_SCENE := "res://prototypes/UndergroundMiningPlayground.tscn"
const PINBALL_SCENE := "res://daily_games/KROLL_Orbital_Pinball/main.tscn"
const TETHER_SCENE := "res://daily_games/KROLL_Tether_Recovery/main.tscn"
const SHADOW_SCENE := "res://daily_games/KROLL_Shadow_Courier/main.tscn"
const FLUX_HOCKEY_SCENE := "res://daily_games/KROLL_Flux_Hockey/main.tscn"
const STAR_CHART_SCENE := "res://daily_games/KROLL_Star_Chart/main.tscn"
const CORE_DRILL_SCENE := "res://daily_games/KROLL_Core_Drill/main.tscn"
const MOLECULE_FORGE_SCENE := "res://daily_games/KROLL_Molecule_Forge/main.tscn"
const HEX_FRONTIER_SCENE := "res://daily_games/KROLL_Hex_Frontier/main.tscn"
const THERMAL_GLIDER_SCENE := "res://daily_games/KROLL_Thermal_Glider/main.tscn"

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
	_expect(ResourceLoader.exists(FLUX_HOCKEY_SCENE), "Flux Hockey game scene exists")
	_expect(ResourceLoader.exists(STAR_CHART_SCENE), "Star Chart game scene exists")
	_expect(ResourceLoader.exists(CORE_DRILL_SCENE), "Core Drill game scene exists")
	_expect(ResourceLoader.exists(MOLECULE_FORGE_SCENE), "Molecule Forge game scene exists")
	_expect(ResourceLoader.exists(HEX_FRONTIER_SCENE), "Hex Frontier game scene exists")
	_expect(ResourceLoader.exists(THERMAL_GLIDER_SCENE), "Thermal Glider game scene exists")
	_expect(str(ProjectSettings.get_setting("application/run/main_scene", "")) == WORLD_SCENE, "project launches directly into the playable surface world")

	var hub := HubScene.instantiate()
	root.add_child(hub)
	await process_frame
	var scroll_list := hub.find_child("LaunchListScroll", true, false) as ScrollContainer
	_expect(scroll_list != null, "hub keeps the expanded launch list accessible in a vertical scroll container")
	var buttons := hub.find_children("*", "Button", true, false)
	_expect(buttons.size() == 13, "hub exposes the world entry and twelve prototype launch buttons")
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
	_expect(labels.has("KROLL Flux Hockey"), "hub labels the Flux Hockey game")
	_expect(labels.has("KROLL Star Chart"), "hub labels the Star Chart game")
	_expect(labels.has("KROLL Core Drill"), "hub labels the Core Drill game")
	_expect(labels.has("KROLL Molecule Forge"), "hub labels the Molecule Forge game")
	_expect(labels.has("KROLL Hex Frontier"), "hub labels the Hex Frontier game")
	_expect(labels.has("KROLL Thermal Glider"), "hub labels the Thermal Glider game")
	_expect(hub.find_child("StatusLabel", true, false) != null, "hub creates visible explanatory labels")

	var star_chart_scene := load(STAR_CHART_SCENE) as PackedScene
	_expect(star_chart_scene != null, "root hub can load the nested Star Chart scene script")
	if star_chart_scene != null:
		var star_chart := star_chart_scene.instantiate()
		root.add_child(star_chart)
		await process_frame
		_expect(star_chart.has_method("get_current_mission"), "root-loaded Star Chart initializes its rules module")
		var star_chart_mission: Dictionary = star_chart.call("get_current_mission")
		_expect(str(star_chart_mission.get("id", "")) == "dockside", "root-loaded Star Chart can execute its rules module")
		star_chart.queue_free()
		await process_frame

	var core_drill_scene := load(CORE_DRILL_SCENE) as PackedScene
	_expect(core_drill_scene != null, "root hub can load the nested Core Drill scene script")
	if core_drill_scene != null:
		var core_drill := core_drill_scene.instantiate()
		root.add_child(core_drill)
		await process_frame
		_expect(core_drill.has_method("get_current_mission"), "root-loaded Core Drill initializes its rules module")
		var drill_mission: Dictionary = core_drill.call("get_current_mission")
		_expect(str(drill_mission.get("id", "")) == "copper_spine", "root-loaded Core Drill can execute its rules module")
		core_drill.queue_free()
		await process_frame

	var molecule_forge_scene := load(MOLECULE_FORGE_SCENE) as PackedScene
	_expect(molecule_forge_scene != null, "root hub can load the Molecule Forge scene script")
	if molecule_forge_scene != null:
		var molecule_forge := molecule_forge_scene.instantiate()
		root.add_child(molecule_forge)
		await process_frame
		_expect(molecule_forge.has_method("get_current_level"), "root-loaded Molecule Forge initializes its rules module")
		var first_molecule: Dictionary = molecule_forge.call("get_current_level")
		_expect(str(first_molecule.get("id", "")) == "water", "root-loaded Molecule Forge can execute its water rules")
		molecule_forge.queue_free()
		await process_frame

	var hex_frontier_scene := load(HEX_FRONTIER_SCENE) as PackedScene
	_expect(hex_frontier_scene != null, "root hub can load the Hex Frontier scene")
	if hex_frontier_scene != null:
		var hex_frontier := hex_frontier_scene.instantiate()
		root.add_child(hex_frontier)
		await process_frame
		_expect(hex_frontier.has_method("get_current_state"), "root-loaded Hex Frontier initializes its rules module")
		var hex_state: Dictionary = hex_frontier.call("get_current_state")
		_expect(int(hex_state.get("tiles", {}).size()) == 19, "root-loaded Hex Frontier builds the nineteen-hex board")
		hex_frontier.queue_free()
		await process_frame

	var thermal_glider_scene := load(THERMAL_GLIDER_SCENE) as PackedScene
	_expect(thermal_glider_scene != null, "root hub can load the Thermal Glider scene")
	if thermal_glider_scene != null:
		var thermal_glider := thermal_glider_scene.instantiate()
		root.add_child(thermal_glider)
		await process_frame
		_expect(thermal_glider.has_method("get_current_state"), "root-loaded Thermal Glider initializes its flight model")
		var flight_state: Dictionary = thermal_glider.call("get_current_state")
		_expect(str(flight_state.get("status", "")) == "flying", "root-loaded Thermal Glider starts a flight")
		thermal_glider.queue_free()
		await process_frame

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

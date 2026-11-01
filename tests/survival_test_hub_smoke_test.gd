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
const GRAVITY_FOUNDRY_SCENE := "res://daily_games/KROLL_Gravity_Foundry/main.tscn"
const ECHO_MAPPER_SCENE := "res://daily_games/KROLL_Echo_Mapper/main.tscn"
const KNIGHT_CIRCUIT_SCENE := "res://daily_games/KROLL_Knight_Circuit/main.tscn"
const ATMOSPHERE_LAB_SCENE := "res://daily_games/KROLL_Atmosphere_Lab/main.tscn"
const NEON_CLIMBER_SCENE := "res://daily_games/KROLL_Neon_Climber/main.tscn"
const ROBOTIC_ARM_OPERATOR_SCENE := "res://daily_games/KROLL_Robotic_Arm_Operator/main.tscn"
const CONVEYOR_ARCHITECT_SCENE := "res://daily_games/KROLL_Conveyor_Architect/main.tscn"
const CROSSFLOW_CONTROLLER_SCENE := "res://daily_games/KROLL_Crossflow_Controller/main.tscn"
const STRATA_MAPPER_SCENE := "res://daily_games/KROLL_Strata_Mapper/main_root.tscn"
const RASTER_SURVEY_SCENE := "res://daily_games/KROLL_Raster_Survey/main_root.tscn"
const WIND_FARM_DISPATCH_SCENE := "res://daily_games/KROLL_Wind_Farm_Dispatch/main_root.tscn"
const INERTIAL_DOCKING_SCENE := "res://daily_games/KROLL_Inertial_Docking/main_root.tscn"
const MICROBE_SCOPE_SCENE := "res://daily_games/KROLL_Microbe_Scope/main_root.tscn"
const FAULTLINE_CARTOGRAPHER_SCENE := "res://daily_games/KROLL_Faultline_Cartographer/main_root.tscn"

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
	_expect(ResourceLoader.exists(GRAVITY_FOUNDRY_SCENE), "Gravity Foundry game scene exists")
	_expect(ResourceLoader.exists(ECHO_MAPPER_SCENE), "Echo Mapper game scene exists")
	_expect(ResourceLoader.exists(ATMOSPHERE_LAB_SCENE), "Atmosphere Lab game scene exists")
	_expect(ResourceLoader.exists(NEON_CLIMBER_SCENE), "Neon Climber game scene exists")
	_expect(ResourceLoader.exists(ROBOTIC_ARM_OPERATOR_SCENE), "Robotic Arm Operator game scene exists")
	_expect(ResourceLoader.exists(CONVEYOR_ARCHITECT_SCENE), "Conveyor Architect game scene exists")
	_expect(ResourceLoader.exists(CROSSFLOW_CONTROLLER_SCENE), "Crossflow Controller game scene exists")
	_expect(ResourceLoader.exists(STRATA_MAPPER_SCENE), "Strata Mapper game scene exists")
	_expect(ResourceLoader.exists(RASTER_SURVEY_SCENE), "Raster Survey game scene exists")
	_expect(ResourceLoader.exists(WIND_FARM_DISPATCH_SCENE), "Wind Farm Dispatch game scene exists")
	_expect(ResourceLoader.exists(INERTIAL_DOCKING_SCENE), "Inertial Docking game scene exists")
	_expect(ResourceLoader.exists(FAULTLINE_CARTOGRAPHER_SCENE), "Faultline Cartographer game scene exists")
	_expect(str(ProjectSettings.get_setting("application/run/main_scene", "")) == WORLD_SCENE, "project launches directly into the playable surface world")

	var hub := HubScene.instantiate()
	root.add_child(hub)
	await process_frame
	var scroll_list := hub.find_child("LaunchListScroll", true, false) as ScrollContainer
	_expect(scroll_list != null, "hub keeps the expanded launch list accessible in a vertical scroll container")
	var buttons := hub.find_children("*", "Button", true, false)
	_expect(buttons.size() == 27, "hub exposes twenty-seven world, prototype and game launch buttons")
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
	_expect(labels.has("KROLL Gravity Foundry"), "hub labels the Gravity Foundry game")
	_expect(labels.has("KROLL Echo Mapper"), "hub labels the Echo Mapper game")
	_expect(labels.has("KROLL Knight Circuit"), "hub labels the Knight Circuit game")
	_expect(labels.has("KROLL Atmosphere Lab"), "hub labels the Atmosphere Lab game")
	_expect(labels.has("KROLL Neon Climber"), "hub labels the Neon Climber game")
	_expect(labels.has("KROLL Robotic Arm Operator"), "hub labels the Robotic Arm Operator game")
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

	var gravity_foundry_scene := load(GRAVITY_FOUNDRY_SCENE) as PackedScene
	_expect(gravity_foundry_scene != null, "root hub can load the Gravity Foundry scene")
	if gravity_foundry_scene != null:
		var gravity_foundry := gravity_foundry_scene.instantiate()
		root.add_child(gravity_foundry)
		await process_frame
		_expect(gravity_foundry.has_method("get_current_state"), "root-loaded Gravity Foundry initializes its puzzle model")
		if gravity_foundry.has_method("get_current_state"):
			var gravity_state: Dictionary = gravity_foundry.call("get_current_state")
			_expect(str(gravity_state.get("level_id", "")) == "reactor_bay", "root-loaded Gravity Foundry starts the Reactor Bay sector")
		gravity_foundry.queue_free()
		await process_frame

	var echo_mapper_scene := load(ECHO_MAPPER_SCENE) as PackedScene
	_expect(echo_mapper_scene != null, "root hub can load the Echo Mapper scene")
	if echo_mapper_scene != null:
		var echo_mapper := echo_mapper_scene.instantiate()
		root.add_child(echo_mapper)
		await process_frame
		_expect(echo_mapper.has_method("get_current_state"), "root-loaded Echo Mapper initializes its sonar rules")
		if echo_mapper.has_method("get_current_state"):
			var echo_state: Dictionary = echo_mapper.call("get_current_state")
			_expect(str(echo_state.get("level_id", "")) == "dockside_echo", "root-loaded Echo Mapper starts the Dockside Echo mission")
		echo_mapper.queue_free()
		await process_frame

	var knight_circuit_scene := load(KNIGHT_CIRCUIT_SCENE) as PackedScene
	_expect(knight_circuit_scene != null, "root hub can load the Knight Circuit scene")
	if knight_circuit_scene != null:
		var knight_circuit := knight_circuit_scene.instantiate()
		root.add_child(knight_circuit)
		await process_frame
		_expect(knight_circuit.has_method("get_current_state"), "root-loaded Knight Circuit initializes its board model")
		if knight_circuit.has_method("get_current_state"):
			var knight_state: Dictionary = knight_circuit.call("get_current_state")
			_expect(str(knight_state.get("level_id", "")) == "hangar_circuit", "root-loaded Knight Circuit starts the Hangar Circuit")
		knight_circuit.queue_free()
		await process_frame

	var atmosphere_lab_scene := load(ATMOSPHERE_LAB_SCENE) as PackedScene
	_expect(atmosphere_lab_scene != null, "root hub can load the Atmosphere Lab scene")
	if atmosphere_lab_scene != null:
		var atmosphere_lab := atmosphere_lab_scene.instantiate()
		root.add_child(atmosphere_lab)
		await process_frame
		_expect(atmosphere_lab.has_method("get_current_state"), "root-loaded Atmosphere Lab initializes its station model")
		if atmosphere_lab.has_method("get_current_state"):
			var atmosphere_state: Dictionary = atmosphere_lab.call("get_current_state")
			_expect(str(atmosphere_state.get("level_id", "")) == "coastal_front", "root-loaded Atmosphere Lab starts Coastal Front")
		atmosphere_lab.queue_free()
		await process_frame
	var neon_climber_scene := load(NEON_CLIMBER_SCENE) as PackedScene
	_expect(neon_climber_scene != null, "root hub can load the Neon Climber scene")
	if neon_climber_scene != null:
		var neon_climber := neon_climber_scene.instantiate()
		root.add_child(neon_climber)
		await process_frame
		_expect(neon_climber.has_method("get_run_state"), "root-loaded Neon Climber initializes its run model")
		if neon_climber.has_method("get_run_state"):
			var climber_state: Dictionary = neon_climber.call("get_run_state")
			_expect(str(climber_state.get("level_id", "")) == "maintenance_shaft", "root-loaded Neon Climber starts Maintenance Shaft")
		neon_climber.queue_free()
		await process_frame


	var arm_scene := load(ROBOTIC_ARM_OPERATOR_SCENE) as PackedScene
	_expect(arm_scene != null, "root hub can load the Robotic Arm Operator scene")
	if arm_scene != null:
		var arm_game := arm_scene.instantiate()
		root.add_child(arm_game)
		await process_frame
		_expect(arm_game.has_method("get_current_state"), "root-loaded Robotic Arm Operator initializes its manipulator model")
		if arm_game.has_method("get_current_state"):
			var arm_state: Dictionary = arm_game.call("get_current_state")
			_expect(str(arm_state.get("status", "")) == "playing", "root-loaded Robotic Arm Operator starts its first work order")
		arm_game.queue_free()
		await process_frame

	_expect(labels.has("KROLL Conveyor Architect"), "hub labels the Conveyor Architect game")
	_expect(labels.has("KROLL Crossflow Controller"), "hub labels the Crossflow Controller game")
	_expect(labels.has("KROLL Strata Mapper"), "hub labels the Strata Mapper game")
	_expect(labels.has("KROLL Raster Survey"), "hub labels the Raster Survey game")
	_expect(labels.has("KROLL Wind Farm Dispatch"), "hub labels the Wind Farm Dispatch game")
	_expect(labels.has("KROLL Inertial Docking"), "hub labels the Inertial Docking game")
	_expect(labels.has("KROLL Microbe Scope"), "hub labels the Microbe Scope game")
	_expect(labels.has("KROLL Faultline Cartographer"), "hub labels the Faultline Cartographer game")
	var conveyor_scene := load(CONVEYOR_ARCHITECT_SCENE) as PackedScene
	_expect(conveyor_scene != null, "root hub can load the Conveyor Architect scene")
	if conveyor_scene != null:
		var conveyor_game := conveyor_scene.instantiate()
		root.add_child(conveyor_game)
		await process_frame
		_expect(conveyor_game.has_method("get_current_state"), "root-loaded Conveyor Architect initializes its routing model")
		if conveyor_game.has_method("get_current_state"):
			var conveyor_state: Dictionary = conveyor_game.call("get_current_state")
			_expect(str(conveyor_state.get("level_id", "")) == "dock_line", "root-loaded Conveyor Architect starts Dock Line")
		conveyor_game.queue_free()
		await process_frame
	var strata_mapper_scene := load(STRATA_MAPPER_SCENE) as PackedScene
	_expect(strata_mapper_scene != null, "root hub can load the Strata Mapper scene")
	if strata_mapper_scene != null:
		var strata_mapper_game := strata_mapper_scene.instantiate()
		root.add_child(strata_mapper_game)
		await process_frame
		_expect(strata_mapper_game.has_method("get_current_state"), "root-loaded Strata Mapper initializes its stratigraphy rules")
		if strata_mapper_game.has_method("get_current_state"):
			var strata_state: Dictionary = strata_mapper_game.call("get_current_state")
			_expect(str(strata_state.get("level_id", "")) == "delta_basin", "root-loaded Strata Mapper starts Delta Basin")
		strata_mapper_game.queue_free()
		await process_frame

	var crossflow_scene := load(CROSSFLOW_CONTROLLER_SCENE) as PackedScene
	_expect(crossflow_scene != null, "root hub can load the Crossflow Controller scene")
	if crossflow_scene != null:
		var crossflow_game := crossflow_scene.instantiate()
		root.add_child(crossflow_game)
		await process_frame
		_expect(crossflow_game.has_method("get_current_state"), "root-loaded Crossflow Controller initializes its traffic model")
		if crossflow_game.has_method("get_current_state"):
			var crossflow_state: Dictionary = crossflow_game.call("get_current_state")
			_expect(str(crossflow_state.get("level_id", "")) == "depot_rush", "root-loaded Crossflow Controller starts Depot Rush")
		crossflow_game.queue_free()
		await process_frame
	var raster_scene := load(RASTER_SURVEY_SCENE) as PackedScene
	_expect(raster_scene != null, "root hub can load the Raster Survey scene")
	if raster_scene != null:
		var raster_game := raster_scene.instantiate()
		root.add_child(raster_game)
		await process_frame
		_expect(raster_game.has_method("get_current_state"), "root-loaded Raster Survey initializes its puzzle rules")
		_expect(raster_game.get_cell_button_count() == 36, "root-loaded Raster Survey builds the six-by-six cell grid")
		if raster_game.has_method("get_current_state"):
			var raster_state: Dictionary = raster_game.call("get_current_state")
			_expect(int(raster_state.get("puzzle_index", -1)) == 0, "root-loaded Raster Survey starts Delta Relay")
		raster_game.queue_free()
		await process_frame

	var wind_farm_scene := load(WIND_FARM_DISPATCH_SCENE) as PackedScene
	_expect(wind_farm_scene != null, "root hub can load the Wind Farm Dispatch scene")
	if wind_farm_scene != null:
		var wind_farm_game := wind_farm_scene.instantiate()
		root.add_child(wind_farm_game)
		await process_frame
		_expect(wind_farm_game.has_method("get_current_state"), "root-loaded Wind Farm Dispatch initializes its turbine model")
		_expect(wind_farm_game.get_turbine_card_count() == 3, "root-loaded Wind Farm Dispatch builds three turbine controls")
		if wind_farm_game.has_method("get_current_state"):
			var wind_state: Dictionary = wind_farm_game.call("get_current_state")
			_expect(str(wind_state.get("status", "")) == "playing", "root-loaded Wind Farm Dispatch starts North Array")
		wind_farm_game.queue_free()
		await process_frame

	var inertial_docking_scene := load(INERTIAL_DOCKING_SCENE) as PackedScene
	_expect(inertial_docking_scene != null, "root hub can load the Inertial Docking scene")
	if inertial_docking_scene != null:
		var inertial_docking_game := inertial_docking_scene.instantiate()
		root.add_child(inertial_docking_game)
		await process_frame
		_expect(inertial_docking_game.has_method("get_current_state"), "root-loaded Inertial Docking initializes its flight model")
		_expect(inertial_docking_game.get_control_button_count() == 5, "root-loaded Inertial Docking builds five thruster controls")
		if inertial_docking_game.has_method("get_current_scenario"):
			var docking_scenario: Dictionary = inertial_docking_game.call("get_current_scenario")
			_expect(str(docking_scenario.get("id", "")) == "cargo_bay", "root-loaded Inertial Docking starts Cargo Bay")
		inertial_docking_game.queue_free()
		await process_frame

	var microbe_scene := load(MICROBE_SCOPE_SCENE) as PackedScene
	_expect(microbe_scene != null, "root hub can load the Microbe Scope scene")
	if microbe_scene != null:
		var microbe_game := microbe_scene.instantiate()
		root.add_child(microbe_game)
		await process_frame
		_expect(microbe_game.has_method("get_current_state"), "root-loaded Microbe Scope initializes its calibration model")
		_expect(microbe_game.get_title_text() == "KROLL // MICROBE SCOPE", "root-loaded Microbe Scope displays its correct title")
		_expect(microbe_game.get_parameter_control_count() == 4, "root-loaded Microbe Scope builds four calibration controls")
		_expect(microbe_game.get_action_button_count() == 3, "root-loaded Microbe Scope builds capture/reset/next controls")
		if microbe_game.has_method("get_current_state"):
			var microbe_state: Dictionary = microbe_game.call("get_current_state")
			_expect(str(microbe_state.get("specimen_id", "")) == "diatom", "root-loaded Microbe Scope starts Diatom Valve")
		microbe_game.queue_free()
		await process_frame

	var faultline_scene := load(FAULTLINE_CARTOGRAPHER_SCENE) as PackedScene
	_expect(faultline_scene != null, "root hub can load the Faultline Cartographer scene")
	if faultline_scene != null:
		var faultline_game := faultline_scene.instantiate()
		root.add_child(faultline_game)
		await process_frame
		_expect(faultline_game.has_method("get_current_state"), "root-loaded Faultline Cartographer initializes its survey model")
		_expect(faultline_game.call("get_title_text") == "KROLL // FAULTLINE CARTOGRAPHER", "root-loaded Faultline Cartographer displays its title")
		_expect(faultline_game.call("get_probe_button_count") == 3, "root-loaded Faultline Cartographer builds three seismic probe controls")
		_expect(faultline_game.call("get_grid_button_count") == 49, "root-loaded Faultline Cartographer builds a 7x7 map")
		if faultline_game.has_method("get_current_state"):
			var survey_state: Dictionary = faultline_game.call("get_current_state")
			_expect(str(survey_state.get("survey_id", "")) == "iron_vein", "root-loaded Faultline Cartographer starts the Iron Vein survey")
		faultline_game.queue_free()
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

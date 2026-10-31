extends SceneTree
const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	_expect(game != null,"BioDome Keeper scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	_expect(game.has_method("get_current_state"),"game exposes deterministic ecosystem state")
	_expect(game.has_method("get_selected_cell_index"),"game exposes selected growing plot")
	var initial: Dictionary = game.call("get_current_state")
	_expect(str(initial.get("mission_id","")) == "fern_hall","game starts at Fern Hall")
	_expect(game.find_child("GrowingGrid",true,false) != null,"thirty-plot growing grid is present")
	_expect(game.find_child("Cell_29",true,false) != null,"last growing plot is selectable")
	_expect(game.find_child("PlantFernButton",true,false) != null,"fern planting control exists")
	_expect(game.find_child("ReleasePollinatorsButton",true,false) != null,"pollinator release control exists")
	var next_button := game.find_child("NextDomeButton",true,false) as Button
	_expect(next_button != null and next_button.disabled,"next dome remains locked before restoration")
	var cell_button := game.find_child("Cell_0",true,false) as Button
	if cell_button != null: cell_button.emit_signal("pressed")
	var plant_button := game.find_child("PlantFernButton",true,false) as Button
	if plant_button != null: plant_button.emit_signal("pressed")
	var planted: Dictionary = game.call("get_current_state")
	_expect(str(planted["cells"][0]["species"]) == "fern","touch-style button plants a fern in the selected plot")
	var water_button := game.find_child("WaterButton",true,false) as Button
	if water_button != null: water_button.emit_signal("pressed")
	var watered: Dictionary = game.call("get_current_state")
	_expect(int(watered["cells"][0]["moisture"]) == 5,"water control updates selected plot moisture")
	var pollinator_button := game.find_child("ReleasePollinatorsButton",true,false) as Button
	if pollinator_button != null: pollinator_button.emit_signal("pressed")
	var pollinated: Dictionary = game.call("get_current_state")
	_expect(int(pollinated.get("pollinators",0)) == 1,"pollinator control updates the ecosystem")
	var advance_button := game.find_child("AdvanceDayButton",true,false) as Button
	if advance_button != null: advance_button.emit_signal("pressed")
	var advanced: Dictionary = game.call("get_current_state")
	_expect(int(advanced.get("day",0)) == 2,"end-day control advances the simulation")
	game.call("_reset")
	var reset_state: Dictionary = game.call("get_current_state")
	_expect(int(reset_state.get("day",0)) == 1 and int(Rules.get_stats(reset_state).get("plants",0)) == 3,"reset restores the starter ecosystem")
	var solved: Dictionary = _solve_first_mission()
	game.set("_state",solved)
	game.call("_refresh")
	if next_button != null:
		_expect(not next_button.disabled,"restoration targets unlock the next dome control")
		next_button.emit_signal("pressed")
	var next_state: Dictionary = game.call("get_current_state")
	_expect(int(next_state.get("mission_index",-1)) == 1,"next dome button loads Orchid Bay")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL BioDome Keeper runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: "+failure)
		quit(1)

func _solve_first_mission() -> Dictionary:
	var state: Dictionary = Rules.new_game(0)
	state=Rules.perform_action(state,"release_pollinators")
	state=Rules.perform_action(state,"release_pollinators")
	state=Rules.perform_action(state,"plant",0,"fern")
	while str(state.get("status","")) == "playing":
		state=Rules.advance_day(state)
	return state

func _expect(condition: bool,description: String) -> void:
	if condition:
		print("PASS: "+description)
	else:
		failures.append(description)
		push_error("FAIL: "+description)

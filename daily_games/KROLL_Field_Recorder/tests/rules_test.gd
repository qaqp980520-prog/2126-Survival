extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.get_scenario_count()==3,"three field sites exist")
	var scenario: Dictionary = Rules.get_scenario(0)
	var state: Dictionary = Rules.create_state(0)
	_expect(is_equal_approx(float(state.get("battery",0.0)),100.0),"camera starts with full battery")
	_expect((state.get("captured",[]) as Array).is_empty(),"field log starts empty")
	var moved: Dictionary = Rules.step(state,{"right":true},0.5,scenario)
	_expect(float(moved["player_position"].x)>float(state["player_position"].x),"movement changes player position")
	_expect(moved["facing"].is_equal_approx(Vector2.RIGHT),"movement sets camera facing")
	_expect(is_equal_approx(float(moved.get("stillness",-1.0)),0.0),"movement resets camera stability")
	var still: Dictionary = Rules.step(moved,{},0.4,scenario)
	_expect(float(still.get("stillness",0.0))>=Rules.STILLNESS_REQUIRED,"stationary time builds camera stability")

	var target_state: Dictionary = Rules.create_state(0)
	var target: Dictionary = target_state["creatures"][0]
	target_state["player_position"] = target["position"]-Vector2(120.0,0.0)
	target_state["facing"] = Vector2.RIGHT
	target_state["focus"] = float(target["focus"])
	target_state["stillness"] = 0.0
	var unsteady: Dictionary = Rules.capture_photo(target_state,scenario)
	_expect(str(unsteady["result"].get("reason",""))=="camera_unsteady","unstable camera rejects a photograph")
	_expect(is_equal_approx(float(unsteady["state"].get("battery",0.0)),98.0),"failed shutter attempt spends base battery cost")
	target_state["stillness"] = 0.5
	target_state["facing"] = Vector2.LEFT
	var wrong_facing: Dictionary = Rules.capture_photo(target_state,scenario)
	_expect(str(wrong_facing["result"].get("reason",""))=="wrong_facing","camera must face the target")
	target_state["facing"] = Vector2.RIGHT
	target_state["focus"] = float(target["focus"])+1.0
	var wrong_focus: Dictionary = Rules.capture_photo(target_state,scenario)
	_expect(str(wrong_focus["result"].get("reason",""))=="wrong_focus","camera focus must match specimen profile")
	target_state["focus"] = float(target["focus"])
	var captured: Dictionary = Rules.capture_photo(target_state,scenario)
	_expect(bool(captured["result"].get("ok",false)),"correct range, facing, focus and stability capture a specimen")
	_expect((captured["state"].get("captured",[]) as Array).has("MOSSBACK"),"successful photograph enters the field log")
	_expect(is_equal_approx(float(captured["state"].get("battery",0.0)),92.0),"successful photograph spends eight battery")
	_expect(float(captured["result"].get("quality",0.0))>=90.0,"close focused photograph receives high quality")

	var return_state: Dictionary = Rules.create_state(0)
	return_state["captured"] = ["MOSSBACK","GLASSWING","TIDEHOPPER"]
	return_state["player_position"] = scenario["base_position"]
	var returned: Dictionary = Rules.step(return_state,{},0.1,scenario)
	_expect(str(returned.get("status",""))=="won","returning to base after all specimens are logged wins")
	var timeout: Dictionary = Rules.step(Rules.create_state(0),{},Rules.MAX_TIME+0.1,scenario)
	_expect(str(timeout.get("status",""))=="failed","survey time limit is enforced")
	var empty_battery: Dictionary = Rules.create_state(0)
	empty_battery["battery"] = 0.0
	var no_power: Dictionary = Rules.capture_photo(empty_battery,scenario)
	_expect(str(no_power["result"].get("reason",""))=="battery_empty","empty battery prevents shutter use")
	if failures.is_empty():
		print("KROLL Field Recorder rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: "+failure)
		quit(1)

func _expect(condition: bool,message: String) -> void:
	if condition: print("PASS: "+message)
	else:
		failures.append(message)
		push_error("FAIL: "+message)

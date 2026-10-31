extends SceneTree
const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	_expect(game != null,"Robotic Arm Operator scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	_expect(game.has_method("get_current_state"),"game exposes deterministic arm and payload state")
	_expect(game.has_method("set_arm_angles_for_test"),"game exposes a controlled joint calibration hook")
	_expect(game.has_method("toggle_gripper_for_test"),"game exposes the gripper interaction hook")
	_expect(game.find_child("ShoulderMinusButton",true,false) != null,"shoulder touch control exists")
	_expect(game.find_child("ElbowPlusButton",true,false) != null,"elbow touch control exists")
	_expect(game.find_child("GripButton",true,false) != null,"gripper touch control exists")
	_expect(game.find_child("ResetCampaignButton",true,false) != null,"campaign reset control exists")
	for index in range(Rules.get_job_count()):
		var job: Dictionary = Rules.get_job(index)
		var cargo: Vector2 = job["cargo"]
		var target: Vector2 = job["target"]
		var pickup: Dictionary = Rules.solve_angles_for_target(cargo)
		game.call("set_arm_angles_for_test",float(pickup["shoulder"]),float(pickup["elbow"]))
		game.call("toggle_gripper_for_test")
		var picked: Dictionary = game.call("get_current_state")
		_expect(bool(picked.get("carrying",false)),"job %d picks up cargo when the gripper is aligned" % index)
		var delivery: Dictionary = Rules.solve_angles_for_target(target)
		game.call("set_arm_angles_for_test",float(delivery["shoulder"]),float(delivery["elbow"]))
		game.call("toggle_gripper_for_test")
		var state: Dictionary = game.call("get_current_state")
		_expect(int(state.get("delivered",0)) == index+1,"job %d increments the delivered payload count" % index)
		if index < Rules.get_job_count()-1:
			_expect(int(state.get("job_index",-1)) == index+1,"successful delivery loads the next work order")
		else:
			_expect(str(state.get("status","")) == "complete","third delivery completes the robotic cell campaign")
	var reset_button := game.find_child("ResetCampaignButton",true,false) as Button
	if reset_button != null:
		reset_button.emit_signal("pressed")
	var reset_state: Dictionary = game.call("get_current_state")
	_expect(str(reset_state.get("status","")) == "playing" and int(reset_state.get("job_index",-1)) == 0 and int(reset_state.get("delivered",0)) == 0,"campaign reset restores the first work order")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Robotic Arm Operator runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: "+failure)
		quit(1)

func _expect(condition: bool,description: String) -> void:
	if condition:
		print("PASS: "+description)
	else:
		failures.append(description)
		push_error("FAIL: "+description)

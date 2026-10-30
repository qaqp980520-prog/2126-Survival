extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.get("state") is Dictionary,"field recorder scene creates state")
	var buttons: Dictionary = game.get("touch_buttons")
	for key in ["up","left","down","right","focus_down","focus_up","capture","reset","next"]:
		_expect(buttons.has(key),"field control exists: "+key)
	var state: Dictionary = game.get("state")
	var start_position: Vector2 = state["player_position"]
	(buttons["right"] as Button).button_down.emit()
	game.call("_process",0.1)
	(buttons["right"] as Button).button_up.emit()
	state = game.get("state")
	_expect(float(state["player_position"].x)>start_position.x,"touch direction button moves the player")
	(buttons["focus_up"] as Button).pressed.emit()
	game.call("_process",0.1)
	state = game.get("state")
	_expect(float(state.get("focus",0.0))>1.0,"focus button changes camera focus")
	var target: Dictionary = state["creatures"][0]
	state["player_position"] = target["position"]-Vector2(120.0,0.0)
	state["facing"] = Vector2.RIGHT
	state["focus"] = float(target["focus"])
	state["stillness"] = 0.5
	game.set("state",state)
	(buttons["capture"] as Button).pressed.emit()
	state = game.get("state")
	_expect((state.get("captured",[]) as Array).has(str(target["species"])),"actual capture button signal records a specimen")
	(buttons["reset"] as Button).pressed.emit()
	_expect((game.get("state") as Dictionary).get("captured",[]).is_empty(),"reset button clears the field log")
	(buttons["next"] as Button).pressed.emit()
	_expect(int(game.get("scenario_index"))==1,"next button selects another field site")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Field Recorder runtime smoke test passed.")
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

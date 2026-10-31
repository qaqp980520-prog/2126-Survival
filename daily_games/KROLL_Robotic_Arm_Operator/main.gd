extends Control
const Rules = preload("res://daily_games/KROLL_Robotic_Arm_Operator/rules.gd")
var job_index: int = 0
var shoulder_angle: float = 0.0
var elbow_angle: float = 0.0
var cargo_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var carrying: bool = false
var dropped: bool = false
var status: String = "playing"
var delivered_count: int = 0
var joint_adjustments: int = 0
var feedback: String = ""
var _job_label: Label
var _brief_label: Label
var _status_label: Label
var _feedback_label: Label
var _step_buttons: Array[Button] = []
var _grip_button: Button
var _reset_button: Button

func _ready() -> void:
	_load_job(0)
	_build_ui()
	_refresh()

func _process(delta: float) -> void:
	if status != "playing":
		return
	var shoulder_delta: float = 0.0
	var elbow_delta: float = 0.0
	if Input.is_key_pressed(KEY_A):
		shoulder_delta -= 55.0*delta
	if Input.is_key_pressed(KEY_D):
		shoulder_delta += 55.0*delta
	if Input.is_key_pressed(KEY_W):
		elbow_delta -= 65.0*delta
	if Input.is_key_pressed(KEY_S):
		elbow_delta += 65.0*delta
	if not is_zero_approx(shoulder_delta) or not is_zero_approx(elbow_delta):
		_apply_joint_delta(shoulder_delta,elbow_delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_toggle_gripper()
		KEY_R:
			_restart_campaign()

func _load_job(index: int) -> void:
	job_index=clampi(index,0,Rules.get_job_count()-1)
	var job: Dictionary = Rules.get_job(job_index)
	cargo_position=job["cargo"]
	target_position=job["target"]
	carrying=false
	dropped=false
	status="playing"
	var solution: Dictionary = Rules.solve_angles_for_target(cargo_position)
	shoulder_angle=float(solution.get("shoulder",0.0))
	elbow_angle=float(solution.get("elbow",0.0))
	queue_redraw()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",18)
	margin.add_theme_constant_override("margin_right",18)
	margin.add_theme_constant_override("margin_top",14)
	margin.add_theme_constant_override("margin_bottom",14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",7)
	margin.add_child(column)
	var title := Label.new()
	title.text="KROLL // ROBOTIC ARM OPERATOR"
	title.add_theme_font_size_override("font_size",29)
	title.add_theme_color_override("font_color",Color("#9ce8f1"))
	column.add_child(title)
	_job_label=Label.new()
	_job_label.add_theme_font_size_override("font_size",21)
	_job_label.add_theme_color_override("font_color",Color("#f2e4b5"))
	column.add_child(_job_label)
	_brief_label=Label.new()
	_brief_label.custom_minimum_size=Vector2(0.0,34.0)
	_brief_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_brief_label.add_theme_color_override("font_color",Color("#a7c9d1"))
	column.add_child(_brief_label)
	_status_label=Label.new()
	_status_label.add_theme_color_override("font_color",Color("#b8e8c8"))
	column.add_child(_status_label)
	var spacer := Control.new()
	spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var controls_title := Label.new()
	controls_title.text="JOINT CALIBRATION  //  A/D SHOULDER · W/S ELBOW · SPACE GRIP/RELEASE"
	controls_title.add_theme_color_override("font_color",Color("#9ce8f1"))
	column.add_child(controls_title)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",7)
	column.add_child(controls)
	_add_step_button(controls,"ShoulderMinusButton","SHOULDER −5°","shoulder",-Rules.JOINT_STEP)
	_add_step_button(controls,"ShoulderPlusButton","SHOULDER +5°","shoulder",Rules.JOINT_STEP)
	_add_step_button(controls,"ElbowMinusButton","ELBOW −5°","elbow",-Rules.JOINT_STEP)
	_add_step_button(controls,"ElbowPlusButton","ELBOW +5°","elbow",Rules.JOINT_STEP)
	_grip_button=Button.new()
	_grip_button.name="GripButton"
	_grip_button.text="CLOSE GRIP / PICK"
	_grip_button.custom_minimum_size=Vector2(150.0,46.0)
	_grip_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_grip_button.pressed.connect(_toggle_gripper)
	controls.add_child(_grip_button)
	_reset_button=Button.new()
	_reset_button.name="ResetCampaignButton"
	_reset_button.text="RESET CAMPAIGN"
	_reset_button.custom_minimum_size=Vector2(145.0,46.0)
	_reset_button.pressed.connect(_restart_campaign)
	controls.add_child(_reset_button)
	_feedback_label=Label.new()
	_feedback_label.custom_minimum_size=Vector2(0.0,34.0)
	_feedback_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_color_override("font_color",Color("#f2d18c"))
	column.add_child(_feedback_label)
	var footer := Label.new()
	footer.text="Align the gripper with the orange payload, close it, then move the arm to the green dock and release. Releasing outside the dock drops the payload. Mouse/touch step buttons are available."
	footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_color_override("font_color",Color("#8baeb8"))
	column.add_child(footer)

func _add_step_button(parent: HBoxContainer,button_name: String,label_text: String,joint: String,amount: float) -> void:
	var button := Button.new()
	button.name=button_name
	button.text=label_text
	button.custom_minimum_size=Vector2(132.0,46.0)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.focus_mode=Control.FOCUS_NONE
	button.pressed.connect(_step_joint.bind(joint,amount))
	parent.add_child(button)
	_step_buttons.append(button)

func _step_joint(joint: String,amount: float) -> void:
	if status != "playing":
		return
	if joint == "shoulder":
		_apply_joint_delta(amount,0.0)
	else:
		_apply_joint_delta(0.0,amount)

func _apply_joint_delta(shoulder_delta: float,elbow_delta: float) -> void:
	var angles: Dictionary = Rules.clamp_angles(shoulder_angle+shoulder_delta,elbow_angle+elbow_delta)
	shoulder_angle=float(angles["shoulder"])
	elbow_angle=float(angles["elbow"])
	joint_adjustments+=1
	feedback="Joint position updated. Current end-effector coordinates are shown in the status line."
	_refresh()

func _toggle_gripper() -> void:
	if status != "playing":
		return
	var points: Dictionary = Rules.forward_kinematics(shoulder_angle,elbow_angle)
	var end_point: Vector2 = points["end"]
	if not carrying:
		if Rules.is_within_radius(end_point,cargo_position,Rules.PICKUP_RADIUS):
			carrying=true
			feedback="PAYLOAD SECURED. Move the arm to the receiving dock."
		else:
			feedback="GRIP MISSED. Align the end effector with the orange payload first."
	else:
		if Rules.is_within_radius(end_point,target_position,Rules.DELIVERY_RADIUS):
			delivered_count+=1
			if job_index >= Rules.get_job_count()-1:
				carrying=false
				status="complete"
				feedback="ALL THREE PAYLOADS DELIVERED. ROBOTIC CELL CALIBRATION ACCEPTED."
			else:
				job_index+=1
				_load_job(job_index)
				feedback="PAYLOAD DELIVERED. Next work order loaded."
		else:
			carrying=false
			dropped=true
			cargo_position=end_point
			status="failed"
			feedback="PAYLOAD DROPPED OUTSIDE THE RECEIVING DOCK. Reset the campaign to retry."
	_refresh()

func _restart_campaign() -> void:
	job_index=0
	delivered_count=0
	joint_adjustments=0
	_load_job(0)
	feedback="Campaign reset. Align the gripper with the first payload."
	_refresh()

func get_current_state() -> Dictionary:
	var points: Dictionary = Rules.forward_kinematics(shoulder_angle,elbow_angle)
	return {
		"job_index":job_index,"shoulder":shoulder_angle,"elbow":elbow_angle,
		"end_effector":points["end"],"cargo_position":cargo_position,"target_position":target_position,
		"carrying":carrying,"dropped":dropped,"status":status,
		"delivered":delivered_count,"joint_adjustments":joint_adjustments
	}

func set_arm_angles_for_test(shoulder: float,elbow: float) -> void:
	var angles: Dictionary = Rules.clamp_angles(shoulder,elbow)
	shoulder_angle=float(angles["shoulder"])
	elbow_angle=float(angles["elbow"])
	queue_redraw()
	_refresh()

func toggle_gripper_for_test() -> void:
	_toggle_gripper()

func _refresh() -> void:
	var job: Dictionary = Rules.get_job(job_index)
	_job_label.text="WORK ORDER %d/%d  //  %s" % [job_index+1,Rules.get_job_count(),str(job.get("name","PAYLOAD"))]
	_brief_label.text=str(job.get("brief",""))
	var points: Dictionary = Rules.forward_kinematics(shoulder_angle,elbow_angle)
	var end_point: Vector2 = points["end"]
	_status_label.text="DELIVERED %d/%d   SHOULDER %+.1f°   ELBOW %+.1f°   GRIP %s   END (%.0f, %.0f)" % [
		delivered_count,Rules.get_job_count(),shoulder_angle,elbow_angle,"CLOSED" if carrying else "OPEN",end_point.x,end_point.y
	]
	_feedback_label.text=feedback
	_grip_button.text="OPEN GRIP / DELIVER" if carrying else "CLOSE GRIP / PICK"
	var can_move: bool = status == "playing"
	for button in _step_buttons:
		button.disabled=not can_move
	_grip_button.disabled=not can_move
	_reset_button.disabled=false
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(960.0,720.0)),Color("#081722"),true)
	for x in range(20,960,40):
		draw_line(Vector2(x,140),Vector2(x,570),Color(0.12,0.24,0.30,0.42),1.0)
	for y in range(150,570,40):
		draw_line(Vector2(20,y),Vector2(940,y),Color(0.12,0.24,0.30,0.42),1.0)
	draw_line(Vector2(30,560),Vector2(930,560),Color("#537c86"),3.0)
	var points: Dictionary = Rules.forward_kinematics(shoulder_angle,elbow_angle)
	var elbow_point: Vector2 = points["elbow"]
	var end_point: Vector2 = points["end"]
	draw_circle(target_position,Rules.DELIVERY_RADIUS,Color(0.15,0.78,0.48,0.12))
	draw_arc(target_position,Rules.DELIVERY_RADIUS,0.0,TAU,48,Color("#4ce3a0"),3.0,true)
	draw_circle(target_position,5.0,Color("#4ce3a0"))
	if not carrying and not dropped:
		_draw_payload(cargo_position,Color("#f0a34d"))
	elif carrying:
		_draw_payload(end_point,Color("#f0a34d"))
	elif dropped:
		_draw_payload(cargo_position,Color("#d96b58"))
	draw_line(Rules.BASE,elbow_point,Color("#b5dce8"),13.0,true)
	draw_line(elbow_point,end_point,Color("#77c7d7"),10.0,true)
	draw_circle(Rules.BASE,17.0,Color("#d5e8ef"))
	draw_circle(elbow_point,12.0,Color("#f2d18c"))
	draw_circle(end_point,8.0,Color("#f4f7ed"))
	var direction: Vector2 = (end_point-elbow_point).normalized()
	var perpendicular := Vector2(-direction.y,direction.x)
	var finger_length: float = 22.0
	var spread: float = 7.0 if not carrying else 3.0
	draw_line(end_point,end_point+direction*finger_length+perpendicular*spread,Color("#f4f7ed"),4.0,true)
	draw_line(end_point,end_point+direction*finger_length-perpendicular*spread,Color("#f4f7ed"),4.0,true)
	draw_circle(Rules.BASE,4.0,Color("#19343f"))

func _draw_payload(position: Vector2,color: Color) -> void:
	var rect := Rect2(position-Vector2(12.0,12.0),Vector2(24.0,24.0))
	draw_rect(rect,color,true)
	draw_rect(rect,Color("#fff0d1"),2.0,false)
	draw_line(position+Vector2(-7.0,-5.0),position+Vector2(7.0,5.0),Color("#6c4930"),2.0)

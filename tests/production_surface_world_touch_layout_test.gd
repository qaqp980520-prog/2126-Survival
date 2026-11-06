extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const EXPECTED_BUTTON_KEYS: Array[String] = [
	"left", "forward", "back",
	"right", "jump", "crop",
	"terrain", "crate", "shaft",
	"deeper", "sprint", "quick_1",
	"quick_2", "quick_3", "quick_4"
]

var _failures: Array[String] = []
var _world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_world = WorldScene.instantiate() as Node3D
	_expect(_world != null, "production SurfaceWorld instantiates for touch-control layout coverage")
	if _world == null:
		_finish(1)
		return
	root.add_child(_world)
	await process_frame
	await process_frame

	var viewport_rect: Rect2 = root.get_visible_rect()
	var panel := _world.get_node_or_null("HUD/TouchControls") as PanelContainer
	var prompt := _world.get_node_or_null("HUD/InteractionPrompt") as Label
	var buttons: Dictionary = _world.get("touch_buttons")
	_expect(panel != null and panel.is_visible_in_tree(), "touch-control panel is visible in the production HUD")
	_expect(prompt != null and prompt.is_visible_in_tree(), "interaction prompt is visible in the production HUD")
	_expect(buttons.size() == EXPECTED_BUTTON_KEYS.size(), "production HUD exposes all fifteen touch controls")
	if panel == null or prompt == null:
		_finish(1)
		return

	var panel_rect: Rect2 = panel.get_global_rect()
	var prompt_rect: Rect2 = prompt.get_global_rect()
	_expect(_rect_is_inside(viewport_rect, panel_rect), "touch-control panel remains inside the active viewport")
	_expect(_rect_is_inside(viewport_rect, prompt_rect), "interaction prompt remains inside the active viewport")
	_expect(not panel_rect.intersects(prompt_rect), "touch-control panel does not overlap the interaction prompt")

	var button_rects: Array[Rect2] = []
	for key in EXPECTED_BUTTON_KEYS:
		var button: Button = buttons.get(key) as Button
		_expect(button != null, "touch control exists: %s" % key)
		if button == null:
			continue
		var button_rect: Rect2 = button.get_global_rect()
		_expect(button.is_visible_in_tree(), "touch control is visible: %s" % key)
		_expect(button_rect.size.x > 0.0 and button_rect.size.y > 0.0, "touch control has a non-zero layout: %s" % key)
		_expect(_rect_is_inside(viewport_rect, button_rect), "touch control stays inside viewport: %s" % key)
		_expect(_rect_is_inside(panel_rect, button_rect), "touch control stays inside its panel: %s" % key)
		_expect(not prompt_rect.intersects(button_rect), "touch control does not overlap interaction prompt: %s" % key)
		for previous_rect in button_rects:
			_expect(not previous_rect.intersects(button_rect), "touch controls do not overlap each other: %s" % key)
		button_rects.append(button_rect)

	_finish(0 if _failures.is_empty() else 1)

func _rect_is_inside(bounds: Rect2, candidate: Rect2) -> bool:
	const EPSILON: float = 0.5
	return (
		candidate.position.x >= bounds.position.x - EPSILON
		and candidate.position.y >= bounds.position.y - EPSILON
		and candidate.end.x <= bounds.end.x + EPSILON
		and candidate.end.y <= bounds.end.y + EPSILON
	)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)

func _finish(exit_code: int) -> void:
	if is_instance_valid(_world):
		_world.queue_free()
	await process_frame
	if exit_code == 0 and _failures.is_empty():
		print("Production SurfaceWorld touch-control layout tests passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAILED: " + failure)
		quit(1)

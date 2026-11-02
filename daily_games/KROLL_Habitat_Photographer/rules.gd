extends RefCounted

const STAGES: Array[Dictionary] = [
	{"id":"reed_marsh","name":"REED MARSH","habitat":"WETLAND","species":"Silver Marsh Heron","speed":0.4,"focus":3,"zoom":2,"exposure":0,"cover_start":0.42,"cover_end":0.64},
	{"id":"canopy_edge","name":"CANOPY EDGE","habitat":"RAINFOREST","species":"Copperwing Glider","speed":0.55,"focus":4,"zoom":3,"exposure":1,"cover_start":0.50,"cover_end":0.72},
	{"id":"dune_shelf","name":"DUNE SHELF","habitat":"DESERT","species":"Glassback Runner","speed":0.7,"focus":2,"zoom":1,"exposure":-1,"cover_start":0.15,"cover_end":0.35}
]

func get_stage_count() -> int:
	return STAGES.size()

func get_stage(stage_index: int) -> Dictionary:
	if stage_index < 0 or stage_index >= STAGES.size():
		return {}
	return STAGES[stage_index].duplicate(true)

func get_center_capture_time(stage_index: int) -> float:
	var stage: Dictionary = get_stage(stage_index)
	if stage.is_empty():
		return -1.0
	var speed: float = float(stage.get("speed", 0.0))
	return 0.5 / speed if speed > 0.0 else -1.0

func get_animal_position(stage_index: int, elapsed: float) -> float:
	var stage: Dictionary = get_stage(stage_index)
	if stage.is_empty() or is_nan(elapsed) or is_inf(elapsed):
		return -1.0
	var speed: float = float(stage.get("speed", 0.0))
	if speed <= 0.0:
		return -1.0
	var phase: float = fposmod(maxf(0.0, elapsed) * speed, 2.0)
	var progress: float = phase if phase <= 1.0 else 2.0 - phase
	return lerpf(0.08, 0.92, progress)

func is_obscured(stage_index: int, elapsed: float) -> bool:
	var stage: Dictionary = get_stage(stage_index)
	if stage.is_empty() or is_nan(elapsed) or is_inf(elapsed):
		return true
	var phase: float = fposmod(maxf(0.0, elapsed), 3.0)
	return phase >= float(stage.get("cover_start", 0.0)) and phase <= float(stage.get("cover_end", 0.0))

func evaluate_capture(stage_index: int, elapsed: float, focus: int, zoom: int, exposure: int) -> Dictionary:
	var stage: Dictionary = get_stage(stage_index)
	if stage.is_empty():
		return {"passed":false,"reason":"invalid_stage","score":0}
	if is_nan(elapsed) or is_inf(elapsed) or elapsed < 0.0:
		return {"passed":false,"reason":"invalid_time","score":0}
	if focus < 1 or focus > 5 or zoom < 1 or zoom > 3 or exposure < -1 or exposure > 1:
		return {"passed":false,"reason":"invalid_camera_settings","score":0}
	if is_obscured(stage_index, elapsed):
		return {"passed":false,"reason":"subject_obscured","score":0}
	var animal_x: float = get_animal_position(stage_index, elapsed)
	if absf(animal_x - 0.5) > 0.085:
		return {"passed":false,"reason":"subject_not_centered","score":0,"animal_x":animal_x}
	if focus != int(stage["focus"]):
		return {"passed":false,"reason":"focus_mismatch","score":0,"animal_x":animal_x}
	if zoom != int(stage["zoom"]):
		return {"passed":false,"reason":"zoom_mismatch","score":0,"animal_x":animal_x}
	if exposure != int(stage["exposure"]):
		return {"passed":false,"reason":"exposure_mismatch","score":0,"animal_x":animal_x}
	return {"passed":true,"reason":"photo_locked","score":100,"animal_x":animal_x,"species":str(stage["species"])}

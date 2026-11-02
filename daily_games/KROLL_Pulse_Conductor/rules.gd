extends RefCounted
class_name KROLLPulseConductorRules
const LANE_COUNT: int = 4
const START_OFFSET: float = 1.5
const PERFECT_WINDOW: float = 0.045
const GREAT_WINDOW: float = 0.09
const GOOD_WINDOW: float = 0.14
const WINDOW_EPSILON: float = 0.000001
const DEFAULT_PASS_SCORE: int = 800
const CHARTS: Array[Dictionary] = [
	{"id":"boot_sequence","title":"BOOT SEQUENCE","bpm":96,"pass_score":800,"pattern":[0,1,2,3,1,0,2,3,0,2,1,3,2,0,3,1]},
	{"id":"phase_shift","title":"PHASE SHIFT","bpm":112,"pass_score":800,"pattern":[0,2,1,3,2,0,3,1,1,3,0,2,3,1,2,0]},
	{"id":"reactor_heartbeat","title":"REACTOR HEARTBEAT","bpm":128,"pass_score":800,"pattern":[0,1,3,2,0,3,1,2,3,0,2,1,1,2,0,3]}
]
func get_chart_count() -> int:
	return CHARTS.size()
func get_chart_definition(chart_index: int) -> Dictionary:
	if chart_index < 0 or chart_index >= CHARTS.size():
		return {}
	return CHARTS[chart_index].duplicate(true)
func create_state(chart_index: int, campaign_score: int = 0, completed_charts: Array = []) -> Dictionary:
	var definition: Dictionary = get_chart_definition(chart_index)
	if definition.is_empty() or campaign_score < 0:
		return {}
	var pattern: Array = definition.get("pattern", [])
	var bpm: int = int(definition.get("bpm", 0))
	if bpm <= 0 or pattern.is_empty():
		return {}
	var notes: Array[Dictionary] = []
	for note_index in range(pattern.size()):
		var lane: int = int(pattern[note_index])
		if lane < 0 or lane >= LANE_COUNT:
			return {}
		notes.append({"lane":lane,"time":START_OFFSET + float(note_index) * (60.0 / float(bpm)),"judged":false,"judgement":"pending","points":0})
	var normalized_completed: Array[int] = []
	for completed_value in completed_charts:
		if completed_value is int:
			var completed_index: int = int(completed_value)
			if completed_index >= 0 and completed_index < CHARTS.size() and not normalized_completed.has(completed_index):
				normalized_completed.append(completed_index)
	return {"chart_index":chart_index,"chart_id":str(definition["id"]),"status":"playing","campaign_score":campaign_score,"score":0,"combo":0,"max_combo":0,"perfect_count":0,"great_count":0,"good_count":0,"miss_count":0,"judged_count":0,"completed_charts":normalized_completed,"notes":notes}
func judge_timing(delta_seconds: float) -> Dictionary:
	if is_nan(delta_seconds) or is_inf(delta_seconds):
		return {"judgement":"invalid","points":0}
	var magnitude: float = absf(delta_seconds)
	if magnitude <= PERFECT_WINDOW + WINDOW_EPSILON:
		return {"judgement":"perfect","points":100}
	if magnitude <= GREAT_WINDOW + WINDOW_EPSILON:
		return {"judgement":"great","points":75}
	if magnitude <= GOOD_WINDOW + WINDOW_EPSILON:
		return {"judgement":"good","points":50}
	return {"judgement":"miss","points":0}
func find_note_index(state: Dictionary, lane: int, song_time: float) -> int:
	if lane < 0 or lane >= LANE_COUNT or is_nan(song_time) or is_inf(song_time):
		return -1
	var notes: Array = state.get("notes", [])
	var best_index: int = -1
	var best_delta: float = GOOD_WINDOW + 1.0
	for note_index in range(notes.size()):
		var note_value: Variant = notes[note_index]
		if not (note_value is Dictionary):
			continue
		var note: Dictionary = note_value
		if bool(note.get("judged", false)) or int(note.get("lane", -1)) != lane:
			continue
		var magnitude: float = absf(song_time - float(note.get("time", -1000000.0)))
		if magnitude > GOOD_WINDOW + WINDOW_EPSILON:
			continue
		if magnitude < best_delta - WINDOW_EPSILON:
			best_delta = magnitude
			best_index = note_index
		elif absf(magnitude - best_delta) <= WINDOW_EPSILON and (best_index < 0 or note_index < best_index):
			best_index = note_index
	return best_index
func hit_note(state: Dictionary, note_index: int, signed_delta: float) -> Dictionary:
	var notes: Array = state.get("notes", [])
	if note_index < 0 or note_index >= notes.size():
		return {"ok":false,"reason":"invalid_note_index"}
	var note_value: Variant = notes[note_index]
	if not (note_value is Dictionary):
		return {"ok":false,"reason":"invalid_note"}
	var note: Dictionary = note_value
	if bool(note.get("judged", false)):
		return {"ok":false,"reason":"already_judged"}
	var result: Dictionary = judge_timing(signed_delta)
	var judgement: String = str(result.get("judgement", "invalid"))
	if judgement == "miss" or judgement == "invalid":
		return {"ok":false,"reason":"outside_window"}
	var next_state: Dictionary = state.duplicate(true)
	var next_notes: Array = next_state.get("notes", [])
	note = next_notes[note_index]
	var points: int = int(result.get("points", 0))
	note["judged"] = true
	note["judgement"] = judgement
	note["points"] = points
	next_notes[note_index] = note
	next_state["notes"] = next_notes
	next_state["score"] = int(next_state.get("score", 0)) + points
	next_state["combo"] = int(next_state.get("combo", 0)) + 1
	next_state["max_combo"] = maxi(int(next_state.get("max_combo", 0)), int(next_state["combo"]))
	next_state["judged_count"] = int(next_state.get("judged_count", 0)) + 1
	match judgement:
		"perfect":
			next_state["perfect_count"] = int(next_state.get("perfect_count", 0)) + 1
		"great":
			next_state["great_count"] = int(next_state.get("great_count", 0)) + 1
		"good":
			next_state["good_count"] = int(next_state.get("good_count", 0)) + 1
	_update_terminal_status(next_state)
	return {"ok":true,"state":next_state,"judgement":judgement,"points":points}
func resolve_misses(state: Dictionary, song_time: float) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	if is_nan(song_time) or is_inf(song_time) or str(next_state.get("status", "")) != "playing":
		return next_state
	var notes: Array = next_state.get("notes", [])
	for note_index in range(notes.size()):
		var note_value: Variant = notes[note_index]
		if not (note_value is Dictionary):
			continue
		var note: Dictionary = note_value
		if bool(note.get("judged", false)):
			continue
		if song_time <= float(note.get("time", 0.0)) + GOOD_WINDOW + WINDOW_EPSILON:
			continue
		note["judged"] = true
		note["judgement"] = "miss"
		note["points"] = 0
		notes[note_index] = note
		next_state["miss_count"] = int(next_state.get("miss_count", 0)) + 1
		next_state["judged_count"] = int(next_state.get("judged_count", 0)) + 1
		next_state["combo"] = 0
	next_state["notes"] = notes
	_update_terminal_status(next_state)
	return next_state
func advance_chart(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "passed":
		return {"ok":false,"reason":"chart_not_passed"}
	var chart_index: int = int(state.get("chart_index", -1))
	if chart_index < 0 or chart_index >= CHARTS.size():
		return {"ok":false,"reason":"invalid_chart_index"}
	var completed: Array = state.get("completed_charts", []).duplicate()
	if not completed.has(chart_index):
		completed.append(chart_index)
	var campaign_score: int = int(state.get("campaign_score", 0)) + int(state.get("score", 0))
	if chart_index + 1 >= CHARTS.size():
		return {"ok":true,"state":{"chart_index":chart_index,"chart_id":"campaign","status":"campaign_complete","campaign_score":campaign_score,"total_score":campaign_score,"score":int(state.get("score", 0)),"completed_charts":completed,"notes":[],"combo":0,"max_combo":int(state.get("max_combo", 0))}}
	return {"ok":true,"state":create_state(chart_index + 1, campaign_score, completed)}
func restart_chart(state: Dictionary) -> Dictionary:
	var status: String = str(state.get("status", ""))
	if status == "passed" or status == "campaign_complete":
		return {"ok":false,"reason":"completed_chart_locked"}
	var restarted: Dictionary = create_state(int(state.get("chart_index", -1)),int(state.get("campaign_score", 0)),state.get("completed_charts", []))
	return {"ok":not restarted.is_empty(),"state":restarted}
func restart_campaign() -> Dictionary:
	return create_state(0)
func get_accuracy(state: Dictionary) -> float:
	var notes: Array = state.get("notes", [])
	var maximum: float = float(notes.size()) * 100.0
	if maximum <= 0.0:
		return 0.0
	return clampf(float(state.get("score", 0)) / maximum * 100.0, 0.0, 100.0)
func _update_terminal_status(state: Dictionary) -> void:
	if str(state.get("status", "")) != "playing":
		return
	var notes: Array = state.get("notes", [])
	if int(state.get("judged_count", 0)) < notes.size():
		return
	var definition: Dictionary = get_chart_definition(int(state.get("chart_index", -1)))
	var pass_score: int = int(definition.get("pass_score", DEFAULT_PASS_SCORE))
	state["status"] = "passed" if int(state.get("score", 0)) >= pass_score else "failed"

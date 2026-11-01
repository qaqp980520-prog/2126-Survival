extends RefCounted

const MOVE_BUDGET: int = 18
const MARKER_ID: String = "ash_marker"

const SITES: Array[Dictionary] = [
	{
		"id": "delta_basin",
		"name": "Delta Basin",
		"marker_index": 2,
		"cores": [
			{"name": "CORE A", "initial": ["ash_marker", "basalt", "sandstone", "shale"], "target": ["basalt", "shale", "ash_marker", "sandstone"]},
			{"name": "CORE B", "initial": ["mudstone", "conglomerate", "siltstone", "ash_marker"], "target": ["conglomerate", "siltstone", "ash_marker", "mudstone"]},
			{"name": "CORE C", "initial": ["limestone", "ash_marker", "granite", "clay"], "target": ["granite", "clay", "ash_marker", "limestone"]}
		]
	},
	{
		"id": "ridge_cut",
		"name": "Ridge Cut",
		"marker_index": 2,
		"cores": [
			{"name": "CORE A", "initial": ["quartzite", "gneiss", "ash_marker", "slate"], "target": ["gneiss", "slate", "ash_marker", "quartzite"]},
			{"name": "CORE B", "initial": ["coal", "sandstone", "schist", "ash_marker"], "target": ["schist", "coal", "ash_marker", "sandstone"]},
			{"name": "CORE C", "initial": ["ash_marker", "limestone", "shale", "basalt"], "target": ["basalt", "shale", "ash_marker", "limestone"]}
		]
	},
	{
		"id": "crater_shelf",
		"name": "Crater Shelf",
		"marker_index": 2,
		"cores": [
			{"name": "CORE A", "initial": ["breccia", "alluvium", "granite", "ash_marker"], "target": ["granite", "breccia", "ash_marker", "alluvium"]},
			{"name": "CORE B", "initial": ["tuff", "claystone", "ash_marker", "gneiss"], "target": ["gneiss", "claystone", "ash_marker", "tuff"]},
			{"name": "CORE C", "initial": ["sandstone", "ash_marker", "basalt", "coal"], "target": ["basalt", "coal", "ash_marker", "sandstone"]}
		]
	}
]

const LAYER_LABELS: Dictionary = {
	"ash_marker": "VOLCANIC ASH",
	"basalt": "BASALT",
	"shale": "SHALE",
	"sandstone": "SANDSTONE",
	"mudstone": "MUDSTONE",
	"conglomerate": "CONGLOMERATE",
	"siltstone": "SILTSTONE",
	"limestone": "LIMESTONE",
	"granite": "GRANITE",
	"clay": "CLAY",
	"gneiss": "GNEISS",
	"slate": "SLATE",
	"quartzite": "QUARTZITE",
	"schist": "SCHIST",
	"coal": "COAL",
	"breccia": "BRECCIA",
	"alluvium": "ALLUVIUM",
	"tuff": "TUFF",
	"claystone": "CLAYSTONE"
}

const LAYER_COLORS: Dictionary = {
	"ash_marker": "#d69b43",
	"basalt": "#52616c",
	"shale": "#526c80",
	"sandstone": "#b77b4b",
	"mudstone": "#806b58",
	"conglomerate": "#8b7764",
	"siltstone": "#a18b70",
	"limestone": "#b6b49b",
	"granite": "#8c6f72",
	"clay": "#9d765f",
	"gneiss": "#647b82",
	"slate": "#536477",
	"quartzite": "#b3c2c6",
	"schist": "#64705f",
	"coal": "#3e4850",
	"breccia": "#92745b",
	"alluvium": "#b9a47c",
	"tuff": "#8b8a79",
	"claystone": "#8f7468"
}

func get_site_count() -> int:
	return SITES.size()

func get_site_data(site_index: int) -> Dictionary:
	if site_index < 0 or site_index >= SITES.size():
		return {}
	return SITES[site_index].duplicate(true)

func make_state(site_index: int = 0) -> Dictionary:
	var site: Dictionary = get_site_data(site_index)
	if site.is_empty():
		return {}
	var cores: Array = []
	for core_value in site.get("cores", []):
		var core: Dictionary = core_value
		var initial_samples: Array = core.get("initial", [])
		var target_samples: Array = core.get("target", [])
		cores.append({
			"name": str(core.get("name", "CORE")),
			"samples": initial_samples.duplicate(),
			"target": target_samples.duplicate()
		})
	return {
		"site_index": site_index,
		"level_index": site_index,
		"level_id": str(site.get("id", "")),
		"site_name": str(site.get("name", "")),
		"marker_index": int(site.get("marker_index", 2)),
		"cores": cores,
		"moves_left": MOVE_BUDGET,
		"moves_used": 0,
		"status": "playing",
		"selected_core": 0,
		"selected_sample": 0
	}

func select_core(state: Dictionary, core_index: int) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "not_playing", "state": state.duplicate(true)}
	var cores: Array = state.get("cores", [])
	if core_index < 0 or core_index >= cores.size():
		return {"ok": false, "reason": "invalid_core", "state": state.duplicate(true)}
	var next: Dictionary = state.duplicate(true)
	next["selected_core"] = core_index
	return {"ok": true, "reason": "", "state": next}

func select_sample(state: Dictionary, core_index: int, sample_index: int) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "not_playing", "state": state.duplicate(true)}
	var cores: Array = state.get("cores", [])
	if core_index < 0 or core_index >= cores.size():
		return {"ok": false, "reason": "invalid_core", "state": state.duplicate(true)}
	var samples: Array = cores[core_index].get("samples", [])
	if sample_index < 0 or sample_index >= samples.size():
		return {"ok": false, "reason": "invalid_sample", "state": state.duplicate(true)}
	var next: Dictionary = state.duplicate(true)
	next["selected_core"] = core_index
	next["selected_sample"] = sample_index
	return {"ok": true, "reason": "", "state": next}

func move_selected(state: Dictionary, direction: int) -> Dictionary:
	return move_sample(state, int(state.get("selected_core", -1)), int(state.get("selected_sample", -1)), direction)

func move_sample(state: Dictionary, core_index: int, sample_index: int, direction: int) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "not_playing", "state": state.duplicate(true)}
	if direction != -1 and direction != 1:
		return {"ok": false, "reason": "invalid_direction", "state": state.duplicate(true)}
	var cores: Array = state.get("cores", [])
	if core_index < 0 or core_index >= cores.size():
		return {"ok": false, "reason": "invalid_core", "state": state.duplicate(true)}
	var samples: Array = cores[core_index].get("samples", [])
	var target_index: int = sample_index + direction
	if sample_index < 0 or sample_index >= samples.size() or target_index < 0 or target_index >= samples.size():
		return {"ok": false, "reason": "out_of_bounds", "state": state.duplicate(true)}
	if int(state.get("moves_left", 0)) <= 0:
		return {"ok": false, "reason": "move_budget_exhausted", "state": state.duplicate(true)}
	var next: Dictionary = state.duplicate(true)
	var next_cores: Array = next.get("cores", [])
	var next_core: Dictionary = next_cores[core_index]
	var next_samples: Array = next_core.get("samples", [])
	var displaced: Variant = next_samples[sample_index]
	next_samples[sample_index] = next_samples[target_index]
	next_samples[target_index] = displaced
	next_core["samples"] = next_samples
	next_cores[core_index] = next_core
	next["cores"] = next_cores
	next["moves_left"] = int(next.get("moves_left", 0)) - 1
	next["moves_used"] = int(next.get("moves_used", 0)) + 1
	next["selected_core"] = core_index
	next["selected_sample"] = target_index
	if is_solved(next):
		next["status"] = "won"
	elif int(next["moves_left"]) <= 0:
		next["status"] = "failed"
	return {"ok": true, "reason": str(next.get("status", "moved")), "state": next}

func is_solved(state: Dictionary) -> bool:
	var site: Dictionary = get_site_data(int(state.get("site_index", -1)))
	if site.is_empty():
		return false
	var target_cores: Array = site.get("cores", [])
	var cores: Array = state.get("cores", [])
	if cores.size() != target_cores.size() or cores.is_empty():
		return false
	var marker_index: int = int(site.get("marker_index", -1))
	for core_index in range(cores.size()):
		var samples: Array = cores[core_index].get("samples", [])
		var target: Array = target_cores[core_index].get("target", [])
		if samples != target or samples.size() != 4:
			return false
		if samples.find(MARKER_ID) != marker_index:
			return false
	return true

func get_progress(state: Dictionary) -> Dictionary:
	var correct: int = 0
	var total: int = 0
	var cores: Array = state.get("cores", [])
	for core_value in cores:
		var core: Dictionary = core_value
		var samples: Array = core.get("samples", [])
		var target: Array = core.get("target", [])
		total += target.size()
		for index in range(mini(samples.size(), target.size())):
			if samples[index] == target[index]:
				correct += 1
	return {
		"correct_slots": correct,
		"total_slots": total,
		"marker_aligned": _marker_aligned(state)
	}

func verify_state(state: Dictionary) -> Dictionary:
	var progress: Dictionary = get_progress(state)
	return {
		"solved": is_solved(state),
		"correct_slots": int(progress.get("correct_slots", 0)),
		"total_slots": int(progress.get("total_slots", 0)),
		"marker_aligned": bool(progress.get("marker_aligned", false))
	}

func advance_state(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "won":
		return {}
	var next_index: int = int(state.get("site_index", -1)) + 1
	if next_index >= SITES.size():
		var completed: Dictionary = state.duplicate(true)
		completed["status"] = "complete"
		return completed
	return make_state(next_index)

func get_layer_label(layer_id: String) -> String:
	return str(LAYER_LABELS.get(layer_id, layer_id.replace("_", " ").to_upper()))

func get_layer_color(layer_id: String) -> String:
	return str(LAYER_COLORS.get(layer_id, "#647784"))

func _marker_aligned(state: Dictionary) -> bool:
	var site: Dictionary = get_site_data(int(state.get("site_index", -1)))
	if site.is_empty():
		return false
	var expected_index: int = int(site.get("marker_index", -1))
	var cores: Array = state.get("cores", [])
	if cores.is_empty():
		return false
	for core_value in cores:
		var core: Dictionary = core_value
		var samples: Array = core.get("samples", [])
		if samples.find(MARKER_ID) != expected_index:
			return false
	return true

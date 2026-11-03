extends RefCounted
class_name FragmentAssemblyRules

const MIN_OVERLAP: int = 2
const MAX_ERRORS: int = 3
const LEVELS = [
	{
		"name": "LATTICE SEED",
		"target": "ACGTAGCTTACG",
		"seed": "ACGTAG",
		"fragments": [
			{"id": "D1", "sequence": "TACCC"},
			{"id": "B", "sequence": "CTTACG"},
			{"id": "D2", "sequence": "GGCTA"},
			{"id": "A", "sequence": "TAGCTT"}
		]
	},
	{
		"name": "RIBBON ARRAY",
		"target": "GATTACAGGCTAAC",
		"seed": "GATTA",
		"fragments": [
			{"id": "D1", "sequence": "AGGCTT"},
			{"id": "C", "sequence": "GCTAAC"},
			{"id": "A", "sequence": "TTACAG"},
			{"id": "D2", "sequence": "CAGTTA"},
			{"id": "B", "sequence": "CAGGCT"}
		]
	},
	{
		"name": "FRACTAL HELIX",
		"target": "CCGATATGCACTG",
		"seed": "CCGATA",
		"fragments": [
			{"id": "D1", "sequence": "ATGCCC"},
			{"id": "C", "sequence": "CACTG"},
			{"id": "A", "sequence": "ATATGC"},
			{"id": "D2", "sequence": "GCACTT"},
			{"id": "B", "sequence": "TGCAC"}
		]
	}
]

func get_level_count() -> int:
	return LEVELS.size()

func create_state(level_index: int = 0, total_score: int = 0) -> Dictionary:
	var safe_index: int = clampi(level_index, 0, LEVELS.size() - 1)
	var level: Dictionary = LEVELS[safe_index].duplicate(true)
	return {
		"level_index": safe_index,
		"level_name": str(level.get("name", "UNKNOWN")),
		"target": str(level.get("target", "")),
		"sequence": str(level.get("seed", "")),
		"fragments": level.get("fragments", []).duplicate(true),
		"used_ids": [],
		"errors": 0,
		"max_errors": MAX_ERRORS,
		"status": "playing",
		"level_score": 0,
		"total_score": total_score,
		"last_message": "Select a fragment whose prefix overlaps the current sequence by at least two bases."
	}

func get_available_fragments(state: Dictionary) -> Array:
	var available: Array = []
	var used_ids: Array = state.get("used_ids", [])
	for fragment_value in state.get("fragments", []):
		if not (fragment_value is Dictionary):
			continue
		var fragment: Dictionary = fragment_value
		var fragment_id: String = str(fragment.get("id", ""))
		if not used_ids.has(fragment_id):
			available.append(fragment.duplicate(true))
	return available

func attempt_fragment(state: Dictionary, fragment_id: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "")) != "playing":
		return next

	var fragment: Dictionary = {}
	for fragment_value in next.get("fragments", []):
		if fragment_value is Dictionary and str(fragment_value.get("id", "")) == fragment_id:
			fragment = fragment_value
			break
	if fragment.is_empty():
		return next

	var used_ids: Array = next.get("used_ids", []).duplicate()
	if used_ids.has(fragment_id):
		return next

	var current_sequence: String = str(next.get("sequence", ""))
	var fragment_sequence: String = str(fragment.get("sequence", ""))
	var overlap: int = _max_overlap(current_sequence, fragment_sequence)
	var candidate: String = current_sequence + fragment_sequence.substr(overlap)
	var target: String = str(next.get("target", ""))

	if overlap < MIN_OVERLAP or not target.begins_with(candidate):
		var errors: int = int(next.get("errors", 0)) + 1
		next["errors"] = errors
		next["last_message"] = "Mismatch: fragment rejected. The assembled prefix is unchanged."
		if errors >= int(next.get("max_errors", MAX_ERRORS)):
			next["status"] = "failed"
			next["last_message"] = "Sample rejected after three mismatches. Restart this lab to try again."
		return next

	next["sequence"] = candidate
	used_ids.append(fragment_id)
	next["used_ids"] = used_ids
	next["last_message"] = "Valid overlap: %d bases. Fragment %s appended." % [overlap, fragment_id]

	if candidate == target:
		var level_score: int = maxi(0, 100 - int(next.get("errors", 0)) * 20)
		next["level_score"] = level_score
		next["total_score"] = int(next.get("total_score", 0)) + level_score
		if int(next.get("level_index", 0)) == LEVELS.size() - 1:
			next["status"] = "campaign_passed"
			next["last_message"] = "All three fictional sample patterns reconstructed. Campaign complete."
		else:
			next["status"] = "level_passed"
			next["last_message"] = "Sequence complete. Advance to the next lab."

	return next

func next_level(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "level_passed":
		return state.duplicate(true)
	return create_state(int(state.get("level_index", 0)) + 1, int(state.get("total_score", 0)))

func restart_level(state: Dictionary) -> Dictionary:
	var status: String = str(state.get("status", ""))
	if status == "level_passed" or status == "campaign_passed":
		return state.duplicate(true)
	return create_state(int(state.get("level_index", 0)), int(state.get("total_score", 0)))

func _max_overlap(first: String, second: String) -> int:
	var max_size: int = mini(first.length(), second.length())
	for overlap_size in range(max_size, MIN_OVERLAP - 1, -1):
		if first.substr(first.length() - overlap_size, overlap_size) == second.substr(0, overlap_size):
			return overlap_size
	return 0

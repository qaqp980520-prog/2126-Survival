extends RefCounted

const BPM: float = 100.0
const BEAT_SECONDS: float = 60.0 / BPM
const NOTE_OFFSET_SECONDS: float = 0.8
const HIT_WINDOW_SECONDS: float = 0.18
const PASS_SCORE: int = 1800
const MAX_MISSES: int = 4

const LANE_PATTERNS: Array = [
	[0, 1, 2, 3, 0, 2, 1, 3, 1, 0, 3, 2, 0, 1, 3, 2, 1, 2, 0, 3, 2, 1, 0, 3],
	[2, 0, 3, 1, 2, 3, 0, 1, 3, 2, 1, 0, 2, 1, 3, 0, 1, 3, 2, 0, 3, 1, 2, 0],
	[1, 3, 0, 2, 3, 1, 2, 0, 2, 3, 1, 0, 3, 0, 2, 1, 0, 2, 3, 1, 2, 0, 1, 3]
]

var chart_index: int = 0
var notes: Array[Dictionary] = []
var elapsed_seconds: float = 0.0
var score: int = 0
var hits: int = 0
var misses: int = 0
var combo: int = 0
var max_combo: int = 0
var finished: bool = false
var won: bool = false

func start_chart(index: int) -> void:
	chart_index = posmod(index, LANE_PATTERNS.size())
	notes.clear()
	var pattern: Array = LANE_PATTERNS[chart_index]
	for i in range(pattern.size()):
		var beat: float = 1.0 + float(i) * 0.5
		notes.append({
			"beat": beat,
			"lane": int(pattern[i]),
			"time": NOTE_OFFSET_SECONDS + beat * BEAT_SECONDS,
			"resolved": false
		})
	elapsed_seconds = 0.0
	score = 0
	hits = 0
	misses = 0
	combo = 0
	max_combo = 0
	finished = false
	won = false

func advance(now_seconds: float) -> void:
	elapsed_seconds = maxf(elapsed_seconds, now_seconds)
	if finished:
		return
	for i in range(notes.size()):
		var note: Dictionary = notes[i]
		if not bool(note["resolved"]) and elapsed_seconds > float(note["time"]) + HIT_WINDOW_SECONDS:
			note["resolved"] = true
			notes[i] = note
			misses += 1
			combo = 0
	_update_finish()

func judge_lane(lane: int, now_seconds: float) -> Dictionary:
	if finished:
		return {"ok": false, "reason": "finished"}
	if lane < 0 or lane > 3:
		return {"ok": false, "reason": "invalid_lane"}
	var misses_before_advance: int = misses
	advance(now_seconds)
	if finished:
		return {"ok": false, "reason": "finished"}
	var best_index: int = -1
	var best_delta: float = INF
	for i in range(notes.size()):
		var note: Dictionary = notes[i]
		if bool(note["resolved"]) or int(note["lane"]) != lane:
			continue
		var delta: float = absf(elapsed_seconds - float(note["time"]))
		if delta < best_delta:
			best_delta = delta
			best_index = i
	if best_index >= 0 and best_delta <= HIT_WINDOW_SECONDS:
		var hit_note: Dictionary = notes[best_index]
		hit_note["resolved"] = true
		notes[best_index] = hit_note
		hits += 1
		score += 100
		combo += 1
		max_combo = maxi(max_combo, combo)
		_update_finish()
		return {"ok": true, "reason": "hit", "lane": lane, "score": score, "combo": combo}
	if misses == misses_before_advance:
		misses += 1
	combo = 0
	_update_finish()
	return {"ok": false, "reason": "offbeat", "lane": lane, "misses": misses}

func get_note_count() -> int:
	return notes.size()

func get_note_time(index: int) -> float:
	if index < 0 or index >= notes.size():
		return -1.0
	return float(notes[index]["time"])

func get_note_lane(index: int) -> int:
	if index < 0 or index >= notes.size():
		return -1
	return int(notes[index]["lane"])

func get_notes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for note in notes:
		result.append(note.duplicate(true))
	return result

func get_status() -> Dictionary:
	var remaining: int = 0
	for note in notes:
		if not bool(note["resolved"]):
			remaining += 1
	return {
		"chart_index": chart_index,
		"score": score,
		"hits": hits,
		"misses": misses,
		"combo": combo,
		"max_combo": max_combo,
		"remaining": remaining,
		"total": notes.size(),
		"finished": finished,
		"won": won
	}

func _update_finish() -> void:
	if finished or notes.is_empty():
		return
	for note in notes:
		if not bool(note["resolved"]):
			return
	var end_time: float = float(notes[notes.size() - 1]["time"]) + 0.6
	if elapsed_seconds < end_time:
		return
	finished = true
	won = score >= PASS_SCORE and misses <= MAX_MISSES

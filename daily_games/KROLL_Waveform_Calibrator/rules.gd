extends RefCounted
class_name KROLLWaveformRules

const LEVELS = [
	{
		"name": "Carrier Lock",
		"par": 8,
		"start": {"frequency": 1, "amplitude": 1, "phase": 0, "offset": 0},
		"target": {"frequency": 2, "amplitude": 3, "phase": 1, "offset": 0}
	},
	{
		"name": "Deep Relay",
		"par": 8,
		"start": {"frequency": 1, "amplitude": 2, "phase": 0, "offset": 0},
		"target": {"frequency": 4, "amplitude": 2, "phase": 5, "offset": -1}
	},
	{
		"name": "Thermal Echo",
		"par": 8,
		"start": {"frequency": 3, "amplitude": 1, "phase": 7, "offset": 1},
		"target": {"frequency": 1, "amplitude": 3, "phase": 2, "offset": 0}
	}
]

static func level_count() -> int:
	return LEVELS.size()

static func get_level(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return LEVELS[index].duplicate(true)

static func clamp_settings(settings: Dictionary) -> Dictionary:
	return {
		"frequency": clampi(int(settings.get("frequency", 1)), 1, 4),
		"amplitude": clampi(int(settings.get("amplitude", 1)), 1, 3),
		"phase": clampi(int(settings.get("phase", 0)), 0, 7),
		"offset": clampi(int(settings.get("offset", 0)), -1, 1)
	}

static func adjust_setting(settings: Dictionary, knob: String, delta: int) -> Dictionary:
	var result := clamp_settings(settings)
	match knob:
		"frequency":
			result["frequency"] = clampi(int(result["frequency"]) + delta, 1, 4)
		"amplitude":
			result["amplitude"] = clampi(int(result["amplitude"]) + delta, 1, 3)
		"phase":
			result["phase"] = clampi(int(result["phase"]) + delta, 0, 7)
		"offset":
			result["offset"] = clampi(int(result["offset"]) + delta, -1, 1)
	return result

static func waveform_value(settings: Dictionary, x: float) -> float:
	var frequency := float(int(settings.get("frequency", 1)))
	var amplitude := float(int(settings.get("amplitude", 1)))
	var phase := float(int(settings.get("phase", 0)) * PI / 4.0)
	var offset := float(int(settings.get("offset", 0)))
	return amplitude * sin(2.0 * PI * frequency * x + phase) + offset

static func root_mean_square_error(current: Dictionary, target: Dictionary, sample_count: int = 64) -> float:
	var count := maxi(8, sample_count)
	var squared_error := 0.0
	for sample_index in range(count):
		var x := float(sample_index) / float(count - 1)
		var difference := waveform_value(current, x) - waveform_value(target, x)
		squared_error += difference * difference
	return sqrt(squared_error / float(count))

static func is_calibrated(current: Dictionary, target: Dictionary) -> bool:
	return root_mean_square_error(current, target, 128) <= 0.001

static func unique_solution_count(target: Dictionary) -> int:
	var matches := 0
	for frequency in range(1, 5):
		for amplitude in range(1, 4):
			for phase in range(0, 8):
				for offset in range(-1, 2):
					var candidate := {
						"frequency": frequency,
						"amplitude": amplitude,
						"phase": phase,
						"offset": offset
					}
					if is_calibrated(candidate, target):
						matches += 1
	return matches

static func score_for_moves(moves: int, par: int) -> int:
	if moves < 0 or par < 0:
		return 0
	return 100 if moves <= par else 75

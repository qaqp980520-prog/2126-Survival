extends RefCounted
class_name ReactorBalanceRules

const REACTOR_COUNT: int = 3
const TARGET_GRID_MIN: float = 135.0
const TARGET_GRID_MAX: float = 165.0
const MAX_HEAT: float = 100.0
const REQUIRED_STABLE_SECONDS: int = 18
const ROUND_SECONDS: float = 60.0

static func apply_action(outputs: Array, heats: Array, reactor_index: int, action: String) -> Dictionary:
	if outputs.size() != REACTOR_COUNT or heats.size() != REACTOR_COUNT:
		return {"ok": false}
	if reactor_index < 0 or reactor_index >= REACTOR_COUNT:
		return {"ok": false}
	if action != "vent" and action != "boost":
		return {"ok": false}
	for value in outputs:
		if not (value is int or value is float) or not is_finite(float(value)):
			return {"ok": false}
	for value in heats:
		if not (value is int or value is float) or not is_finite(float(value)):
			return {"ok": false}

	var next_outputs: Array = outputs.duplicate()
	var next_heats: Array = heats.duplicate()
	if action == "vent":
		next_outputs[reactor_index] = maxf(0.0, float(next_outputs[reactor_index]) - 12.0)
		next_heats[reactor_index] = maxf(0.0, float(next_heats[reactor_index]) - 18.0)
	else:
		next_outputs[reactor_index] = minf(100.0, float(next_outputs[reactor_index]) + 10.0)
		next_heats[reactor_index] = minf(120.0, float(next_heats[reactor_index]) + 12.0)
	return {"ok": true, "outputs": next_outputs, "heats": next_heats}

static func advance(outputs: Array, heats: Array, drift: Array, delta: float = 1.0) -> Dictionary:
	if outputs.size() != REACTOR_COUNT or heats.size() != REACTOR_COUNT or drift.size() != REACTOR_COUNT:
		return {"ok": false}
	if not is_finite(delta) or delta <= 0.0 or delta > 5.0:
		return {"ok": false}
	var next_outputs: Array = []
	var next_heats: Array = []
	for index in range(REACTOR_COUNT):
		var output_value: Variant = outputs[index]
		var heat_value: Variant = heats[index]
		var drift_value: Variant = drift[index]
		if not (output_value is int or output_value is float) or not is_finite(float(output_value)):
			return {"ok": false}
		if not (heat_value is int or heat_value is float) or not is_finite(float(heat_value)):
			return {"ok": false}
		if not (drift_value is int or drift_value is float) or not is_finite(float(drift_value)):
			return {"ok": false}
		var output: float = clampf(float(output_value) + float(drift_value) * delta, 0.0, 100.0)
		var heat_change: float = maxf(0.0, output - 48.0) * 0.10 - 1.4
		var heat: float = clampf(float(heat_value) + heat_change * delta, 0.0, 120.0)
		next_outputs.append(output)
		next_heats.append(heat)
	return {"ok": true, "outputs": next_outputs, "heats": next_heats}

static func is_grid_stable(outputs: Array) -> bool:
	if outputs.size() != REACTOR_COUNT:
		return false
	var total: float = 0.0
	for value in outputs:
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
		total += float(value)
	return total >= TARGET_GRID_MIN and total <= TARGET_GRID_MAX

static func is_overheated(heats: Array) -> bool:
	if heats.size() != REACTOR_COUNT:
		return true
	for value in heats:
		if not (value is int or value is float) or not is_finite(float(value)):
			return true
		if float(value) >= MAX_HEAT:
			return true
	return false

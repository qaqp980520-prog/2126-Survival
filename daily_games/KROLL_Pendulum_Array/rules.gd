extends RefCounted
class_name KrollPendulumArrayRules

const GRAVITY: float = 9.81
const MIN_LENGTH: float = 0.5
const MAX_LENGTH: float = 3.0
const LENGTH_STEP: float = 0.05
const PERIOD_TOLERANCE: float = 0.02
const CYCLES_PER_TEST: int = 4
const STAGES: Array[Dictionary] = [
	{"name":"Calibration Chamber","target_length":1.0},
	{"name":"Long-Arm Observatory","target_length":1.8},
	{"name":"Deep Array","target_length":2.8}
]

func get_stage_count() -> int:
	return STAGES.size()

func get_stage(index: int) -> Dictionary:
	if index < 0 or index >= STAGES.size():
		return {}
	var stage: Dictionary = STAGES[index].duplicate(true)
	stage["target_period"] = period_for_length(float(stage["target_length"]))
	return stage

func period_for_length(length: float) -> float:
	if not is_finite(length) or length <= 0.0:
		return -1.0
	return TAU * sqrt(length / GRAVITY)

func length_for_period(period: float) -> float:
	if not is_finite(period) or period <= 0.0:
		return -1.0
	return GRAVITY * pow(period / TAU, 2.0)

func snap_length(length: float) -> float:
	if not is_finite(length):
		return MIN_LENGTH
	var clamped: float = clampf(length, MIN_LENGTH, MAX_LENGTH)
	return snappedf(clamped, LENGTH_STEP)

func evaluate(length: float, stage_index: int) -> Dictionary:
	var stage: Dictionary = get_stage(stage_index)
	if stage.is_empty():
		return {"ok":false,"error":"invalid_stage"}
	if not is_finite(length) or length < MIN_LENGTH or length > MAX_LENGTH:
		return {"ok":false,"error":"invalid_length"}
	var measured_period: float = period_for_length(length)
	var target_period: float = float(stage["target_period"])
	var error: float = absf(measured_period - target_period)
	var passed: bool = error <= PERIOD_TOLERANCE
	return {
		"ok":true,
		"passed":passed,
		"measured_period":measured_period,
		"target_period":target_period,
		"period_error":error,
		"score":100 if passed else 0,
		"cycles":CYCLES_PER_TEST
	}

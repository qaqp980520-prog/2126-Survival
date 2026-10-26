extends SceneTree

const Rules = preload("res://scripts/rules.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 731
	rng_b.seed = 731
	var sequence_a: Array[int] = Rules.make_sequence(rng_a, 7)
	var sequence_b: Array[int] = Rules.make_sequence(rng_b, 7)
	assert(sequence_a.size() == 7)
	assert(sequence_a == sequence_b, "The same seed must produce the same sequence")
	for cell in sequence_a:
		assert(cell >= 0 and cell < Rules.CELL_COUNT)
	assert(Rules.next_round_length(1) == 3)
	assert(Rules.next_round_length(5) == 7)
	assert(Rules.is_correct_input([0, 4, 8], 1, 4))
	assert(not Rules.is_correct_input([0, 4, 8], 1, 3))
	assert(not Rules.is_correct_input([0, 4, 8], -1, 0))
	assert(not Rules.is_correct_input([0, 4, 8], 0, 9))
	assert(not Rules.is_round_complete([0, 4, 8], 2))
	assert(Rules.is_round_complete([0, 4, 8], 3))
	assert(not Rules.is_round_complete([], 0))
	assert(Rules.can_advance_round(4))
	assert(not Rules.can_advance_round(5))
	print("KROLL Cipher Recall rules tests passed.")
	quit(0)

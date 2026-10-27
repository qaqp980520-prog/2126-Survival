extends RefCounted
class_name KrollFrequencyLockRules

const CODE_LENGTH := 4
const SYMBOL_COUNT := 6
const MAX_ATTEMPTS := 8

static func generate_secret(seed_value: int) -> Array[int]:
	var symbols: Array[int] = [1, 2, 3, 4, 5, 6]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(symbols.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := symbols[index]
		symbols[index] = symbols[swap_index]
		symbols[swap_index] = temporary
	var secret: Array[int] = []
	for index in range(CODE_LENGTH):
		secret.append(symbols[index])
	return secret

static func is_valid_guess(guess: Array) -> bool:
	if guess.size() != CODE_LENGTH:
		return false
	var seen: Dictionary = {}
	for value in guess:
		if not (value is int or value is float):
			return false
		var number := float(value)
		if not is_finite(number) or floorf(number) != number or number < 1.0 or number > float(SYMBOL_COUNT):
			return false
		var symbol := int(number)
		if seen.has(symbol):
			return false
		seen[symbol] = true
	return true

static func is_valid_code(code: Array) -> bool:
	return is_valid_guess(code)

static func score_guess(secret: Array, guess: Array) -> Dictionary:
	if not is_valid_code(secret) or not is_valid_guess(guess):
		return {"valid": false, "exact": 0, "misplaced": 0}
	var exact := 0
	var remaining_secret: Dictionary = {}
	for index in range(CODE_LENGTH):
		var secret_symbol := int(secret[index])
		if secret_symbol == int(guess[index]):
			exact += 1
		else:
			remaining_secret[secret_symbol] = int(remaining_secret.get(secret_symbol, 0)) + 1
	var misplaced := 0
	for index in range(CODE_LENGTH):
		if int(secret[index]) == int(guess[index]):
			continue
		var guessed_symbol := int(guess[index])
		if int(remaining_secret.get(guessed_symbol, 0)) > 0:
			misplaced += 1
			remaining_secret[guessed_symbol] = int(remaining_secret[guessed_symbol]) - 1
	return {"valid": true, "exact": exact, "misplaced": misplaced}

static func create_state(secret: Array) -> Dictionary:
	if not is_valid_code(secret):
		return {"secret": [], "guesses": [], "feedback": [], "attempts_left": MAX_ATTEMPTS, "status": "invalid"}
	var stored_secret: Array[int] = []
	for value in secret:
		stored_secret.append(int(value))
	return {
		"secret": stored_secret,
		"guesses": [],
		"feedback": [],
		"attempts_left": MAX_ATTEMPTS,
		"status": "playing"
	}

static func submit_guess(state: Dictionary, guess: Array) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return {"accepted": false, "reason": "terminal"}
	if not is_valid_guess(guess):
		return {"accepted": false, "reason": "invalid_guess"}
	var secret: Array = state.get("secret", [])
	if not is_valid_code(secret):
		return {"accepted": false, "reason": "invalid_secret"}
	var feedback := score_guess(secret, guess)
	var guesses: Array = state.get("guesses", [])
	var history: Array = state.get("feedback", [])
	guesses.append(guess.duplicate())
	history.append(feedback.duplicate(true))
	state["guesses"] = guesses
	state["feedback"] = history
	state["attempts_left"] = MAX_ATTEMPTS - guesses.size()
	if int(feedback["exact"]) == CODE_LENGTH:
		state["status"] = "won"
	elif int(state["attempts_left"]) <= 0:
		state["status"] = "lost"
	return {
		"accepted": true,
		"feedback": feedback,
		"status": str(state["status"]),
		"attempts_left": int(state["attempts_left"])
	}

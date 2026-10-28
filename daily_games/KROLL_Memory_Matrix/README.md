# KROLL Memory Matrix M0.1

A compact nine-tile sequence-memory game for Godot 4.3+. Memorize a deterministic signal pattern, repeat it with keyboard, mouse or touch, and clear six rounds. Every round adds one signal; three mistakes end the run.

## Import and controls

Open `project.godot` from the Godot Project Manager.

- Click/tap a tile or press keys `1`–`9` to repeat the sequence.
- Press `R` or click **RESTART** to begin again.
- The game uses generated UI only: no external art, audio, plugins or network access.

## Files

- `main.tscn`, `main.gd`: runtime UI and sequence playback.
- `rules.gd`: deterministic game state machine.
- `tests/rules_test.gd`: seed determinism, input validation, retry, progression, win/loss locks.
- `tests/game_smoke_test.gd`: headless scene construction and first-input test.

## Validation

The root Godot validation workflow imports this project, runs the rules suite, and launches the runtime smoke test with a timeout. A successful GitHub Actions run is required before merging the feature PR. Local GUI, GPU and iPhone device tests are separate and are not implied by headless CI.

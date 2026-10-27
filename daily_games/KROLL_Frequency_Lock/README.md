# KROLL Frequency Lock M0.1

A standalone Godot 4 code-breaking puzzle. Decode a four-symbol signal using the six-symbol bank in at most eight attempts.

## Play

- Select four different symbols with mouse/touch or press keys 1–6.
- Press Enter or click Submit to test the signal.
- Feedback reports exact positions and correct-but-misplaced symbols.
- Backspace/Clear removes the draft; R restarts.
- The secret is shown only after victory or lockout.

## Files

- `project.godot`: Godot project settings.
- `main.tscn`, `main.gd`: game scene and vector-drawn interface.
- `rules.gd`: deterministic code generation, feedback scoring, and state machine.
- `tests/rules_test.gd`: logic regression tests.
- `tests/game_smoke_test.gd`: scene interaction smoke test.

## Import

Use Godot 4.3 or newer and open this folder's `project.godot` in Project Manager. No external assets or addons are required.

## Validation and limits

CI uses headless Godot 4.3 import, rules tests, and scene smoke tests. No local GUI, GPU performance, or iPhone hardware test is claimed. The code uses a fixed four-symbol, no-repeat code and is a small puzzle prototype, not an account-security tool.

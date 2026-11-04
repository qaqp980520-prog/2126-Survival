# KROLL Thermal Containment Lab M0.1

A standalone Godot 4.3+ thermal-field stabilization puzzle.

## Play

- 1–4: select the vent row.
- Space: vent the selected row and advance one thermal cycle.
- U: undo the previous cycle.
- R: restart the current chamber.
- N: advance after successful containment.
- C: restart the campaign.
- On-screen row and action buttons support pointer and touch.

## Thermal model

The 4×4 field runs for exactly four cycles. Each cycle:

1. The selected row loses 4°C (floor 10°C).
2. Fixed reactor sources add 2°C.
3. Every cell diffuses 25% toward the average of its orthogonal neighbors, rounded to the nearest degree.

A chamber is contained only when all 16 cells are between 19°C and 29°C inclusive after cycle four. Each of the three chambers awards 100 points once; campaign maximum is 300.

The authored four-row vent schedules are unique solutions, verified by exhaustive enumeration of all 4^4 schedules in the Godot rules test.

## Import and validation

Open this folder in Godot 4.3 or newer and run main.tscn. The project uses the Compatibility renderer and has no external assets, plugins, audio, network or save dependencies.

- tests/rules_test.gd exhaustively checks all 256 vent schedules per chamber, unique solutions, state immutability, undo, failure and one-time scoring.
- tests/game_smoke_test.gd instantiates the scene, checks touch controls, completes all three chambers and exercises keyboard controls.

This is a deterministic discrete thermal model for puzzle gameplay, not a full CFD or thermodynamics solver. Headless CI does not establish local rendered GUI, GPU performance or physical iPhone behavior.

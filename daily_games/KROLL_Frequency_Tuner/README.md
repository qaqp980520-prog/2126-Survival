# KROLL Frequency Tuner M0.1

A deterministic three-dial signal-lock puzzle built with Godot 4.3+ and no external assets or plugins.

## Play

Open `project.godot` in Godot Project Manager and run the main scene.

- Q / W: decrease / increase dial A
- A / S: decrease / increase dial B
- Z / X: decrease / increase dial C
- Use the on-screen minus/plus buttons for mouse or touch
- R: restart the current seed
- N: move to the next fixed seed

Each dial wraps from 0 to 9. The three output channels are coupled modulo-10 equations. Match all target outputs within 14 moves.

## Validation

- `tests/rules_test.gd`: deterministic layouts, solvability, input validation, move-budget failure and terminal immutability
- `tests/game_smoke_test.gd`: scene construction, named controls, a full solve through the scene action handler, restart and seed cycling

CI status must be checked against the exact commit SHA; a pending workflow is not a test pass.

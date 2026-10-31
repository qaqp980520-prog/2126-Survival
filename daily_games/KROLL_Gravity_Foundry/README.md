# KROLL Gravity Foundry M0.1

A self-contained Godot 4 grid puzzle about moving an operator, pushing a loose core, rotating gravity and securing the core on a pressure plate before reaching the exit.

## Import

Open the project.godot file in Godot 4.3 or newer. No external assets, plugins, audio or network access are required. The game is also registered in the repository's Survival Test Hub.

## Controls

- W / Up: move up
- D / Right: move right
- S / Down: move down
- A / Left: move left
- Q: rotate gravity counter-clockwise
- E: rotate gravity clockwise
- R: restart the current sector
- N: advance after a sector is solved

On-screen buttons provide the same actions for touch devices.

## Rules

The operator moves one tile per valid action. A loose core is pushed when the operator walks into it, then slides in the current gravity direction until blocked by a wall, the board edge, the operator or the pressure plate. Q/E rotates gravity and settles the core again. The exit is secured only when the core rests on the pressure plate and the operator reaches the exit. Blocked actions do not consume a turn.

## Authored sectors

1. Reactor Bay
2. Coolant Vault
3. Core Archive

The standalone rules test contains a deterministic winning action sequence for each authored sector. The scene smoke test emits the real touch-button signal and completes all three sectors.

## Files

- project.godot, main.tscn, main.gd: playable UI and controls
- rules.gd: deterministic grid, pushing, gravity and win-state model
- tests/rules_test.gd: boundaries, blocked pushes, gravity settling and all three solutions
- tests/game_smoke_test.gd: scene initialization, actual button signal and full three-sector runtime route

## Limits

This is a turn-based puzzle prototype, not a physics simulation. It has no campaign save, audio, animation or controller remapping. The board is drawn from built-in Godot primitives and uses no external art.

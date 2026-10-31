# KROLL Orbital Pinball M0.1

A self-contained Godot 4 arcade pinball prototype with three bumper layouts, three balls, deterministic manual 2D simulation, flipper controls, keyboard input and mouse/touch buttons.

## Import
Open `project.godot` in Godot 4.3 or newer. No external assets, audio, plugins or network access are required.

## Controls
- A / D: hold left/right flippers
- Space: launch
- R: reset the current table
- N: next bumper layout
- On-screen buttons provide mouse and touch controls.

## Files
- `main.tscn`, `main.gd`: playable UI and drawing.
- `rules.gd`: deterministic ball, rail, bumper, flipper and drain simulation.
- `tests/rules_test.gd`: collision and scoring rules.
- `tests/game_smoke_test.gd`: scene, input buttons and frame simulation.

## Limitations
This is an M0.1 prototype using deterministic manual ball integration rather than Godot rigid-body physics. It does not yet include audio, persistent high scores, multiball or mobile haptics.

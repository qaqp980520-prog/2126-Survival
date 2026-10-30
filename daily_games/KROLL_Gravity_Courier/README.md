# KROLL Gravity Courier M0.1

A compact 2D gravity-switching cargo recovery platformer built with Godot 4.3+.

## Import
Open the project.godot file in Godot Project Manager. No external assets, audio, plugins or network access are required.

## Objective
Recover four cargo cells and reach the exit. Gravity can be reversed between DOWN and UP to travel between the floor and ceiling. Cargo is collected once; the exit remains locked until all four cells are secured.

## Controls
- A / D: move left / right
- Space: jump away from the currently attracted surface
- Q: reverse gravity
- R: restart
- On-screen LEFT / RIGHT / JUMP / FLIP buttons support mouse and touch.

## Verification
The rules test checks gravity transitions, immutable rejected actions, cargo identity, duplicate rejection and exit gating. The smoke test instantiates the real scene, emits touch and cargo/exit signals, and verifies mission completion and restart.

## Limits
This is a single-screen prototype with deterministic collision geometry. It is not a full campaign or a save-backed progression system.

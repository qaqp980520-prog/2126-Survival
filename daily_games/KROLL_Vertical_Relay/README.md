# KROLL Vertical Relay M0.1

A standalone Godot 4.3+ vertical platform-climbing game. Climb the KROLL relay shaft, collect five data chips, avoid two moving patrol hazards, and touch the extraction gate before the 75-second timer expires.

## Controls

- A/D or left/right arrows: move horizontally.
- W, Space, or Up: jump.
- R: restart.
- On-screen left/right buttons and JUMP button: touch controls.

## Import

Open this folder's project.godot in Godot Project Manager. The project uses generated polygon visuals and built-in physics shapes; no external assets or add-ons are required.

## Rules

- Collect all five unique relay data chips.
- The extraction gate remains locked until all five are collected.
- Falling below the shaft or touching a patrol hazard fails the run.
- The 75-second timer is terminal; press R to retry.

## Validation

The root repository Godot 4.3 workflow imports the project, runs tests/rules_test.gd and tests/game_smoke_test.gd, and also runs the surface chunk streaming playground integration test.

## Known limits

This is a compact single-level prototype. It has no audio, save system, level editor, or iPhone device certification. The automated smoke test is not a substitute for manual graphical play.

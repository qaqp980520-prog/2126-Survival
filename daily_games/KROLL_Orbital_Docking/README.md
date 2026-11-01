# KROLL Orbital Docking M0.1

A compact 2D inertial spacecraft-docking simulator built with Godot 4.3+.

## Objective

Reach the station's docking ring with all three conditions satisfied:

- distance at or below 30 world units;
- relative speed at or below 26 units/second;
- heading error at or below 0.22 radians.

The craft has limited fuel and a time limit. Thrust accelerates; reverse thrust reduces forward velocity. The craft is never snapped to the target.

## Controls

- A / D: rotate left / right
- W: forward thrust
- S: reverse thruster
- R: restart current approach
- N: next approach
- On-screen buttons support mouse and touch.

## Scenarios

Training Ring, Crosswind Approach and Deep Orbit use fixed initial conditions for repeatable practice.

## Import and verification

Open `project.godot` in Godot Project Manager. No external assets, audio, plugins or network access are required.

Run the rules suite with `tests/rules_test.gd` and the scene smoke test with `tests/game_smoke_test.gd`.

## Limits

M0.1 is a single-screen 2D prototype with deterministic inertial movement. It has no orbital gravity field, campaign save or multiplayer.

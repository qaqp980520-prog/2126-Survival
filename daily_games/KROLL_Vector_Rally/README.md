# KROLL Vector Rally M0.1

A self-contained top-down electric time-trial racer for Godot 4.3+.

## Objective
Drive one clean lap on three authored oval circuits. Hit the four checkpoints in order, keep the car on the road ring, and use throttle, brake, steering and handbrake to control speed and drift.

## Controls
- W / Up: throttle
- S / Down: brake
- A / Left: steer left
- D / Right: steer right
- Space: handbrake / drift
- R: restart current track
- N: advance after finishing
- On-screen buttons: touch equivalents

## Tracks
1. Dock Loop — balanced grip and a wide service ring.
2. Reactor Ring — narrower road and lower grip.
3. Canyon Sweep — wider outside radius and higher grip.

## Import
Open daily_games/KROLL_Vector_Rally/project.godot in Godot 4.3 or newer. No external assets, plugins, audio or network services are required. The game is registered in the root Survival Test Hub.

## Tests
- tests/rules_test.gd: track geometry, acceleration, braking, steering, drift, off-road penalty, speed cap, ordered checkpoints, lap completion and track progression.
- tests/game_smoke_test.gd: scene initialization, real touch-button signals, steering, acceleration and restart.
- Root SurvivalTestHub smoke test verifies the scene can be loaded from the root project.

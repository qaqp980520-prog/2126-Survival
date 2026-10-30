# KROLL Tidal Survey M0.1

A deterministic top-down underwater navigation game built with Godot 4.3+ and no external assets or add-ons.

## Objective

Pilot a survey drone through three fixed underwater layouts. Collect the three beacons in order, avoid hazards, manage oxygen, then return to the dock.

## Controls

- W/A/S/D or arrow keys: apply thrust.
- On-screen directional buttons: touch/mouse thrust.
- R or RESTART: reset the current layout.
- N or NEXT: advance to the next layout.

The drone has inertia. Water drag slows it when no thrust is applied, and current fields add deterministic drift. Hazard contact costs oxygen and uses a short per-hazard cooldown to avoid repeated frame-by-frame damage.

## Import

Open `daily_games/KROLL_Tidal_Survey/project.godot` in Godot 4.3 or newer and run the main scene.

## Tests

From the repository root, the shared CI runs:
- project file verification,
- Godot headless import,
- `tests/rules_test.gd`,
- `tests/game_smoke_test.gd`.

The rule model covers thrust, drag, current drift, speed cap, ordered beacon collection, dock gating, hazard cooldown, oxygen depletion and terminal-state immutability.

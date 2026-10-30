# KROLL Tidal Survey M0.1 — 2026-10-30

## Concept

A deterministic top-down underwater survey game. Pilot a drone with inertial thrust through three authored layouts, collect beacons in order, avoid hazards, manage oxygen and return to the dock.

## Controls

- W/A/S/D or arrow keys: thrust.
- On-screen directional buttons: mouse/touch thrust.
- R / RESTART: reset the current layout.
- N / NEXT: advance to the next layout.

## Rules

- Arena: 640 × 420 logical units.
- Three beacons must be collected in route order.
- Return to the dock after the final beacon to win.
- Oxygen drains continuously.
- Hazard contact costs oxygen; a per-hazard cooldown prevents repeated damage every frame.
- Thrust accelerates the drone, drag reduces momentum and current fields add deterministic drift.
- Maximum speed is capped; arena edges reflect the drone at reduced speed.
- Oxygen depletion ends the run.

## Authored layouts

- Kelp Trench
- Basalt Channel
- Abyssal Shelf

Each layout has a fixed start, dock, three ordered beacons, hazards and current fields. Layout data is deterministic and has no external asset dependency.

## Files and import

Open `daily_games/KROLL_Tidal_Survey/project.godot` in Godot 4.3 or newer. The project contains:
- `main.tscn` and `main.gd` for UI, drawing and input.
- `rules.gd` for deterministic simulation.
- `tests/rules_test.gd` and `tests/game_smoke_test.gd`.
- `README.md` for player-facing controls.

No external assets, audio files or add-ons are required.

## Validation

The shared Godot workflow verifies project files, imports/parses the project, runs rules tests and runs a scene smoke test. Rule coverage includes thrust, drag, current drift, speed cap, arena bounds, ordered beacon collection, dock gating, hazard cooldown, oxygen depletion and terminal-state immutability.

## Known limits

- This is a compact prototype, not the full underwater biome system for 2126 Survival.
- Current fields are constant within their radius; they do not yet vary over time.
- There is no saved high score or campaign progression.
- GUI/GPU/mobile device behavior still requires manual hardware QA.

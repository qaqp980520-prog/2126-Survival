# KROLL Abyssal Sonar M0.1

A standalone Godot 4.3+ turn-based sonar triangulation and deep-trench extraction game.

## Objective

Recover the hidden beacon in each of three 9×9 trench maps, then return to the green SUB tile to extract it. Sonar reveals a coarse distance band and an eight-way bearing; it never directly draws the beacon. Each authored route has two planned ping positions whose combined clues uniquely identify the beacon. Walls block movement but are visible.

## Controls

- W / Up: move north.
- D / Right: move east.
- S / Down: move south.
- A / Left: move west.
- Space: send a sonar ping (2 battery, maximum 3 pings).
- E: collect the beacon when standing on it; interact again at SUB to extract.
- R: restart the current trench while preserving previously earned campaign rewards.
- N: advance after extraction.
- C: restart the campaign.
- On-screen directional, PING, INTERACT, RESTART, NEXT and NEW CAMPAIGN controls support pointer and touch.

## Mission rules

- Every movement costs 1 battery; every sonar ping costs 2.
- Echo distance is Manhattan distance: NEAR (0–2), MID (3–5), FAINT (6+).
- Bearing is one of N, NE, E, SE, S, SW, W or NW.
- Each mission has a finite battery budget and three pings.
- Each mission awards once: 100 points when extracted with at least its par battery remaining, otherwise 75. Campaign maximum is 300.

## Import

Open this folder in Godot 4.3 or newer and run main.tscn. The project uses the Compatibility renderer and has no external assets, plugins, audio, network or save dependencies.

## Validation

- tests/rules_test.gd checks all mission paths, sonar clue correctness, unique two-ping triangulation, battery/ping budgets, extraction, one-time rewards and restart behavior.
- tests/game_smoke_test.gd instantiates the scene and exercises keyboard-facing actions and touch hit-testing.
- tests/route_simulation_test.gd drives each route through real grid moves, sonar pings, beacon collection and return-to-sub extraction without teleporting.
- The root project regression tests/world_bridge_restore_read_isolation_test.gd proves that serialization and metric/count reads do not expose a partially restored custom inventory.

This is a deterministic grid-navigation sonar puzzle, not a hydrodynamic submarine simulator. Headless CI does not establish local rendered GUI, GPU performance or physical iPhone behavior.

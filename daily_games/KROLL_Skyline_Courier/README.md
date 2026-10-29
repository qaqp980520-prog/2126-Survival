# KROLL Skyline Courier — M0.1

A self-contained Godot 4.3+ three-lane runner. Move between elevated traffic lanes, dodge red barriers and collect six data packets before the 45-second delivery window closes. All visuals are drawn by GDScript; no external assets or plugins are required.

## Run
1. Open this folder in Godot Project Manager.
2. Import the project if prompted.
3. Press F6/F5 or use Project > Run.

## Controls
- A / Left Arrow: move one lane left.
- D / Right Arrow: move one lane right.
- Touch or click LEFT / CENTER / RIGHT: select a lane directly.
- R: restart the current deterministic route.
- N: load the next seeded route.

## Rules
Three lives. Matching a red barrier costs one life; matching a cyan data packet adds 100 points. Collect six packets to win. The route advances at a fixed speed, and the run fails if lives reach zero or the delivery timer expires.

## Validation
- tests/rules_test.gd covers deterministic routes, lane bounds, invalid delta, hazards, packet collection, victory lockout and timeout.
- tests/game_smoke_test.gd covers scene load, keyboard input, touch controls and a live frame.
- Shared repository CI uses Godot 4.3 headless import/rules/runtime tests. Manual GUI/GPU/iPhone device QA is separate and is not claimed by a passing headless run.

# KROLL Rail Yard M0.1

A deterministic shunting-yard logic game for Godot 4.3+.

## Goal

Move five cars into output order A, B, C, D, E. The incoming track is a queue; the siding is a last-in/first-out stack with capacity 3. The move budget is 12. Invalid actions do not consume moves.

## Controls

- 1: send the next incoming car directly to output (only if it is the next required car).
- 2: push the next incoming car onto the siding.
- 3: pop the siding's top car to output (only if it is the next required car).
- R: restart the current layout.
- N: advance to the next deterministic layout.
- On-screen buttons support mouse and touch.

## Layouts

Seeds 1, 2, and 3 are fixed and deterministic. All have valid solutions within the 12-move budget.

## Import

Open daily_games/KROLL_Rail_Yard/project.godot with Godot 4.3 or newer. No external assets or add-ons are required.

## Tests

- tests/rules_test.gd: deterministic layouts, illegal moves, stack capacity, move limit, terminal lock and all three solutions.
- tests/game_smoke_test.gd: scene import/runtime, stable button names, actual pressed signals, reset and next-layout behavior.

The root repository's shared Godot validation workflow runs these checks in headless mode. Manual GUI, GPU and iPhone-device QA are separate and are not implied by headless CI.

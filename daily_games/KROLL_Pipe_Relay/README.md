# KROLL Pipe Relay M0.1

A deterministic 4×4 pipe-routing puzzle for Godot 4.3+.

## Import
Open project.godot with Godot Project Manager. No external assets, plugins, or audio files are required.

## Controls
- Click/tap a pipe tile to rotate it clockwise.
- TEST NETWORK or Space checks the current route.
- R restarts the current layout.
- N advances to the next layout.

## Rules
Connect SOURCE to TARGET while powering every pipe segment. The three deterministic layouts use a 10-rotation budget. A solved board locks further edits.

## Validation
- tests/rules_test.gd: deterministic layouts, route completion, all-segment connectivity, invalid indices, duplicate coordinates, exact move budget and terminal lock.
- tests/game_smoke_test.gd: real scene instantiation, 4×4 board, actual Button.pressed signals, restart, next layout and visible status feedback.

The puzzle uses an explicit graph traversal over reciprocal pipe ports. It is a logic model, not a fluid simulation.

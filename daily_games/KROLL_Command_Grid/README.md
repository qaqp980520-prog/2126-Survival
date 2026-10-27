# KROLL Command Grid M0.1

A deterministic turn-based grid tactics mini-game for Godot 4.3+.

## Objective
Collect all four data cores, then reach the green exit at (7, 7) before the 32-action budget runs out. Three security bots move one cell along a shortest path after each successful action. EMP disables bots within Manhattan distance 2 and has three charges.

## Controls
- WASD / arrow keys: move one cell
- Space: EMP pulse
- R: restart
- Mouse/touch: tap an adjacent grid cell or use the on-screen controls

## Import
Open project.godot in Godot 4.3 or newer. No external assets or add-ons are required.

## Included tests
- tests/rules_test.gd: movement, walls, data collection, EMP range/charges, enemy capture, victory and turn exhaustion.
- tests/game_smoke_test.gd: scene instantiation, 64-cell grid, action-to-state binding and restart.

This is a self-contained arcade prototype, not the production multiplayer combat system.

# KROLL Flux Hockey M0.1

A small real-time air-hockey arcade game for Godot 4.3+.

## Objective

Defend the lower goal, return the puck past the upper paddle, and score five points before the opponent. Three arenas add different bumper layouts.

## Controls

- Drag with mouse or touch to move the lower paddle.
- A / D or Left / Right also move the lower paddle.
- R resets the current arena.
- N advances to the next arena.
- First player to five goals wins.

## Arenas

1. Dock Ring — open arena, no bumpers.
2. Reactor Pair — two central bumpers.
3. Split Orbit — four offset bumpers.

## Import

Open daily_games/KROLL_Flux_Hockey/project.godot with Godot 4.3 or newer and run main.tscn.

No external assets, audio, plugins, add-ons, or network access are required.

## Tests

- tests/rules_test.gd: deterministic movement, wall and bumper collisions, goal scoring, win lock and arena progression.
- tests/game_smoke_test.gd: scene instantiation, touch-drag input, next-arena and reset behavior.

The project uses procedural vector drawing; no downloaded art or copyrighted game assets are included.

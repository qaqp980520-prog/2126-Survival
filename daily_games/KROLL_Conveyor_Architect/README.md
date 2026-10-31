# KROLL Conveyor Architect M0.1

A deterministic factory-routing puzzle for Godot 4.3+.

## Goal

Route each cargo unit from the input to the receiving dock by placing directional conveyors. Each work order has a fixed build budget. Cargo advances one cell at a time when the player presses Advance.

## Controls

- Click/tap an empty cell to place the currently selected direction.
- Click/tap an occupied conveyor to rotate it clockwise.
- Arrow keys or WASD set the selected cell's direction.
- Space advances the cargo by one cell.
- R resets the current work order.
- N advances after delivery.
- On-screen direction, Advance, Reset and Next buttons support touch.

## Rules

- The board is 6×6.
- Walls cannot be routed through.
- Each new conveyor consumes one build slot; rotating an existing conveyor does not.
- Missing conveyors safely stall cargo and can be repaired.
- Leaving the board, hitting a wall or revisiting a cell jams the route.
- Three authored work orders: Dock Line, Coolant Bend and Core Archive.

## Import

Open project.godot in Godot 4.3 or newer. No external assets, plugins, packages, network services or imported resources are required.

## Validation

- tests/rules_test.gd: deterministic solutions for all three work orders, budget, invalid input, stall recovery, wall and loop handling.
- tests/game_smoke_test.gd: scene instantiation, route placement, cargo delivery, progression and reset.
- Root project registration: Survival Test Hub and root smoke test.

## Limitations

This is a deterministic one-cell-per-command routing puzzle, not a real-time conveyor physics simulation. No campaign save, audio, animation or procedural levels are included in M0.1.

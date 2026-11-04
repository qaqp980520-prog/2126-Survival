# KROLL Drift Rescue M0.1

A standalone Godot 4.3+ orbital momentum and rescue-docking puzzle.

## Play

- W / Up: thrust upward.
- S / Down: thrust downward.
- A / Left: thrust left.
- D / Right: thrust right.
- Space: coast without spending fuel.
- U: undo the previous flight action.
- R: restart the current mission.
- N: advance after a successful docking.
- C: restart the campaign.
- On-screen buttons support mouse and touch.

## Flight rules

The rescue craft has two-axis velocity. Each directional thrust adds one velocity unit on that axis, with each component capped at -2..2. The craft then moves by its resulting velocity. Velocity persists while coasting; counter-thrust is required to brake. Every thrust consumes one fuel unit, while coasting consumes none.

The full swept path is checked against debris and the 9x9 flight boundary, so a fast craft cannot skip through an obstacle. Docking succeeds only when the craft reaches the target with zero velocity. Each mission has a finite fuel reserve and turn budget. A completed mission awards 100 points at or under par, otherwise 75; each mission can award only once.

## Authored routes

- Debris-Free Transfer: right, right, coast, left, left.
- Broken Bulkhead: up, coast, right, right, down, left, left.
- Cryo-Ring Extraction: down, down, up, right, right, up, left, left.

The route fixtures are also asserted by the Godot rules tests.

## Import and validation

Open this folder in Godot 4.3 or newer and run main.tscn. The project uses the Compatibility renderer and has no external assets, add-ons, audio, network or save dependencies.

- tests/rules_test.gd checks all three authored routes, momentum, braking, swept collision detection, out-of-bounds failure, fuel and turn budgets, undo and one-time rewards.
- tests/game_smoke_test.gd checks scene construction, touch buttons, full campaign completion and keyboard input.

This is a deterministic discrete-flight puzzle, not a continuous rigid-body orbital simulator. Headless CI does not establish local rendered GUI, GPU performance or physical iPhone behavior.

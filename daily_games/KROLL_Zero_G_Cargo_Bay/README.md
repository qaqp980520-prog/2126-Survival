# KROLL Zero-G Cargo Bay M0.1

A standalone Godot 4.3+ spatial packing and mass-balancing puzzle.

## Play

- Move the placement cursor with WASD or the arrow keys.
- Rotate the current cargo piece with Q.
- Place it with Space.
- Undo the last piece with U. This also lets you recover from an unstable completed load.
- Advance to the next manifest with N after a stable load.
- Restart the campaign with R.
- The 5×5 deck cells and on-screen controls support pointer and touch input.

## Rules

Each manifest supplies a fixed sequence of cargo pieces with a footprint and mass. Pieces may be rotated, but cannot overlap or extend beyond the 5×5 deck. The center of mass is calculated by distributing each piece's mass evenly across its occupied cells.

A load is stable when its center of mass remains inside the support rectangle from 1.25 to 3.75 on both axes. A stable load scores 100 when the center is within 0.8 units of the deck center, otherwise 75. Every manifest can award points only once. An unstable final placement can be corrected by undoing the last piece.

## Import

Open the folder containing project.godot in Godot 4.3 or newer and run main.tscn. The project uses the Compatibility renderer and has no external assets, add-ons, audio, network or save dependencies.

## Validation

- tests/rules_test.gd checks rotations, overlap and boundary rejection, unstable-load recovery, all three authored layouts, exact campaign scoring and restart behavior.
- tests/game_smoke_test.gd checks scene construction, all touch controls and runtime placement/rotation/undo.

The prototype is a deterministic grid-based center-of-mass puzzle, not a rigid-body physics simulation. Local rendered GUI, GPU and physical iPhone QA require a device/runtime and are not implied by headless CI.

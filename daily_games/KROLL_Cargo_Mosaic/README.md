# KROLL Cargo Mosaic M0.1

A tactile polyomino freight-bay packing game for Godot 4.3+.

## Objective

Place four distinct four-cell modules (ION, FORK, HOOK and CORE) onto the sixteen illuminated cells in each 6x6 bay. Every illuminated cell must be covered exactly once. Dark cells are blocked; overlap, out-of-board placement and repeated module placement are rejected.

Three authored bays are included: Dockside Matrix, Fracture Bay and Orbital Hold. Each has a valid exact-cover solution; alternate valid packings are accepted when they cover the same mask without overlap.

## Controls

- 1–4: select a cargo module; selecting a placed module lifts it back to the tray.
- Q / E: rotate the selected module left / right.
- Arrow keys: move the placement anchor.
- Enter: place the selected module at the anchor.
- Backspace: lift the most recently placed module.
- R: reset the current bay.
- N: advance after a bay is solved.
- Tap a signalled board cell to place; tap an occupied cell to lift its module.
- On-screen buttons support mouse and touch.

## Import and tests

Open this folder's project.godot in Godot Project Manager (Godot 4.3 or newer). No external assets, audio, plugins or network access are required.

- tests/rules_test.gd validates geometry, bounds, blocked cells, overlap, duplicate placement, removal and all three authored solutions.
- tests/game_smoke_test.gd instantiates the root scene, exercises rejection and completes all three bays.

Headless validation does not replace manual graphical or iPhone device testing.

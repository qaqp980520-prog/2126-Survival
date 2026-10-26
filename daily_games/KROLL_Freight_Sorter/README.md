# KROLL Freight Sorter — Godot 4

A self-contained 60-second cargo-sorting arcade game for the KROLL universe. No external assets or plugins are required.

## Run
1. Open this folder in Godot 4.3 or newer.
2. Run main.tscn or press F6 with the main scene open.
3. Sort incoming cargo before its 2.8-second timer expires.

## Controls
- A or 1: route raw ore to the ore bay.
- S or 2: route medical supplies to the medical bay.
- D or 3: route data cores to the data bay.
- Space: quarantine a hazard crate.
- R: restart after the shift ends.

Correct cargo earns points and builds a combo. Each wrong route or missed crate costs one life. You have three lives and 60 seconds.

## Validation
The repository CI imports the project, runs tests/rules_test.gd, and launches a headless scene smoke test. A CI pass validates parsing and the tested game logic, not manual visual or iPhone touch testing.

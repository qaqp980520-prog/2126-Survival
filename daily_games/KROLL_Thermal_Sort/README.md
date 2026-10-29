# KROLL Thermal Sort M0.1

A deterministic temperature-routing game built with Godot 4.3+ and no external assets or add-ons.

## Play

Open this folder's `project.godot` in Godot Project Manager.

- A / Left Arrow: route to COLD (temperature <= -10 C)
- S / Down Arrow: route to STABLE (-9 C through 9 C)
- D / Right Arrow: route to HOT (temperature >= 10 C)
- R: restart the current seed
- N: move to the next deterministic seed

Each shift contains 12 canisters. The third misroute ends the shift. A clean shift is winnable on seeds 101, 202, and 303. Mouse and touch are supported through the on-screen buttons.

## Files

- `main.tscn`: UI scene
- `main.gd`: keyboard, button and rendering logic
- `rules.gd`: deterministic rules/state transitions
- `tests/rules_test.gd`: boundaries, invalid input, three layouts and terminal-state tests
- `tests/game_smoke_test.gd`: scene instantiation and full-shift smoke test

## Limits

This is a self-contained arcade prototype, not connected to the main survival inventory or world economy. Local GUI/device testing is separate from headless CI.

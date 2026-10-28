# KROLL Cargo Crane M0.1

A deterministic stacking arcade game for Godot 4.3+.

## Goal

Stack six containers on the base. Move the crane hook horizontally, then release the current load. A load must overlap the top support by at least 35% (minimum 24 px), and the resulting center must stay within the stability envelope. A miss or excessive center drift ends the run.

## Controls

- A / Left Arrow: move the hook left.
- D / Right Arrow: move the hook right.
- Space: drop the current load.
- R: restart the current manifest.
- N: next deterministic manifest.
- On-screen LEFT / RIGHT / DROP / RESET / NEXT buttons support mouse and touch.

## Import

Open `project.godot` in Godot 4.3 or newer. No external assets or add-ons are required.

## Tests

- `tests/rules_test.gd`: deterministic state, immutable rejected movement, clamping, stable stacking, miss, support narrowing, win and terminal lockout.
- `tests/game_smoke_test.gd`: scene startup, on-screen controls, six-load win, restart and next manifest.

## Limits

M0.1 is a local single-player prototype. It does not include a campaign save, sound, or a full rigid-body crane simulation.

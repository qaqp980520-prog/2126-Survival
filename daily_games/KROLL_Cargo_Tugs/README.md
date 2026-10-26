# KROLL Cargo Tugs M0.1

A standalone Godot 4.3+ warehouse-pushing puzzle. Move the tug unit and push cargo crates onto every green docking pad. Complete three shifts with one, two, then three crates. Crates cannot be pulled or pushed through walls, and the undo command restores both player and cargo positions.

## Controls

- WASD or arrow keys: move one cell.
- Z: undo one successful move.
- R: restart the current shift.
- N: continue after solving a shift.
- On touch screens, use the four directional buttons or tap an adjacent cell.

The board, player, crates and pads are drawn procedurally. No external assets or third-party addons are required.

## Import

Open this folder's project.godot in Godot Project Manager.

## Automated validation

- Import/parse: godot --headless --path daily_games/KROLL_Cargo_Tugs --editor --quit
- Rules: godot --headless --path daily_games/KROLL_Cargo_Tugs --script res://tests/rules_test.gd
- Runtime smoke: godot --headless --path daily_games/KROLL_Cargo_Tugs --script res://tests/game_smoke_test.gd

Automated headless validation does not replace graphical manual play or iPhone device testing.

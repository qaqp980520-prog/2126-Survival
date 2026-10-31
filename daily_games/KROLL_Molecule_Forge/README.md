# KROLL Molecule Forge M0.1

A compact grid-based molecular construction puzzle for Godot 4.3+.

## Goal

Build three stable molecules in order:

1. Water — H2O (2 bonds)
2. Ammonia — NH3 (3 bonds)
3. Methane — CH4 (4 bonds)

Atoms bond automatically to orthogonally adjacent atoms. Hydrogen has valence 1, oxygen 2, nitrogen 3 and carbon 4. A placement that exceeds either atom's valence is rejected without changing the board. A molecule is verified only when the exact formula is present, every atom is connected, the target bond count is reached and every atom's valence is satisfied.

## Controls

- 1 / 2 / 3 / 4: select H / O / N / C
- Arrow keys or WASD: move the board cursor
- Space: place the selected atom
- Backspace or Delete: remove the atom at the cursor
- U: undo the last accepted board edit
- R: reset the current molecule
- N: advance after a molecule is verified
- Mouse / touch: select an atom chip, then tap a grid cell to place it
- Right mouse button: remove an atom from a grid cell

## Import

Open project.godot in Godot 4.3 or newer, or launch this project from the 2126 Survival Test Hub. No external assets, audio, plugins or network access are required.

## Files

- main.gd / main.tscn: UI, input and board interaction
- rules.gd: pure valence, adjacency, formula and connectivity model
- tests/rules_test.gd: deterministic molecule and rejection tests
- tests/game_smoke_test.gd: scene, touch, undo and campaign smoke test

M0.1 uses a 2D orthogonal single-bond model for the puzzle mechanic; it is not a chemistry simulator and does not model bond order, geometry or charge.

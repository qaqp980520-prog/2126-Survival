# KROLL Signal Sleuth M0.1

A five-by-five nonogram-style deduction puzzle. Use the row and column run-length clues to reveal one of three deterministic pixel patterns. The player has 60 cell changes; correct filled cells reveal the pattern, while incorrect filled cells prevent a win.

## Import and controls

Open project.godot from Godot Project Manager. Requires Godot 4.3 or newer. No external art, audio, plugins or network access.

- Click/tap a cell to cycle unknown → filled → marked empty.
- Arrow keys move the selection; Space marks the selected cell.
- R restarts the current grid; N advances to the next deterministic grid.
- The game is designed around generated UI, so it runs without downloaded assets.

## Files

- project.godot, main.tscn, main.gd: project setup, scene and UI.
- rules.gd: deterministic puzzle selection, clue generation, move budget and win/loss state.
- tests/rules_test.gd: clue correctness, seed determinism, invalid coordinates, mark cycling, win lock, move limit and puzzle rotation.
- tests/game_smoke_test.gd: headless UI construction and input wiring.

## Validation

The repository Godot 4.3 workflow imports the project, runs the rules suite and launches a headless runtime smoke test. CI does not imply local GUI, GPU or iPhone hardware playtesting.

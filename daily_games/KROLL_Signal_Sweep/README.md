# KROLL Signal Sweep — Godot 4 mini-game

A compact search-and-deduction game for the Daily Handcrafted Game Plan.

## Play
1. Open this folder in Godot 4.2+.
2. Press F5 to run the project.
3. Choose a difficulty, then click/tap grid cells to scan. Empty cells show the Manhattan distance to the nearest hidden data core; CORE marks a recovered core.
4. Recover all cores within the scan quota. Use 重新部署 to start a fresh randomized run.

## Difficulty
- Easy: 2 cores, 30 scans.
- Normal: 3 cores, 22 scans.
- Hard: 4 cores, 18 scans.

## Controls
- Mouse/touch: tap a grid cell to scan.
- Difficulty selector: starts a fresh round at the chosen difficulty.
- 重新部署: reset and randomize target locations.

## Tests
Run these commands from this project folder:
```sh
godot --headless --path . --script res://tests/rules_test.gd
godot --headless --path . --script res://tests/game_smoke_test.gd
```

## Validation status
Godot 4.3 headless CI passed on 2026-10-25 in run #13:
- Project import/parser check
- Game rule tests
- Runtime smoke test: scene startup, 64-cell grid, normal difficulty, scan counting, repeated-scan protection
- Shared inventory save validation
- Inventory save adapter regression tests

See [CI run #13](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40208274953). This is headless engine validation; manual iPhone/touch layout verification remains recommended.

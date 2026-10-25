# KROLL Signal Sweep — Godot 4 mini-game

A compact search-and-deduction game for the Daily Handcrafted Game Plan.

## Play
1. Open this folder in Godot 4.2+.
2. Press F5 to run the project.
3. Click grid cells to scan. Empty cells show the Manhattan distance to the nearest hidden data core; CORE marks a recovered core.
4. Recover all 3 cores within 22 scans. Use 重新部署 to start a fresh randomized run.

## Controls
- Mouse/touch: tap a grid cell to scan.
- 重新部署: reset and randomize the three data-core positions.

## Validation
Static file and logic review only. Godot 4 is not installed in the current build environment, so this project has not been engine-run or parser-tested here. The UI is generated from code at runtime; check the first engine run for layout/parser issues before treating the build as validated.

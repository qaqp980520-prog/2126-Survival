# KROLL Raster Survey M0.1

A six-by-six nonogram survey puzzle with three authored scan sites. Use row and column run clues to reconstruct each raster image.

## Controls

- Left click / tap a cell: fill or clear it.
- Right click: mark the cell empty.
- Arrow keys: move selection.
- Space: fill selected cell.
- X: mark selected cell empty.
- Backspace/Delete: clear selected cell.
- R: reset the current site.
- N: advance after solving a site.
- On-screen FILL / EMPTY / CLEAR / RESET / NEXT buttons support touch-only play.

## Sites

1. Delta Relay
2. Basalt Archive
3. Ice Shelf

A site is solved only when all 36 cells are explicitly marked and match the authored scan. Unknown cells never count as empty.

## Dependencies and import

- Godot 4.3 or newer.
- No external assets, audio, plugins or network dependencies.
- Standalone: open this folder's project.godot.
- Root integration: launch main_root.tscn from the Survival Test Hub.

## Tests

From the standalone project root:

- godot --headless --path . --editor --quit
- godot --headless --path . --script res://tests/rules_test.gd
- godot --headless --path . --script res://tests/game_smoke_test.gd

The root Survival Test Hub smoke test separately verifies root-path loading.

## Limitations

M0.1 uses fixed authored 6x6 scans. No save campaign, generated puzzles, audio, animations or scoring system is included.

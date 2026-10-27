# KROLL Star Chart Expedition M0.1

A standalone Godot 4.3+ turn-based grid navigation puzzle. Recover three survey beacons and reach the extraction gate before time or fuel runs out.

## Controls
- WASD / arrow keys: move one tile.
- Tap/click an adjacent tile: move one tile.
- R: restart the mission.

## Rules
- Board: 7x7; start at (0,3), extraction at (6,3).
- Fuel starts at 34; every successful move costs one unit.
- Asteroids and board boundaries block movement without consuming fuel.
- Three fixed survey beacons must be collected before extraction.
- 90-second time limit.
- No external art, fonts, audio, or third-party plugins.

## Open
Use Godot 4.3+ Project Manager and import this folder's project.godot.

## Tests
Run the root repository's Godot validation workflow, or locally:
- `godot --headless --path daily_games/KROLL_Star_Chart_Expedition --script res://tests/rules_test.gd`
- `godot --headless --path daily_games/KROLL_Star_Chart_Expedition --script res://tests/game_smoke_test.gd`

## Known limits
One authored map, no save/load, audio, procedural maps, or manual iPhone test yet.

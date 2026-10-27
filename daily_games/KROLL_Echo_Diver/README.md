# KROLL Echo Diver M0.1

A small top-down sonar-navigation game for Godot 4.3+.

## Goal
Collect all three data beacons and reach the extraction gate before the 75-second timer or fuel supply runs out.

## Controls
- **WASD** or arrow keys: move one tile.
- **E** or **Space**: pulse sonar.
- Click/tap a neighbouring tile: move one tile.
- Click/tap **Pulse Sonar**: reveal nearby hazards for 2.4 seconds.
- **R** or the on-screen restart button: restart.

## Mechanics
- Board: 8×7.
- Initial fuel: 32.
- Each successful step costs 1 fuel.
- Hidden hazards cost an additional 4 fuel when entered.
- Sonar has four charges; each pulse reveals hazards within Manhattan radius 3 for 2.4 seconds.
- Walls and board edges block movement.
- All three beacons are required before extraction.

## Import
Open the project.godot file in Godot 4.3 or newer. No third-party addons or external art assets are required.

## Validation
The repository CI imports the project, runs tests/rules_test.gd, and runs tests/game_smoke_test.gd headlessly.

## Known limits
The board is fixed; there is no save system, audio, procedural map generation, or device-level touch QA yet. Headless CI is not a substitute for a manual visual playtest or iPhone hardware test.

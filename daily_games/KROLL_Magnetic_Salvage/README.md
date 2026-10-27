# KROLL Magnetic Salvage M0.1

A code-drawn Godot 4 mini-game about collecting metal scrap with a short-range magnetic pulse and returning to the extraction dock.

## Import
Open `project.godot` in Godot Project Manager (Godot 4.3+). No addons, external art, or audio files are required.

## Controls
- WASD / arrow keys: move the salvage drone.
- Left mouse click: pulse the magnet.
- Space: attempt extraction.
- R: restart.
- Bottom touch controls: nudge, pulse, dock, restart.

## Rules
Collect at least six of eight metal parts, then move into the glowing dock ring and extract before 75 seconds expire. Each pulse consumes charge; collecting metal refunds one charge. Charge regenerates slowly over time. Red debris fields drain one charge and return the drone to the launch point.

## Tests
- `tests/rules_test.gd`: deterministic movement, pulse, collection and extraction rules.
- `tests/game_smoke_test.gd`: scene initialization, collection, extraction and restart.

CI validation uses Godot 4.3 headless. GUI and iPhone hardware playtesting remain separate, not claimed by headless tests.

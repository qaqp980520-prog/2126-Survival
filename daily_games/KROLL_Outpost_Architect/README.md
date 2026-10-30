# KROLL Outpost Architect M0.1

A deterministic outpost-building puzzle for Godot 4.3+.

## Import

Open project.godot in Godot Project Manager. No external assets, plugins, audio files, or network access are required.

## Goal

Place eight modules on the 5×5 grid. Keep within the 18-energy budget, include Power, Water, Greenhouse, and Habitat, and reach the scenario target score.

## Modules

| Module | Energy | Base score | Adjacency effect |
|---|---:|---:|---|
| Power | 0 | 1 | +1 for each adjacent non-Power module |
| Water | 2 | 2 | +2 for each adjacent Greenhouse |
| Greenhouse | 2 | 3 | +1 for each adjacent Habitat |
| Habitat | 3 | 2 | +1 for each adjacent Power |
| Workshop | 3 | 4 | +1 for each adjacent Relay |
| Relay | 2 | 2 | No adjacency bonus |

Only orthogonal neighbors count. A layout is won after the eighth placement when all four essential module types are present and the target score is reached.

## Controls

- Select a hand card with its button or keys 1–3.
- Select an empty grid cell with a click/touch, or move keyboard focus with the arrow keys and press Enter/Space.
- R restarts the current layout.
- N advances to the next layout.

## Determinism

Three authored decks are fixed in source. There is no random generation, external service, or persistent save requirement in M0.1.

## Tests

- tests/rules_test.gd: layout routes, exact scores, energy accounting, turn limits, invalid indices, occupied cells, and insufficient energy.
- tests/game_smoke_test.gd: real scene creation, hand/button signals, placement, restart, and layout advance.

Run with Godot 4.3+:
- godot --headless --path daily_games/KROLL_Outpost_Architect --editor --quit
- godot --headless --path daily_games/KROLL_Outpost_Architect --script res://tests/rules_test.gd
- godot --headless --path daily_games/KROLL_Outpost_Architect --script res://tests/game_smoke_test.gd

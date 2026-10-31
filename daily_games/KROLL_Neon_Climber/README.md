# KROLL Neon Climber M0.1

A three-sector 2D side-scrolling platformer prototype.

## Gameplay

- Recover three data cores in each sector.
- Reach the checkpoint beacon to update the respawn position.
- Avoid laser hazards; falling or touching a hazard returns the player to the latest checkpoint.
- Double jump and a short horizontal dash help cross gaps.
- The exit unlocks only after all three cores are recovered.

## Controls

- A / D: move left / right
- Space / W / Up: jump (double jump supported)
- X: dash
- R: restart current sector
- N: next sector after completion
- On-screen LEFT / RIGHT / JUMP / DASH buttons support touch input.

## Sectors

1. Maintenance Shaft
2. Reactor Scaffold
3. Signal Tower

## Import

Open this folder as a standalone Godot 4.3+ project, or run the scene from the root 2126 Survival project after the files are added to its Test Hub.

No external assets, plugins, audio or network dependencies are required.

## Tests

- `tests/rules_test.gd`: level geometry, core identity, checkpoints, hazard counter, exit lock and progression.
- `tests/game_smoke_test.gd`: scene/player creation, collection, checkpoint respawn, exit completion, next sector and reset.

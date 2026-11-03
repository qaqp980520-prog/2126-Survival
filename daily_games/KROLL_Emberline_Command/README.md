# KROLL Emberline Command

A turn-based wildfire-containment tactics game for Godot 4.3.

## Gameplay

Protect three relay stations across three 8x8 fire-response maps. Each turn provides two response actions:

- FIREBREAK: spend one kit to remove fuel from a frontline grass/forest cell, creating a permanent barrier.
- WATER: spend one drop to extinguish the selected burning cell and wet adjacent flammable cells for two spread checks.
- END TURN: advance the deterministic wind-driven fire front.

Fire spreads downwind and, from high-fuel cells, to one alternating crosswind neighbor. Burning cells consume fuel each turn. A fire reaching a relay destroys its integrity and fails the mission. Contain every active fire before the turn limit.

## Controls

- Arrow keys / WASD: move the selected cell.
- F: place a firebreak.
- V: drop water on the selected active fire.
- Enter: end the turn.
- N: advance after a successful mission.
- R: restart the campaign.
- Touch/mouse: tap a board cell and use the on-screen controls.

## Project

- Standalone entry: project.godot → main.tscn.
- Root Test Hub entry: main_root.tscn.
- Rules: rules.gd.
- Tests: tests/rules_test.gd and tests/game_smoke_test.gd.
- No external assets, plugins, network services or save-schema changes.

Open daily_games/KROLL_Emberline_Command/project.godot in Godot 4.3, import the project, then run the main scene. The repository Survival Test Hub also contains a launch button.

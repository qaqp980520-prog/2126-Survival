# KROLL Shadow Courier M0.1

A deterministic turn-based stealth grid game. Recover three data shards, avoid rotating patrol sight lines, and reach extraction.

## Requirements and import

- Godot 4.3 or newer.
- Open `project.godot` through Godot Project Manager.
- No external assets, audio, plugins, add-ons, or network access.

## Controls

- WASD / Arrow keys: move one tile.
- Space: wait one turn.
- E: deploy a decoy to distract the nearest patrol.
- R: reset the current mission.
- N: advance to the next mission.
- On-screen directional, WAIT, DECOY, RESET, and NEXT buttons support mouse and touch.

## Rules

- Three authored 8×8 missions.
- Recover every cyan data shard before entering the green extraction tile.
- Amber tiles are currently watched by a patrol.
- Patrols rotate clockwise after each player action.
- Walls block both movement and sight.
- Two decoys are available per mission; each distracts the nearest patrol for two guard phases.
- Touching a patrol or entering its active sight line ends the mission.

## Files

- `main.gd`: board rendering, keyboard input, and touch controls.
- `rules.gd`: deterministic mission state and stealth rules.
- `tests/rules_test.gd`: pure rules and edge-case tests.
- `tests/game_smoke_test.gd`: scene, button, and keyboard smoke test.

## Known limits

M0.1 uses fixed patrol positions and authored maps. It has no save campaign, audio, multiplayer, procedural generation, or device haptics.

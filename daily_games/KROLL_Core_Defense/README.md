# KROLL Core Defense — M0.1

A standalone, asset-free Godot 4 tower-defense prototype. It is intentionally different from recent stealth, signal-grid, convoy and lander games.

## Run
1. Open this folder in Godot Project Manager.
2. Use Godot 4.3 or newer.
3. Press F6/F5 or run `Main.tscn`.

## Controls
- Left-click an empty board tile to build a turret (35 credits).
- Drones follow the gold route. Turrets automatically target drones in range.
- Each neutralized drone returns 10 credits.
- Survive three waves; leaked drones damage the core.
- Press R to restart after victory or defeat.

## Files
- `project.godot`: standalone project configuration.
- `Main.tscn`, `main.gd`: playable game and procedural drawing.
- `rules.gd`: deterministic board/build/wave rules.
- `tests/rules_test.gd`: rule unit tests.
- `tests/game_smoke_test.gd`: scene initialization smoke test.

## Dependencies
Godot 4.3+ only; no addons, external textures, fonts, or network calls.

## Validation status
The repository's Godot 4.3 GitHub Actions workflow will import the project and run the rule and scene smoke tests for this branch/PR. The local environment used to prepare this change does not have a Godot executable, so no local engine run or manual playtest is claimed. iPhone touch support is not implemented in this prototype.

## Known limits
The route and enemy waves are fixed; there are no upgrade trees, sound effects, or saved scores. Tower targeting applies damage in range rather than simulating projectile travel.

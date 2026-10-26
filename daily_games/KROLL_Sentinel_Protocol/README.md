# KROLL Sentinel Escape M0.1

A self-contained top-down arcade survival game for Godot 4.3+. Collect eight energy cells while avoiding KROLL security drones for 45 seconds.

## Controls
- WASD / arrow keys: move.
- Space: short dash with cooldown.
- Mobile: drag on the left half to move; tap the right half to dash toward that point.
- R: redeploy after victory, defeat, or timeout.

## Rules
- Start with 3 core integrity.
- Collect 8 energy cells before the 45-second extraction window closes.
- Contact with a red security drone costs one integrity.
- Dash grants a brief movement burst and has a 1.4-second cooldown.
- No external assets, fonts, plugins, weapons, or third-party libraries.

## Open
Use Godot Project Manager to open `daily_games/KROLL_Sentinel_Protocol/project.godot`.

## Tests
```sh
godot --headless --path daily_games/KROLL_Sentinel_Protocol --editor --quit
godot --headless --path daily_games/KROLL_Sentinel_Protocol --script res://tests/rules_test.gd
godot --headless --path daily_games/KROLL_Sentinel_Protocol --script res://tests/game_smoke_test.gd
```

CI validation is the engine test source until manual GUI and iPhone playtests are available.

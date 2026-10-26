# KROLL Sentinel Protocol M0.1

A self-contained top-down arena survival shooter for Godot 4.3+. Hold out for 45 seconds while KROLL security drones pursue the player.

## Controls
- WASD / arrow keys: move.
- Mouse: aim.
- Hold left mouse or Space: fire.
- Mobile: drag on the left half to move; touch/drag on the right half to aim and fire.
- R: redeploy after victory or defeat.

## Rules
- 3 core integrity.
- Each drone eliminated gives 10 points.
- Survive 45 seconds to secure the sector.
- Three hits end the run.
- No external assets, fonts, plugins, or third-party libraries.

## Open
Use Godot Project Manager to open `daily_games/KROLL_Sentinel_Protocol/project.godot`.

## Tests
```sh
godot --headless --path daily_games/KROLL_Sentinel_Protocol --editor --quit
godot --headless --path daily_games/KROLL_Sentinel_Protocol --script res://tests/rules_test.gd
godot --headless --path daily_games/KROLL_Sentinel_Protocol --script res://tests/game_smoke_test.gd
```

CI validation is the authoritative engine test until manual GUI and iPhone playtests are available.

# KROLL Orbital Convoy — Godot 4

A compact arcade navigation game, different from the recent grid-deduction and stealth prototypes.

## Goal

Recover six floating cargo cells before 75 seconds expire. Avoid moving asteroids; three hull points are available. Recovering all cargo wins the run. Losing all hull or running out of time ends the run.

## Controls

- WASD or arrow keys: direct movement.
- Mouse click or touch: set a destination and let the ship glide toward it.
- R: restart at any time.
- After a win/loss, click/touch or press R to start a new run.

## Import and run

1. Install Godot 4.3 or a compatible Godot 4 release.
2. Open this folder (project.godot) in the Godot Project Manager.
3. Let the editor import the project, then run the project.

No external assets or add-ons are required. The game uses procedural shapes and a built-in font for its HUD. The project targets the GL Compatibility renderer for broader desktop/mobile support; touch input is supported, but iPhone layout and performance still need manual device checks.

## Tests

    godot --headless --path daily_games/KROLL_Orbital_Convoy --editor --quit
    godot --headless --path daily_games/KROLL_Orbital_Convoy --script res://tests/rules_test.gd
    godot --headless --path daily_games/KROLL_Orbital_Convoy --script res://tests/game_smoke_test.gd

Local build environment has no Godot executable, so no local engine run is claimed. CI status is tracked in the associated GitHub pull request. ZIP integrity or static checks are not substitutes for an engine test.

## Known limits

- No audio, persistent score, upgrades, or save system.
- Asteroids and cargo use procedural circles/diamonds, not final art.
- Touch control is tap-to-move; no virtual joystick yet.

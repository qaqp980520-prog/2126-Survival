# KROLL Gravity Lander — Godot 4

A compact physics landing game. This is deliberately different from the recent signal-deduction, stealth, and orbital collection games.

## Objective

Land the KROLL lunar lander on the green platform before 75 seconds expire. The craft starts with 100% fuel. A successful landing must be inside the platform and below both horizontal and vertical speed limits.

## Controls

- A / D or Left / Right: side thrusters.
- W / Up / Space: main thruster.
- R: restart.
- On touch screens, hold the lower-left zone to steer left, the lower-middle zone to thrust, and the lower-right zone to steer right.

## Import and run

1. Install Godot 4.3 or a compatible Godot 4 release.
2. Open this folder in Godot Project Manager by selecting project.godot.
3. Wait for import, then run the project.

No external assets, plug-ins, or network services are required. Graphics are generated with built-in drawing primitives.

## Tests

    godot --headless --path daily_games/KROLL_Gravity_Lander --editor --quit
    godot --headless --path daily_games/KROLL_Gravity_Lander --script res://tests/rules_test.gd
    godot --headless --path daily_games/KROLL_Gravity_Lander --script res://tests/game_smoke_test.gd

CI is the intended engine test path in this environment. Local Godot is unavailable here, so do not treat static inspection as a local runtime pass. iPhone touch feel and device performance still require a physical-device check.

## Known limits

- No score persistence, upgrades, sound, or save system.
- The lander is drawn procedurally rather than using final art.
- The touch controls are large screen zones rather than a virtual joystick.

# KROLL Tether Recovery M0.1

A self-contained Godot 4 top-down salvage-towing game. Pilot a small recovery drone, attach one cargo pod at a time with a tether, avoid mine hazards, and tow all three pods into the KROLL dock.

## Import
Open project.godot with Godot 4.3 or newer. No external assets, audio, plugins, network access or addons are required.

## Controls
- W / A / S / D: thrust in four directions.
- Shift: brake inertial drift.
- Space: attach the nearest cargo pod or release the current tether.
- R: reset the current mission.
- N: advance to the next authored mission.
- On-screen buttons provide mouse and touch controls.

## Files
- main.tscn and main.gd: playable arena, drawing and input.
- rules.gd: deterministic thrust, inertia, tether tension, hazard collision, hull and docking rules.
- tests/rules_test.gd: movement, braking, tether, delivery, hazard, reset and progression tests.
- tests/game_smoke_test.gd: actual scene and button-signal smoke test.

## Limitations
M0.1 uses deterministic manual 2D integration, not a rope physics joint. It has three authored missions, no persistent campaign score, audio, multiplayer or haptics.

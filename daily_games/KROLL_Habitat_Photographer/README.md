# KROLL Habitat Photographer M0.1

A timing-and-observation field photography game for Godot 4.3+.

## Gameplay
Track a moving animal in three habitats, calibrate focus, zoom and exposure from the neutral F3 / Z2 / E0 camera profile using the visible field brief, then take the photo while the subject is centered and unobscured. Each successful habitat photo awards 100 points once. A completed habitat cannot be reset to farm score.

The animal follows a deterministic triangular patrol path. The central viewfinder tolerance is 0.085 normalized screen units. Each habitat defines its own required focus, zoom, exposure and foliage-obscuration interval.

## Controls
- Q / E: focus down / up
- W / S: zoom in / out
- A / D: exposure down / up
- Space / Enter: shutter
- R: reset an uncleared field station
- N: advance after a successful photo
- On-screen buttons: all settings and actions are available by mouse and touch

## Import
- Standalone: open this folder in Godot 4.3+ and run main.tscn.
- Repository Test Hub: open the repository root project and choose KROLL Habitat Photographer; the hub loads main_root.tscn.
- No external assets, plugins, network access or audio dependencies.

## Validation
- tests/rules_test.gd: exact capture windows, obscuration, framing, focus, zoom, exposure, invalid stages and non-finite time.
- tests/game_smoke_test.gd: root scene, all three habitats, scoring integrity, campaign completion and restart.
- Local GUI/GPU/device QA is separate from cloud headless validation.

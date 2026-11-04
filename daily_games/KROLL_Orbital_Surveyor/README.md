# KROLL Orbital Surveyor M0.1

A standalone Godot 4.3+ turn-based exploration and battery-routing game.

## Gameplay

- Three authored 7x7 survey sectors.
- Navigate a rover through open ground, rough terrain and rock formations.
- Rough terrain costs two battery units; ordinary ground costs one.
- Scan beacons A, B and C, then return to the base tile to complete a sector.
- Each scan costs one battery unit.
- Running out of battery before returning to base fails the current campaign.
- Each sector awards exactly 100 campaign points once; maximum score is 300.
- The next sector unlocks only after the rover returns to base with all three beacons scanned.

## Controls

- W / Up: move north.
- S / Down: move south.
- A / Left: move west.
- D / Right: move east.
- Space: scan the beacon under the rover.
- N: advance after a successful sector.
- R: restart the campaign.
- On-screen movement and scan buttons support pointer and touch input.

## Import

Open project.godot in Godot 4.3+ and run main.tscn. The project uses the Compatibility renderer and has no external assets, plugins, audio, network or save dependencies.

## Tests

- tests/rules_test.gd covers map bounds, rock collision, rough-terrain battery cost, beacon scan restrictions, battery depletion, three authored campaign routes and one-time rewards.
- tests/game_smoke_test.gd imports the scene, checks touch controls, executes the full three-sector campaign and verifies the 300-point cap.

This is a standalone prototype and is not registered in the Survival Test Hub in M0.1.

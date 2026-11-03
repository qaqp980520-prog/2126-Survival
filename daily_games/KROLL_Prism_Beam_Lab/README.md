# KROLL Prism Beam Lab M0.1

A deterministic 7×7 optical-routing puzzle. Rotate four mirrors in each facility, then fire a beam from the emitter to the receiver without crossing a wall or leaving the board.

## Campaign

- Service Bend
- Coolant Bypass
- Vertical Relay

Each level has one unique mirror-orientation solution. Rotations consume moves; solving within the level's par earns 100 points, otherwise 75. Each facility awards points only once, so the campaign maximum is 300.

## Controls

- Click a mirror tile to rotate it.
- Keys 1–4 rotate the corresponding mirror.
- Space fires the beam.
- R resets the current unfinished level.
- N advances after a successful level.
- C restarts the campaign.

## Import

Open `project.godot` in Godot 4.3+ and run `main.tscn`. No external assets, plugins, network access or world-save integration are required.

## Tests

From this project root:

```sh
godot --headless --path . --script res://tests/rules_test.gd
godot --headless --path . --script res://tests/game_smoke_test.gd
```

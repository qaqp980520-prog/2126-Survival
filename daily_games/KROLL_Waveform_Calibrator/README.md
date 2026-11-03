# KROLL Waveform Calibrator M0.1

A three-relay signal-matching puzzle. Adjust frequency, amplitude, phase and DC offset until the cyan waveform matches the amber reference.

## Campaign

- Carrier Lock
- Deep Relay
- Thermal Echo

Each relay has a unique solution in the bounded setting space. Calibration is evaluated by sampled root-mean-square waveform error. A relay awards 100 points at or below par moves, otherwise 75; each relay awards once, for a 300-point campaign cap.

## Controls

- A / D: decrease / increase frequency
- S / W: decrease / increase amplitude
- Q / E: decrease / increase phase
- Z / C: decrease / increase offset
- Space: calibrate
- R: reset current unsolved relay
- N: advance after a successful relay
- X: restart campaign

Mouse/touch users can use the on-screen plus/minus buttons and action buttons.

## Import

Open `project.godot` in Godot 4.3+ and run `main.tscn`. No external assets, plugins, network access or world-save integration are required.

## Tests

From this project root:

```sh
godot --headless --path . --script res://tests/rules_test.gd
godot --headless --path . --script res://tests/game_smoke_test.gd
```

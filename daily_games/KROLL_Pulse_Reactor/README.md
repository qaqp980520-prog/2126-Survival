# KROLL Pulse Reactor M0.1

A standalone Godot 4.3+ rhythm/timing game. Keep the three reactor relays synchronized by pressing the correct lane key close to each visual pulse.

## Gameplay

- Three authored relays: Coolant Loop (72 BPM), Turbine Array (90 BPM), Core Synchronizer (108 BPM).
- Twelve beats per relay and three lanes.
- Perfect window: ±0.10 seconds; Good window: ±0.22 seconds.
- Correct lane is required. Wrong lane, late input or missed pulse increments the miss count.
- A relay clears with at least ten hits and no more than two misses.
- Individual beats affect timing quality/combo only; campaign score is awarded after a relay clear.
- Each relay grants 100 points once, even if replayed; campaign maximum is 300.
- A live countdown label and pulse-window meter provide visual timing; the metronome is visual only and uses no audio. No external assets, plugins, network services or save integration.

## Controls

- A / S / D: left / center / right lane.
- R: retry current relay.
- N: advance after a successful relay.
- C: restart the full campaign.
- Pointer/touch: use the three large lane buttons and on-screen actions.

## Import

Open `project.godot` in Godot 4.3+ and run `main.tscn`. The project uses the Compatibility renderer and has no external dependencies.

## Tests

- `tests/rules_test.gd`: deterministic lane, timing-window, validation and relay-clear rules.
- `tests/game_smoke_test.gd`: scene import, visible controls, full first-relay completion, one-time score and campaign progression.

The project is standalone and is not registered in the Survival Test Hub in M0.1.

# KROLL Thermal Glider M0.1

A 2D glider flight-and-landing challenge for Godot 4.3+.

## Objective

Fly through three survey beacons, use thermal columns to recover battery and lift, then land on the runway inside the safe speed, pitch and altitude window. Three deterministic courses are included: Coastal Thermals, Ridge Crossing and Floodplain Wind.

## Controls

- W / Up: nose up
- S / Down: nose down
- Space: short boost (consumes battery)
- Shift: airbrake
- R: restart current course
- N: next course
- On-screen buttons support touch input.

## Flight model

Pitch changes lift; forward speed creates baseline lift; thermals add localized updraft and recharge the assist battery. A long stall, ground/ceiling strike, missed beacon route or unsafe runway approach ends the flight. A valid landing requires all three beacons and a bounded speed, vertical speed, pitch and runway-height window.

## Files

- `project.godot`, `main.tscn`: standalone Godot project.
- `main.gd`: flight display, input and UI.
- `rules.gd`: deterministic flight model and course definitions.
- `daily_games/KROLL_Thermal_Glider/main.gd`: root-project script shim.
- `tests/rules_test.gd`: physics, thermal, checkpoint and landing tests.
- `tests/game_smoke_test.gd`: scene/runtime and input smoke test.

No external assets, plugins, audio or network services are required. Open `project.godot` in Godot Project Manager.

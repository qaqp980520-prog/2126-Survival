# KROLL Atmosphere Lab M0.1

A deterministic weather-station balancing puzzle for Godot 4.3+.

## Gameplay

Tune four instruments to match each station's target forecast while keeping the calculated storm load below the station limit. Every ±5 adjustment consumes one action.

Stations:
1. Coastal Front
2. Desert Thermal
3. Polar Calm

## Controls

- Click or tap each instrument's −5 / +5 buttons.
- Keyboard 1–4 selects temperature, humidity, pressure or wind.
- Left / Right adjusts the selected instrument by −5 / +5.
- R resets the current station.
- N advances after a stable forecast.

## Import and run

Open this folder as a standalone Godot project using project.godot, or use the root Survival Test Hub entry. No external assets, plugins, audio or network dependencies.

## Tests

- tests/rules_test.gd: deterministic station, bounds, action-budget, storm-load and progression tests.
- tests/game_smoke_test.gd: scene import/runtime smoke, UI controls, adjustment and station progression.

The storm-load formula is an arcade puzzle model, not a meteorological forecast.

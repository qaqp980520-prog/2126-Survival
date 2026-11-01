# KROLL Wind Farm Dispatch M0.1

A deterministic wind-farm management game. Tune three turbines' yaw and blade pitch, serve each grid-demand window, manage battery reserve and avoid thermal trips across three arrays.

## Controls

- Select turbine: buttons or keys 1 / 2 / 3.
- Yaw: Q / E or the YAW - / YAW + buttons.
- Blade pitch: W / S or the PITCH - / PITCH + buttons.
- Commit the current weather window: Space or COMMIT ROUND.
- Reset the current array: R or RESET ARRAY.
- Advance after a successful array: N or NEXT ARRAY.
- Touch: all turbine and round controls are on-screen buttons.

## Scenarios

1. North Array — steady winds with gradual direction changes.
2. Coastal Array — stronger crosswinds and changing demand.
3. Polar Array — high-speed gusts that punish aggressive blade pitch.

Each round estimates turbine output from wind alignment and pitch. The battery automatically absorbs surplus and covers shortfalls. Turbine heat rises with aggressive pitch and wind speed; reaching the trip threshold takes that turbine offline for later rounds.

## Dependencies and import

- Godot 4.3 or newer.
- No external assets, plugins, audio or network dependencies.
- Standalone: open this folder's project.godot.
- Root integration: launch main_root.tscn from the Survival Test Hub.

## Tests

From the standalone project root:

- godot --headless --path . --editor --quit
- godot --headless --path . --script res://tests/rules_test.gd
- godot --headless --path . --script res://tests/game_smoke_test.gd

The root Survival Test Hub smoke test separately verifies root-path loading.

## Limitations

M0.1 uses three fixed four-round scenarios and a simplified deterministic turbine model. It has no campaign save, random weather, animated blades, audio, multiplayer or real-world engineering calibration. Local GUI/GPU/iPhone QA is not claimed.

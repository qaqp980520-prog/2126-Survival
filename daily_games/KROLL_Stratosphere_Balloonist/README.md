# KROLL Stratosphere Balloonist M0.1

A small Godot 4 altitude-management game. Pilot a weather balloon through three atmospheric sampling missions by spending ballast to ascend, venting envelope gas to descend, and holding through predictable wind drift.

## Controls

- Up: ascend (spends one ballast unit)
- Space: hold altitude (wind drift still applies)
- Down: descend (spends two envelope-integrity points)
- N: next mission after a successful sample
- R: restart the campaign

Three consecutive calm ticks inside the target altitude band capture a sample. Exceeding the altitude ceiling, dropping below ground, exhausting the envelope, or reaching the mission tick limit fails the flight.

## Project layout

- project.godot: standalone Godot project configuration
- main_root.tscn and main.tscn: playable entry scenes
- main.gd: responsive keyboard/touch UI
- rules.gd: deterministic altitude and campaign rules
- tests/rules_test.gd: mission, resource, scoring and failure-boundary tests
- tests/game_smoke_test.gd: scene-level runtime smoke test

## Import

Open this folder as a Godot 4 project, or run:

    godot --headless --path daily_games/KROLL_Stratosphere_Balloonist --editor --quit

No third-party assets, plugins, network access or external services are required.

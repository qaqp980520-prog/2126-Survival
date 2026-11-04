# Run 118 — KROLL Moonbase Courier M0.1

## Asset

- Path: daily_games/KROLL_Moonbase_Courier/
- Main scene: main.tscn
- Scripts: main.gd, rules.gd
- Tests: tests/rules_test.gd, tests/game_smoke_test.gd
- Engine: Godot 4.3+, Compatibility renderer.
- Dependencies: none; no external assets, plugins, audio or network.

## Gameplay

- Side-view delivery platformer with three moonbase routes.
- Walk and jump across one-way platforms, avoid heated vents, collect a parcel and deliver it to an airlock.
- Three suit charges per route; a vent hit consumes one charge, respawns at the start and returns the parcel to its pickup pad.
- Finite oxygen/time window per route.
- Keyboard, pointer and on-screen touch controls.
- Each route awards 100 points before par time or 75 after; each route awards once; campaign cap 300.

## Import

Open daily_games/KROLL_Moonbase_Courier/project.godot in Godot 4.3 or newer and run main.tscn.

## Verification

- Rules tests cover all route geometry, hazard separation, one-way landing and campaign initialization.
- Runtime smoke completes all three deliveries, checks one-time rewards, touch hit-testing and movement/jump.
- Exact-head CI is required before merge.

## Limitations

- Deterministic rectangular collision model, not a full rigid-body simulation.
- No local GUI/GPU or physical iPhone QA is claimed by headless CI.

# Run 108 Closeout — KROLL Pulse Reactor and rollback Controller lifecycle guard

Date: 2026-11-04  
Engine target: Godot 4.3+  
Feature PR: [#252](https://github.com/qaqp980520-prog/2126-Survival/pull/252)  
Merge commit: `8ed93236672c3e48e137fd16e7faa4fd1bdb387b`  
Validated feature head: `1d315ce1100c9ef5e9c966ec1b04ded7897914d3`

## Delivered game — KROLL Pulse Reactor M0.1

Path: `daily_games/KROLL_Pulse_Reactor/`

- Three-lane timing campaign: Coolant Loop (72 BPM), Turbine Array (90 BPM), Core Synchronizer (108 BPM).
- Twelve authored beats per relay; A/S/D and pointer/touch lane controls.
- Perfect window ±0.10 s; Good window ±0.22 s; at least 10 hits and no more than 2 misses to clear.
- One-time 100-point reward per relay; campaign cap 300.
- Countdown and pulse-window meter; no audio, external assets, plugins, network or save dependencies.
- Import `project.godot` in Godot 4.3+ and run `main.tscn`.

## Existing-system change

Updated `systems/MineralGridStreamingDirector.gd` rollback helpers.

- Revalidate Controller/factory readiness before and after rollback factory callbacks and after registration.
- Roll back a newly restored root if a live Controller detaches during `load_chunk()`.
- Permit cleanup through a detached-but-live Controller.
- Never call a queued/destroyed Controller during rollback; clear stale Director ownership and report incomplete rollback.
- Regression: `tests/mineral_grid_streaming_rollback_lifecycle_test.gd`.
- World-save schema remains version 1.

## Validation

- Exact-head full Godot 4.3 [#41741925844](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41741925844): 488/488 job steps successful, zero failures; Run 108 gates, checkout cleanup, container shutdown and complete-job succeeded.
- Focused Run 108 [#41741494399](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41741494399): 13/13.
- Post-merge main full [#41751450876](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41751450876): 488/488 successful.

## Limitations

Local rendered GUI/GPU and physical iPhone QA were not performed. Main branch protection remains tracked under issue #236.

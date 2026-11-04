# Run 107 Closeout — KROLL Waveform Calibrator and Synchronous Controller Lifecycle Guard

Date: 2026-11-04  
Engine target: Godot 4.3+  
Feature PR: [#251](https://github.com/qaqp980520-prog/2126-Survival/pull/251)  
Feature merge commit: `e20f81de7c0a0c4d27cdfb3b987371780f6088d9`  
Exact validated feature head: `6ccb9ccec4666f212638e462349e3575b97cb12c`

## Delivered game — KROLL Waveform Calibrator M0.1

Path: `daily_games/KROLL_Waveform_Calibrator/`

- Standalone signal-matching campaign with three relays: Carrier Lock, Deep Relay and Thermal Echo.
- Four bounded controls: frequency 1–4, amplitude 1–3, phase 0–7 and DC offset −1–1.
- Live amber reference / cyan player waveform; 128-sample root-mean-square comparison.
- Independent enumeration of all 288 possible settings found exactly one solution for each authored target. This is a supplementary model check, not a substitute for engine validation.
- One-time reward per relay: 100 at or below par, otherwise 75; campaign maximum 300.
- Keyboard: A/D frequency, W/S amplitude, Q/E phase, Z/C offset, Space calibrate, R reset, N next, X restart. On-screen buttons support pointer/touch.
- Standalone project; no external assets, plugins, network services, save integration or Test Hub entry. The existing Test Hub remains at 50 entries.

Import: open `daily_games/KROLL_Waveform_Calibrator/project.godot` in Godot 4.3+ and run `main.tscn`.

Files:
- `daily_games/KROLL_Waveform_Calibrator/project.godot`
- `daily_games/KROLL_Waveform_Calibrator/main.tscn`
- `daily_games/KROLL_Waveform_Calibrator/main.gd`
- `daily_games/KROLL_Waveform_Calibrator/rules.gd`
- `daily_games/KROLL_Waveform_Calibrator/waveform_graph.gd`
- `daily_games/KROLL_Waveform_Calibrator/tests/rules_test.gd`
- `daily_games/KROLL_Waveform_Calibrator/tests/game_smoke_test.gd`
- `daily_games/KROLL_Waveform_Calibrator/README.md`

## Delivered system change — synchronous Controller lifecycle guard

Files:
- `systems/MineralGridStreamingDirector.gd`
- `tests/mineral_grid_streaming_sync_controller_lifecycle_test.gd`
- `tests/README_run107_sync_controller_lifecycle.md`
- `.github/workflows/run105-validation.yml`
- `.github/workflows/godot-validation.yml`
- `.github/workflows/run107-validation.yml`

A shared `_controller_ready_for_sync()` check now requires the bound Controller to be a valid instance, inside the scene tree, not queued for deletion and to expose the required load/unload/query methods. Synchronous sync, recovery and async dependency checks use the same contract.

The synchronous path also revalidates after every factory callback. If the callback detaches or queues the Controller, the uncommitted candidate is released and newly registered chunks are rolled back. If the Controller has already been destroyed, the stale managed map is cleared and the report explicitly marks rollback incomplete.

Regression cases:
- Controller detached before sync and recovery.
- Controller queued for deletion before sync and recovery.
- Factory callback detaches the Controller after the entry check.
- Candidate is freed, previous managed IDs are preserved, and reattaching a detached Controller allows sync to resume.

No world-save schema or chunk serialization change; schema remains version 1.

## Exact-head validation evidence

- Full Godot 4.3 [Run #41737860767](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41737860767): **483/483 steps succeeded**, zero failures/skips. Run 107 rules test (#478), runtime smoke (#479), synchronous Controller lifecycle regression (#480), checkout cleanup (#959), container shutdown (#960) and complete-job (#961) all succeeded.
- Run 107 standalone focused [#41737860768](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41737860768): **12/12**.
- Combined Run 105–107 focused [#41737860860](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41737860860): **25/25**.
- Compatibility: Run 101 #41737860820 13/13; Run 102 #41737860808 13/13; Run 103 #41737860785 13/13; Run 104 #41737860807 13/13; Run 106 #41737860806 12/12 — **64/64** total.
- All accepted runs completed checkout cleanup, container shutdown and complete-job.

Historical test corrections:
- Run #41737279677 passed game import and rules but the smoke test searched for the nested graph as a root child; commit `1f585ca` changed it to recursive lookup.
- Run #41737486484 passed game import/rules/runtime but the system fixture used the default 64-unit chunk size, so positions 1 and 21 did not cross a chunk boundary. Commit `6ccb9ce` sets 10-unit chunks and radius 1 so the factory callback is actually exercised. Both failed predecessors remain historical and are not counted as passes.

## Git state

- PR #251 merged.
- Merge commit: `e20f81de7c0a0c4d27cdfb3b987371780f6088d9`.
- Exact validated feature head: `6ccb9ccec4666f212638e462349e3575b97cb12c`.
- Main after merge: `e20f81de7c0a0c4d27cdfb3b987371780f6088d9`.

## Post-merge main-push validation

The following workflows were triggered on the merge SHA and were in progress at the closeout check:
- Run 105–107 focused [#41739226907](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41739226907)
- Full Godot headless [#41739226795](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41739226795)
- Run 107 focused [#41739226910](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41739226910)
- Run 106 focused [#41739226792](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41739226792)

These push-triggered runs are supplementary post-merge validation and are not described as passed until their own conclusions are successful.

## Limitations and next steps

- Local Godot executable unavailable; rendered GUI/GPU and physical iPhone QA remain untested.
- Main branch protection remains unresolved under [issue #236](https://github.com/qaqp980520-prog/2126-Survival/issues/236).
- World-save schema remains version 1.
- Next: complete the post-merge push workflows, then merge the rebased Run 104–107 documentation PR only after its exact-head full CI succeeds.

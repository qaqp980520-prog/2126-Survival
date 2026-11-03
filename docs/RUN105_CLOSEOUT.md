# Run 105 Closeout — KROLL Orbital Curling and Crop Queued-Root Recovery

Date: 2026-11-03  
Engine target: Godot 4.3+  
Feature PR: [#247](https://github.com/qaqp980520-prog/2126-Survival/pull/247)  
Merge commit: `564b36cd86510af3aaa7b5c7475fc7b8f2bee909`  
Final feature head: `ded40bb1afe91dd8b403ace96f2d0c6447f3f0ed`

## Delivered game — KROLL Orbital Curling M0.1

Path: `daily_games/KROLL_Orbital_Curling/`

- Three target layouts and three stones per round.
- Deterministic 60 Hz fixed-step motion, friction, rink-wall bounce and equal-mass stone collisions.
- Target-distance scoring: 30 / 20 / 10 / 0; campaign goal 45.
- Mouse/touch drag aiming, restart and one-time round progression.
- Standalone `main.tscn` and repository-root `main_root.tscn`.
- Added to Survival Test Hub, now 50 launch buttons.
- No external assets/plugins/network dependencies.

Import: open `daily_games/KROLL_Orbital_Curling/project.godot` in Godot 4.3+ and run `main.tscn`; the root Test Hub launches `main_root.tscn`.

## Delivered system regression — crop queued-root recovery

Files:
- `tests/mineral_grid_streaming_queued_root_crop_recovery_test.gd`
- `tests/README_run105_crop_queued_root_recovery.md`
- `.github/workflows/run105-validation.yml`
- `.github/workflows/godot-validation.yml`

The production Director→MineralChunkController path is exercised with a real CropPlotVisual and CropRegistry. The test plants and advances a stable-ID wheat crop, externally queues the owning chunk root, then synchronizes the same coordinate. The replacement plot must retain the stable ID and restore/catch up stage, progress, moisture and reload timestamp. Repeating the same timestamp is idempotent; old root and plot weak references must clear. This extends Run 104's queued-root recovery coverage to crops without adding a crop mechanic or changing world-save schema (still version 1).

## Validation evidence

Exact candidate: `ded40bb1afe91dd8b403ace96f2d0c6447f3f0ed`.

- Full Godot 4.3 Run [#41651767754](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41651767754): all 471 numbered workflow steps successful; Run 105 gates #466–470 passed; cleanup, container shutdown and complete-job (#939–941) succeeded.
- Run 105 focused [#41651840241](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41651840241): 14/14.
- Compatibility: Run 92 [#41651840120](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41651840120) 13/13; Run 93 [#41651840308](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41651840308) 13/13; Run 94–100 [#41651840326](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41651840326) 39/39; Run 101 [#41651840222](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41651840222) 13/13; Run 102 [#41651840238](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41651840238) 13/13; Run 103 [#41651840390](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41651840390) 13/13; Run 104 [#41651840279](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41651840279) 13/13. Compatibility total 117/117.
- Initial focused cleanup failure [#41651381777](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41651381777) was caused by Git dubious ownership inside the container. Commit `66588a0cd2ca05dea9229c3d4007be131223d48c` added the workspace to `safe.directory`; `ded40bb` added a static guard. The initial failure remains historical and is not counted as a pass.

## Git state

- PR #247 merged.
- Merge commit: `564b36cd86510af3aaa7b5c7475fc7b8f2bee909`.
- Main at merge: same SHA.
- Previous Run 104 docs PR #246 was validated against the pre-Run-105 main and must be rebased before merging; this closeout supersedes its stale-base attempt.

## Limitations and next steps

- Local Godot executable unavailable; rendered GUI/GPU and physical iPhone QA remain untested.
- Post-merge main push CI for `564b36c...` is unconfirmed; connected status/workflow lookup returned no records.
- Main branch protection / required checks remain unresolved under [issue #236](https://github.com/qaqp980520-prog/2126-Survival/issues/236).
- Next: merge the rebased documentation closeout after its exact-head Godot validation succeeds, then begin Run 106 from the new main.

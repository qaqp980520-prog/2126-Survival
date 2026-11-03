# Run 104 Closeout — KROLL Stealth Grid and Queued-Root Recovery

Date: 2026-11-03  
Engine target: Godot 4.3+  
Feature PR: [#245](https://github.com/qaqp980520-prog/2126-Survival/pull/245)  
Merge commit: `7628fc980d739bd8000a916d59bcf306f8a9b31c`  
Final feature head: `ca1d2d146fa5f564b2cc1149be6ee7327999fe68`

## Delivered assets

### KROLL Stealth Grid M0.1

Path: `daily_games/KROLL_Stealth_Grid/`

- Three authored 9×9 sectors: Service Spine, Split Relay and Black Archive.
- Deterministic turn-based movement, guard patrols, forward line-of-sight, wall occlusion, access-key collection, exits, retry and one-time rewards.
- Maximum campaign reward: 300 points; replaying a cleared sector does not farm points.
- Keyboard, mouse and touch controls.
- Standalone `main.tscn` and repository-root `main_root.tscn`; portable rules loading supports both project roots.
- No external assets, plugins, network services or world-save changes.

Import: open `daily_games/KROLL_Stealth_Grid/project.godot` in Godot 4.3+ and run `main.tscn`. The repository Test Hub launches `main_root.tscn`.

### MineralChunkController queued-root recovery

Files:

- `systems/MineralChunkController.gd`
- `tests/mineral_grid_streaming_queued_root_recovery_test.gd`
- `tests/README_run104_queued_root_recovery.md`

When an existing chunk root is externally queued for deletion but remains valid, live getters omit it. A same-coordinate load invokes the normal unload/persistence path before registering a replacement. The unload path is not allowed to queue the already-queued root a second time. A production Director→Controller regression mutates a real SalvageCrate and gold MineralMiningNode, queues their shared root, syncs the same coordinate, and verifies stable-ID restoration into new instances plus release of old weak references.

World-save schema remains version 1.

## Validation evidence

Exact candidate: `ca1d2d146fa5f564b2cc1149be6ee7327999fe68`.

- Full Godot 4.3 Run [#41647196682](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41647196682): **468/468** job steps successful, zero failures/skips. Run 104 gates, post-checkout cleanup, container shutdown and complete-job succeeded.
- Run 104 focused [#41647196464](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41647196464): 13/13.
- Run 92 focused [#41647196424](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41647196424): 13/13.
- Run 93 focused [#41647196366](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41647196366): 13/13.
- Run 94–100 extended [#41647198263](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41647198263): 39/39.
- Run 101 focused [#41647196599](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41647196599): 13/13.
- Run 102 focused [#41647196586](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41647196586): 13/13.
- Run 103 focused [#41647196511](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41647196511): 13/13.
- Focused compatibility total: **117/117**, all zero failures/skips with successful cleanup/job completion.

Historical correction: candidate `1e8e24ba65d67404564f0bc3e8c7bb070f6b8b59` exposed two Split Relay patrol cells on walls. The corridor was corrected in `ca1d2d1`; the 16-turn safe route was re-simulated. The failed run is not counted as a pass.

## Git state

- PR #245: merged.
- Merge commit: `7628fc980d739bd8000a916d59bcf306f8a9b31c`.
- Main at feature merge: `7628fc980d739bd8000a916d59bcf306f8a9b31c`.
- A separate post-merge main push CI result has not surfaced through the connected commit-workflow lookup; it is unconfirmed, not passed/failed.

## Limitations and next steps

- Local Godot executable unavailable; local rendered GUI/GPU and physical iPhone QA remain untested.
- Main branch protection / required checks remain unresolved under [issue #236](https://github.com/qaqp980520-prog/2126-Survival/issues/236); the connected integration has no branch-protection write action.
- Next: finish documentation PR validation and update the Notion asset index; then continue with a distinct new Godot mini-game and the next existing-system reliability task.

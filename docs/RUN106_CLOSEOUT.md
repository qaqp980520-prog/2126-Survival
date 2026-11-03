# Run 106 Closeout — KROLL Prism Beam Lab and Async Staged-Root Lifecycle Guard

Date: 2026-11-04  
Engine target: Godot 4.3+  
Feature PR: [#249](https://github.com/qaqp980520-prog/2126-Survival/pull/249)  
Feature merge commit: `de56d39c2f9372bd90bc17a222f82df75180beea`  
Exact validated feature head: `fec150957bb9ad4b2849384883d0c44c8fbf8966`

## Delivered game — KROLL Prism Beam Lab M0.1

Path: `daily_games/KROLL_Prism_Beam_Lab/`

- Standalone 7×7 optical-routing puzzle with three authored facilities: Service Bend, Coolant Bypass and Vertical Relay.
- Four rotatable mirrors per board; deterministic ray tracing handles receiver hits, walls, bounds and loops.
- Independent enumeration of all 16 mirror-orientation states per level found exactly one receiver-reaching state for each board. This is a model check, not a substitute for engine tests.
- Scoring: 100 within par, otherwise 75; one-time reward per level; campaign maximum 300.
- Controls: click mirror or 1–4 to rotate; Space fires; R resets; N advances; C restarts.
- Standalone launch only; intentionally no Test Hub entry, so the existing 50-entry Test Hub contract is unchanged.
- No external assets, plugins, network services or world-save integration.

Import: open `daily_games/KROLL_Prism_Beam_Lab/project.godot` in Godot 4.3+ and run `main.tscn`.

Files:
- `daily_games/KROLL_Prism_Beam_Lab/project.godot`
- `daily_games/KROLL_Prism_Beam_Lab/main.tscn`
- `daily_games/KROLL_Prism_Beam_Lab/main.gd`
- `daily_games/KROLL_Prism_Beam_Lab/rules.gd`
- `daily_games/KROLL_Prism_Beam_Lab/tests/rules_test.gd`
- `daily_games/KROLL_Prism_Beam_Lab/tests/game_smoke_test.gd`
- `daily_games/KROLL_Prism_Beam_Lab/README.md`

## Delivered system change — async staged-root lifecycle guard

Files:
- `systems/MineralGridStreamingDirector.gd`
- `tests/mineral_grid_streaming_staged_root_lifecycle_test.gd`
- `tests/README_run106_staged_root_lifecycle.md`
- `.github/workflows/run106-validation.yml`
- `.github/workflows/run105-validation.yml`
- `.github/workflows/godot-validation.yml`

Every staged Node3D root is revalidated before the next factory call, immediately after factory callbacks, after frame yields, before commit, and before each individual Controller registration. Invalid, queued-for-deletion or parented roots abort with precise diagnostics:
- `staged_root_invalid`
- `staged_root_queued_for_deletion`
- `staged_root_parented`

The production regression makes the factory queue the first staged root while producing the second. It verifies abort before any Controller registration, complete staging cleanup, candidate release, preservation of the active chunk set, rollback and active-request-lock release.

No world-save schema or chunk serialization change; schema remains version 1.

## Validation evidence — exact feature head

- Full Godot 4.3 [Run #41662249016](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41662249016): **475 numbered steps passed**, zero failures/skips; post-checkout cleanup (#949), container shutdown (#950) and complete-job (#951) all succeeded.
- Run 106 focused [#41662249000](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41662249000): **12/12**.
- Combined Run 105–106 focused [#41662248958](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41662248958): **19/19**.
- Compatibility focused: Run 101 [#41662248984](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41662248984), Run 102 [#41662248993](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41662248993), Run 103 [#41662248967](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41662248967), Run 104 [#41662248908](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41662248908): **52/52** total.
- All accepted exact-head runs completed cleanup, container shutdown and complete-job.

Historical correction: initial compatibility run [#41661960393](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41661960393) exposed a GDScript parse error because an async-only check was misplaced in synchronous `sync_to_world_position`. Commit `fec1509` moved the check into the async request scope. The failed run remains historical and is not counted as a pass.

## Git state

- PR #249 merged.
- Merge commit: `de56d39c2f9372bd90bc17a222f82df75180beea`.
- Validated feature head: `fec150957bb9ad4b2849384883d0c44c8fbf8966`.
- Main at feature merge: `de56d39c2f9372bd90bc17a222f82df75180beea`.
- The connected commit-workflow lookup returned no separate main-push workflow record for the merge SHA; post-merge main-push validation is therefore unconfirmed, not claimed as passed.

## Limitations and next steps

- Local Godot executable unavailable; local rendered GUI/GPU and physical iPhone QA remain untested.
- Main branch protection remains unresolved under [issue #236](https://github.com/qaqp980520-prog/2126-Survival/issues/236); the connected GitHub tooling has no write action for branch-protection settings.
- World-save schema remains version 1.
- Next: finish rebased documentation closeout PR, then continue with a distinct Godot mini-game and a new production-system reliability task.

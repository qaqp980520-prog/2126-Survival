# Backrooms Production Seed-Change Auxiliary Rollback Regression — M0.1.5.1

## Purpose

Extend the production SurfaceWorld restore transaction regression to exercise the more destructive seed-change path before the Backrooms location layer is introduced. The parent M0.1.5 implementation already handles rollback after stamina or quick-use adapters partially mutate and fail, but the existing injected-failure tests did not change `world_seed`. This left the mine-window unload/rebuild/recovery branch without direct failure-injection coverage.

## Runtime changes

No runtime code changes are included. This milestone strengthens the production integration test only.

## Test changes

File: `tests/production_surface_world_test.gd`

- Both fail-once adapter cases now submit a candidate with a different valid `world_seed` and a different player position.
- The stamina failure is injected after the base restore and stamina adapter mutation.
- The quick-use failure is injected after the base restore, stamina application, and quick-use adapter mutation.
- Both cases assert the rollback report confirms `mine_window_restored`, `layer_state_restored`, and `mine_chunk_ready_restored`.
- The exact post-rollback save snapshot is compared for player position, streamed chunk IDs, minerals, crops, world objects, inventory, stamina, quick-use, world seed, location layer, mine depth, and surface return position.
- The `UndergroundMineDirector` managed chunk IDs are compared with the pre-attempt snapshot, and the persistent mine origin chunk must be loaded.

These assertions specifically exercise `_recover_underground_window()` after the candidate seed has caused the prior mine window to be unloaded and rebuilt.

## Dependencies and import

- Parent PR: [#329 — SurfaceWorld auxiliary restore rollback](https://github.com/qaqp980520-prog/2126-Survival/pull/329).
- Ancestor PR: [#328 — production Backrooms portal interaction](https://github.com/qaqp980520-prog/2126-Survival/pull/328).
- Godot 4.3 root project, `SurfaceWorld`, `WorldSessionController`, `UndergroundMineDirector`, mineral registry, world-object registry, stamina and quick-use adapters.
- No third-party packages, new autoloads, Project Settings, save-schema changes, or runtime behavior changes.
- Import: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.

## Validation status

- Local Godot executable is unavailable in this environment; no local engine run is claimed.
- Exact-head GitHub Actions Godot 4.3 Full Compatibility Gate is required before this version can be accepted.
- The parent PR #329 exact-head gate passed 553/553 with 0 failures and 0 skipped at HEAD `fe80489516c5eaa4c8408c3827841f48dd84b422`. That parent result does not validate this child test change.

## Branch and PR

- Branch: `test/surface-world-seed-change-aux-rollback-2026-11-12`.
- Base: parent PR #329 branch `fix/surface-world-restore-auxiliary-rollback-2026-11-12`.
- Initial branch point: `fe80489516c5eaa4c8408c3827841f48dd84b422`.
- Test commit: `def5593f8be142e3cb048b1d7e48c2799766f494`.
- This is a child stack. Do not merge it before #329 and #328. After the parent stack is integrated, reconcile this branch to main and rerun its exact-head gate.

## Scope boundary and next step

This version does not add the Backrooms location layer or perform a portal transition. It proves the existing SurfaceWorld rollback can recover its previous mine window when the world seed changes and a later auxiliary restore phase fails. The next transition milestone can then build on this transaction guarantee without treating the prototype save/load path as production evidence.

# SurfaceWorld Auxiliary Restore Rollback — M0.1.5

## Purpose

Close a transaction gap in the production SurfaceWorld save/restore path before adding a third Backrooms location layer. The base WorldSessionController already rolls back minerals, crops, inventory, world objects, player position and streaming when its own apply/stream phases fail. SurfaceWorld applies stamina and quick-use state after the base restore succeeds; previously, if either auxiliary adapter failed after partially mutating itself, the method returned false while the base world remained at the candidate state.

## Runtime changes

- `world/SurfaceWorld.gd`
  - Captures a complete base WorldSession snapshot before any target mine/surface synchronization.
  - Captures and validates the pre-restore stamina and quick-use payloads, plus player velocity, location-layer state, world seed, mine depth, surface return position and mine-window readiness.
  - If stamina or quick-use application fails after the base restore, restores the prior mine window (including the seed-change recovery path), reapplies the base WorldSession snapshot, restores both auxiliary adapters and restores the derived SurfaceWorld state.
  - Reports phase-specific failure with `rollback_complete` and per-subsystem diagnostics instead of returning a false result with the candidate world still applied.
  - Keeps the successful restore path and schema-1 payload unchanged.

- `tests/production_surface_world_test.gd`
  - Adds fail-once adapters that deliberately mutate their candidate state and then return false on the first load.
  - Exercises both stamina failure and quick-use failure after the base world restore has succeeded.
  - Verifies the adapter's partial mutation is undone and the exact player position, loaded chunk set, mineral registry, crop registry, world-object registry, inventory, stamina and quick-use payloads match the pre-attempt snapshot.
  - Verifies the restore report identifies the failing phase and reports a complete rollback.

## Files and dependencies

- `world/SurfaceWorld.gd`
- `tests/production_surface_world_test.gd`
- `docs/BACKROOMS_WORLDSESSION_AUXILIARY_RESTORE_ROLLBACK_M0_1_5.md`
- Depends on Godot 4.3, `WorldSessionController`, `MineralGridStreamingDirector`, `UndergroundMineDirector`, `SurvivalStamina`, `SurvivalQuickUse`, and the existing registry/bridge save contracts.
- No third-party packages, new autoloads, input actions, Project Settings, or save-schema changes.
- Import: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.

## Branch and PR

- Parent prerequisite: PR [#328](https://github.com/qaqp980520-prog/2126-Survival/pull/328), branch `feature/backrooms-production-player-group-contract-2026-11-12`.
- This implementation branch is stacked on PR #328 at parent HEAD `b4de19abf9b14178176c3d920e407758fdf17302`.
- PR #329 targets the PR #328 branch, not main. Keep both PRs unmerged until the parent exact-head gate and this child exact-head gate succeed and independent review is obtained.
- No main change or merge is part of this milestone.

## Validation status

- Static source review completed for the new snapshot, rollback helper and failure-injection fixtures.
- Local Godot executable is unavailable in the current environment; no local engine test is claimed.
- Exact-head GitHub Actions Godot 4.3 Full Compatibility Gate is required for this branch. The parent PR #328 gate was still running when this child work began; its result must be recorded separately and must not be substituted for this child HEAD.
- Expected new regression coverage is part of the existing `production_surface_world_test.gd` workflow step, so no workflow-file edit is required.

## Deliberate scope boundary

This milestone does not add the `backrooms` location layer, instantiate a Backrooms runtime, spawn production portals, or consume the production `portal_entered` signal. It only makes the existing SurfaceWorld restore path safe when a post-base auxiliary adapter fails. The production transition contract remains M0.1.4.

## Next steps

1. Complete the parent PR #328 exact-head gate and obtain independent review.
2. Complete this branch's exact-head Godot 4.3 Full Compatibility Gate and fix any regression before further transition work.
3. Use this rollback behavior as a prerequisite for the future Backrooms entry/return transaction, then add Backrooms layer/runtime state only with failure-injection coverage at each apply phase.

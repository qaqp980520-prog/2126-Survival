# M0.3.40 — Late Participant Restore Failure Recovery

## Purpose

Prove that a failure from a late world participant (`SurvivalStamina` or `SurvivalQuickUse`) after the base world/stream restore has already changed live state is retained as a world recovery barrier, remains blocked while the participant keeps rejecting, and can be retried to an exact pre-attempt snapshot after the original participant is restored.

This closes a focused regression-coverage gap in the production `SurfaceWorld` save/load transaction. The production recovery wrapper already retains the pre-restore payload when `_restore_stream_state_impl()` reports `rollback_complete=false`; this asset verifies both late participant exits against that contract.

## Changes

- Add failure-injection subclasses of the real `SurvivalStamina` and `SurvivalQuickUse` scripts. They preserve the original serialized state but reject `load_save_dict()`.
- Run a real `SurfaceWorld.restore_stream_state()` to a different chunk window so the base restore mutates the world before the late participant rejects.
- Assert the report phase is `stamina_restore` or `quick_use_restore`, with `rollback_complete=false`.
- Assert new snapshots are blocked while the recovery barrier is active.
- Retry while the injected participant still rejects and assert the barrier remains.
- Restore the original participant, call `retry_save_recovery()`, and compare the complete serialized world snapshot plus active chunk IDs to the exact pre-attempt state.

## Files

- `tests/production_surface_world_test.gd` — adds two failure-injection cases and a shared recovery assertion helper.
- `docs/PRODUCTION_SURFACE_WORLD_LATE_PARTICIPANT_RECOVERY_M0_3_40.md` — this version record.

No production GDScript, save schema, storage layout, or runtime behavior is changed by this test-only increment.

## Dependencies

- Parent feature PR: [#452 — Production SurfaceWorld durable save/load](https://github.com/qaqp980520-prog/2126-Survival/pull/452)
- Parent HEAD at branch creation: `519256ef5a909b0e1657725a4f2ccd1391ea16d4`
- Existing implementation: `world/SurfaceWorld.gd` methods `_restore_stream_state_with_snapshot()`, `_restore_stream_state_impl()`, and `retry_save_recovery()`.
- Participant implementations: `systems/SurvivalStamina.gd` and `systems/SurvivalQuickUse.gd`.

## Import / Test

No asset import or external dependency is required. The existing production SurfaceWorld test entry executes the regression:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
```

The dedicated Production SurfaceWorld Save Validation workflow and full Godot 4.3 Compatibility Gate must pass on the exact PR HEAD.

## Validation status

Pending exact-head GitHub Actions at the time this version record was created. The local environment has no Godot executable; no local engine pass is claimed.

## Limitations

- This is failure-injection coverage for late participant application; it does not simulate operating-system process termination.
- No persistent disk recovery journal or autosave is introduced.
- No main-branch change is implied.

## Next Step

Run exact-head focused and full Godot 4.3 CI. If successful, integrate this child into PR #452 using the verified parent SHA, then rerun exact-head validation on the updated parent branch. Keep the parent PR unmerged to main pending the parent-first release review.
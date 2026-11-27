# M0.3.41 — Production SurfaceWorld Verified First-write Temp Recovery

## Purpose

Recover a fully validated `.tmp` save left by a process interruption during the very first save, when no committed primary, backup, or `.previous` file exists.

Before this correction, `recover_interrupted_write()` returned `no_interrupted_write` whenever `.previous` was absent. A first save that had completed the temp write, flush, envelope validation, and payload validation but stopped before promotion could therefore leave a valid `.tmp` that `load_game()` ignored.

## Recovery policy

When `.previous` is absent:

1. Validate the primary. If it is valid, keep it authoritative; do not promote an uncommitted temp.
2. Validate the committed `.bak`. If it is valid, leave temp promotion to the normal backup fallback path; the committed backup takes precedence over an uncommitted temp.
3. Only when neither primary nor backup is valid, validate `.tmp` with the full envelope checksum and world-payload validator.
4. Copy the validated temp to `.restore.tmp`, validate the copy byte-for-byte, archive an existing invalid primary, promote the restore copy, and validate the resulting primary byte-for-byte.
5. Keep the original `.tmp` as the retry source until the promoted primary is verified. Remove it after successful verification; a cleanup failure is reported as a warning rather than invalidating the verified primary.
6. If promotion fails, restore the archived primary when possible and keep the validated temp source for a later retry. Recovery remains blocked until a later attempt succeeds.

The `.previous` recovery path remains unchanged.

## Versioned files

- `systems/SurfaceWorldSaveStore.gd` — verified first-write temp detection and guarded promotion.
- `tests/production_surface_world_test.gd` — first-write restart recovery, committed-backup precedence, invalid-temp preservation, corrupt-primary archival, and promotion-failure rollback/retry.
- `docs/PRODUCTION_SURFACE_WORLD_FIRST_WRITE_TEMP_RECOVERY_M0_3_41.md` — this version record.

## Dependencies and integration

- Parent feature: [PR #452 — Production SurfaceWorld durable save/load](https://github.com/qaqp980520-prog/2126-Survival/pull/452).
- Exact parent HEAD at branch creation: `aa113f37b4c84a3c34e54e968a815f877789134e`.
- Existing storage implementation: `systems/SurfaceWorldSaveStore.gd`.
- Production entry point: `world/SurfaceWorld.gd`, through `_recover_interrupted_save_file()` called by `save_game()` and `load_game()`.

## Import and test

No asset import, project setting, Autoload, scene change, or external dependency is required.

The production save validation workflow imports the root Godot project and runs:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
```

Exact-head Dedicated Production SurfaceWorld Save Validation and Full Godot 4.3 Compatibility Gate are required before integration. CI is pending for this branch at the time this document is created.

## Limitations

- This is a recovery improvement for a verified temp file; it does not claim OS-level power-loss durability or filesystem `fsync` guarantees.
- It does not add autosave, a disk-persisted in-memory world rollback journal, or a new save-schema version.
- Local Godot is unavailable in this run; no local engine pass is claimed.
- GPU/rendering, mobile-device, and target-hardware validation are outside the headless CI scope.

## Next step

Run the exact child-head dedicated save validation and full Godot 4.3 gate. If both pass, retain the child PR as Draft until parent-first independent review is complete, then integrate into the PR #452 feature branch with an expected-SHA fast-forward and rerun exact-head parent CI. Do not merge to main.
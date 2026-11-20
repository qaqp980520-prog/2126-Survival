# M0.1.86 — Fresh-World Seed Restoration Regression

## Purpose

Strengthen M0.1.85's production SurfaceWorld + Hound durable-envelope test so it proves that a newly instantiated world restores the saved world seed from disk, rather than inheriting the source world's seed before loading.

## Files

- `tests/surface_world_hound_file_roundtrip_test.gd`
- `docs/BACKROOMS_FRESH_WORLD_SEED_RESTORE_REGRESSION_M0_1_86.md`

## Previous coverage gap

The M0.1.85 fixture assigned `WORLD_SEED` to both the source SurfaceWorld and the restored SurfaceWorld before either entered the scene tree. That made the restored world's pre-load seed equal the saved seed, so the test did not exercise the production seed-change restore path.

The production `SurfaceWorld.restore_world_envelope()` validates the saved SurfaceWorld payload and delegates to `restore_stream_state()`, which validates and applies the persisted seed before rebuilding the target stream. The regression should exercise that behavior from a genuinely fresh scene instance.

## Change

- Keep the deterministic `WORLD_SEED = 20261118` on the source world so Level 2 portal entry and Hound selection remain reproducible.
- Instantiate the restore target directly from `world/SurfaceWorld.tscn` without overriding its scene-default seed.
- Add the fresh world to the tree and assert its seed differs from the saved fixture seed before calling `load_game()`.
- Retain the post-load assertion that the restored seed equals `WORLD_SEED`.
- Keep the existing malformed-primary / `.bak` recovery, Hound A-to-B ownership transfer, immutable spawn identity, owner revision, exactly-one reconstruction and fresh NavigationAgent3D assertions.

## Dependencies

- PR #402: current cell-local Backrooms navigation and production maze runtime.
- PR #404: `WorldEnvelopeFileStore`, production SurfaceWorld save/load and combined Hound envelope round-trip.
- Godot 4.3; no new third-party dependency, autoload, project setting or input action.

## Import and execution

Root project import:

```bash
godot --headless --path . --editor --import --quit
```

Focused test:

```bash
godot --headless --path . --script res://tests/surface_world_hound_file_roundtrip_test.gd
```

The existing Full Compatibility Gate and focused SurfaceWorld File Persistence workflow already execute this test, so the source-file change triggers both exact-head gates.

## Acceptance criteria

- The fresh restore target begins with a seed different from the saved source seed.
- `load_game()` restores the saved seed from the validated primary/backup envelope.
- The active Level 2 Session and Hound owner/runtime record still restore correctly.
- Backup recovery still repairs the primary and preserves the malformed primary as `.corrupt`.
- Exactly one Hound is reconstructed under the committed owner cell with a newly created NavigationAgent3D.

## Validation status

- Static review: the previous pre-load seed assignment was removed only from the restore target; the deterministic source-world seed remains unchanged.
- Godot 4.3 runtime validation: pending on the new exact PR HEAD in the existing focused and full workflows.
- No local Godot executable is available in the authoring environment.
- Physical iPhone/iPad and hardware-GPU validation remain outside this regression.

## Next step

Run the focused persistence workflow and Full Compatibility Gate on the new exact HEAD. Keep PR #404 unmerged and do not claim acceptance until both current-head gates and their complete logs are audited.

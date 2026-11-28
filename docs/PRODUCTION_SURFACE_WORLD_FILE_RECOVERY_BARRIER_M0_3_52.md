# M0.3.52 — Production File-Recovery Barrier and Retry Coverage

## Purpose

Close an integration-test gap in M0.3.51. The prior dual-failure regression invoked the static SaveStore recovery function directly, then retried through `SurfaceWorld.load_game()`. It proved disk evidence preservation and successful retry, but did not prove that the production world wrapper establishes its file-recovery barrier after the same failure, blocks public save/load calls, and clears the barrier only after `retry_save_recovery()` succeeds.

## Versioned files

- `world/SurfaceWorld.gd` — add an optional rename-operation parameter to the private `_recover_interrupted_save_file()` wrapper and pass it to SaveStore. All normal production call sites omit it, preserving the default filesystem behavior; the optional callable exists to deterministically exercise the wrapper's failure path.
- `tests/production_surface_world_test.gd` — add a separate per-process invalid-Previous / corrupt Primary / invalid Backup / verified Temp fixture. Inject both Temp promotion and Primary archive rollback failures through the world wrapper, assert the world recovery barrier and public API fail-closed behavior, then clear injection and retry through `retry_save_recovery()` followed by public `load_game()`.
- `docs/PRODUCTION_SURFACE_WORLD_FILE_RECOVERY_BARRIER_M0_3_52.md` — this version record.

## Dependencies and staging

- Production durable Save/Load: PR #452.
- Interrupted-write recovery: PR #459.
- Invalid-Previous Temp fallback and double-failure preservation: PR #461.
- Exact base at branch update: `b7ffb4e5d1334a0bd7005a2ef4cbb7e4e9b42762`.
- Existing PR #461 branch: `fix/save-recover-temp-after-invalid-previous-2026-11-28-run12`.
- Pre-change backup branch: `backup/pr461-before-world-file-recovery-barrier-test-2026-11-28-run15`, preserving exact HEAD `b7ffb4e5d1334a0bd7005a2ef4cbb7e4e9b42762`.
- This extends PR #461 in place; it is not a new stacked PR and remains Draft pending parent-first independent review.

## Failure sequence and assertions

1. Create corrupt Primary, invalid Previous, invalid Backup, and a checksum/payload-validated Temp.
2. Call the production world's private file-recovery wrapper with an injected rename operation that fails Temp promotion and Primary archive rollback.
3. Require the wrapper to return failure and set `interrupted_save_file_recovery_required` with the complete nested SaveStore report.
4. Require both corrupt archives and the valid Temp to remain byte-for-byte intact; Primary must remain absent and the owned restore staging file must be gone.
5. Require public `save_game()` and `load_game()` to fail closed with phase `recovery_barrier` without consuming or changing the Temp.
6. Remove the injected failure and call `retry_save_recovery()`; require exact Temp promotion, archive/Backup preservation, and barrier clearance.
7. Call public `load_game()` and require the normal `loaded_from_primary` path with no remaining barrier.

## Import and test

No import, scene, Autoload, Project Settings, save schema, or external dependency changes.

Repository-root commands:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
```

Both exact-head Dedicated Production SurfaceWorld Save Validation and Full Godot 4.3 Compatibility Gate are required.

## Validation status at creation

- Code/test changes are based on PR #461 exact HEAD `b7ffb4e5d1334a0bd7005a2ef4cbb7e4e9b42762`.
- Exact-head CI is pending after the branch update; no pass is claimed at creation.
- The authoring environment has no local Godot executable; no local engine pass is claimed.

## Limitations and next step

- The optional rename callable is a deterministic test seam on a private wrapper; normal `save_game()` / `load_game()` calls use the default filesystem operation.
- Headless CI does not prove power-loss durability, filesystem `fsync` guarantees, GPU/rendering, Xvfb/Mesa, iPhone/iPad, or target-device behavior.
- Windows filesystem and symlink tests remain subject to platform-specific skips.
- Keep PR #461 Draft until parent-first independent review of #452 → #459 → #461 is complete. Do not merge main.

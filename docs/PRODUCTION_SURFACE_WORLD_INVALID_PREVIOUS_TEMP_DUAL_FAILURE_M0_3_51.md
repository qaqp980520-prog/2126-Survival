# M0.3.51 — Invalid-Previous Temp Recovery Dual-failure Rollback Coverage

## Purpose

Extend M0.3.50's production recovery regression to cover the case where the invalid staged `.previous` has already been archived, verified-temp promotion fails, and rollback of the invalid Primary archive also fails. The test must prove that both corrupt archives and the validated source Temp remain available, and that a later retry through the real `SurfaceWorld.load_game()` entry point can still recover the world.

## Versioned files

- `tests/production_surface_world_test.gd` — add an isolated per-process fixture with corrupt Primary, invalid `.previous`, invalid `.bak`, and a fully validated `.tmp`; inject both promotion and archive-rollback failures; verify exact evidence preservation; then retry through production `load_game()`.
- `docs/PRODUCTION_SURFACE_WORLD_INVALID_PREVIOUS_TEMP_DUAL_FAILURE_M0_3_51.md` — this version record.

## Dependencies and staging

- Production durable save/load parent: PR #452.
- First-write and interrupted-write recovery: PR #459.
- Invalid-previous Temp recovery implementation and failure-atomicity coverage: PR #461.
- PR #461 exact base at this run: `959b2f85328510d8c4ab36e763c3f9c363f4c995`.
- Working branch: `fix/save-recover-temp-after-invalid-previous-2026-11-28-run12`.
- Pre-change HEAD backup: `backup/pr461-before-invalid-previous-temp-double-failure-2026-11-28-run13`, preserving `dea895774324a5c628615f3ffd41ff4c529ecadf`.
- This is additional test coverage within the existing PR #461 staging branch; it is not a standalone release and must remain Draft pending parent-first review.

## Failure sequence covered

1. Write a corrupt Primary, corrupt staged `.previous`, corrupt committed `.bak`, and a valid checksum- and payload-validated `.tmp`.
2. Inject failure when moving `.restore.tmp` into Primary.
3. Inject a second failure when rolling the corrupt Primary archive back to Primary.
4. Require a top-level and nested `recovery_required` result.
5. Require Primary to remain absent rather than falsely reported as recovered.
6. Require the source Temp and invalid Backup to remain byte-for-byte intact.
7. Require the owned `.restore.tmp` staging file to be cleaned.
8. Require invalid Previous and corrupt Primary to survive in two distinct archive paths with their exact original bytes.
9. Remove fault injection and retry through the real `SurfaceWorld.load_game()` entry point.
10. Require the exact Temp to become Primary, the Temp to be consumed only after successful promotion, both corrupt archives and the invalid Backup to remain intact, and the normal `loaded_from_primary` report.

The existing generic first-write dual-failure regression remains in place; this new fixture covers the additional invalid-Previous archive stage and its interaction with Primary rollback.

## Import and test

No asset import, Project Settings, scene, Autoload, save-schema, production runtime code, or external dependency changes.

From the repository root:

~~~bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
~~~

Both exact-head Dedicated Production SurfaceWorld Save Validation and Full Godot 4.3 Compatibility Gate are required before promotion.

## Validation status at creation

- Test change commit: `b1bb53059ee04071d6f2112b65e067a07d51f7c5`.
- The version document is added in a following commit on the same PR #461 branch.
- Exact-head Godot 4.3 CI for the new candidate is pending; no pass is claimed here.
- Local Godot is unavailable in the authoring container; no local engine pass is claimed.

## Limitations and next step

- Headless CI does not prove OS-level power-loss durability, filesystem `fsync` guarantees, GPU/rendering, Xvfb/Mesa, iPhone/iPad, or target-device behavior.
- Windows symlink and filesystem behavior remains subject to existing platform-specific test skips.
- After both exact-head workflows pass, update PR #461 and this version record with the final evidence. Keep the PR Draft until parent-first independent review of #452 → #459 → #461 is complete; do not merge to main.

# M0.3.45 — Non-destructive Symlink Test Fixture Isolation

## Purpose

Prevent the production save regression suite from deleting pre-existing user-data entries while preparing symbolic-link fixtures. A test must never remove a file or symlink merely because a fixed fixture name is already occupied.

## Versioned files

- `tests/production_surface_world_test.gd` — all save-path symlink fixtures now use a per-run namespace derived from `Time.get_ticks_usec()`; an occupied path causes a fail-closed test result instead of deletion. The test removes only symlinks successfully created by the current invocation.
- `docs/PRODUCTION_SURFACE_WORLD_SYMLINK_TEST_FIXTURE_ISOLATION_M0_3_45.md` — this version record.

## Dependencies

- Parent production persistence feature: [PR #452](https://github.com/qaqp980520-prog/2126-Survival/pull/452).
- Child recovery and archive collision work: [PR #459](https://github.com/qaqp980520-prog/2126-Survival/pull/459).
- Prior archive symlink guard: [M0.3.44](https://github.com/qaqp980520-prog/2126-Survival/blob/fix/recover-verified-first-write-temp-2026-11-27-run11/docs/PRODUCTION_SURFACE_WORLD_CORRUPT_ARCHIVE_SYMLINK_COLLISION_M0_3_44.md).

## Behavior

- Replace fixed `run451_*` and `run461_*` fixture names with a unique per-run prefix.
- Add `_user_entry_is_occupied()` to check files, directories, and symlink entries before writing or creating a link.
- Remove pre-test cleanup that could delete an unrelated existing symlink or regular file.
- Treat an unexpected occupied candidate as a failed fixture setup; never delete it to continue.
- Track only successfully created end-to-end symlinks and remove only those entries during cleanup.
- Use the unique prefix for Primary, Temp, target, and archive sidecars so `_cleanup_save_test_files()` is scoped to this test run.

## Import and test

No asset import, scene, Project Settings, Autoload, save-schema migration, or external dependency is required. This is test-harness isolation only; production runtime GDScript is unchanged.

The regression runs through the existing root Godot 4.3 workflows:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
```

The exact-head Dedicated Production SurfaceWorld Save Validation and Full Godot 4.3 Compatibility Gate must both pass before this version is considered validated.

## Validation status

Pending exact-head CI for the new test fixture isolation commit. No local Godot run is claimed because the working container has no Godot executable.

## Limitations

- Windows may skip symlink-specific fixtures when Developer Mode or elevated privileges are unavailable; the test must report that skip explicitly.
- This change does not modify production save recovery behavior and does not claim OS-level power-loss durability or filesystem `fsync` guarantees.
- GPU/rendering, Xvfb/Mesa, mobile, and target-device QA remain outside the headless CI scope.

## Next step

Run exact-head Dedicated Save Validation and Full Godot 4.3 Gate. If both pass, update PR #459 with the final evidence, keep it Draft pending parent-first independent review, and only then integrate into PR #452 with an expected-SHA fast-forward and rerun the parent gate. Do not merge to main.

## Validation history — Run 463

The initial intermediate HEAD `58ce0d4d00e008dd7def650d8afe16155f763c42` failed because the test helper was declared twice. The duplicate declaration was removed in code/test commit `5954469b33b23f22e8195e1a3236e2412a2a5f25`; the corrected test file contains exactly one helper declaration.

The corrected code/test commit `5954469b33b23f22e8195e1a3236e2412a2a5f25` passed:

- Dedicated Production SurfaceWorld Save Validation [46022706468](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/46022706468): **success, 10/10 steps, 461 PASS markers**.
- Full Godot 4.3 Compatibility Gate [46022706794](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/46022706794): **success, 553/553 steps**.
- Full Gate decoded log: 84,579 lines, 7,740,107 characters, 78,234 PASS markers, 26 warnings, and no actual Script/Parse/Runtime/ERROR/FAIL diagnostics after excluding echoed shell-guard commands. No ObjectDB leak or Orphan StringName report was found.
- Production SurfaceWorld integration (205), underground mining integration (211), UndergroundMineDirector (212), all-layer lift lifecycle (300), terrain patch persistence (310), randomized 4x4 terrain soak (426), historical 60-layout soak (431), and clean validation workspace (550) all passed.

This document update is documentation-only. The live exact-head check status for the latest PR #459 HEAD must be read from [PR #459](https://github.com/qaqp980520-prog/2126-Survival/pull/459) and its linked Actions runs; this static version record does not claim that a later documentation-only HEAD has already passed.
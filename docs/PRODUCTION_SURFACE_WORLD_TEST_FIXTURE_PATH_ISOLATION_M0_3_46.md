# M0.3.46 — Per-process Save Test Fixture Ownership and Non-destructive Cleanup

## Purpose

Extend M0.3.45 beyond the symlink-only fixtures. A review found that the broader production save/load regression still used fixed `user://production_surface_world_*_test.json` paths and called cleanup before setup. That could delete or truncate an unrelated pre-existing file if a developer ran the test in a user-data directory containing the same name. Fixed paths also made parallel Godot test processes more likely to collide.

## Versioned files

- `tests/production_surface_world_test.gd` — all save-test base paths now use one per-process namespace; fixtures must claim an unused save family before writing; writers refuse unclaimed or occupied paths; cleanup is restricted to claimed fixture families and runs on normal or early test completion.
- `docs/PRODUCTION_SURFACE_WORLD_TEST_FIXTURE_PATH_ISOLATION_M0_3_46.md` — this version record.

## Dependencies

- Parent production persistence feature: [PR #452](https://github.com/qaqp980520-prog/2126-Survival/pull/452).
- Recovery and archive-collision child: [PR #459](https://github.com/qaqp980520-prog/2126-Survival/pull/459).
- M0.3.45 symlink fixture isolation: [version record](https://github.com/qaqp980520-prog/2126-Survival/blob/fix/recover-verified-first-write-temp-2026-11-27-run11/docs/PRODUCTION_SURFACE_WORLD_SYMLINK_TEST_FIXTURE_ISOLATION_M0_3_45.md).

## Behavior

- Build a fixture namespace from `OS.get_process_id()` and `Time.get_ticks_usec()`, separating simultaneous processes as well as repeated test invocations.
- Route reserved-path, symlink, save, blocked-save, promotion, interrupted-write, first-write recovery, JSON numeric, invalid-save, invalid-temp, corrupt-primary, and rollback-failure fixtures through the namespace helper.
- Claim a save base only when the primary, all supported sidecars, and visible corrupt-archive entries are unused.
- Refuse duplicate claims, paths outside the current run namespace, and writes to unclaimed or occupied entries. `_replace_owned_test_text()` is reserved for deliberate corruption fixtures and can replace only an existing regular file inside a claimed save family; it rejects links, directories, and unclaimed paths.
- Release ownership after cleanup; a test that deliberately resets and reuses a fixture path must explicitly claim it again before writing.
- Clean only claimed save families, relative to the fixture's actual parent directory; do not scan or delete unrelated fixed global names.
- Clean any still-claimed save families in the test finish path, including early failure exits.
- Add an occupied-file regression proving that claim and write operations fail closed and preserve the sentinel bytes.

## Import and test

No asset import, scene, Project Settings, Autoload, save-schema migration, production runtime GDScript, or external dependency is required.

Run the existing root Godot 4.3 checks:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
```

The exact-head Dedicated Production SurfaceWorld Save Validation and Full Godot 4.3 Compatibility Gate must both pass.

## Validation status

The implementation/test candidate `70e6b30b2d54f70986c39aa6acb01c633ef9dd01` completed both exact-head workflows successfully:

- Full Godot 4.3 Compatibility Gate [46080303260](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/46080303260): **Success, 553/553 reported steps**, including clean validation workspace.
- Dedicated Production SurfaceWorld Save Validation [46080303177](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/46080303177): **Success, 10/10 steps**.
- Full Gate log: 84,584 lines, 7,743,035 characters, 78,239 PASS markers; zero actual Godot Script/Parse/Runtime/ERROR/FAIL diagnostics after excluding CI shell-guard command echoes; zero ObjectDB leak and Orphan StringName reports.
- 26 warnings were classified, not hidden: 19 filled-`draw_rect` width warnings, 1 nested KROLL project warning, 4 mineral-grid rollback warnings from explicit failure/lifecycle injection, 1 pending lifecycle recovery-barrier warning, and 1 underground rollback warning from an explicit restore-rejection test.

The first candidate `b383ce3c...` failed Dedicated Validation due to test-fixture setup (the no-overwrite writer correctly rejected a retained temp and intentional corruption fixtures needed a restricted replacement helper). The fixture setup was corrected; the final implementation/test candidate `70e6b30b...` passed both workflows.

This document update is documentation-only. Its new document commit still requires exact-head CI; do not transfer the `70e6b30b...` results to a later commit until the new Full Gate and Dedicated workflow complete. No local Godot run is claimed; the authoring container does not have a Godot executable.

## Limitations

- Symlink-specific assertions may be explicitly skipped on Windows when Developer Mode or elevated privileges are unavailable.
- This is test-harness path isolation, not a change to production save recovery, save format, or filesystem durability guarantees.
- It does not claim power-loss durability, filesystem `fsync` guarantees, GPU/rendering, Xvfb/Mesa, mobile, or target-device QA.

## Next step

Validate the exact candidate HEAD with Dedicated Save Validation and the full Godot 4.3 gate. If both pass, fast-forward the tested candidate into PR #459 with an expected-SHA guard, update the PR's exact-head evidence, and keep it Draft pending parent-first independent review. Do not merge to main.
